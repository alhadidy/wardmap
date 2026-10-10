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
        .select('id, label, map_row, map_column')
        .eq('ward_id', wardId);
    int number(Map b) => int.tryParse(b['label']) ?? 1 << 30;
    return beds..sort((a, b) {
      final byNumber = number(a).compareTo(number(b));
      return byNumber != 0
          ? byNumber
          : (a['label'] as String).compareTo(b['label']);
    });
  }

  static Future<Map<String, dynamic>> ward(String wardId) => _db
      .from('wards')
      .select('id, name, map_rows, map_columns')
      .eq('id', wardId)
      .single();

  // ---- Ward map (admin only) ----

  static Future<List<Map<String, dynamic>>> landmarks(String wardId) => _db
      .from('ward_landmarks')
      .select('id, label, map_row, map_column')
      .eq('ward_id', wardId);

  static Future<void> setMapSize(String wardId, int rows, int columns) =>
      _mustChange(
        _db
            .from('wards')
            .update({'map_rows': rows, 'map_columns': columns})
            .eq('id', wardId)
            .select(),
      );

  /// Puts a bed in a map cell, or takes it off the map (row and column null).
  static Future<void> placeBed(String bedId, int? row, int? column) =>
      _mustChange(
        _db
            .from('beds')
            .update({'map_row': row, 'map_column': column})
            .eq('id', bedId)
            .select(),
      );

  static Future<void> addBedAt(
    String hospitalId,
    String wardId,
    String label,
    int row,
    int column,
  ) => _db.from('beds').insert({
    'hospital_id': hospitalId,
    'ward_id': wardId,
    'label': label.trim(),
    'map_row': row,
    'map_column': column,
  });

  static Future<void> addLandmark(
    String hospitalId,
    String wardId,
    String label,
    int row,
    int column,
  ) => _db.from('ward_landmarks').insert({
    'hospital_id': hospitalId,
    'ward_id': wardId,
    'label': label.trim(),
    'map_row': row,
    'map_column': column,
  });

  static Future<void> moveLandmark(String id, int row, int column) =>
      _mustChange(
        _db
            .from('ward_landmarks')
            .update({'map_row': row, 'map_column': column})
            .eq('id', id)
            .select(),
      );

  static Future<void> deleteLandmark(String id) =>
      _mustChange(_db.from('ward_landmarks').delete().eq('id', id).select());

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
