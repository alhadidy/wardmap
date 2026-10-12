import 'package:flutter/material.dart';

/// Drawing pieces for showing rooms from above, like an architect's floor
/// plan: walls around a tiled floor, beds seen from the ceiling (headboard,
/// pillow, blanket) and fixtures such as the nurse station.
/// Used by the ward board and the rooms list.

/// What a bed shows. [mine] means taken by a patient I can see.
enum BedState { free, mine, occupied }

/// The plan's colours, kept in one place so every screen matches.
class PlanColors {
  static const floor = Color(0xFFF6F4EF);
  static const tileLine = Color(0xFFE9E5DC);
  static const wall = Color(0xFF3E4C59);
  static const fixture = Color(0xFFE3E8EC);
  static const fixtureInk = Color(0xFF4A5A68);

  static const freeBlanket = Color(0xFFE6F4EA);
  static const freeInk = Color(0xFF2E6B47);
  static const mineBlanket = Color(0xFF16867A);
  static const occupiedBlanket = Color(0xFFB8C2CC);
  static const occupiedInk = Color(0xFF34404B);

  static Color blanket(BedState s) => switch (s) {
    BedState.free => freeBlanket,
    BedState.mine => mineBlanket,
    BedState.occupied => occupiedBlanket,
  };

  static Color ink(BedState s) => switch (s) {
    BedState.free => freeInk,
    BedState.mine => Colors.white,
    BedState.occupied => occupiedInk,
  };

  /// Headboard and frame: a darker shade of the blanket.
  static Color frame(BedState s) =>
      Color.lerp(blanket(s), Colors.black, s == BedState.free ? 0.35 : 0.3)!;
}

/// A room's walls and tiled floor, with an optional name on the wall.
class FloorPlan extends StatelessWidget {
  const FloorPlan({
    super.key,
    required this.child,
    this.name,
    this.padding = const EdgeInsets.all(10),
    this.tileSize = 24,
    this.wallWidth = 5,
  });

  final Widget child;
  final String? name;
  final EdgeInsets padding;
  final double tileSize;
  final double wallWidth;

  @override
  Widget build(BuildContext context) {
    // A Container insets its child by the border, so the floor stays inside
    // the walls rather than painted over them.
    final plan = Container(
      decoration: BoxDecoration(
        color: PlanColors.floor,
        border: Border.all(color: PlanColors.wall, width: wallWidth),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: CustomPaint(
          painter: _TilePainter(tileSize),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    if (name == null) return plan;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            name!.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w600,
              color: PlanColors.wall,
            ),
          ),
        ),
        plan,
      ],
    );
  }
}

class _TilePainter extends CustomPainter {
  _TilePainter(this.tile);

  final double tile;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = PlanColors.tileLine
      ..strokeWidth = 1;
    for (var x = tile; x < size.width; x += tile) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (var y = tile; y < size.height; y += tile) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(_TilePainter old) => old.tile != tile;
}

/// A bed seen from above: headboard, pillow and a blanket coloured by
/// [state], with the bed's name and who is in it written on the blanket.
class TopDownBed extends StatelessWidget {
  const TopDownBed({
    super.key,
    required this.label,
    required this.status,
    required this.state,
    this.onTap,
    this.onLongPress,
  });

  final String label;
  final String status;
  final BedState state;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final ink = PlanColors.ink(state);
    final frame = PlanColors.frame(state);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Material(
        color: Colors.white,
        elevation: state == BedState.free ? 1 : 2,
        shadowColor: const Color(0x55000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: frame, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Headboard.
              Container(height: 6, color: frame),
              // Pillow.
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDFDFB),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFD9D6CE)),
                  ),
                ),
              ),
              // Blanket, with its folded-back edge.
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: PlanColors.blanket(state),
                    border: Border(
                      top: BorderSide(
                        color: Color.lerp(
                          PlanColors.blanket(state),
                          Colors.white,
                          0.45,
                        )!,
                        width: 5,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(6, 3, 6, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          status,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: ink, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A fixed feature of the room drawn on the plan (nurse station, WC…),
/// with an icon guessed from its label.
class PlanFixture extends StatelessWidget {
  const PlanFixture({super.key, required this.label});

  final String label;

  static IconData iconFor(String label) {
    final l = label.toLowerCase();
    bool has(List<String> words) => words.any(l.contains);
    if (has(['nurse', 'station', 'desk', 'counter'])) {
      return Icons.medical_services_outlined;
    }
    if (has(['wc', 'toilet', 'bath', 'shower', 'restroom'])) return Icons.wc;
    if (has(['entrance', 'entry', 'door', 'exit'])) {
      return Icons.door_front_door_outlined;
    }
    if (has(['sink', 'wash', 'hand'])) return Icons.wash_outlined;
    if (has(['stair'])) return Icons.stairs_outlined;
    if (has(['lift', 'elevator'])) return Icons.elevator_outlined;
    if (has(['store', 'supply', 'supplies', 'stock'])) {
      return Icons.inventory_2_outlined;
    }
    if (has(['window'])) return Icons.window_outlined;
    if (has(['doctor', 'office', 'room'])) return Icons.chair_outlined;
    if (has(['oxygen', 'gas'])) return Icons.air;
    if (has(['trolley', 'crash', 'resus'])) return Icons.monitor_heart_outlined;
    return Icons.place_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: PlanColors.fixture,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFC5CED6)),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(iconFor(label), size: 20, color: PlanColors.fixtureInk),
                const SizedBox(height: 2),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: PlanColors.fixtureInk,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small key explaining the bed colours.
class BedLegend extends StatelessWidget {
  const BedLegend({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(BedState s, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: PlanColors.blanket(s),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: PlanColors.frame(s)),
          ),
        ),
        const SizedBox(width: 4),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        item(BedState.free, 'Free'),
        item(BedState.mine, 'Your patient'),
        item(BedState.occupied, 'Occupied'),
      ],
    );
  }
}

/// A room in miniature for the rooms list: its walls, and each bed as a
/// small coloured block where it sits on the room's map (or in a row when
/// the room has no map yet).
class RoomMiniPlan extends StatelessWidget {
  const RoomMiniPlan({
    super.key,
    required this.rows,
    required this.columns,
    required this.beds,
  });

  final int rows;
  final int columns;

  /// Each bed's map cell (null if not placed) and state.
  final List<({int? row, int? column, BedState state})> beds;

  @override
  Widget build(BuildContext context) {
    final placed = beds
        .where(
          (b) =>
              b.row != null &&
              b.column != null &&
              b.row! < rows &&
              b.column! < columns,
        )
        .toList();
    final loose = beds.where((b) => !placed.contains(b)).toList();
    Widget block(BedState s) => Container(
      decoration: BoxDecoration(
        color: PlanColors.blanket(s),
        borderRadius: BorderRadius.circular(3),
        border: Border(
          top: BorderSide(color: PlanColors.frame(s), width: 3),
          left: BorderSide(color: PlanColors.frame(s), width: 0.8),
          right: BorderSide(color: PlanColors.frame(s), width: 0.8),
          bottom: BorderSide(color: PlanColors.frame(s), width: 0.8),
        ),
      ),
    );
    return FloorPlan(
      padding: const EdgeInsets.all(6),
      tileSize: 12,
      wallWidth: 3,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (placed.isNotEmpty)
            SizedBox(
              height: 96,
              child: LayoutBuilder(
                builder: (context, c) {
                  // Same scale both ways so beds keep their shape; centred.
                  final unit = [
                    c.maxWidth / columns,
                    c.maxHeight / (rows * 1.3),
                  ].reduce((a, b) => a < b ? a : b);
                  final w = unit, h = unit * 1.3;
                  final left = (c.maxWidth - w * columns) / 2;
                  final top = (c.maxHeight - h * rows) / 2;
                  return Stack(
                    children: [
                      for (final b in placed)
                        Positioned(
                          left: left + b.column! * w + w * 0.15,
                          top: top + b.row! * h + h * 0.1,
                          width: w * 0.7,
                          height: h * 0.8,
                          child: block(b.state),
                        ),
                    ],
                  );
                },
              ),
            ),
          if (loose.isNotEmpty)
            Container(
              constraints: BoxConstraints(minHeight: placed.isEmpty ? 96 : 0),
              alignment: Alignment.center,
              padding: EdgeInsets.only(top: placed.isEmpty ? 0 : 6),
              child: Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  for (final b in loose)
                    SizedBox(width: 14, height: 20, child: block(b.state)),
                ],
              ),
            ),
          if (beds.isEmpty)
            const SizedBox(
              height: 96,
              child: Center(
                child: Text(
                  'No beds',
                  style: TextStyle(fontSize: 11, color: PlanColors.fixtureInk),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
