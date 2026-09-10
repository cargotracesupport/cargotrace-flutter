import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/db.dart';
import '../theme/tokens.dart';
import '../widgets/ct_widgets.dart';

/// Email + password sign-in shared by every role (agent, customer, driver) —
/// the same accounts as the website. What happens next depends on the role:
/// [RoleGate] reads it, and drivers are then asked for their vehicle number
/// on a separate step before reaching the app.
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Hero backdrop: a container truck on the highway. Anchored to the
          // top so the sky and truck stay visible above the sign-in card.
          Image.asset(
            'assets/illustrations/truck.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            excludeFromSemantics: true,
          ),
          // Scrim: clear over the artwork, solid page colour behind the form,
          // so the card and wordmark read in both light and dark themes.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  c.bg.withValues(alpha: 0),
                  c.bg.withValues(alpha: 0),
                  c.bg.withValues(alpha: 0.45),
                  c.bg.withValues(alpha: 0.85),
                ],
                stops: const [0, 0.58, 0.86, 1],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: CtSpace.lg,
                  vertical: CtSpace.lg,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - CtSpace.lg * 2,
                  ),
                  child: Column(
                    // Wordmark up in the sky, form pinned to the bottom, the
                    // truck filling the space between.
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Goodswala',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          // Fixed dark ink: this sits on the bright sky of the
                          // backdrop in light and dark themes.
                          color: Color(0xFF0F1727),
                          letterSpacing: -0.6,
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
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
                                    'Use your Goodswala account.',
                                    style: TextStyle(color: c.muted2),
                                  ),
                                  const SizedBox(height: CtSpace.lg),
                                  TextField(
                                    controller: _email,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    autocorrect: false,
                                    enableSuggestions: false,
                                    autofillHints: const [
                                      AutofillHints.username,
                                    ],
                                    enabled: !_busy,
                                    onSubmitted: (_) =>
                                        _passwordFocus.requestFocus(),
                                    decoration: const InputDecoration(
                                      labelText: 'Email',
                                      prefixIcon: Icon(
                                        Icons.mail_outline,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: CtSpace.md),
                                  TextField(
                                    controller: _password,
                                    focusNode: _passwordFocus,
                                    obscureText: _obscure,
                                    enabled: !_busy,
                                    autofillHints: const [
                                      AutofillHints.password,
                                    ],
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) =>
                                        _busy ? null : _signIn(),
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      prefixIcon: const Icon(
                                        Icons.lock_outline,
                                        size: 20,
                                      ),
                                      suffixIcon: IconButton(
                                        // 48dp tap target for the reveal toggle.
                                        onPressed: () => setState(
                                          () => _obscure = !_obscure,
                                        ),
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
                                    CtErrorBanner(_error!),
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
                            const SizedBox(height: CtSpace.md),
                            const Text(
                              'Accounts are created by your administrator.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xB30F1727),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
