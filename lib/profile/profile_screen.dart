import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/vehicle.dart';
import '../theme/tokens.dart';
import '../widgets/ct_widgets.dart';

/// The Profile tab: who the driver is, which vehicle they signed in with, and
/// sign-out. Vehicle can be changed here, which re-runs the vehicle picker.
class ProfileScreen extends StatelessWidget {
  final String? driverName;
  final String? phone;
  final Vehicle? vehicle;

  const ProfileScreen({
    super.key,
    this.driverName,
    this.phone,
    this.vehicle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.ct;
    final email = supabase.auth.currentUser?.email;
    final name = (driverName == null || driverName!.trim().isEmpty)
        ? 'Driver'
        : driverName!;
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'D';

    return Scaffold(
      appBar: const CtHeader(
        title: 'Profile',
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              CtSpace.md, CtSpace.md, CtSpace.md, CtSpace.xl),
          children: [
            // Identity header.
            Row(
              children: [
                Container(
                  height: 56,
                  width: 56,
                  decoration: BoxDecoration(
                    gradient: c.gradPrimary,
                    borderRadius: BorderRadius.circular(CtRadius.lg),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: c.onAccent,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: CtSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: c.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: c.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'DRIVER',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: c.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: CtSpace.lg),

            // Vehicle.
            CtCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Line(
                    icon: Icons.local_shipping_outlined,
                    label: 'Vehicle number',
                    value: vehicle?.number ?? 'Not set',
                  ),
                  if (vehicle?.subtitle != null) ...[
                    const Divider(height: CtSpace.lg),
                    _Line(
                      icon: Icons.badge_outlined,
                      label: 'Vehicle',
                      value: vehicle!.subtitle!,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: CtSpace.md),

            // Contact / account.
            CtCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Line(
                    icon: Icons.mail_outline_rounded,
                    label: 'Email',
                    value: email ?? '—',
                  ),
                  if (phone != null && phone!.trim().isNotEmpty) ...[
                    const Divider(height: CtSpace.lg),
                    _Line(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: phone!,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: CtSpace.lg),

            CtPrimaryButton(
              label: 'Sign out',
              icon: Icons.logout_rounded,
              onPressed: () => supabase.auth.signOut(),
            ),
            const SizedBox(height: CtSpace.md),
            Text(
              'Managers and dispatchers use the CargoTrace web dashboard.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// A labelled value row with a leading icon and optional trailing widget.
class _Line extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Line({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.ct;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: c.muted2),
        const SizedBox(width: CtSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: c.muted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  color: c.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
