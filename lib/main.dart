import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'data/db.dart';
import 'auth/login_screen.dart';
import 'auth/role_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: Config.supabaseUrl,
    // This project uses the classic anon JWT (same key the website ships).
    // publishableKey is Supabase's newer key format, not adopted here yet.
    // ignore: deprecated_member_use
    anonKey: Config.supabaseAnonKey,
  );
  runApp(const CargoTraceDriverApp());
}

class CargoTraceDriverApp extends StatelessWidget {
  const CargoTraceDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CargoTrace Driver',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2F9BD1),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

/// Swaps between the login screen (signed out) and the role gate (signed in),
/// reacting live to Supabase auth changes so sign-in / sign-out just work.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, _) {
        final session = supabase.auth.currentSession;
        if (session == null) return const LoginScreen();
        return RoleGate(userId: session.user.id);
      },
    );
  }
}
