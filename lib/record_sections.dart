/// The sections of a patient's record. Each one is a database table with the
/// same shape (see supabase/migrations/*_patient_record.sql); this file only
/// says which fields each has and how to show an entry in a list.
///
/// To add a field: add the column in a new migration, then add it here.
library;

import 'roles.dart';

enum FieldKind { text, longText, integer, decimal, dateTime, choice, staff }

class RecordField {
  const RecordField(
    this.key,
    this.label,
    this.kind, {
    this.required = false,
    this.choices = const [],
    this.defaultsToNow = false,
  });

  final String key;
  final String label;
  final FieldKind kind;
  final bool required;
  final List<String> choices;

  /// For date-time fields: start new entries at the current time.
  final bool defaultsToNow;
}

class RecordSection {
  const RecordSection({
    required this.table,
    required this.title,
    required this.fields,
    required this.orderBy,
    required this.summary,
  });

  final String table;
  final String title;
  final List<RecordField> fields;

  /// Newest first by this column.
  final String orderBy;

  /// The two lines shown for an entry in the list.
  final (String, String) Function(Map<String, dynamic> row, StaffLookup who)
  summary;
}

typedef StaffLookup = String Function(String? staffId);

/// "2026-10-10 14:05" from a database timestamp, in local time.
String when(Object? timestamp) {
  if (timestamp == null) return '';
  final t = DateTime.parse(timestamp as String).toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

String _join(List<Object?> parts, [String separator = ' · ']) => parts
    .where((p) => p != null && p.toString().trim().isNotEmpty)
    .join(separator);

final recordSections = <RecordSection>[
  RecordSection(
    table: 'problems',
    title: 'Problems',
    orderBy: 'created_at',
    fields: const [
      RecordField(
        'diagnosis',
        'Diagnosis / problem',
        FieldKind.text,
        required: true,
      ),
      RecordField(
        'status',
        'Status',
        FieldKind.choice,
        required: true,
        choices: ['active', 'resolved'],
      ),
      RecordField('details', 'Details', FieldKind.longText),
    ],
    summary: (r, who) => (r['diagnosis'], _join([r['status'], r['details']])),
  ),
  RecordSection(
    table: 'notes',
    title: 'Notes',
    orderBy: 'created_at',
    fields: const [
      RecordField('body', 'Progress note', FieldKind.longText, required: true),
    ],
    summary: (r, who) =>
        (r['body'], _join([who(r['created_by']), when(r['created_at'])])),
  ),
  RecordSection(
    table: 'vitals',
    title: 'Vitals',
    orderBy: 'taken_at',
    fields: const [
      RecordField(
        'taken_at',
        'Taken at',
        FieldKind.dateTime,
        required: true,
        defaultsToNow: true,
      ),
      RecordField('temperature', 'Temperature (°C)', FieldKind.decimal),
      RecordField('heart_rate', 'Heart rate (/min)', FieldKind.integer),
      RecordField('systolic', 'Systolic BP (mmHg)', FieldKind.integer),
      RecordField('diastolic', 'Diastolic BP (mmHg)', FieldKind.integer),
      RecordField(
        'respiratory_rate',
        'Respiratory rate (/min)',
        FieldKind.integer,
      ),
      RecordField('spo2', 'SpO₂ (%)', FieldKind.integer),
      RecordField('note', 'Note', FieldKind.text),
    ],
    summary: (r, who) => (
      _join([
        if (r['temperature'] != null) 'T ${r['temperature']}',
        if (r['heart_rate'] != null) 'HR ${r['heart_rate']}',
        if (r['systolic'] != null)
          'BP ${r['systolic']}/${r['diastolic'] ?? '?'}',
        if (r['respiratory_rate'] != null) 'RR ${r['respiratory_rate']}',
        if (r['spo2'] != null) 'SpO₂ ${r['spo2']}%',
      ], '  '),
      _join([when(r['taken_at']), r['note']]),
    ),
  ),
  RecordSection(
    table: 'results',
    title: 'Results',
    orderBy: 'taken_at',
    fields: const [
      RecordField(
        'kind',
        'Type',
        FieldKind.choice,
        required: true,
        choices: ['lab', 'imaging'],
      ),
      RecordField(
        'name',
        'Test (e.g. Hb, CXR)',
        FieldKind.text,
        required: true,
      ),
      RecordField('value', 'Result', FieldKind.longText, required: true),
      RecordField(
        'taken_at',
        'Taken at',
        FieldKind.dateTime,
        required: true,
        defaultsToNow: true,
      ),
    ],
    summary: (r, who) => (
      '${r['name']}: ${r['value']}',
      _join([r['kind'], when(r['taken_at'])]),
    ),
  ),
  RecordSection(
    table: 'medications',
    title: 'Meds',
    orderBy: 'started_at',
    fields: const [
      RecordField('name', 'Medication', FieldKind.text, required: true),
      RecordField('dose', 'Dose', FieldKind.text),
      RecordField('route', 'Route', FieldKind.text),
      RecordField('frequency', 'Frequency', FieldKind.text),
      RecordField(
        'started_at',
        'Started',
        FieldKind.dateTime,
        required: true,
        defaultsToNow: true,
      ),
      RecordField('stopped_at', 'Stopped', FieldKind.dateTime),
    ],
    summary: (r, w) => (
      _join([r['name'], r['dose'], r['route'], r['frequency']], ' '),
      r['stopped_at'] == null
          ? 'Since ${when(r['started_at'])}'
          : 'Stopped ${when(r['stopped_at'])}',
    ),
  ),
  RecordSection(
    table: 'tasks',
    title: 'Tasks',
    orderBy: 'created_at',
    fields: const [
      RecordField('title', 'Task', FieldKind.text, required: true),
      RecordField('assigned_to', 'Assigned to', FieldKind.staff),
      RecordField('due_at', 'Due', FieldKind.dateTime),
    ],
    summary: (r, who) => (
      r['title'],
      r['done_at'] != null
          ? 'Done by ${who(r['done_by'])} · ${when(r['done_at'])}'
          : _join([
              if (r['assigned_to'] != null) 'For ${who(r['assigned_to'])}',
              if (r['due_at'] != null) 'Due ${when(r['due_at'])}',
            ]),
    ),
  ),
];

/// Readable names for tables and columns in the change history.
String sectionName(String table) => switch (table) {
  'patients' => 'patient details',
  'patient_team' => 'care team',
  'medications' => 'medications',
  _ => table,
};

String fieldLabel(String table, String key) {
  for (final s in recordSections.where((s) => s.table == table)) {
    for (final f in s.fields.where((f) => f.key == key)) {
      return f.label;
    }
  }
  return switch (key) {
    'ward_id' => 'Ward',
    'bed_id' => 'Bed',
    'staff_id' => 'Person',
    'mrn' => 'MRN',
    _ => key[0].toUpperCase() + key.substring(1).replaceAll('_', ' '),
  };
}

/// Lets sections show "Dr Ali" instead of an id.
StaffLookup staffLookup(List<Staff> staff) =>
    (id) => id == null
    ? ''
    : (staff.where((s) => s.id == id).firstOrNull?.fullName ?? 'Unknown');
