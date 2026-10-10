import 'package:supabase_flutter/supabase_flutter.dart';

import 'roles.dart';

/// Every call the app makes to the backend lives in this file.
class Api {
  static SupabaseClient get _db => Supabase.instance.client;

  /// Logins use a username and PIN. Supabase wants an email, so each username
  /// maps to a made-up one that nobody sees (see manage-staff function).
  static String _emailFor(String username) =>
      '${username.trim().toLowerCase()}@wardmap.local';

  static Future<void> logIn(String username, String pin) =>
      _db.auth.signInWithPassword(email: _emailFor(username), password: pin);

  static Future<void> logOut() => _db.auth.signOut();

  static bool get isLoggedIn => _db.auth.currentSession != null;

  static Future<Staff> me() async {
    final row = await _db
        .from('staff')
        .select()
        .eq('id', _db.auth.currentUser!.id)
        .single();
    return Staff.fromRow(row);
  }

  static Future<List<Staff>> colleagues() async {
    final rows = await _db
        .from('staff')
        .select()
        .order('full_name', ascending: true);
    return rows.map(Staff.fromRow).toList();
  }

  /// Patients I can see (my care teams, plus juniors' patients I oversee),
  /// with their ward name. Discharged patients are left out.
  static Future<List<Map<String, dynamic>>> currentPatients() async {
    return await _db
        .from('patients')
        .select(
          'id, mrn, full_name, admitted_at, ward_id, wards(name), beds(label)',
        )
        .isFilter('discharged_at', null)
        .order('admitted_at', ascending: true);
  }

  /// The database skips rows I'm not allowed to change instead of failing,
  /// so updates and deletes ask for the changed rows back and check.
  static Future<void> _mustChange(
    PostgrestTransformBuilder<List<Map<String, dynamic>>> query,
  ) async {
    final changed = await query;
    if (changed.isEmpty) {
      throw Exception('You don\'t have permission to do that.');
    }
  }

  // ---- Wards and beds ----

  static Future<List<Map<String, dynamic>>> wards() =>
      _db.from('wards').select('id, name').order('name', ascending: true);

  /// Beds in a ward, in natural order (Bed 2 before Bed 10).
  static Future<List<Map<String, dynamic>>> beds(String wardId) async {
    final beds = await _db
        .from('beds')
        .select('id, label')
        .eq('ward_id', wardId);
    int number(Map b) => int.tryParse(b['label']) ?? 1 << 30;
    return beds..sort((a, b) {
      final byNumber = number(a).compareTo(number(b));
      return byNumber != 0
          ? byNumber
          : (a['label'] as String).compareTo(b['label']);
    });
  }

  /// Ids of taken beds in a ward, including beds whose patient I can't see.
  static Future<Set<String>> occupiedBeds(String wardId) async {
    final rows = await _db.rpc(
      'ward_occupied_beds',
      params: {'p_ward_id': wardId},
    );
    return {for (final id in rows as List) id as String};
  }

  /// Admin only (the database refuses anyone else).
  static Future<void> addWard(String hospitalId, String name) => _db
      .from('wards')
      .insert({'hospital_id': hospitalId, 'name': name.trim()});

  static Future<void> renameWard(String wardId, String name) => _mustChange(
    _db.from('wards').update({'name': name.trim()}).eq('id', wardId).select(),
  );

  static Future<void> deleteWard(String wardId) =>
      _mustChange(_db.from('wards').delete().eq('id', wardId).select());

  static Future<void> addBed(String hospitalId, String wardId, String label) =>
      _db.from('beds').insert({
        'hospital_id': hospitalId,
        'ward_id': wardId,
        'label': label.trim(),
      });

  static Future<void> deleteBed(String bedId) =>
      _mustChange(_db.from('beds').delete().eq('id', bedId).select());

  // ---- Patients ----

  /// Current patients in one ward that I can see.
  static Future<List<Map<String, dynamic>>> wardPatients(String wardId) => _db
      .from('patients')
      .select('id, mrn, full_name, bed_id')
      .eq('ward_id', wardId)
      .isFilter('discharged_at', null);

  static Future<Map<String, dynamic>> patient(String id) => _db
      .from('patients')
      .select('*, wards(name), beds(label)')
      .eq('id', id)
      .single();

  /// Puts the patient in a ward (and bed), and me on their care team.
  static Future<String> admitPatient({
    required String wardId,
    String? bedId,
    required String mrn,
    required String fullName,
    DateTime? dateOfBirth,
    String? sex,
    String? ownerId,
  }) async {
    final id = await _db.rpc(
      'admit_patient',
      params: {
        'p_ward_id': wardId,
        'p_bed_id': bedId,
        'p_mrn': mrn.trim(),
        'p_full_name': fullName.trim(),
        'p_date_of_birth': dateOfBirth?.toIso8601String().substring(0, 10),
        'p_sex': sex,
        'p_owner_id': ownerId,
      },
    );
    return id as String;
  }

  static Future<void> transferPatient(
    String id,
    String wardId,
    String? bedId,
  ) => _mustChange(
    _db
        .from('patients')
        .update({'ward_id': wardId, 'bed_id': bedId})
        .eq('id', id)
        .select(),
  );

  /// Discharging also frees the bed.
  static Future<void> dischargePatient(String id) => _mustChange(
    _db
        .from('patients')
        .update({
          'discharged_at': DateTime.now().toUtc().toIso8601String(),
          'bed_id': null,
        })
        .eq('id', id)
        .select(),
  );

  // ---- Patient record sections (see record_sections.dart) ----

  static Future<List<Map<String, dynamic>>> records(
    String table,
    String patientId,
    String orderBy,
  ) => _db.from(table).select().eq('patient_id', patientId).order(orderBy);

  static Future<void> addRecord(
    String table,
    String hospitalId,
    String patientId,
    Map<String, dynamic> values,
  ) => _db.from(table).insert({
    ...values,
    'hospital_id': hospitalId,
    'patient_id': patientId,
  });

  static Future<void> updateRecord(
    String table,
    String id,
    Map<String, dynamic> values,
  ) => _mustChange(_db.from(table).update(values).eq('id', id).select());

  static Future<void> deleteRecord(String table, String id) =>
      _mustChange(_db.from(table).delete().eq('id', id).select());

  static Future<void> setTaskDone(String id, bool done) => updateRecord(
    'tasks',
    id,
    done
        ? {
            'done_at': DateTime.now().toUtc().toIso8601String(),
            'done_by': _db.auth.currentUser!.id,
          }
        : {'done_at': null, 'done_by': null},
  );

  static Future<void> setDischargeSummary(String patientId, String text) =>
      _mustChange(
        _db
            .from('patients')
            .update({'discharge_summary': text})
            .eq('id', patientId)
            .select(),
      );

  /// Names for every ward and bed in my hospital, by id (used by History).
  static Future<Map<String, String>> placeNames() async {
    final wards = await _db.from('wards').select('id, name');
    final beds = await _db.from('beds').select('id, label');
    return {
      for (final w in wards) w['id'] as String: w['name'] as String,
      for (final b in beds) b['id'] as String: 'Bed ${b['label']}',
    };
  }

  /// Everything that ever happened to this patient, newest first.
  static Future<List<Map<String, dynamic>>> patientHistory(String patientId) =>
      _db
          .from('audit_log')
          .select('at, actor_id, table_name, action, old_data, new_data')
          .eq('patient_id', patientId)
          .order('at')
          .limit(500);

  // ---- Care teams ----

  static Future<List<Map<String, dynamic>>> careTeam(String patientId) => _db
      .from('patient_team')
      .select('staff_id, access')
      .eq('patient_id', patientId);

  static Future<void> addToCareTeam(
    String hospitalId,
    String patientId,
    String staffId,
    String access,
  ) => _db.from('patient_team').insert({
    'hospital_id': hospitalId,
    'patient_id': patientId,
    'staff_id': staffId,
    'access': access,
    'added_by': _db.auth.currentUser!.id,
  });

  static Future<void> changeCareTeamAccess(
    String patientId,
    String staffId,
    String access,
  ) => _mustChange(
    _db
        .from('patient_team')
        .update({'access': access})
        .eq('patient_id', patientId)
        .eq('staff_id', staffId)
        .select(),
  );

  static Future<void> removeFromCareTeam(String patientId, String staffId) =>
      _mustChange(
        _db
            .from('patient_team')
            .delete()
            .eq('patient_id', patientId)
            .eq('staff_id', staffId)
            .select(),
      );

  // ---- Accounts ----

  static Future<void> createAccount({
    required String username,
    required String fullName,
    required StaffRole role,
    required String pin,
  }) => _manageStaff({
    'action': 'create',
    'username': username.trim().toLowerCase(),
    'full_name': fullName.trim(),
    'role': role.name,
    'pin': pin,
  });

  static Future<void> resetPin(String staffId, String pin) =>
      _manageStaff({'action': 'reset_pin', 'staff_id': staffId, 'pin': pin});

  static Future<void> setActive(String staffId, bool active) => _manageStaff({
    'action': 'set_active',
    'staff_id': staffId,
    'active': active,
  });

  static Future<void> _manageStaff(Map<String, dynamic> body) async {
    try {
      await _db.functions.invoke('manage-staff', body: body);
    } on FunctionException catch (e) {
      final details = e.details;
      throw Exception(
        details is Map ? details['error'] : 'Something went wrong',
      );
    }
  }
}
