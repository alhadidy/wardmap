import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../record_sections.dart';
import '../roles.dart';
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
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Search name or MRN',
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
        SwitchListTile(
          title: const Text('Include discharged'),
          value: _includeDischarged,
          onChanged: (v) {
            _includeDischarged = v;
            _reload();
          },
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
                  return Center(child: Text(errorText(snapshot.error!)));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final patients = snapshot.data!;
                if (patients.isEmpty) {
                  return ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          _search.isEmpty
                              ? 'No current patients'
                              : 'No patients match',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  );
                }
                return ListView(
                  children: [
                    for (final p in patients)
                      ListTile(
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PatientScreen(
                                me: widget.me,
                                patientId: p['id'],
                              ),
                            ),
                          );
                          _reload();
                        },
                        title: Text(p['full_name']),
                        subtitle: Text(
                          [
                            'MRN ${p['mrn']}',
                            if (p['discharged_at'] != null)
                              'Discharged ${when(p['discharged_at']).substring(0, 10)}'
                            else ...[
                              p['wards']?['name'],
                              if (p['beds'] != null)
                                'Bed ${p['beds']['label']}',
                            ],
                          ].whereType<String>().join(' · '),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
