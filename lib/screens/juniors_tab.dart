import 'package:flutter/material.dart';

import '../api.dart';
import '../components.dart';
import '../record_sections.dart';
import '../roles.dart';
import '../theme.dart';
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
            return EmptyState(
              icon: Icons.cloud_off,
              title: 'Could not load your juniors',
              message: errorText(snapshot.error!),
            );
          }
          if (!snapshot.hasData) return const Loading();
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
            return const EmptyState(
              icon: Icons.supervisor_account_outlined,
              title: 'Nothing to review',
              message: 'None of your juniors are following patients right now.',
            );
          }
          return CardList(
            children: [
              for (final (junior, followUps) in sections)
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: RoleAvatar(junior.role),
                        title: Text(
                          junior.fullName,
                          style: context.text.titleMedium,
                        ),
                        subtitle: Text(junior.role.label),
                        trailing: StatusPill(
                          count(followUps.length, 'patient'),
                          tone: Tone.brand,
                        ),
                      ),
                      const Divider(),
                      for (final f in followUps) _patientTile(o, f),
                    ],
                  ),
                ),
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
    return ListTile(
      leading: BedBadge(p['beds']?['label']),
      title: Text(p['full_name']),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: Space.xs),
        child: Wrap(
          spacing: Space.xs,
          runSpacing: Space.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (p['wards']?['name'] != null)
              Padding(
                padding: const EdgeInsets.only(right: Space.xs),
                child: Text(p['wards']['name']),
              ),
            noteToday
                ? StatusPill(
                    'Note ${when(lastNote).substring(11)}',
                    tone: Tone.success,
                    icon: Icons.check,
                  )
                : const StatusPill(
                    'No note in 24h',
                    tone: Tone.danger,
                    icon: Icons.priority_high,
                  ),
            if (tasks > 0)
              StatusPill(
                count(tasks, 'open task'),
                tone: Tone.warning,
                icon: Icons.checklist,
              ),
          ],
        ),
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
