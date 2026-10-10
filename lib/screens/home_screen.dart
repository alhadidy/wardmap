import 'package:flutter/material.dart';

import '../api.dart';
import '../roles.dart';
import 'login_screen.dart';
import 'patients_tab.dart';
import 'team_tab.dart';

/// After login: my patients, and the team accounts I manage.
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
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()));
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
                  ? TextButton(onPressed: _logOut, child: const Text('Account not found. Log out'))
                  : const CircularProgressIndicator(),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text('${me.fullName} · ${me.role.label}'),
            actions: [
              IconButton(
                  tooltip: 'Log out',
                  onPressed: _logOut,
                  icon: const Icon(Icons.logout)),
            ],
          ),
          body: _tab == 0 ? const PatientsTab() : TeamTab(me: me),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.bed), label: 'Patients'),
              NavigationDestination(icon: Icon(Icons.group), label: 'Team'),
            ],
          ),
        );
      },
    );
  }
}
