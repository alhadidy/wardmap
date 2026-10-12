import 'package:flutter/material.dart';

import '../api.dart';
import '../floor_plan.dart';
import '../roles.dart';
import '../ui.dart';
import '../ward_types.dart';
import 'admit_screen.dart';
import 'patient_screen.dart';
import 'ward_board_screen.dart';

/// Opens a ward: straight on its beds if it has one room, otherwise on the
/// list of its rooms.
Future<void> openWard(
  BuildContext context,
  Staff me,
  Map<String, dynamic> ward,
) async {
  final List<Map<String, dynamic>> rooms;
  try {
    rooms = await Api.rooms(ward['id']);
  } catch (e) {
    if (context.mounted) showMessage(context, errorText(e));
    return;
  }
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => rooms.length == 1
          ? WardBoardScreen(me: me, ward: ward, room: rooms.single)
          : RoomsScreen(me: me, ward: ward),
    ),
  );
}

/// The rooms of one ward, with how many beds are free in each. Admins add,
/// rename and remove rooms here.
class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key, required this.me, required this.ward});

  final Staff me;
  final Map<String, dynamic> ward;

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _Rooms {
  _Rooms(this.rooms, this.beds, this.occupied, this.patients);

  final List<Map<String, dynamic>> rooms;
  final List<Map<String, dynamic>> beds;
  final Set<String> occupied;
  final List<Map<String, dynamic>> patients;

  List<Map<String, dynamic>> bedsIn(String roomId) =>
      beds.where((b) => b['room_id'] == roomId).toList();

  int freeIn(String roomId) =>
      bedsIn(roomId).where((b) => !occupied.contains(b['id'])).length;

  BedState stateOf(Map<String, dynamic> bed) {
    if (patients.any((p) => p['bed_id'] == bed['id'])) return BedState.mine;
    return occupied.contains(bed['id']) ? BedState.occupied : BedState.free;
  }

  List<Map<String, dynamic>> get withoutBed =>
      patients.where((p) => p['bed_id'] == null).toList();
}

class _RoomsScreenState extends State<RoomsScreen> {
  String get _wardId => widget.ward['id'];
  late Future<_Rooms> _data = _load();

  Future<_Rooms> _load() async => _Rooms(
    await Api.rooms(_wardId),
    await Api.beds(_wardId),
    await Api.occupiedBeds(_wardId),
    await Api.wardPatients(_wardId),
  );

  void _reload() => setState(() => _data = _load());

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    _reload();
  }

  Future<void> _do(Future<void> Function() action, String done) async {
    if (await runAction(context, action, done)) _reload();
  }

  Future<void> _addRoom() async {
    final name = await askText(context, 'New room', 'Room name or number');
    if (name == null || !mounted) return;
    await _do(
      () => Api.addRoom(widget.me.hospitalId, _wardId, name),
      'Room added',
    );
  }

  Future<void> _renameRoom(Map<String, dynamic> room) async {
    final name = await askText(
      context,
      'Rename room',
      'Room name or number',
      initial: room['name'],
    );
    if (name == null || !mounted) return;
    await _do(() => Api.renameRoom(room['id'], name), 'Room renamed');
  }

  Future<void> _deleteRoom(Map<String, dynamic> room) async {
    if (!await confirm(
          context,
          'Remove ${room['name']}? Only a room with no beds can be removed.',
          'Remove',
        ) ||
        !mounted) {
      return;
    }
    await _do(() => Api.deleteRoom(room['id']), 'Room removed');
  }

  /// The ward from above: its rooms side by side inside the outer walls,
  /// each drawn in miniature with its beds coloured by state.
  Widget _wardPlan(_Rooms data) {
    return FloorPlan(
      name: widget.ward['name'],
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (context, c) {
          final perRow = (c.maxWidth / 170).floor().clamp(1, 4);
          final width = (c.maxWidth - (perRow - 1) * 8) / perRow;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final room in data.rooms)
                SizedBox(width: width, child: _roomTile(data, room)),
            ],
          );
        },
      ),
    );
  }

  Widget _roomTile(_Rooms data, Map<String, dynamic> room) {
    final beds = data.bedsIn(room['id']);
    final summary =
        '${count(beds.length, 'bed')} · ${data.freeIn(room['id'])} free';
    return Material(
      color: Colors.white,
      elevation: 1,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(
          WardBoardScreen(
            me: widget.me,
            ward: widget.ward,
            room: room,
            severalRooms: data.rooms.length > 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 0, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      room['name'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  if (widget.me.isAdmin)
                    PopupMenuButton<String>(
                      tooltip: 'Room options',
                      onSelected: (c) =>
                          c == 'rename' ? _renameRoom(room) : _deleteRoom(room),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'rename',
                          child: Text('Rename'),
                        ),
                        if (data.rooms.length > 1)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Remove'),
                          ),
                      ],
                    )
                  else
                    const SizedBox(height: 40),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: RoomMiniPlan(
                  rows: room['map_rows'],
                  columns: room['map_columns'],
                  beds: [
                    for (final b in beds)
                      (
                        row: b['map_row'] as int?,
                        column: b['map_column'] as int?,
                        state: data.stateOf(b),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(summary, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canAdmit = widget.me.role != StaffRole.viewer;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            WardTypeIcons(WardType.of(widget.ward), size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(widget.ward['name'], overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          if (widget.me.isAdmin)
            IconButton(
              tooltip: 'Add room',
              onPressed: _addRoom,
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
          await _data;
        },
        child: FutureBuilder<_Rooms>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text(errorText(snapshot.error!)));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data!;
            final free = data.beds
                .where((b) => !data.occupied.contains(b['id']))
                .length;
            return ListView(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 88),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '${count(data.rooms.length, 'room')} · '
                    '${count(data.beds.length, 'bed')} · $free free',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 6, 16, 12),
                  child: BedLegend(),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _wardPlan(data),
                ),
                if (data.withoutBed.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: Text(
                      'Without a bed',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  for (final p in data.withoutBed)
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
}
