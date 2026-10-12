import 'package:flutter/material.dart';

import '../api.dart';
import '../components.dart';
import '../theme.dart';
import 'home_screen.dart';

/// Username + PIN. Accounts are created by a senior, never self-registered.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.username, this.message});

  /// Prefilled after an automatic logout.
  final String? username;

  /// Shown above the form, e.g. why the user was logged out.
  final String? message;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final _username = TextEditingController(text: widget.username);
  final _pin = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _logIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.logIn(_username.text, _pin.text);
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (_) {
      setState(() => _error = 'Wrong username or PIN');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: BrandMark(size: 56)),
                  const SizedBox(height: Space.lg),
                  Text(
                    'Wardmap',
                    textAlign: TextAlign.center,
                    style: context.text.headlineMedium,
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    'Log in with the username and PIN your senior gave you.',
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Space.xl),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(Space.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: Space.lg,
                        children: [
                          if (widget.message != null)
                            Notice(widget.message!, icon: Icons.lock_clock),
                          TextField(
                            controller: _username,
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            autocorrect: false,
                            textInputAction: TextInputAction.next,
                          ),
                          TextField(
                            controller: _pin,
                            decoration: const InputDecoration(
                              labelText: 'PIN',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            obscureText: true,
                            keyboardType: TextInputType.number,
                            onSubmitted: (_) => _logIn(),
                          ),
                          if (_error != null)
                            Notice(_error!, tone: Tone.danger),
                          FilledButton(
                            onPressed: _busy ? null : _logIn,
                            child: Text(_busy ? 'Logging in…' : 'Log in'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
