import 'package:flutter/material.dart';

import '../api.dart';
import '../roles.dart';
import '../ui.dart';
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

  @override
  Widget build(BuildContext context) {
    final canAdmit = widget.me.role != StaffRole.viewer;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ward['name']),
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
                for (final room in data.rooms)
                  ListTile(
                    leading: const Icon(Icons.meeting_room_outlined),
                    title: Text(room['name']),
                    subtitle: Text(
                      '${count(data.bedsIn(room['id']).length, 'bed')} · '
                      '${data.freeIn(room['id'])} free',
                    ),
                    onTap: () => _open(
                      WardBoardScreen(
                        me: widget.me,
                        ward: widget.ward,
                        room: room,
                        severalRooms: data.rooms.length > 1,
                      ),
                    ),
                    trailing: !widget.me.isAdmin
                        ? const Icon(Icons.chevron_right)
                        : PopupMenuButton<String>(
                            onSelected: (c) => c == 'rename'
                                ? _renameRoom(room)
                                : _deleteRoom(room),
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
                          ),
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
