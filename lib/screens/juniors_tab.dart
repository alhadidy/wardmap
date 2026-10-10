import 'package:flutter/material.dart';

import '../api.dart';
import '../record_sections.dart';
import '../roles.dart';
import '../ui.dart';
import 'patient_screen.dart';

/// For seniors: each doctor junior to me and the current patients they
/// follow, with open tasks and whether a note was written in the last day.
/// Lets a senior see at a glance who needs help or review.
class JuniorsTab extends StatefulWidget {
  const JuniorsTab({super.key, required this.me});

  final Staff me;

  @override
  State<JuniorsTab> createState() => _JuniorsTabState();
}

class _Overview {
  _Overview(this.followUps, this.staff, this.openTasks, this.latestNotes);

  final List<Map<String, dynamic>> followUps;
  final List<Staff> staff;
  final Map<String, int> openTasks;
  final Map<String, String> latestNotes;
}

class _JuniorsTabState extends State<JuniorsTab> {
  late Future<_Overview> _overview = _load();

  Future<_Overview> _load() async => _Overview(
    await Api.teamFollowUps(),
    await Api.colleagues(),
    await Api.openTaskCounts(),
    await Api.latestNotes(),
  );

  void _reload() => setState(() => _overview = _load());

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        _reload();
        await _overview;
      },
      child: FutureBuilder<_Overview>(
        future: _overview,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(errorText(snapshot.error!)));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final o = snapshot.data!;
          // Doctors junior to me (viewers aren't overseen), most senior first.
          final juniors =
              o.staff
                  .where(
                    (s) =>
                        s.isActive &&
                        s.role != StaffRole.viewer &&
                        s.role.rank < widget.me.role.rank,
                  )
                  .toList()
                ..sort((a, b) => b.role.rank.compareTo(a.role.rank));
          final sections = [
            for (final j in juniors)
              (j, o.followUps.where((f) => f['staff_id'] == j.id).toList()),
          ].where((s) => s.$2.isNotEmpty).toList();
          if (sections.isEmpty) {
            return ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'None of your juniors are following patients right now',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              for (final (junior, followUps) in sections) ...[
                ListTile(
                  leading: CircleAvatar(child: Text(junior.role.short)),
                  title: Text(
                    junior.fullName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: Text(
                    '${followUps.length} patient${followUps.length == 1 ? '' : 's'}',
                  ),
                ),
                for (final f in followUps) _patientTile(o, f),
                const Divider(),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _patientTile(_Overview o, Map<String, dynamic> followUp) {
    final p = followUp['patients'] as Map<String, dynamic>;
    final tasks = o.openTasks[p['id']] ?? 0;
    final lastNote = o.latestNotes[p['id']];
    final noteToday =
        lastNote != null &&
        DateTime.now().difference(DateTime.parse(lastNote)) <
            const Duration(hours: 24);
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 72, right: 16),
      title: Text(p['full_name']),
      subtitle: Text(
        [
          p['wards']?['name'],
          if (p['beds'] != null) 'Bed ${p['beds']['label']}',
          if (tasks > 0) '$tasks open task${tasks == 1 ? '' : 's'}',
          noteToday ? 'Note ${when(lastNote).substring(11)}' : 'No note in 24h',
        ].whereType<String>().join(' · '),
        style: noteToday ? null : TextStyle(color: colors.error),
      ),
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PatientScreen(me: widget.me, patientId: p['id']),
          ),
        );
        _reload();
      },
    );
  }
}
