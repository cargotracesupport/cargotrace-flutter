import 'package:flutter/material.dart';

import '../data/db.dart';
import '../theme/tokens.dart';
import '../vehicle/vehicle_gate.dart';
import '../widgets/ct_widgets.dart';

/// After login, loads the user's role from `profiles` and routes:
///  - driver        → the trips screen
///  - admin / agent  → "use the web dashboard"
///
/// Mirrors the website, which routes admin→/admin, agent→/agent,
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
    _profile = _load();
  }

  Future<Map<String, dynamic>> _load() => supabase
      .from('profiles')
      .select('role, full_name, phone, vehicle_id')
      .eq('id', widget.userId)
      .single();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _profile,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return _Gate(
            icon: Icons.cloud_off_rounded,
            title: 'Could not load your profile',
            body: 'Check your connection and try again.',
            tint: context.ct.red,
            retry: () => setState(() => _profile = _load()),
          );
        }
        final role = snap.data?['role'] as String?;
        final name = snap.data?['full_name'] as String?;
        final phone = snap.data?['phone'] as String?;
        final vehicleId = snap.data?['vehicle_id'] as String?;
        if (role == 'driver') {
          return VehicleGate(
            driverName: name,
            phone: phone,
            initialVehicleId: vehicleId,
          );
        }
        return _Gate(
          icon: Icons.desktop_windows_outlined,
          title: 'This app is for drivers',
          body: 'Your account is a ${role ?? 'staff'} account. '
              'Managers and dispatchers use the CargoTrace web dashboard.',
        );
      },
    );
  }
}

class _Gate extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color? tint;
  final VoidCallback? retry;
  const _Gate({
    required this.icon,
    required this.title,
    required this.body,
    this.tint,
    this.retry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CtMessage(
          icon: icon,
          title: title,
          body: body,
          tint: tint,
          action: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Column(
              children: [
                if (retry != null) ...[
                  CtPrimaryButton(
                    label: 'Try again',
                    icon: Icons.refresh_rounded,
                    onPressed: retry,
                  ),
                  const SizedBox(height: CtSpace.sm),
                ],
                TextButton.icon(
                  onPressed: () => supabase.auth.signOut(),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Sign out'),
                  style: TextButton.styleFrom(
                    foregroundColor: context.ct.muted2,
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
