import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// Brand app bar: the blue→cyan gradient behind a white title, optional
/// subtitle and trailing actions. Gives every screen a coloured header that
/// matches the web's brand bar. Two-line when [subtitle] is set.
class CtHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  const CtHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.automaticallyImplyLeading = true,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(subtitle == null ? kToolbarHeight : 64);

  @override
  Widget build(BuildContext context) {
    final c = context.ct;
    return AppBar(
      toolbarHeight: preferredSize.height,
      automaticallyImplyLeading: automaticallyImplyLeading,
      surfaceTintColor: Colors.transparent,
      foregroundColor: c.onAccent,
      elevation: 0,
      titleSpacing: CtSpace.md,
      // White status-bar glyphs read well over the blue gradient.
      systemOverlayStyle: SystemUiOverlayStyle.light,
      iconTheme: IconThemeData(color: c.onAccent),
      actionsIconTheme: IconThemeData(color: c.onAccent),
      // A solid base guarantees a coloured bar; the gradient sits on top.
      // (A Container fills the flexibleSpace slot; a bare DecoratedBox would
      // collapse to zero size inside the AppBar's Stack.)
      backgroundColor: c.primary,
      flexibleSpace: Container(
        decoration: BoxDecoration(gradient: c.gradPrimary),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: subtitle == null ? 18 : 20,
              fontWeight: FontWeight.w800,
              color: c.onAccent,
              letterSpacing: -0.2,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: c.onAccent.withValues(alpha: 0.85),
              ),
            ),
        ],
      ),
      actions: actions,
    );
  }
}

/// The shared sign-in backdrop: the truck artwork behind a scrim in the page
/// colour. Used by onboarding and the login screen so both look like one
/// continuous scene.
///
/// The artwork is bright in light and dark themes, so anything drawn on top of
/// it should use fixed ink colours rather than the theme's text colours.
class CtHeroBackdrop extends StatelessWidget {
  final Widget child;
  const CtHeroBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.ct;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/illustrations/truck.png',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          excludeFromSemantics: true,
        ),
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
        child,
      ],
    );
  }
}

/// The Goodswala wordmark: "Goods" in dark ink, "wala" in brand blue, with a
/// soft white glow so it reads over the sky, the road or the container.
class CtWordmark extends StatelessWidget {
  final double fontSize;
  const CtWordmark({super.key, this.fontSize = 32});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      const TextSpan(
        children: [
          TextSpan(text: 'Goods'),
          TextSpan(
            text: 'wala',
            style: TextStyle(color: Color(0xFF2563EB)),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF0F1727),
        letterSpacing: -0.6,
        // Two-stop white halo: centred on the artwork the mark can sit over
        // the sky, the white cab or the blue container, and a single soft
        // shadow wasn't enough to hold the blue "wala" against the container.
        shadows: const [
          Shadow(color: Color(0xF2FFFFFF), blurRadius: 16),
          Shadow(color: Color(0x80FFFFFF), blurRadius: 34),
        ],
      ),
    );
  }
}

/// A small "DRIVER" pill for the gradient header — translucent white so it
/// reads on the blue bar. Marks the signed-in role at a glance.
class CtDriverBadge extends StatelessWidget {
  const CtDriverBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.ct;
    return Container(
      margin: const EdgeInsets.only(right: CtSpace.md),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.onAccent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.onAccent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.badge_outlined, size: 14, color: c.onAccent),
          const SizedBox(width: 5),
          Text(
            'DRIVER',
            style: TextStyle(
              color: c.onAccent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline error placed directly under the fields it refers to. Icon + text so
/// the failure is not signalled by colour alone.
class CtErrorBanner extends StatelessWidget {
  final String message;
  const CtErrorBanner(this.message, {super.key});

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

/// Gives anything tappable the same feel: a small scale-down while held and a
/// light haptic on release. Used by cards and buttons so touch response is
/// uniform instead of each widget inventing its own.
class CtPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final BorderRadius? borderRadius;
  const CtPressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.975,
    this.borderRadius,
  });

  @override
  State<CtPressable> createState() => _CtPressableState();
}

class _CtPressableState extends State<CtPressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null || _down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Page transition used for pushes inside the app: a short fade with a slight
/// rise, rather than the platform's full-width slide. Calmer, and it keeps the
/// gradient header from sliding across the screen on every tap.
class CtPageRoute<T> extends PageRouteBuilder<T> {
  CtPageRoute({required WidgetBuilder builder})
    : super(
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, a, b) => builder(context),
        transitionsBuilder: (context, a, b, child) {
          final curved = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.035),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      );
}

/// Wraps a non-scrolling state (empty, error) so it can still be pulled down
/// to refresh — a bare Column gives RefreshIndicator no scrollable to listen to.
class CtPullable extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  const CtPullable({super.key, required this.onRefresh, required this.child});

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: child,
        ),
      ),
    ),
  );
}

/// A modal confirmation sheet — the app's replacement for AlertDialog.
///
/// Slides up from the bottom, so it stays in the thumb's reach on a phone and
/// carries the app's own surface, radii and buttons rather than the platform
/// dialog's. Returns true only when the confirm action is chosen; dismissing by
/// tapping outside or dragging down returns false.
Future<bool> showCtConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  IconData icon = Icons.help_outline_rounded,
  bool destructive = false,
}) async {
  final c = context.ct;
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xFF0F1727).withValues(alpha: 0.45),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: CtSpace.md,
        right: CtSpace.md,
        bottom: CtSpace.md + MediaQuery.of(ctx).padding.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(CtSpace.lg),
        decoration: BoxDecoration(
          color: c.s1,
          borderRadius: BorderRadius.circular(CtRadius.xl),
          border: Border.all(color: c.border),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F1E46).withValues(alpha: 0.20),
              blurRadius: 34,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border2,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: CtSpace.lg),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (destructive ? c.red : c.primary).withValues(
                  alpha: 0.12,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 26,
                color: destructive ? c.red : c.primary,
              ),
            ),
            const SizedBox(height: CtSpace.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: c.text,
              ),
            ),
            const SizedBox(height: CtSpace.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.muted2, height: 1.45),
            ),
            const SizedBox(height: CtSpace.lg),
            CtPrimaryButton(
              label: confirmLabel,
              onPressed: () => Navigator.pop(ctx, true),
            ),
            const SizedBox(height: CtSpace.sm),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: TextButton.styleFrom(
                foregroundColor: c.muted2,
                minimumSize: const Size(0, 48),
              ),
              child: Text(cancelLabel),
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}

/// Card surface matching the web `.ct-card` (rounded-xl, hairline border,
/// translucent surface, soft shadow).
class CtCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const CtCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(CtSpace.md),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.ct;
    final brightness = Theme.of(context).brightness;
    final radius = BorderRadius.circular(CtRadius.xl);
    final card = DecoratedBox(
      decoration: BoxDecoration(
        // A hair of vertical gradient stops the surface reading as flat fill.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: brightness == Brightness.dark
              ? [c.s2, c.s1]
              : [c.s1, c.s2.withValues(alpha: 0.55)],
        ),
        borderRadius: radius,
        border: Border.all(color: c.border),
        boxShadow: CtShadow.card(brightness),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );
    if (onTap == null) return card;
    return CtPressable(onTap: onTap, borderRadius: radius, child: card);
  }
}

/// Primary button using the brand blue→cyan gradient (`.ct-btn-primary`).
/// Shows a spinner and blocks re-entry while [loading].
class CtPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  const CtPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.ct;
    final enabled = onPressed != null && !loading;
    final radius = BorderRadius.circular(CtRadius.lg);
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: CtPressable(
        scale: 0.985,
        borderRadius: radius,
        onTap: enabled
            ? () {
                HapticFeedback.mediumImpact();
                onPressed!();
              }
            : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: c.gradPrimary,
            borderRadius: radius,
            boxShadow: enabled
                ? CtShadow.raised(Theme.of(context).brightness, c.primary)
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: 52, // >= 48dp touch target
              child: Center(
                child: loading
                    ? SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation(c.onAccent),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[
                            Icon(icon, size: 18, color: c.onAccent),
                            const SizedBox(width: CtSpace.sm),
                          ],
                          Text(
                            label,
                            style: TextStyle(
                              color: c.onAccent,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
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

/// Status pill matching the web `.ct-pill` + DeliveryStatusBadge: a tinted
/// background, a solid dot, and an uppercase label. The dot means the status is
/// never carried by colour alone.
class CtStatusPill extends StatelessWidget {
  final String status;
  const CtStatusPill(this.status, {super.key});

  static const _labels = {
    'awaiting_dropoff': 'Awaiting drop-off',
    'pending': 'Pending',
    'assigned': 'Assigned',
    'en_route': 'En route',
    'delivered': 'Delivered',
    'cancelled': 'Cancelled',
  };

  Color _color(CtColors c) => switch (status) {
    'awaiting_dropoff' => c.amber,
    'assigned' => c.blue,
    'en_route' => c.green,
    'delivered' => c.green,
    'cancelled' => c.red,
    _ => c.muted2,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.ct;
    final color = _color(c);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: status == 'delivered' ? 0.18 : 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            _labels[status] ?? status,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen message with an icon, title, body and optional action. Used for
/// empty, error and access-denied states.
class CtMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;
  final Color? tint;
  const CtMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.ct;
    final color = tint ?? c.muted;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CtSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: color),
            ),
            const SizedBox(height: CtSpace.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: c.text,
              ),
            ),
            const SizedBox(height: CtSpace.sm),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.muted2, height: 1.5),
            ),
            if (action != null) ...[
              const SizedBox(height: CtSpace.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Shimmerless skeleton row shown while the trips stream is still connecting —
/// reserves the same height as a real card so nothing jumps when data lands.
class CtTripSkeleton extends StatefulWidget {
  const CtTripSkeleton({super.key});

  @override
  State<CtTripSkeleton> createState() => _CtTripSkeletonState();
}

class _CtTripSkeletonState extends State<CtTripSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ct;
    // A highlight sweeping across the placeholders reads as "loading"; a static
    // grey block reads as broken content.
    Widget bar(double w, double h) => AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          gradient: LinearGradient(
            begin: Alignment(-1 - 2 * (1 - _c.value), 0),
            end: Alignment(1 + 2 * _c.value, 0),
            colors: [c.s3, c.s2, c.s3],
            stops: const [0.35, 0.5, 0.65],
          ),
        ),
      ),
    );
    return CtCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [bar(110, 16), bar(76, 20)],
          ),
          const SizedBox(height: CtSpace.md),
          bar(170, 12),
          const SizedBox(height: CtSpace.md),
          bar(double.infinity, 12),
          const SizedBox(height: CtSpace.sm),
          bar(200, 12),
        ],
      ),
    );
  }
}

/// Uppercase micro-heading above a group of rows.
class CtSectionLabel extends StatelessWidget {
  final String text;
  const CtSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: CtSpace.sm, left: 2),
    child: Text(
      text,
      style: CtType.label.copyWith(color: context.ct.muted, letterSpacing: 1.2),
    ),
  );
}
