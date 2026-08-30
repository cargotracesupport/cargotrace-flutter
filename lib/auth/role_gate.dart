import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/vehicle.dart';
import '../shell/home_shell.dart';
import '../theme/tokens.dart';
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
  late Future<_Loaded> _profile;

  @override
  void initState() {
    super.initState();
    _profile = _load();
  }

  /// Two steps rather than a PostgREST embed: `profiles.vehicle_id` has no FK
  /// relationship the API can join on, so the vehicle is fetched by id.
  Future<_Loaded> _load() async {
    final p = await supabase
        .from('profiles')
        .select('role, full_name, phone, vehicle_id')
        .eq('id', widget.userId)
        .single();
    Vehicle? vehicle;
    final vid = p['vehicle_id'] as String?;
    if (vid != null) {
      final rows =
          await supabase.from('vehicles').select('id, plate, name').eq('id', vid);
      if (rows.isNotEmpty) vehicle = Vehicle.fromMap(rows.first);
    }
    return _Loaded(
      role: p['role'] as String?,
      name: p['full_name'] as String?,
      phone: p['phone'] as String?,
      vehicle: vehicle,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Loaded>(
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
        final role = snap.data?.role;
        if (role == 'driver') {
          return HomeShell(
            driverName: snap.data?.name,
            phone: snap.data?.phone,
            vehicle: snap.data?.vehicle,
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

/// What [RoleGate] needs after loading: the driver's role, name, phone and
/// resolved vehicle.
class _Loaded {
  final String? role;
  final String? name;
  final String? phone;
  final Vehicle? vehicle;
  const _Loaded({this.role, this.name, this.phone, this.vehicle});
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
