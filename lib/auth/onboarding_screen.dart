import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../widgets/ct_widgets.dart';

/// First screen a signed-out user sees: the truck backdrop with a frosted
/// panel introducing the app and a "Get started" button that leads to sign-in.
class OnboardingScreen extends StatelessWidget {
  final VoidCallback onGetStarted;
  const OnboardingScreen({super.key, required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CtHeroBackdrop(
        child: Stack(
          children: [
            // Wordmark floats in the middle of the artwork, not in the panel.
            const Center(child: CtWordmark(fontSize: 40)),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(CtSpace.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: _GlassPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Every delivery, tracked door to door.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F1727),
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: CtSpace.sm),
                            const Text(
                              'Pick up, navigate turn by turn, and confirm '
                              'drop-off — your trips and their live status in one '
                              'place.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.45,
                                color: Color(0xCC0F1727),
                              ),
                            ),
                            const SizedBox(height: CtSpace.lg),
                            CtPrimaryButton(
                              label: 'Get started',
                              icon: Icons.arrow_forward_rounded,
                              onPressed: onGetStarted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Frosted, translucent panel so the artwork stays visible behind the copy.
class _GlassPanel extends StatelessWidget {
  final Widget child;
  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(CtRadius.xl);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(CtSpace.lg),
          decoration: BoxDecoration(
            // Fixed white glass: the backdrop is bright in both themes.
            color: Colors.white.withValues(alpha: 0.62),
            borderRadius: radius,
            border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F1E46).withValues(alpha: 0.14),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
