import 'package:flutter/material.dart';

import '../api.dart';
import '../floor_plan.dart';
import '../roles.dart';
import '../ui.dart';
import '../ward_types.dart';
import 'admit_screen.dart';
import 'patient_screen.dart';
import 'rooms_screen.dart';

/// One room at a glance: every bed, free or taken, and the patients in it
/// that I can see. Taken beds whose patient I can't see show as "Occupied".
/// A ward with a single room opens straight here, so it reads as the ward.
///
/// Once an admin lays the room out on its map (Edit map), beds are drawn
/// where they really are, with landmarks such as the nurse station.
class WardBoardScreen extends StatefulWidget {
  const WardBoardScreen({
    super.key,
    required this.me,
    required this.ward,
    required this.room,
    this.severalRooms = false,
  });

  final Staff me;
  final Map<String, dynamic> ward;
  final Map<String, dynamic> room;
  final bool severalRooms;

  @override
  State<WardBoardScreen> createState() => _WardBoardScreenState();
}

class _WardBoard {
  _WardBoard(
    this.room,
    this.rooms,
    List<Map<String, dynamic>> wardBeds,
    this.occupied,
    this.patients,
    this.landmarks,
  ) : beds = wardBeds.where((b) => b['room_id'] == room['id']).toList();

  final Map<String, dynamic> room;

  /// Every room in the ward, this one included.
  final List<Map<String, dynamic>> rooms;

  /// Beds in this room only.
  final List<Map<String, dynamic>> beds;
  final Set<String> occupied;

  /// Patients in the whole ward that I can see.
  final List<Map<String, dynamic>> patients;
  final List<Map<String, dynamic>> landmarks;

  bool get hasSeveralRooms => rooms.length > 1;

  int get rows => room['map_rows'];
  int get columns => room['map_columns'];

  Map<String, dynamic>? patientIn(String bedId) =>
      patients.where((p) => p['bed_id'] == bedId).firstOrNull;

  List<Map<String, dynamic>> get withoutBed =>
      patients.where((p) => p['bed_id'] == null).toList();

  bool _at(Map<String, dynamic> item, int row, int column) =>
      item['map_row'] == row && item['map_column'] == column;

  Map<String, dynamic>? bedAt(int row, int column) =>
      beds.where((b) => _at(b, row, column)).firstOrNull;

  Map<String, dynamic>? landmarkAt(int row, int column) =>
      landmarks.where((l) => _at(l, row, column)).firstOrNull;

  /// Beds not on the map, or outside it after the map was made smaller.
  List<Map<String, dynamic>> get bedsOffMap => beds
      .where(
        (b) =>
            b['map_row'] == null ||
            b['map_row'] >= rows ||
            b['map_column'] >= columns,
      )
      .toList();

  bool get hasMap => beds.length > bedsOffMap.length || landmarks.isNotEmpty;

  /// True if nothing sits in that row (or column), so it can be removed.
  bool rowIsEmpty(int row) =>
      ![...beds, ...landmarks].any((i) => i['map_row'] == row);

  bool columnIsEmpty(int column) =>
      ![...beds, ...landmarks].any((i) => i['map_column'] == column);
}

/// Something picked on the map in edit mode, waiting for a cell to move to.
class _Picked {
  _Picked(this.item, {required this.isBed});

  final Map<String, dynamic> item;
  final bool isBed;

  String get name => isBed ? 'Bed ${item['label']}' : item['label'];
}

class _WardBoardScreenState extends State<WardBoardScreen> {
  String get _wardId => widget.ward['id'];
  String get _roomId => widget.room['id'];
  late Future<_WardBoard> _board = _load();
  bool _editing = false;
  _Picked? _picked;

  /// The ward's rooms, once loaded. The title and actions depend on them.
  List<Map<String, dynamic>>? _rooms;

  bool get _severalRooms =>
      (_rooms?.length ?? 1) > 1 || widget.severalRooms && _rooms == null;

  static const _minCellWidth = 84.0;
  static const _maxCellWidth = 124.0;
  static const _cellHeight = 116.0;

  /// Size of a bed drawn off the map (not yet placed, or no map yet).
  static const _bedWidth = 104.0;
  static const _bedHeight = 124.0;

  /// Room walls and floor padding around the map grid, on each side.
  static const _planInset = 5.0 + 10.0;

  Future<_WardBoard> _load() async {
    final rooms = await Api.rooms(_wardId);
    if (mounted) setState(() => _rooms = rooms);
    return _WardBoard(
      rooms.where((r) => r['id'] == _roomId).firstOrNull ?? widget.room,
      rooms,
      await Api.beds(_wardId),
      await Api.occupiedBeds(_wardId),
      await Api.wardPatients(_wardId),
      await Api.landmarks(_roomId),
    );
  }

  void _reload() => setState(() {
    _picked = null;
    _board = _load();
  });

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    _reload();
  }

  Future<void> _do(Future<void> Function() action, String done) async {
    if (await runAction(context, action, done)) _reload();
  }

  Future<void> _addBed() async {
    final label = await askText(context, 'New bed', 'Bed name or number');
    if (label == null || !mounted) return;
    await _do(
      () => Api.addBed(widget.me.hospitalId, _wardId, _roomId, label),
      'Bed added',
    );
  }

  Future<void> _deleteBed(Map<String, dynamic> bed) async {
    if (!await confirm(context, 'Remove bed ${bed['label']}?', 'Remove') ||
        !mounted) {
      return;
    }
    await _do(() => Api.deleteBed(bed['id']), 'Bed removed');
  }

  // ---- Map editing (admins) ----

  Future<void> _resize(_WardBoard board, int rows, int columns) async {
    if (rows < board.rows && !board.rowIsEmpty(board.rows - 1) ||
        columns < board.columns && !board.columnIsEmpty(board.columns - 1)) {
      showMessage(context, 'Move things out of the last row or column first');
      return;
    }
    await _do(() => Api.setMapSize(_roomId, rows, columns), 'Map resized');
  }

  Future<void> _tapEmptyCell(_WardBoard board, int row, int column) async {
    final picked = _picked;
    if (picked != null) {
      await _do(
        () => picked.isBed
            ? Api.placeBed(picked.item['id'], row, column)
            : Api.moveLandmark(picked.item['id'], row, column),
        'Moved ${picked.name}',
      );
      return;
    }
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final bed in board.bedsOffMap)
              ListTile(
                leading: const Icon(Icons.bed),
                title: Text('Put bed ${bed['label']} here'),
                onTap: () => Navigator.pop(context, 'bed:${bed['id']}'),
              ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('New bed here'),
              onTap: () => Navigator.pop(context, 'new-bed'),
            ),
            ListTile(
              leading: const Icon(Icons.label_outline),
              title: const Text('Label here (e.g. Nurse station)'),
              onTap: () => Navigator.pop(context, 'landmark'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice.startsWith('bed:')) {
      await _do(
        () => Api.placeBed(choice.substring(4), row, column),
        'Bed placed',
      );
    } else if (choice == 'new-bed') {
      final label = await askText(context, 'New bed', 'Bed name or number');
      if (label == null || !mounted) return;
      await _do(
        () => Api.addBedAt(
          widget.me.hospitalId,
          _wardId,
          _roomId,
          label,
          row,
          column,
        ),
        'Bed added',
      );
    } else {
      final label = await askText(context, 'Label', 'e.g. Nurse station');
      if (label == null || !mounted) return;
      await _do(
        () => Api.addLandmark(
          widget.me.hospitalId,
          _wardId,
          _roomId,
          label,
          row,
          column,
        ),
        'Label added',
      );
    }
  }

  Future<void> _moveToRoom(Map<String, dynamic> bed) async {
    final roomId = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final room in _rooms ?? const <Map<String, dynamic>>[])
              if (room['id'] != _roomId)
                ListTile(
                  leading: const Icon(Icons.meeting_room_outlined),
                  title: Text('Move bed ${bed['label']} to ${room['name']}'),
                  onTap: () => Navigator.pop(context, room['id'] as String),
                ),
          ],
        ),
      ),
    );
    if (roomId == null || !mounted) return;
    await _do(() => Api.moveBedToRoom(bed['id'], roomId), 'Bed moved');
  }

  /// A single-room ward opens straight on its beds, so admins reach the
  /// rooms list from here to add a second room.
  Future<void> _openRooms() => Navigator.of(context).pushReplacement(
    MaterialPageRoute(
      builder: (_) => RoomsScreen(me: widget.me, ward: widget.ward),
    ),
  );

  // ---- Building the screen ----

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
              child: Text(
                _severalRooms
                    ? '${widget.room['name']} · ${widget.ward['name']}'
                    : widget.ward['name'],
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (widget.me.isAdmin && !_editing && !_severalRooms)
            IconButton(
              tooltip: 'Rooms',
              onPressed: _openRooms,
              icon: const Icon(Icons.meeting_room_outlined),
            ),
          if (widget.me.isAdmin && !_editing)
            IconButton(
              tooltip: 'Add bed',
              onPressed: _addBed,
              icon: const Icon(Icons.add),
            ),
          if (widget.me.isAdmin)
            IconButton(
              tooltip: _editing ? 'Done editing map' : 'Edit map',
              onPressed: () => setState(() {
                _editing = !_editing;
                _picked = null;
              }),
              icon: Icon(_editing ? Icons.check : Icons.edit_location_alt),
            ),
        ],
      ),
      floatingActionButton: canAdmit && !_editing
          ? FloatingActionButton.extended(
              onPressed: () => _open(AdmitScreen(ward: widget.ward)),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Admit'),
            )
          : null,
      bottomNavigationBar: _editing ? _editBar() : null,
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
            final showMap = _editing || board.hasMap;
            final listed = showMap ? board.bedsOffMap : board.beds;
            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              children: [
                Text(
                  '${count(board.beds.length, 'bed')} · $free free',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                if (board.beds.isNotEmpty) const BedLegend(),
                const SizedBox(height: 12),
                if (_editing) _sizeControls(board),
                if (board.beds.isEmpty && !_editing)
                  Text(
                    widget.me.isAdmin
                        ? 'No beds yet. Use + to add them, or Edit map to '
                              'draw the ward.'
                        : 'No beds yet.',
                  ),
                if (showMap) _map(board),
                if (showMap && listed.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Not on the map',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                ],
                if (listed.isNotEmpty)
                  showMap
                      ? _bedRow(board, listed)
                      // No map yet: the beds still stand in a room.
                      : FloorPlan(child: _bedRow(board, listed)),
                // With several rooms these are listed on the rooms screen.
                if (!board.hasSeveralRooms && board.withoutBed.isNotEmpty) ...[
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

  /// Rows and columns steppers shown while editing.
  Widget _sizeControls(_WardBoard board) {
    Widget stepper(String label, int value, void Function(int) set) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label $value'),
        IconButton(
          tooltip: 'Fewer $label',
          onPressed: value > 1 ? () => set(value - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        IconButton(
          tooltip: 'More $label',
          onPressed: value < 30 ? () => set(value + 1) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
    return Wrap(
      spacing: 16,
      children: [
        stepper('rows', board.rows, (r) => _resize(board, r, board.columns)),
        stepper('columns', board.columns, (c) => _resize(board, board.rows, c)),
      ],
    );
  }

  Widget _bedRow(_WardBoard board, List<Map<String, dynamic>> beds) => Wrap(
    children: [
      for (final bed in beds)
        SizedBox(
          width: _bedWidth,
          height: _bedHeight,
          child: _bedCard(board, bed),
        ),
    ],
  );

  /// The room drawn from above: walls around a tiled floor, with beds and
  /// fixtures in their grid cells. Cells shrink to fit the screen, down to a
  /// readable minimum; beyond that the map scrolls sideways.
  Widget _map(_WardBoard board) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth =
            ((constraints.maxWidth - 2 * _planInset) / board.columns).clamp(
              _minCellWidth,
              _maxCellWidth,
            );
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 12),
          child: FloorPlan(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var row = 0; row < board.rows; row++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var column = 0; column < board.columns; column++)
                        SizedBox(
                          width: cellWidth,
                          height: _cellHeight,
                          child: _cell(board, row, column),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _cell(_WardBoard board, int row, int column) {
    final colors = Theme.of(context).colorScheme;
    final bed = board.bedAt(row, column);
    final landmark = board.landmarkAt(row, column);
    bool isPicked(Map<String, dynamic> item) =>
        _picked?.item['id'] == item['id'];
    void pick(Map<String, dynamic> item, bool isBed) => setState(
      () => _picked = isPicked(item) ? null : _Picked(item, isBed: isBed),
    );

    if (bed != null) {
      final card = _bedCard(board, bed, compact: true);
      if (!_editing) return card;
      return _Selectable(
        label: 'Pick bed ${bed['label']}',
        selected: isPicked(bed),
        onTap: () => pick(bed, true),
        child: IgnorePointer(child: card),
      );
    }
    if (landmark != null) {
      final label = PlanFixture(label: landmark['label']);
      if (!_editing) return label;
      return _Selectable(
        label: 'Pick ${landmark['label']}',
        selected: isPicked(landmark),
        onTap: () => pick(landmark, false),
        child: label,
      );
    }
    if (!_editing) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Semantics(
        button: true,
        label: 'Cell ${row + 1}-${column + 1}',
        child: InkWell(
          onTap: () => _tapEmptyCell(board, row, column),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              border: Border.all(color: colors.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                _picked == null ? Icons.add : Icons.place,
                size: 18,
                color: colors.outline,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Shown at the bottom while editing: what to do with the picked item.
  Widget _editBar() {
    final picked = _picked;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: picked == null
            ? const Text(
                'Tap an empty cell to put a bed or label there. '
                'Tap a bed or label to move or remove it.',
              )
            : Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text('Tap an empty cell to move ${picked.name}.'),
                  if (picked.isBed)
                    TextButton(
                      onPressed: () => _do(
                        () => Api.placeBed(picked.item['id'], null, null),
                        'Taken off the map',
                      ),
                      child: const Text('Take off map'),
                    ),
                  if (picked.isBed && _severalRooms)
                    TextButton(
                      onPressed: () => _moveToRoom(picked.item),
                      child: const Text('Move to room'),
                    ),
                  TextButton(
                    onPressed: () => picked.isBed
                        ? _deleteBed(picked.item)
                        : _do(
                            () => Api.deleteLandmark(picked.item['id']),
                            'Label removed',
                          ),
                    child: const Text('Delete'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _picked = null),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _bedCard(
    _WardBoard board,
    Map<String, dynamic> bed, {
    bool compact = false,
  }) {
    final patient = board.patientIn(bed['id']);
    final taken = board.occupied.contains(bed['id']);
    final BedState state;
    final String status;
    final VoidCallback? onTap;
    if (patient != null) {
      state = BedState.mine;
      status = patient['full_name'];
      onTap = () =>
          _open(PatientScreen(me: widget.me, patientId: patient['id']));
    } else if (taken) {
      state = BedState.occupied;
      status = 'Occupied';
      onTap = null;
    } else {
      state = BedState.free;
      status = 'Free';
      onTap = widget.me.role == StaffRole.viewer
          ? null
          : () => _open(AdmitScreen(ward: widget.ward, bedId: bed['id']));
    }
    return TopDownBed(
      label: 'Bed ${bed['label']}',
      status: status,
      state: state,
      onTap: onTap,
      onLongPress: widget.me.isAdmin && !taken && !compact
          ? () => _deleteBed(bed)
          : null,
    );
  }
}

/// Highlights a map item that can be picked up and moved.
class _Selectable extends StatelessWidget {
  const _Selectable({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              width: 2,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: child,
        ),
      ),
    );
  }
}
