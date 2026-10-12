import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../components.dart';
import '../record_sections.dart';
import '../roles.dart';
import '../theme.dart';
import '../ui.dart';
import 'patient_screen.dart';

/// Patients I can see across all wards: my care teams, plus the patients of
/// juniors I oversee. Search by name or MRN; switch on "Include discharged"
/// to find past patients. Admitting happens from a ward board.
class PatientsTab extends StatefulWidget {
  const PatientsTab({super.key, required this.me});

  final Staff me;

  @override
  State<PatientsTab> createState() => _PatientsTabState();
}

class _PatientsTabState extends State<PatientsTab> {
  String _search = '';
  bool _includeDischarged = false;
  Timer? _typing;
  late Future<List<Map<String, dynamic>>> _patients = _load();

  Future<List<Map<String, dynamic>>> _load() =>
      Api.patients(search: _search, includeDischarged: _includeDischarged);

  void _reload() => setState(() => _patients = _load());

  @override
  void dispose() {
    _typing?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, 0),
          child: Row(
            spacing: Space.sm,
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search name or MRN',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (text) {
                    // Wait for a pause in typing before searching.
                    _typing?.cancel();
                    _typing = Timer(const Duration(milliseconds: 400), () {
                      _search = text;
                      _reload();
                    });
                  },
                ),
              ),
              FilterChip(
                label: const Text('Discharged'),
                tooltip: 'Include discharged patients',
                selected: _includeDischarged,
                onSelected: (v) {
                  _includeDischarged = v;
                  _reload();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _patients;
            },
            child: FutureBuilder(
              future: _patients,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return EmptyState(
                    icon: Icons.cloud_off,
                    title: 'Could not load patients',
                    message: errorText(snapshot.error!),
                  );
                }
                if (!snapshot.hasData) return const Loading();
                final patients = snapshot.data!;
                if (patients.isEmpty) {
                  return EmptyState(
                    icon: Icons.bed_outlined,
                    title: _search.isEmpty
                        ? 'No current patients'
                        : 'No patients match',
                    message: _search.isEmpty
                        ? 'Patients you care for, or your juniors do, '
                              'show here. Admit from a ward.'
                        : null,
                  );
                }
                return CardList(
                  children: [for (final p in patients) _patientCard(p)],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _patientCard(Map<String, dynamic> p) {
    final discharged = p['discharged_at'] != null;
    final bed = p['beds']?['label'];
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(
          Space.md,
          Space.xs,
          Space.md,
          Space.xs,
        ),
        leading: BedBadge(discharged ? null : bed),
        title: Text(p['full_name'], style: context.text.titleMedium),
        subtitle: Text(
          [
            'MRN ${p['mrn']}',
            if (discharged)
              'Discharged ${when(p['discharged_at']).substring(0, 10)}'
            else
              p['wards']?['name'],
          ].whereType<String>().join(' · '),
        ),
        trailing: discharged
            ? const StatusPill('Discharged')
            : const Icon(Icons.chevron_right),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PatientScreen(me: widget.me, patientId: p['id']),
            ),
          );
          _reload();
        },
      ),
    );
  }
}
