import 'package:flutter/material.dart';

import '../api.dart';
import '../roles.dart';
import 'patient_screen.dart';

/// Current patients I can see across all wards: my care teams, plus the
/// patients of juniors I oversee. Admitting happens from a ward board.
class PatientsTab extends StatefulWidget {
  const PatientsTab({super.key, required this.me});

  final Staff me;

  @override
  State<PatientsTab> createState() => _PatientsTabState();
}

class _PatientsTabState extends State<PatientsTab> {
  late Future<List<Map<String, dynamic>>> _patients = Api.currentPatients();

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _patients = Api.currentPatients());
        await _patients;
      },
      child: FutureBuilder(
        future: _patients,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final patients = snapshot.data!;
          if (patients.isEmpty) {
            return ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No current patients',
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
                        builder: (_) =>
                            PatientScreen(me: widget.me, patientId: p['id']),
                      ),
                    );
                    setState(() => _patients = Api.currentPatients());
                  },
                  title: Text(p['full_name']),
                  subtitle: Text(
                    [
                      'MRN ${p['mrn']}',
                      p['wards']?['name'],
                      if (p['beds'] != null) 'Bed ${p['beds']['label']}',
                    ].whereType<String>().join(' · '),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
