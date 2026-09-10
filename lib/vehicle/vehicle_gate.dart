import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/prefs.dart';
import '../data/vehicle.dart';
import '../shell/home_shell.dart';
import '../theme/tokens.dart';
import '../widgets/ct_widgets.dart';

/// Driver-only step after sign-in: type the vehicle number to continue.
///
/// Works as a second factor. The typed number is matched (case- and
/// whitespace-insensitive) against `vehicles.plate`/`name`, and must be the
/// vehicle on the driver's profile; if the profile has no vehicle yet, the
/// matched one is assigned. A wrong or unknown number never reaches the app.
/// Shown on every launch so the driver confirms what they're driving today.
class VehicleGate extends StatefulWidget {
  final String? driverName;
  final String? phone;

  /// The vehicle currently on the profile, if any (from RoleGate's embed).
  final Vehicle? assigned;

  const VehicleGate({super.key, this.driverName, this.phone, this.assigned});

  @override
  State<VehicleGate> createState() => _VehicleGateState();
}

class _VehicleGateState extends State<VehicleGate> {
  final _number = TextEditingController();
  bool _busy = false;
  String? _error;
  Vehicle? _confirmed;

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  Future<void> _continue() async {
    FocusScope.of(context).unfocus();
    final typed = _norm(_number.text);
    if (typed.isEmpty) {
      setState(() => _error = 'Enter your vehicle number.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final uid = supabase.auth.currentUser!.id;
      final rows = await supabase.from('vehicles').select('id, plate, name');
      Vehicle? match;
      for (final v in rows.map(Vehicle.fromMap)) {
        final plate = v.plate == null ? null : _norm(v.plate!);
        if (plate == typed || _norm(v.number) == typed) {
          match = v;
          break;
        }
      }
      if (match == null) {
        setState(() => _error = 'Vehicle number not recognised.');
        return;
      }
      final assignedId = widget.assigned?.id;
      if (assignedId != null && assignedId != match.id) {
        setState(() => _error = "That vehicle isn't assigned to your account.");
        return;
      }
      if (assignedId == null) {
        await supabase
            .from('profiles')
            .update({'vehicle_id': match.id})
            .eq('id', uid);
      }
      // Remembered so the next launch skips straight to the app.
      await Prefs.setConfirmedVehicleId(match.id);
      if (mounted) setState(() => _confirmed = match);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not check the vehicle. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_confirmed != null) {
      return HomeShell(
        driverName: widget.driverName,
        phone: widget.phone,
        vehicle: _confirmed,
      );
    }

    final c = context.ct;
    final first = widget.driverName?.split(' ').first;
    return Scaffold(
      appBar: CtHeader(
        title: first == null ? 'Your vehicle' : 'Hi, $first',
        subtitle: 'Which vehicle are you driving today?',
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(CtSpace.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: CtCard(
                padding: const EdgeInsets.all(CtSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.local_shipping_rounded,
                      size: 40,
                      color: c.primary,
                    ),
                    const SizedBox(height: CtSpace.md),
                    Text(
                      'Enter your vehicle number',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: CtSpace.xs),
                    Text(
                      'This confirms the vehicle assigned to you before you '
                      'see your deliveries.',
                      style: TextStyle(color: c.muted2, height: 1.4),
                    ),
                    const SizedBox(height: CtSpace.lg),
                    TextField(
                      controller: _number,
                      enabled: !_busy,
                      autofocus: true,
                      textCapitalization: TextCapitalization.characters,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _busy ? null : _continue(),
                      decoration: const InputDecoration(
                        labelText: 'Vehicle number',
                        hintText: 'e.g. KA01AB1234',
                        prefixIcon: Icon(
                          Icons.local_shipping_outlined,
                          size: 20,
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: CtSpace.md),
                      CtErrorBanner(_error!),
                    ],
                    const SizedBox(height: CtSpace.lg),
                    CtPrimaryButton(
                      label: 'Continue',
                      icon: Icons.arrow_forward_rounded,
                      loading: _busy,
                      onPressed: _continue,
                    ),
                    const SizedBox(height: CtSpace.sm),
                    TextButton.icon(
                      onPressed: _busy ? null : () => supabase.auth.signOut(),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Sign out'),
                      style: TextButton.styleFrom(
                        foregroundColor: c.muted2,
                        minimumSize: const Size(0, 48),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
