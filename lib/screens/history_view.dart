import 'package:flutter/material.dart';

import '../api.dart';
import '../components.dart';
import '../record_sections.dart';
import '../roles.dart';
import '../theme.dart';
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
            return EmptyState(
              icon: Icons.cloud_off,
              title: 'Could not load the history',
              message: errorText(snapshot.error!),
            );
          }
          if (!snapshot.hasData) return const Loading();
          final entries = snapshot.data![0] as List<Map<String, dynamic>>;
          _placeNames = snapshot.data![1] as Map<String, String>;
          return ListView.separated(
            padding: const EdgeInsets.all(Space.lg),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
            itemBuilder: (context, i) {
              final e = entries[i];
              final (verb, icon, tone) = switch (e['action']) {
                'insert' => ('added to', Icons.add, Tone.success),
                'update' => ('changed', Icons.edit_outlined, Tone.info),
                _ => ('deleted from', Icons.delete_outline, Tone.danger),
              };
              final changes = _changes(e, who);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(Space.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: context.tones.background(tone),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          size: 18,
                          color: context.tones.foreground(tone),
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${who(e['actor_id'])} $verb '
                              '${sectionName(e['table_name'])}',
                              style: context.text.titleSmall,
                            ),
                            Text(when(e['at']), style: context.text.bodySmall),
                            if (changes.isNotEmpty) ...[
                              const SizedBox(height: Space.xs),
                              Text(
                                changes.join('\n'),
                                style: context.text.bodyMedium,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
