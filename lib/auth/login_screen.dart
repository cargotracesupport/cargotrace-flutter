import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/db.dart';
import '../data/vehicle.dart';
import '../theme/tokens.dart';
import '../widgets/ct_widgets.dart';

/// Email + password sign-in, plus a vehicle-number check. The same CargoTrace
/// accounts as the website — a driver's credentials work in both. Role routing
/// happens in [RoleGate].
///
/// The vehicle number is a second factor: after the password is accepted, the
/// typed number must match the vehicle on the driver's profile (or, if none is
/// assigned yet, any vehicle on file — which then becomes theirs). A wrong
/// number rejects the sign-in.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  /// Carries a vehicle-check failure back to a freshly rebuilt login screen
  /// after we sign the half-authenticated session out.
  static String? bootError;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _vehicle = TextEditingController();
  final _passwordFocus = FocusNode();
  final _vehicleFocus = FocusNode();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Surface a vehicle-check failure from the previous attempt.
    _error = LoginScreen.bootError;
    LoginScreen.bootError = null;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _vehicle.dispose();
    _passwordFocus.dispose();
    _vehicleFocus.dispose();
    super.dispose();
  }

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();
    if (_vehicle.text.trim().isEmpty) {
      setState(() => _error = 'Enter your vehicle number.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await supabase.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      // Password OK — now the vehicle check. A failure here throws and the
      // session is rolled back so a wrong vehicle number never gets in.
      await _verifyVehicle();
      // AuthGate reacts to the auth state change and swaps the screen.
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on _VehicleError catch (e) {
      // Undo the sign-in; hand the message to the rebuilt login screen.
      LoginScreen.bootError = e.message;
      await supabase.auth.signOut();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not sign in. Check your connection.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Throws [_VehicleError] if the typed number doesn't match. Assigns the
  /// matched vehicle to the profile when none was set before.
  Future<void> _verifyVehicle() async {
    final uid = supabase.auth.currentUser!.id;
    final typed = _norm(_vehicle.text);

    final rows = await supabase.from('vehicles').select('id, plate, name');
    final vehicles = rows.map(Vehicle.fromMap).toList();

    Vehicle? match;
    for (final v in vehicles) {
      final plate = v.plate == null ? null : _norm(v.plate!);
      if (plate == typed || _norm(v.number) == typed) {
        match = v;
        break;
      }
    }
    if (match == null) {
      throw const _VehicleError('Vehicle number not recognised.');
    }

    final profile =
        await supabase.from('profiles').select('vehicle_id').eq('id', uid).single();
    final assigned = profile['vehicle_id'] as String?;
    if (assigned != null && assigned != match.id) {
      throw const _VehicleError("That vehicle isn't assigned to your account.");
    }
    if (assigned == null) {
      await supabase.from('profiles').update({'vehicle_id': match.id}).eq('id', uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ct;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: CtSpace.lg,
              vertical: CtSpace.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Brand(),
                  const SizedBox(height: CtSpace.xl),
                  CtCard(
                    padding: const EdgeInsets.all(CtSpace.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Sign in',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: c.text,
                          ),
                        ),
                        const SizedBox(height: CtSpace.xs),
                        Text(
                          'Use your CargoTrace driver account.',
                          style: TextStyle(color: c.muted2),
                        ),
                        const SizedBox(height: CtSpace.lg),
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: const [AutofillHints.username],
                          enabled: !_busy,
                          onSubmitted: (_) => _passwordFocus.requestFocus(),
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.mail_outline, size: 20),
                          ),
                        ),
                        const SizedBox(height: CtSpace.md),
                        TextField(
                          controller: _password,
                          focusNode: _passwordFocus,
                          obscureText: _obscure,
                          enabled: !_busy,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => _vehicleFocus.requestFocus(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline, size: 20),
                            suffixIcon: IconButton(
                              // 48dp tap target for the reveal toggle.
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 20,
                              ),
                              tooltip: _obscure
                                  ? 'Show password'
                                  : 'Hide password',
                            ),
                          ),
                        ),
                        const SizedBox(height: CtSpace.md),
                        TextField(
                          controller: _vehicle,
                          focusNode: _vehicleFocus,
                          enabled: !_busy,
                          textCapitalization: TextCapitalization.characters,
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _busy ? null : _signIn(),
                          decoration: const InputDecoration(
                            labelText: 'Vehicle number',
                            hintText: 'e.g. KA01AB1234',
                            prefixIcon:
                                Icon(Icons.local_shipping_outlined, size: 20),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: CtSpace.md),
                          _ErrorBanner(_error!),
                        ],
                        const SizedBox(height: CtSpace.lg),
                        CtPrimaryButton(
                          label: 'Sign in',
                          loading: _busy,
                          onPressed: _signIn,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: CtSpace.lg),
                  Text(
                    'Managers and dispatchers use the web dashboard.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.muted, fontSize: 12),
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

/// Internal signal that the vehicle-number check failed.
class _VehicleError implements Exception {
  final String message;
  const _VehicleError(this.message);
}

class _Brand extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.ct;
    return Column(
      children: [
        SvgPicture.asset(
          'assets/illustrations/truck.svg',
          height: 132,
          semanticsLabel: 'Delivery truck',
        ),
        const SizedBox(height: CtSpace.md),
        Text(
          'CargoTrace',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: c.text,
            letterSpacing: -0.4,
          ),
        ),
        Text(
          'Driver',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: c.primary,
            letterSpacing: 2.4,
          ),
        ),
      ],
    );
  }
}

/// Inline error, placed directly under the fields it refers to. Icon + text so
/// the failure is not signalled by colour alone.
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    final c = context.ct;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.red.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(CtRadius.lg),
        border: Border.all(color: c.red.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: c.red),
          const SizedBox(width: CtSpace.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: c.red, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
