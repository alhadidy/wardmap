import 'package:flutter_test/flutter_test.dart';
import 'package:wardmap/record_sections.dart';

void main() {
  String nobody(String? id) => '';
  RecordSection section(String table) =>
      recordSections.firstWhere((s) => s.table == table);

  test('vitals list line shows only what was measured', () {
    final (line, _) = section('vitals').summary({
      'temperature': 38.4,
      'heart_rate': 104,
      'systolic': 118,
      'diastolic': 72,
      'spo2': 93,
      'taken_at': '2026-10-10T10:00:00Z',
    }, nobody);
    expect(line, 'T 38.4  HR 104  BP 118/72  SpO₂ 93%');
  });

  test('history uses the form labels', () {
    expect(fieldLabel('vitals', 'heart_rate'), 'Heart rate (/min)');
    expect(fieldLabel('patients', 'bed_id'), 'Bed');
    expect(fieldLabel('tasks', 'done_at'), 'Done at');
  });
}
