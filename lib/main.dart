import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/login_screen.dart';
import 'auth/onboarding_screen.dart';
import 'auth/role_gate.dart';
import 'config.dart';
import 'data/db.dart';
import 'data/prefs.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Prefs.load();
  ThemeController.init();
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
    // Rebuilds the app when the driver picks a theme in Profile. The default
    // is ThemeMode.system, so it follows the phone until they choose.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, _) => MaterialApp(
        title: 'Goodswala',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        home: const AuthGate(),
      ),
    );
  }
}

/// Swaps between the signed-out flow and the role gate (signed in), reacting
/// live to Supabase auth changes so sign-in / sign-out just work.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, _) {
        final session = supabase.auth.currentSession;
        if (session == null) return const SignedOutFlow();
        return RoleGate(userId: session.user.id);
      },
    );
  }
}

/// Onboarding first, then sign-in. Both share the truck backdrop, so moving
/// between them reads as one scene with the panel swapping.
///
/// The step is held in state rather than persisted, so a signed-out user sees
/// onboarding again on the next launch. Persisting "already seen" would need a
/// storage plugin.
///
/// Signing out always lands back on onboarding: while signed in [AuthGate]
/// builds a [RoleGate] instead, so this widget's element is destroyed and a
/// fresh state (with [_started] false) is created on the way back. Keep that
/// type swap in place — routing both states through one shared widget would
/// preserve [_started] and drop the user straight onto the sign-in form.
class SignedOutFlow extends StatefulWidget {
  const SignedOutFlow({super.key});

  @override
  State<SignedOutFlow> createState() => _SignedOutFlowState();
}

class _SignedOutFlowState extends State<SignedOutFlow> {
  bool _started = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: _started
          ? const LoginScreen(key: ValueKey('login'))
          : OnboardingScreen(
              key: const ValueKey('onboarding'),
              onGetStarted: () => setState(() => _started = true),
            ),
    );
  }
}
