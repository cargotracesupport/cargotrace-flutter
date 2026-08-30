import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/vehicle.dart';
import '../shell/home_shell.dart';
import '../theme/tokens.dart';
import '../widgets/ct_widgets.dart';

/// Required vehicle step, shown after a driver signs in (and again when they
/// tap "Change" in Profile). The driver must pick the vehicle they're driving
/// before reaching the app. The choice is saved to `profiles.vehicle_id` so
/// dispatch and the web dashboard see the same vehicle.
///
/// Vehicles are managed records (the `vehicles` table), not free text — a plate
/// that isn't on file would break the foreign key — so the driver selects from
/// the list rather than typing a number.
class VehicleGate extends StatefulWidget {
  final String? driverName;
  final String? phone;
  final String? initialVehicleId;

  const VehicleGate({
    super.key,
    this.driverName,
    this.phone,
    this.initialVehicleId,
  });

  @override
  State<VehicleGate> createState() => _VehicleGateState();
}

class _VehicleGateState extends State<VehicleGate> {
  late Future<List<Vehicle>> _vehicles;
  String? _selectedId;
  bool _saving = false;

  /// Once confirmed, the app proper is shown; "Change" from Profile resets it.
  Vehicle? _confirmed;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialVehicleId;
    _vehicles = _load();
  }

  Future<List<Vehicle>> _load() async {
    final rows = await supabase
        .from('vehicles')
        .select('id, plate, name')
        .order('plate');
    return rows.map(Vehicle.fromMap).toList();
  }

  Future<void> _confirm(List<Vehicle> vehicles) async {
    final id = _selectedId;
    if (id == null) return;
    final vehicle = vehicles.firstWhere((v) => v.id == id);
    setState(() => _saving = true);
    try {
      // Persist so the web/dispatch see the vehicle this driver is on.
      await supabase
          .from('profiles')
          .update({'vehicle_id': id}).eq('id', supabase.auth.currentUser!.id);
    } catch (_) {
      // Best-effort: if the row can't be written (e.g. RLS), keep going with
      // the selection so the driver isn't locked out; just say it didn't save.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't save the vehicle to your profile."),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (mounted) setState(() => _confirmed = vehicle);
  }

  @override
  Widget build(BuildContext context) {
    if (_confirmed != null) {
      return HomeShell(
        driverName: widget.driverName,
        phone: widget.phone,
        vehicle: _confirmed,
        onChangeVehicle: () => setState(() => _confirmed = null),
      );
    }

    final c = context.ct;
    return Scaffold(
      appBar: const CtHeader(
        title: 'Select your vehicle',
        subtitle: 'Confirm what you\'re driving today',
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<Vehicle>>(
          future: _vehicles,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return CtMessage(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load vehicles',
                body: 'Check your connection and try again.',
                tint: c.red,
                action: CtPrimaryButton(
                  label: 'Try again',
                  icon: Icons.refresh_rounded,
                  onPressed: () => setState(() => _vehicles = _load()),
                ),
              );
            }
            final vehicles = snap.data ?? const <Vehicle>[];
            if (vehicles.isEmpty) {
              return CtMessage(
                icon: Icons.local_shipping_outlined,
                title: 'No vehicles available',
                body: 'Ask your dispatcher to add a vehicle for your account.',
                action: TextButton.icon(
                  onPressed: () => supabase.auth.signOut(),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Sign out'),
                ),
              );
            }
            // Keep the selection valid even if it wasn't in the list.
            if (_selectedId != null &&
                !vehicles.any((v) => v.id == _selectedId)) {
              _selectedId = null;
            }
            return Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        CtSpace.md, CtSpace.md, CtSpace.md, CtSpace.sm),
                    itemCount: vehicles.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: CtSpace.sm),
                    itemBuilder: (_, i) {
                      final v = vehicles[i];
                      final selected = v.id == _selectedId;
                      return _VehicleTile(
                        vehicle: v,
                        selected: selected,
                        onTap: _saving
                            ? null
                            : () => setState(() => _selectedId = v.id),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      CtSpace.md, CtSpace.sm, CtSpace.md, CtSpace.md),
                  child: CtPrimaryButton(
                    label: 'Continue',
                    loading: _saving,
                    onPressed: _selectedId == null
                        ? null
                        : () => _confirm(vehicles),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _VehicleTile extends StatelessWidget {
  final Vehicle vehicle;
  final bool selected;
  final VoidCallback? onTap;
  const _VehicleTile({
    required this.vehicle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.ct;
    final radius = BorderRadius.circular(CtRadius.xl);
    return Material(
      color: selected ? c.primary.withValues(alpha: 0.08) : c.s1,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(CtSpace.md),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected ? c.primary : c.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.local_shipping_rounded,
                  size: 22, color: selected ? c.primary : c.muted2),
              const SizedBox(width: CtSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.number,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                        letterSpacing: 0.4,
                      ),
                    ),
                    if (vehicle.subtitle != null)
                      Text(
                        vehicle.subtitle!,
                        style: TextStyle(fontSize: 13, color: c.muted2),
                      ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? c.primary : c.muted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
