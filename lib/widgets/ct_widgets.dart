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
    final radius = BorderRadius.circular(CtRadius.xl);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.s1,
        borderRadius: radius,
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F1E46).withValues(alpha: 0.10),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
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
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: c.gradPrimary,
          borderRadius: radius,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: c.primary.withValues(alpha: 0.42),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onPressed : null,
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
        color: color.withValues(alpha: status == 'delivered' ? 0.20 : 0.12),
        borderRadius: BorderRadius.circular(999),
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
class CtTripSkeleton extends StatelessWidget {
  const CtTripSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.ct;
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: c.s3,
            borderRadius: BorderRadius.circular(6),
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
