import 'package:flutter/material.dart';

import '../api.dart';
import '../roles.dart';

/// Colleagues in my hospital. I can create, reset and deactivate accounts
/// for anyone junior to me (admins: anyone).
class TeamTab extends StatefulWidget {
  const TeamTab({super.key, required this.me});

  final Staff me;

  @override
  State<TeamTab> createState() => _TeamTabState();
}

class _TeamTabState extends State<TeamTab> {
  late Future<List<Staff>> _staff = Api.colleagues();

  bool _canManage(Staff s) =>
      s.id != widget.me.id && widget.me.role.canCreate.contains(s.role);

  void _reload() => setState(() => _staff = Api.colleagues());

  Future<void> _run(Future<void> Function() action, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(done)));
      _reload();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _createAccount() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _AccountDialog(roles: widget.me.role.canCreate),
    );
    if (created == true) _reload();
  }

  Future<void> _resetPin(Staff s) async {
    final pin = await _askForPin(context, 'New PIN for ${s.fullName}');
    if (pin != null) _run(() => Api.resetPin(s.id, pin), 'PIN changed');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: widget.me.role.canCreate.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _createAccount,
              icon: const Icon(Icons.person_add),
              label: const Text('New account'),
            ),
      body: FutureBuilder<List<Staff>>(
        future: _staff,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final staff = snapshot.data!
            ..sort((a, b) => b.role.rank.compareTo(a.role.rank));
          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              for (final s in staff)
                ListTile(
                  leading: CircleAvatar(child: Text(s.role.short)),
                  title: Text(s.fullName),
                  subtitle: Text(
                    '@${s.username}${s.isActive ? '' : ' · deactivated'}',
                  ),
                  enabled: s.isActive,
                  trailing: !_canManage(s)
                      ? null
                      : PopupMenuButton<String>(
                          onSelected: (choice) => switch (choice) {
                            'pin' => _resetPin(s),
                            _ => _run(
                              () => Api.setActive(s.id, !s.isActive),
                              s.isActive ? 'Deactivated' : 'Reactivated',
                            ),
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'pin',
                              child: Text('Reset PIN'),
                            ),
                            PopupMenuItem(
                              value: 'active',
                              child: Text(
                                s.isActive ? 'Deactivate' : 'Reactivate',
                              ),
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

Future<String?> _askForPin(BuildContext context, String title) {
  final pin = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: pin,
        decoration: const InputDecoration(labelText: 'PIN (6-12 digits)'),
        keyboardType: TextInputType.number,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, pin.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

class _AccountDialog extends StatefulWidget {
  const _AccountDialog({required this.roles});

  final List<StaffRole> roles;

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _pin = TextEditingController();
  late StaffRole _role = widget.roles.first;
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.createAccount(
        username: _username.text,
        fullName: _name.text,
        role: _role,
        pin: _pin.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New account'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Full name'),
          ),
          TextField(
            controller: _username,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Username'),
          ),
          DropdownButtonFormField<StaffRole>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'Role'),
            items: [
              for (final r in widget.roles)
                DropdownMenuItem(value: r, child: Text(r.label)),
            ],
            onChanged: (r) => setState(() => _role = r!),
          ),
          TextField(
            controller: _pin,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'PIN (6-12 digits)'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('Create'),
        ),
      ],
    );
  }
}
