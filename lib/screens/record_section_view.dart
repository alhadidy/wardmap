import 'package:flutter/material.dart';

import '../api.dart';
import '../record_sections.dart';
import '../roles.dart';
import '../ui.dart';

/// One section of the patient record (problems, notes, vitals…) as a list,
/// newest first. Editors add entries with the button and tap one to change
/// or delete it. Every change is kept in the History tab.
class RecordSectionView extends StatefulWidget {
  const RecordSectionView({
    super.key,
    required this.section,
    required this.me,
    required this.patientId,
    required this.canEdit,
    required this.staff,
  });

  final RecordSection section;
  final Staff me;
  final String patientId;
  final bool canEdit;
  final List<Staff> staff;

  @override
  State<RecordSectionView> createState() => _RecordSectionViewState();
}

class _RecordSectionViewState extends State<RecordSectionView>
    with AutomaticKeepAliveClientMixin {
  late Future<List<Map<String, dynamic>>> _rows = _load();

  RecordSection get _section => widget.section;
  bool get _isTasks => _section.table == 'tasks';

  Future<List<Map<String, dynamic>>> _load() =>
      Api.records(_section.table, widget.patientId, _section.orderBy);

  void _reload() => setState(() => _rows = _load());

  @override
  bool get wantKeepAlive => true;

  Future<void> _openForm([Map<String, dynamic>? row]) async {
    final result = await showDialog<_FormResult>(
      context: context,
      builder: (_) =>
          _RecordForm(section: _section, row: row, staff: widget.staff),
    );
    if (result == null || !mounted) return;
    final ok = await runAction(
      context,
      () => switch (result) {
        _Delete() => Api.deleteRecord(_section.table, row!['id']),
        _Save(:final values) when row == null => Api.addRecord(
          _section.table,
          widget.me.hospitalId,
          widget.patientId,
          values,
        ),
        _Save(:final values) => Api.updateRecord(
          _section.table,
          row!['id'],
          values,
        ),
      },
      result is _Delete ? 'Deleted' : 'Saved',
    );
    if (ok) _reload();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final who = staffLookup(widget.staff);
    return Scaffold(
      floatingActionButton: widget.canEdit
          ? FloatingActionButton.small(
              tooltip: 'Add to ${_section.title}',
              onPressed: () => _openForm(),
              child: const Icon(Icons.add),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          _reload();
          await _rows;
        },
        child: FutureBuilder(
          future: _rows,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text(errorText(snapshot.error!)));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final rows = snapshot.data!;
            if (rows.isEmpty) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No ${_section.title.toLowerCase()} yet',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.only(bottom: 72),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final row = rows[i];
                final (title, subtitle) = _section.summary(row, who);
                final done = _isTasks && row['done_at'] != null;
                return ListTile(
                  leading: _isTasks
                      ? Checkbox(
                          value: done,
                          onChanged: widget.canEdit
                              ? (v) async {
                                  final nowDone = v ?? false;
                                  if (await runAction(
                                    context,
                                    () => Api.setTaskDone(row['id'], nowDone),
                                    nowDone ? 'Done' : 'Reopened',
                                  )) {
                                    _reload();
                                  }
                                }
                              : null,
                        )
                      : null,
                  title: Text(
                    title,
                    style: done
                        ? const TextStyle(
                            decoration: TextDecoration.lineThrough,
                          )
                        : null,
                  ),
                  subtitle: subtitle.isEmpty ? null : Text(subtitle),
                  isThreeLine: _section.table == 'notes',
                  onTap: widget.canEdit ? () => _openForm(row) : null,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

sealed class _FormResult {}

class _Save extends _FormResult {
  _Save(this.values);
  final Map<String, dynamic> values;
}

class _Delete extends _FormResult {}

/// Add or change one entry. The form is built from the section's fields.
class _RecordForm extends StatefulWidget {
  const _RecordForm({required this.section, required this.staff, this.row});

  final RecordSection section;
  final List<Staff> staff;
  final Map<String, dynamic>? row;

  @override
  State<_RecordForm> createState() => _RecordFormState();
}

class _RecordFormState extends State<_RecordForm> {
  late final Map<String, dynamic> _values = {
    for (final f in widget.section.fields)
      f.key:
          widget.row?[f.key] ??
          (widget.row == null && f.defaultsToNow
              ? DateTime.now().toUtc().toIso8601String()
              : f.kind == FieldKind.choice
              ? f.choices.first
              : null),
  };
  late final Map<String, TextEditingController> _text = {
    for (final f in widget.section.fields)
      if (_isTyped(f.kind))
        f.key: TextEditingController(text: _values[f.key]?.toString() ?? ''),
  };
  String? _error;

  bool _isTyped(FieldKind k) => const [
    FieldKind.text,
    FieldKind.longText,
    FieldKind.integer,
    FieldKind.decimal,
  ].contains(k);

  void _save() {
    final values = <String, dynamic>{};
    for (final f in widget.section.fields) {
      Object? value = _values[f.key];
      if (_isTyped(f.kind)) {
        final text = _text[f.key]!.text.trim();
        value = switch (f.kind) {
          _ when text.isEmpty => null,
          FieldKind.integer => int.tryParse(text) ?? 'bad',
          FieldKind.decimal => num.tryParse(text) ?? 'bad',
          _ => text,
        };
      }
      if (value == 'bad') {
        setState(() => _error = '${f.label} must be a number');
        return;
      }
      if (f.required && value == null) {
        setState(() => _error = '${f.label} is required');
        return;
      }
      values[f.key] = value;
    }
    Navigator.pop(context, _Save(values));
  }

  Future<void> _pickDateTime(RecordField f) async {
    final current = _values[f.key] == null
        ? DateTime.now()
        : DateTime.parse(_values[f.key]).toLocal();
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;
    setState(
      () => _values[f.key] = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ).toUtc().toIso8601String(),
    );
  }

  Widget _field(RecordField f) {
    final label = f.required ? '${f.label} *' : f.label;
    return switch (f.kind) {
      FieldKind.text || FieldKind.longText => TextField(
        controller: _text[f.key],
        decoration: InputDecoration(labelText: label),
        minLines: f.kind == FieldKind.longText ? 3 : 1,
        maxLines: f.kind == FieldKind.longText ? 10 : 1,
      ),
      FieldKind.integer || FieldKind.decimal => TextField(
        controller: _text[f.key],
        decoration: InputDecoration(labelText: label),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
      FieldKind.choice => DropdownButtonFormField<String>(
        initialValue: _values[f.key],
        decoration: InputDecoration(labelText: label),
        items: [
          for (final c in f.choices) DropdownMenuItem(value: c, child: Text(c)),
        ],
        onChanged: (v) => setState(() => _values[f.key] = v),
      ),
      FieldKind.staff => DropdownButtonFormField<String?>(
        initialValue: _values[f.key],
        decoration: InputDecoration(labelText: label),
        items: [
          const DropdownMenuItem(value: null, child: Text('Nobody')),
          for (final s in widget.staff.where((s) => s.isActive))
            DropdownMenuItem(
              value: s.id,
              child: Text('${s.fullName} (${s.role.label})'),
            ),
        ],
        onChanged: (v) => setState(() => _values[f.key] = v),
      ),
      FieldKind.dateTime => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        subtitle: Text(
          _values[f.key] == null ? 'Not set' : when(_values[f.key]),
        ),
        onTap: () => _pickDateTime(f),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_values[f.key] != null && !f.required)
              IconButton(
                tooltip: 'Clear ${f.label}',
                onPressed: () => setState(() => _values[f.key] = null),
                icon: const Icon(Icons.clear),
              ),
            const Icon(Icons.schedule),
          ],
        ),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.row != null;
    return AlertDialog(
      title: Text('${editing ? 'Edit' : 'Add'}: ${widget.section.title}'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final f in widget.section.fields) _field(f),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (editing)
          TextButton(
            onPressed: () async {
              if (await confirm(
                    context,
                    'Delete this entry? It stays in the history.',
                    'Delete',
                  ) &&
                  context.mounted) {
                Navigator.pop(context, _Delete());
              }
            },
            child: const Text('Delete'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
