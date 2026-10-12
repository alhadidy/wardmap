import 'package:flutter/material.dart';

/// The kinds of ward an admin can tag a ward with. A ward can have several
/// (a women and children ward has both). The database accepts the same keys
/// (supabase/migrations/20261012120000_ward_types.sql); add new ones in both.
enum WardType {
  men('men', 'Men', Icons.man),
  women('women', 'Women', Icons.woman),
  children('children', 'Children', Icons.child_care),
  neonatal('neonatal', 'Neonatal', Icons.crib),
  maternity('maternity', 'Maternity', Icons.pregnant_woman),
  er('er', 'ER', Icons.emergency),
  icu('icu', 'ICU', Icons.monitor_heart),
  rcu('rcu', 'RCU', Icons.air),
  ccu('ccu', 'CCU', Icons.favorite),
  hdu('hdu', 'HDU', Icons.medical_services),
  medical('medical', 'Medical', Icons.medication),
  surgical('surgical', 'Surgical', Icons.healing),
  neuro('neuro', 'Neuro', Icons.psychology),
  ortho('ortho', 'Ortho', Icons.personal_injury),
  burns('burns', 'Burns', Icons.local_fire_department),
  oncology('oncology', 'Oncology', Icons.biotech),
  renal('renal', 'Renal', Icons.water_drop),
  psychiatric('psychiatric', 'Psychiatric', Icons.self_improvement),
  isolation('isolation', 'Isolation', Icons.coronavirus),
  recovery('recovery', 'Recovery', Icons.hotel),
  dayCase('day_case', 'Day case', Icons.wb_sunny);

  const WardType(this.key, this.label, this.icon);

  final String key;
  final String label;
  final IconData icon;

  /// The types stored on a ward row, in the order above. Unknown keys are
  /// skipped so an older app keeps working if new types are added.
  static List<WardType> of(Map<String, dynamic> ward) {
    final keys = {...(ward['types'] as List? ?? const [])};
    return [
      for (final t in values)
        if (keys.contains(t.key)) t,
    ];
  }
}

/// A ward's type icons in a row, or the plain room icon when it has none.
class WardTypeIcons extends StatelessWidget {
  const WardTypeIcons(this.types, {super.key, this.size = 24});

  final List<WardType> types;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (types.isEmpty) return Icon(Icons.meeting_room, size: size);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final t in types)
          Tooltip(
            message: t.label,
            child: Icon(t.icon, size: size, semanticLabel: t.label),
          ),
      ],
    );
  }
}
