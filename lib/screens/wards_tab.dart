import 'package:flutter/material.dart';

import '../api.dart';
import '../roles.dart';
import '../ui.dart';
import '../ward_types.dart';
import 'rooms_screen.dart';

/// All wards in my hospital, each with its type icons. Admins add, edit and
/// remove wards here.
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
    final result = await showDialog<_WardForm>(
      context: context,
      builder: (_) => const _WardDialog(),
    );
    if (result == null || !mounted) return;
    if (await runAction(
      context,
      () => Api.addWard(widget.me.hospitalId, result.name, result.types),
      'Ward added',
    )) {
      _reload();
    }
  }

  Future<void> _editWard(Map<String, dynamic> ward) async {
    final result = await showDialog<_WardForm>(
      context: context,
      builder: (_) => _WardDialog(ward: ward),
    );
    if (result == null || !mounted) return;
    if (await runAction(
      context,
      () => Api.updateWard(ward['id'], result.name, result.types),
      'Ward saved',
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
                  // Fixed width keeps ward names lined up; many icons shrink.
                  leading: SizedBox(
                    width: 76,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: WardTypeIcons(WardType.of(w)),
                    ),
                  ),
                  title: Text(w['name']),
                  subtitle: WardType.of(w).isEmpty
                      ? null
                      : Text(WardType.of(w).map((t) => t.label).join(' · ')),
                  onTap: () async {
                    await openWard(context, widget.me, w);
                    _reload();
                  },
                  trailing: !widget.me.isAdmin
                      ? const Icon(Icons.chevron_right)
                      : PopupMenuButton<String>(
                          onSelected: (c) =>
                              c == 'edit' ? _editWard(w) : _deleteWard(w),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit name and type'),
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

typedef _WardForm = ({String name, List<String> types});

/// Name and types for a new or existing ward.
class _WardDialog extends StatefulWidget {
  const _WardDialog({this.ward});

  final Map<String, dynamic>? ward;

  @override
  State<_WardDialog> createState() => _WardDialogState();
}

class _WardDialogState extends State<_WardDialog> {
  late final _name = TextEditingController(text: widget.ward?['name'] ?? '');
  late final Set<WardType> _types = {
    if (widget.ward != null) ...WardType.of(widget.ward!),
  };
  String? _error;

  void _save() {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Ward name is required');
      return;
    }
    Navigator.pop<_WardForm>(context, (
      name: _name.text,
      types: [
        for (final t in WardType.values)
          if (_types.contains(t)) t.key,
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.ward == null ? 'New ward' : 'Edit ward'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                autofocus: widget.ward == null,
                decoration: InputDecoration(
                  labelText: 'Ward name',
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Type (pick any that apply)',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in WardType.values)
                    FilterChip(
                      avatar: Icon(t.icon),
                      label: Text(t.label),
                      selected: _types.contains(t),
                      showCheckmark: false,
                      onSelected: (on) =>
                          setState(() => on ? _types.add(t) : _types.remove(t)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
