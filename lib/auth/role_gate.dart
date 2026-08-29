import 'package:flutter/material.dart';

import '../data/db.dart';
import '../trips/trips_screen.dart';

/// After login, loads the user's role from `profiles` and routes:
///  - driver          → the trips screen
///  - admin / agent    → a friendly "use the web dashboard" screen
///
/// This mirrors the website, which routes admin→/admin, agent→/agent,
/// driver→/driver from the same login. Row-Level Security lets a user read
/// their own profile row, so no service key is involved.
class RoleGate extends StatefulWidget {
  final String userId;
  const RoleGate({super.key, required this.userId});

  @override
  State<RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<RoleGate> {
  late Future<Map<String, dynamic>> _profile;

  @override
  void initState() {
    super.initState();
    _profile = supabase
        .from('profiles')
        .select('role, full_name')
        .eq('id', widget.userId)
        .single();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _profile,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return const _Message(
            title: 'Something went wrong',
            body: 'Could not load your profile. Please sign out and try again.',
          );
        }
        final role = snap.data?['role'] as String?;
        final name = snap.data?['full_name'] as String?;
        if (role == 'driver') {
          return TripsScreen(driverName: name);
        }
        return _Message(
          title: 'This app is for drivers',
          body: 'Your account is a ${role ?? 'staff'} account. '
              'Managers, please use the CargoTrace web dashboard.',
        );
      },
    );
  }
}

/// Full-screen message with a sign-out action (used for the role gate and
/// profile-load errors).
class _Message extends StatelessWidget {
  final String title;
  final String body;
  const _Message({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(body, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () => supabase.auth.signOut(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
