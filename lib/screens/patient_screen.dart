import 'package:flutter/material.dart';

import '../api.dart';
import '../record_sections.dart';
import '../roles.dart';
import '../ui.dart';
import 'history_view.dart';
import 'record_section_view.dart';

/// One patient. Tabs: Overview (details, care team, discharge summary), one
/// tab per record section (problems, notes, vitals, results, meds, tasks),
/// and History. Transfer and discharge are in the ⋮ menu.
class PatientScreen extends StatefulWidget {
  const PatientScreen({super.key, required this.me, required this.patientId});

  final Staff me;
  final String patientId;

  @override
  State<PatientScreen> createState() => _PatientScreenState();
}

class _PatientView {
  _PatientView(this.patient, this.team, this.staff);

  final Map<String, dynamic> patient;
  final List<Map<String, dynamic>> team;
  final List<Staff> staff;

  Staff? person(String id) => staff.where((s) => s.id == id).firstOrNull;

  String? accessOf(String staffId) =>
      team.where((t) => t['staff_id'] == staffId).firstOrNull?['access'];
}

class _PatientScreenState extends State<PatientScreen> {
  late Future<_PatientView> _view = _load();

  Future<_PatientView> _load() async => _PatientView(
    await Api.patient(widget.patientId),
    await Api.careTeam(widget.patientId),
    await Api.colleagues(),
  );

  void _reload() => setState(() => _view = _load());

  // These mirror the database rules (docs/roles-and-access.md) so we only
  // show buttons that will work. The database is still the real check.
  bool _canEdit(_PatientView v) =>
      widget.me.isAdmin || ['owner', 'edit'].contains(v.accessOf(widget.me.id));

  bool _canManageTeam(_PatientView v) =>
      widget.me.isAdmin || v.accessOf(widget.me.id) == 'owner';

  Future<void> _transfer(_PatientView v) async {
    final moved = await showDialog<bool>(
      context: context,
      builder: (_) => _TransferDialog(patient: v.patient),
    );
    if (moved == true) _reload();
  }

  Future<void> _discharge(_PatientView v) async {
    if (!await confirm(
          context,
          'Discharge ${v.patient['full_name']}? Their bed will be freed.',
          'Discharge',
        ) ||
        !mounted) {
      return;
    }
    if (await runAction(
          context,
          () => Api.dischargePatient(widget.patientId),
          'Discharged',
        ) &&
        mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _addMember(_PatientView v) async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => _AddMemberDialog(
        me: widget.me,
        patientId: widget.patientId,
        // Owners and admins can add anyone; editors only people junior to them.
        candidates: v.staff
            .where(
              (s) =>
                  s.isActive &&
                  v.accessOf(s.id) == null &&
                  (_canManageTeam(v) || s.role.rank < widget.me.role.rank),
            )
            .toList(),
        allowOwner: _canManageTeam(v),
      ),
    );
    if (added == true) _reload();
  }

  Future<void> _memberAction(
    _PatientView v,
    String staffId,
    String choice,
  ) async {
    final ok = choice == 'remove'
        ? await runAction(
            context,
            () => Api.removeFromCareTeam(widget.patientId, staffId),
            'Removed from team',
          )
        : await runAction(
            context,
            () => Api.changeCareTeamAccess(widget.patientId, staffId, choice),
            'Access changed',
          );
    if (!ok || !mounted) return;
    if (choice == 'remove' && staffId == widget.me.id && !widget.me.isAdmin) {
      Navigator.pop(context); // I may no longer be able to see this patient.
    } else {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PatientView>(
      future: _view,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(errorText(snapshot.error!))),
          );
        }
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final v = snapshot.data!;
        final p = v.patient;
        final discharged = p['discharged_at'] != null;
        final canEdit = _canEdit(v) && !discharged;
        return DefaultTabController(
          length: recordSections.length + 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text(p['full_name']),
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  const Tab(text: 'Overview'),
                  for (final s in recordSections) Tab(text: s.title),
                  const Tab(text: 'History'),
                ],
              ),
              actions: [
                if (canEdit)
                  PopupMenuButton<String>(
                    onSelected: (c) =>
                        c == 'transfer' ? _transfer(v) : _discharge(v),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'transfer',
                        child: Text('Transfer / change bed'),
                      ),
                      PopupMenuItem(
                        value: 'discharge',
                        child: Text('Discharge'),
                      ),
                    ],
                  ),
              ],
            ),
            body: TabBarView(
              children: [
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _details(p, discharged),
                    const SizedBox(height: 16),
                    _dischargeSummary(v),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Care team',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (canEdit)
                          TextButton.icon(
                            onPressed: () => _addMember(v),
                            icon: const Icon(Icons.person_add),
                            label: const Text('Add'),
                          ),
                      ],
                    ),
                    for (final member in v.team) _memberTile(v, member),
                  ],
                ),
                for (final section in recordSections)
                  RecordSectionView(
                    section: section,
                    me: widget.me,
                    patientId: widget.patientId,
                    canEdit: canEdit,
                    staff: v.staff,
                  ),
                HistoryView(patientId: widget.patientId, staff: v.staff),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Written at discharge; editors can also fill it in after discharge.
  Widget _dischargeSummary(_PatientView v) {
    final summary = v.patient['discharge_summary'] as String?;
    return Card(
      child: ListTile(
        title: const Text('Discharge summary'),
        subtitle: Text(
          summary == null || summary.isEmpty ? 'Not written yet' : summary,
        ),
        trailing: _canEdit(v) ? const Icon(Icons.edit) : null,
        onTap: !_canEdit(v)
            ? null
            : () async {
                final text = await showDialog<String>(
                  context: context,
                  builder: (_) => _LongTextDialog(
                    title: 'Discharge summary',
                    initial: summary ?? '',
                  ),
                );
                if (text == null || !mounted) return;
                if (await runAction(
                  context,
                  () => Api.setDischargeSummary(widget.patientId, text),
                  'Saved',
                )) {
                  _reload();
                }
              },
      ),
    );
  }

  Widget _details(Map<String, dynamic> p, bool discharged) {
    String line(String label, Object? value) => '$label: ${value ?? '—'}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(line('MRN', p['mrn'])),
            Text(line('Ward', p['wards']?['name'])),
            Text(line('Bed', p['beds']?['label'])),
            Text(line('Date of birth', p['date_of_birth'])),
            Text(line('Sex', p['sex'])),
            Text(
              line('Admitted', (p['admitted_at'] as String).substring(0, 10)),
            ),
            if (discharged)
              Text(
                line(
                  'Discharged',
                  (p['discharged_at'] as String).substring(0, 10),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _memberTile(_PatientView v, Map<String, dynamic> member) {
    final person = v.person(member['staff_id']);
    final isMe = member['staff_id'] == widget.me.id;
    final canChange = _canManageTeam(v);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Text(person?.role.short ?? '?')),
      title: Text('${person?.fullName ?? 'Unknown'}${isMe ? ' (you)' : ''}'),
      subtitle: Text(member['access']),
      trailing: !(canChange || isMe)
          ? null
          : PopupMenuButton<String>(
              onSelected: (c) => _memberAction(v, member['staff_id'], c),
              itemBuilder: (_) => [
                if (canChange)
                  for (final a in ['owner', 'edit', 'view'])
                    if (a != member['access'])
                      PopupMenuItem(value: a, child: Text('Make $a')),
                PopupMenuItem(
                  value: 'remove',
                  child: Text(isMe ? 'Leave team' : 'Remove'),
                ),
              ],
            ),
    );
  }
}

class _TransferDialog extends StatefulWidget {
  const _TransferDialog({required this.patient});

  final Map<String, dynamic> patient;

  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  late final Future<List<Map<String, dynamic>>> _wards = Api.wards();
  late String _wardId = widget.patient['ward_id'];
  String? _bedId;
  Future<List<Map<String, dynamic>>>? _freeBeds;

  @override
  void initState() {
    super.initState();
    _loadBeds();
  }

  void _loadBeds() {
    _freeBeds = () async {
      final beds = await Api.beds(_wardId);
      final taken = await Api.occupiedBeds(_wardId);
      return beds.where((b) => !taken.contains(b['id'])).toList();
    }();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Transfer / change bed'),
      content: FutureBuilder(
        future: Future.wait([_wards, _freeBeds!]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final [wards, freeBeds] = snapshot.data!;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _wardId,
                decoration: const InputDecoration(labelText: 'Ward'),
                items: [
                  for (final w in wards)
                    DropdownMenuItem(
                      value: w['id'] as String,
                      child: Text(w['name']),
                    ),
                ],
                onChanged: (v) => setState(() {
                  _wardId = v!;
                  _bedId = null;
                  _loadBeds();
                }),
              ),
              DropdownButtonFormField<String?>(
                key: ValueKey(_wardId),
                initialValue: _bedId,
                decoration: const InputDecoration(labelText: 'Bed'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('No bed')),
                  for (final b in freeBeds)
                    DropdownMenuItem(
                      value: b['id'] as String,
                      child: Text(bedName(b, freeBeds)),
                    ),
                ],
                onChanged: (v) => setState(() => _bedId = v),
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final ok = await runAction(
              context,
              () => Api.transferPatient(widget.patient['id'], _wardId, _bedId),
              'Moved',
            );
            if (ok && context.mounted) Navigator.pop(context, true);
          },
          child: const Text('Move'),
        ),
      ],
    );
  }
}

class _AddMemberDialog extends StatefulWidget {
  const _AddMemberDialog({
    required this.me,
    required this.patientId,
    required this.candidates,
    required this.allowOwner,
  });

  final Staff me;
  final String patientId;
  final List<Staff> candidates;
  final bool allowOwner;

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  String? _staffId;
  String _access = 'edit';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add to care team'),
      content: widget.candidates.isEmpty
          ? const Text('There is nobody you can add.')
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _staffId,
                  decoration: const InputDecoration(labelText: 'Person'),
                  items: [
                    for (final s in widget.candidates)
                      DropdownMenuItem(
                        value: s.id,
                        child: Text('${s.fullName} (${s.role.label})'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _staffId = v),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _access,
                  decoration: const InputDecoration(labelText: 'Access'),
                  items: [
                    if (widget.allowOwner)
                      const DropdownMenuItem(
                        value: 'owner',
                        child: Text('Owner'),
                      ),
                    const DropdownMenuItem(value: 'edit', child: Text('Edit')),
                    const DropdownMenuItem(
                      value: 'view',
                      child: Text('View only'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _access = v!),
                ),
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _staffId == null
              ? null
              : () async {
                  final ok = await runAction(
                    context,
                    () => Api.addToCareTeam(
                      widget.me.hospitalId,
                      widget.patientId,
                      _staffId!,
                      _access,
                    ),
                    'Added to team',
                  );
                  if (ok && context.mounted) Navigator.pop(context, true);
                },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _LongTextDialog extends StatefulWidget {
  const _LongTextDialog({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_LongTextDialog> createState() => _LongTextDialogState();
}

class _LongTextDialogState extends State<_LongTextDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 480,
        child: TextField(
          controller: _text,
          minLines: 6,
          maxLines: 20,
          autofocus: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _text.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
