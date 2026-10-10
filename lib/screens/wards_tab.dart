import 'package:flutter/material.dart';

import '../api.dart';
import '../roles.dart';
import '../ui.dart';
import 'ward_board_screen.dart';

/// All wards in my hospital. Admins add, rename and remove wards here.
class WardsTab extends StatefulWidget {
  const WardsTab({super.key, required this.me});

  final Staff me;

  @override
  State<WardsTab> createState() => _WardsTabState();
}

class _WardsTabState extends State<WardsTab> {
  late Future<List<Map<String, dynamic>>> _wards = Api.wards();

  void _reload() => setState(() => _wards = Api.wards());

  Future<void> _addWard() async {
    final name = await askText(context, 'New ward', 'Ward name');
    if (name == null || !mounted) return;
    if (await runAction(
      context,
      () => Api.addWard(widget.me.hospitalId, name),
      'Ward added',
    )) {
      _reload();
    }
  }

  Future<void> _renameWard(Map<String, dynamic> ward) async {
    final name = await askText(
      context,
      'Rename ward',
      'Ward name',
      initial: ward['name'],
    );
    if (name == null || !mounted) return;
    if (await runAction(
      context,
      () => Api.renameWard(ward['id'], name),
      'Ward renamed',
    )) {
      _reload();
    }
  }

  Future<void> _deleteWard(Map<String, dynamic> ward) async {
    if (!await confirm(
          context,
          'Remove ${ward['name']}? Only an empty ward with no beds can be removed.',
          'Remove',
        ) ||
        !mounted) {
      return;
    }
    if (await runAction(
      context,
      () => Api.deleteWard(ward['id']),
      'Ward removed',
    )) {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: widget.me.isAdmin
          ? FloatingActionButton.extended(
              onPressed: _addWard,
              icon: const Icon(Icons.add),
              label: const Text('New ward'),
            )
          : null,
      body: FutureBuilder(
        future: _wards,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final wards = snapshot.data!;
          if (wards.isEmpty) {
            return Center(
              child: Text(
                widget.me.isAdmin
                    ? 'No wards yet. Add the first one.'
                    : 'No wards yet. An admin needs to add them.',
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              for (final w in wards)
                ListTile(
                  leading: const Icon(Icons.meeting_room),
                  title: Text(w['name']),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => WardBoardScreen(me: widget.me, ward: w),
                      ),
                    );
                    _reload();
                  },
                  trailing: !widget.me.isAdmin
                      ? const Icon(Icons.chevron_right)
                      : PopupMenuButton<String>(
                          onSelected: (c) =>
                              c == 'rename' ? _renameWard(w) : _deleteWard(w),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'rename',
                              child: Text('Rename'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Remove'),
                            ),
                          ],
                        ),
                ),
            ],
          );
        },
      ),
    );
  }
}
