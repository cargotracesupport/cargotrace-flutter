import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/db.dart';
import '../theme/tokens.dart';
import '../widgets/ct_widgets.dart';

/// Email + password sign-in. The same CargoTrace accounts as the website — a
/// driver's credentials work in both. Role routing happens in [RoleGate].
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await supabase.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      // AuthGate reacts to the auth state change and swaps the screen.
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not sign in. Check your connection.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
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
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _busy ? null : _signIn(),
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

class _Brand extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.ct;
    return Column(
      children: [
        Container(
          height: 64,
          width: 64,
          decoration: BoxDecoration(
            gradient: c.gradPrimary,
            borderRadius: BorderRadius.circular(CtRadius.xl),
            boxShadow: [
              BoxShadow(
                color: c.primary.withValues(alpha: 0.42),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Icon(Icons.local_shipping_rounded,
              size: 34, color: c.onAccent),
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
