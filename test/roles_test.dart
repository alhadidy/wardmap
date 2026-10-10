import 'package:flutter_test/flutter_test.dart';
import 'package:wardmap/roles.dart';

void main() {
  test('residents can only create accounts junior to them', () {
    expect(StaffRole.r3.canCreate,
        [StaffRole.r2, StaffRole.r1, StaffRole.rotator, StaffRole.viewer]);
  });

  test('admins can create any role', () {
    expect(StaffRole.admin.canCreate, StaffRole.values);
  });

  test('viewers create nobody', () {
    expect(StaffRole.viewer.canCreate, isEmpty);
  });
}
