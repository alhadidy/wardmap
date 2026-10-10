import 'package:flutter/material.dart';

import '../api.dart';
import '../record_sections.dart';
import '../roles.dart';
import '../ui.dart';

/// Everything that ever happened to a patient, newest first: who, when, and
/// what changed (before → after). Read-only; it can't be edited by anyone.
class HistoryView extends StatefulWidget {
  const HistoryView({super.key, required this.patientId, required this.staff});

  final String patientId;
  final List<Staff> staff;

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  late Future<List<Map<String, dynamic>>> _entries = Api.patientHistory(
    widget.patientId,
  );
  final Future<Map<String, String>> _places = Api.placeNames();
  Map<String, String> _placeNames = {};

  // Bookkeeping columns that would only clutter the list.
  static const _hidden = {
    'id',
    'hospital_id',
    'patient_id',
    'created_by',
    'created_at',
    'added_by',
    'added_at',
  };

  @override
  Widget build(BuildContext context) {
    final who = staffLookup(widget.staff);
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _entries = Api.patientHistory(widget.patientId));
        await _entries;
      },
      child: FutureBuilder(
        future: Future.wait([_entries, _places]),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(errorText(snapshot.error!)));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data![0] as List<Map<String, dynamic>>;
          _placeNames = snapshot.data![1] as Map<String, String>;
          return ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = entries[i];
              final verb = switch (e['action']) {
                'insert' => 'added to',
                'update' => 'changed',
                _ => 'deleted from',
              };
              return ListTile(
                title: Text(
                  '${who(e['actor_id'])} $verb ${sectionName(e['table_name'])}',
                ),
                subtitle: Text([when(e['at']), ..._changes(e, who)].join('\n')),
              );
            },
          );
        },
      ),
    );
  }

  /// One line per field that changed, e.g. "Status: active → resolved".
  List<String> _changes(Map<String, dynamic> e, StaffLookup who) {
    final table = e['table_name'] as String;
    final before = (e['old_data'] as Map?) ?? {};
    final after = (e['new_data'] as Map?) ?? {};
    String show(String key, Object? v) {
      if (v == null) return '—';
      if (key == 'staff_id' || key.endsWith('_to') || key.endsWith('_by')) {
        return who(v as String);
      }
      if (key.endsWith('_at')) return when(v);
      if (key == 'ward_id' || key == 'bed_id') {
        return _placeNames[v] ?? 'removed';
      }
      return v.toString();
    }

    final keys = {...before.keys, ...after.keys}.cast<String>().where(
      (k) => !_hidden.contains(k) && before[k] != after[k],
    );
    return [
      for (final k in keys)
        e['action'] == 'update'
            ? '${fieldLabel(table, k)}: ${show(k, before[k])} → ${show(k, after[k])}'
            : '${fieldLabel(table, k)}: ${show(k, after[k] ?? before[k])}',
    ];
  }
}
