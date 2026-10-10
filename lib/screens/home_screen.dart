import 'package:flutter/material.dart';

import '../api.dart';
import '../roles.dart';
import 'juniors_tab.dart';
import 'login_screen.dart';
import 'patients_tab.dart';
import 'team_tab.dart';
import 'wards_tab.dart';

/// After login: the wards, my patients, my juniors' patients (seniors only),
/// and the team accounts I manage.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<Staff> _me = Api.me();
  int _tab = 0;

  Future<void> _logOut() async {
    await Api.logOut();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Staff>(
      future: _me,
      builder: (context, snapshot) {
        final me = snapshot.data;
        if (me == null) {
          return Scaffold(
            body: Center(
              child: snapshot.hasError
                  ? TextButton(
                      onPressed: _logOut,
                      child: const Text('Account not found. Log out'),
                    )
                  : const CircularProgressIndicator(),
            ),
          );
        }
        // Anyone with doctors below them gets the Juniors tab.
        final oversees = me.role.rank > StaffRole.rotator.rank && !me.isAdmin;
        final tabs = [
          (
            const NavigationDestination(
              icon: Icon(Icons.meeting_room),
              label: 'Wards',
            ),
            WardsTab(me: me),
          ),
          (
            const NavigationDestination(
              icon: Icon(Icons.bed),
              label: 'My patients',
            ),
            PatientsTab(me: me),
          ),
          if (oversees)
            (
              const NavigationDestination(
                icon: Icon(Icons.supervisor_account),
                label: 'Juniors',
              ),
              JuniorsTab(me: me),
            ),
          (
            const NavigationDestination(icon: Icon(Icons.group), label: 'Team'),
            TeamTab(me: me),
          ),
        ];
        return Scaffold(
          appBar: AppBar(
            title: Text('${me.fullName} · ${me.role.label}'),
            actions: [
              IconButton(
                tooltip: 'Log out',
                onPressed: _logOut,
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body: tabs[_tab].$2,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: [for (final t in tabs) t.$1],
          ),
        );
      },
    );
  }
}
