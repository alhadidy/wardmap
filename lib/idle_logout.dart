import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';

/// Logs the user out after [limit] without a tap or key press, so a phone or
/// ward computer left unattended doesn't stay open on patient data.
///
/// Also checks when the app comes back from the background, because timers
/// don't run while a phone app is suspended.
class IdleLogout extends StatefulWidget {
  const IdleLogout({
    super.key,
    required this.limit,
    required this.onLogout,
    required this.child,
  });

  final Duration limit;
  final VoidCallback onLogout;
  final Widget child;

  @override
  State<IdleLogout> createState() => _IdleLogoutState();
}

class _IdleLogoutState extends State<IdleLogout> with WidgetsBindingObserver {
  Timer? _timer;
  DateTime _lastActive = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_onKey);
    _restart();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent _) {
    _restart();
    return false; // Let the key through.
  }

  void _restart() {
    _lastActive = DateTime.now();
    _timer?.cancel();
    _timer = Timer(widget.limit, _timeUp);
  }

  Future<void> _timeUp() async {
    if (!Api.isLoggedIn) return;
    await Api.logOut();
    widget.onLogout();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (DateTime.now().difference(_lastActive) >= widget.limit) {
        _timeUp();
      } else {
        _restart();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _restart(),
      onPointerSignal: (_) => _restart(),
      child: widget.child,
    );
  }
}
