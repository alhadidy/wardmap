import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

// Backend address and publishable (public) key, passed at build time:
//   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_KEY=...
// See docs/setup.md.
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseKey = String.fromEnvironment('SUPABASE_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
  runApp(const WardmapApp());
}

class WardmapApp extends StatelessWidget {
  const WardmapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wardmap',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: Api.isLoggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}
