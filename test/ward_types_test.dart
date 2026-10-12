import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wardmap/ward_types.dart';

void main() {
  test('a ward can have several types, in a fixed order', () {
    final types = WardType.of({
      'types': ['children', 'women'],
    });
    expect(types, [WardType.women, WardType.children]);
  });

  test('unknown or missing types are ignored', () {
    expect(WardType.of({'types': null}), isEmpty);
    expect(
      WardType.of({
        'types': ['icu', 'something_new'],
      }),
      [WardType.icu],
    );
  });

  test('the app and the database allow the same types', () {
    final sql = File('supabase/migrations/20261012120000_ward_types.sql')
        .readAsStringSync();
    final inDatabase = RegExp(r"'([a-z_]+)'")
        .allMatches(sql.substring(sql.indexOf('array[')))
        .map((m) => m.group(1))
        .toSet();
    expect(inDatabase, {for (final t in WardType.values) t.key});
  });
}
