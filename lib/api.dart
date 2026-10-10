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
    final rows = await _db.from('staff').select().order('role').order('full_name');
    return rows.map(Staff.fromRow).toList();
  }

  /// Patients I can see (my care teams, plus juniors' patients I oversee),
  /// with their ward name. Discharged patients are left out.
  static Future<List<Map<String, dynamic>>> currentPatients() async {
    return await _db
        .from('patients')
        .select('id, mrn, full_name, admitted_at, wards(name), beds(label)')
        .isFilter('discharged_at', null)
        .order('admitted_at');
  }

  static Future<void> createAccount({
    required String username,
    required String fullName,
    required StaffRole role,
    required String pin,
  }) =>
      _manageStaff({
        'action': 'create',
        'username': username.trim().toLowerCase(),
        'full_name': fullName.trim(),
        'role': role.name,
        'pin': pin,
      });

  static Future<void> resetPin(String staffId, String pin) =>
      _manageStaff({'action': 'reset_pin', 'staff_id': staffId, 'pin': pin});

  static Future<void> setActive(String staffId, bool active) => _manageStaff(
      {'action': 'set_active', 'staff_id': staffId, 'active': active});

  static Future<void> _manageStaff(Map<String, dynamic> body) async {
    try {
      await _db.functions.invoke('manage-staff', body: body);
    } on FunctionException catch (e) {
      final details = e.details;
      throw Exception(details is Map ? details['error'] : 'Something went wrong');
    }
  }
}
