/// Staff roles, from most to least senior. Mirrors `staff_role` in the
/// database (supabase/migrations). See docs/roles-and-access.md.
enum StaffRole {
  admin('Admin', 'AD', 100),
  consultant('Consultant', 'CON', 90),
  r6('R6', 'R6', 60),
  r5('R5', 'R5', 50),
  r4('R4', 'R4', 40),
  r3('R3', 'R3', 30),
  r2('R2', 'R2', 20),
  r1('R1', 'R1', 10),
  rotator('Rotator', 'ROT', 5),
  viewer('Viewer', 'VW', 0);

  const StaffRole(this.label, this.short, this.rank);

  final String label;

  /// Fits in a small round badge.
  final String short;
  final int rank;

  static StaffRole parse(String name) =>
      StaffRole.values.firstWhere((r) => r.name == name);

  /// Roles this person may create accounts for: admins can create anyone,
  /// everyone else only roles junior to them.
  List<StaffRole> get canCreate => this == StaffRole.admin
      ? StaffRole.values
      : StaffRole.values.where((r) => r.rank < rank).toList();
}

/// A person who can log in.
class Staff {
  Staff({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.isActive,
    required this.hospitalId,
  });

  final String id;
  final String username;
  final String fullName;
  final StaffRole role;
  final bool isActive;
  final String hospitalId;

  factory Staff.fromRow(Map<String, dynamic> row) => Staff(
    id: row['id'],
    username: row['username'],
    fullName: row['full_name'],
    role: StaffRole.parse(row['role']),
    isActive: row['is_active'],
    hospitalId: row['hospital_id'],
  );

  bool get isAdmin => role == StaffRole.admin;
}
