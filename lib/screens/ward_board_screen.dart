import 'package:flutter/material.dart';

import '../api.dart';
import '../roles.dart';
import '../ui.dart';
import 'admit_screen.dart';
import 'patient_screen.dart';

/// One ward at a glance: every bed, free or taken, and the patients in it
/// that I can see. Taken beds whose patient I can't see show as "Occupied".
class WardBoardScreen extends StatefulWidget {
  const WardBoardScreen({super.key, required this.me, required this.ward});

  final Staff me;
  final Map<String, dynamic> ward;

  @override
  State<WardBoardScreen> createState() => _WardBoardScreenState();
}

class _WardBoard {
  _WardBoard(this.beds, this.occupied, this.patients);

  final List<Map<String, dynamic>> beds;
  final Set<String> occupied;
  final List<Map<String, dynamic>> patients;

  Map<String, dynamic>? patientIn(String bedId) =>
      patients.where((p) => p['bed_id'] == bedId).firstOrNull;

  List<Map<String, dynamic>> get withoutBed =>
      patients.where((p) => p['bed_id'] == null).toList();
}

class _WardBoardScreenState extends State<WardBoardScreen> {
  String get _wardId => widget.ward['id'];
  late Future<_WardBoard> _board = _load();

  Future<_WardBoard> _load() async => _WardBoard(
    await Api.beds(_wardId),
    await Api.occupiedBeds(_wardId),
    await Api.wardPatients(_wardId),
  );

  void _reload() => setState(() => _board = _load());

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    _reload();
  }

  Future<void> _addBed() async {
    final label = await askText(context, 'New bed', 'Bed name or number');
    if (label == null || !mounted) return;
    if (await runAction(
      context,
      () => Api.addBed(widget.me.hospitalId, _wardId, label),
      'Bed added',
    )) {
      _reload();
    }
  }

  Future<void> _deleteBed(Map<String, dynamic> bed) async {
    if (!await confirm(context, 'Remove bed ${bed['label']}?', 'Remove') ||
        !mounted) {
      return;
    }
    if (await runAction(
      context,
      () => Api.deleteBed(bed['id']),
      'Bed removed',
    )) {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canAdmit = widget.me.role != StaffRole.viewer;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ward['name']),
        actions: [
          if (widget.me.isAdmin)
            IconButton(
              tooltip: 'Add bed',
              onPressed: _addBed,
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      floatingActionButton: canAdmit
          ? FloatingActionButton.extended(
              onPressed: () => _open(AdmitScreen(ward: widget.ward)),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Admit'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          _reload();
          await _board;
        },
        child: FutureBuilder<_WardBoard>(
          future: _board,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text(errorText(snapshot.error!)));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final board = snapshot.data!;
            final free = board.beds
                .where((b) => !board.occupied.contains(b['id']))
                .length;
            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              children: [
                Text(
                  '${board.beds.length} beds · $free free',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                if (board.beds.isEmpty)
                  Text(
                    widget.me.isAdmin
                        ? 'No beds yet. Use + to add them.'
                        : 'No beds yet.',
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final bed in board.beds) _bedCard(board, bed),
                  ],
                ),
                if (board.withoutBed.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Without a bed',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  for (final p in board.withoutBed)
                    ListTile(
                      title: Text(p['full_name']),
                      subtitle: Text('MRN ${p['mrn']}'),
                      onTap: () => _open(
                        PatientScreen(me: widget.me, patientId: p['id']),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _bedCard(_WardBoard board, Map<String, dynamic> bed) {
    final colors = Theme.of(context).colorScheme;
    final patient = board.patientIn(bed['id']);
    final taken = board.occupied.contains(bed['id']);
    final String status;
    final VoidCallback? onTap;
    if (patient != null) {
      status = patient['full_name'];
      onTap = () =>
          _open(PatientScreen(me: widget.me, patientId: patient['id']));
    } else if (taken) {
      status = 'Occupied';
      onTap = null;
    } else {
      status = 'Free';
      onTap = widget.me.role == StaffRole.viewer
          ? null
          : () => _open(AdmitScreen(ward: widget.ward, bedId: bed['id']));
    }
    return SizedBox(
      width: 160,
      child: Card(
        color: taken ? colors.secondaryContainer : colors.surfaceContainerLow,
        child: InkWell(
          onTap: onTap,
          onLongPress: widget.me.isAdmin && !taken
              ? () => _deleteBed(bed)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bed ${bed['label']}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(status, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
