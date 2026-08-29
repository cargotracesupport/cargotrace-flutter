import 'package:flutter/material.dart';

/// CargoTrace design tokens, ported from the web app's Aurora design system
/// (src/app/design-tokens.css). Names and values match the CSS custom
/// properties one-to-one so the two clients stay visually in sync — when a
/// token changes on the web, change it here.
@immutable
class CtColors extends ThemeExtension<CtColors> {
  // Surfaces
  final Color bg, s1, s2, s3, border, border2;
  // Brand
  final Color primary, primary2, accent, onAccent;
  // Status hues
  final Color green, amber, red, blue;
  // Text
  final Color text, muted, muted2;

  const CtColors({
    required this.bg,
    required this.s1,
    required this.s2,
    required this.s3,
    required this.border,
    required this.border2,
    required this.primary,
    required this.primary2,
    required this.accent,
    required this.onAccent,
    required this.green,
    required this.amber,
    required this.red,
    required this.blue,
    required this.text,
    required this.muted,
    required this.muted2,
  });

  /// :root in design-tokens.css
  static const light = CtColors(
    bg: Color(0xFFF6F8FF),
    s1: Color(0xFFFFFFFF),
    s2: Color(0xFFF0F4FB),
    s3: Color(0xFFE6ECF6),
    border: Color(0xFFE0E7F2),
    border2: Color(0xFFC9D5E8),
    primary: Color(0xFF2563EB),
    primary2: Color(0xFF0696C7),
    accent: Color(0xFFEA580C),
    onAccent: Color(0xFFFFFFFF),
    green: Color(0xFF009650),
    amber: Color(0xFFC26608),
    red: Color(0xFFDC2626),
    blue: Color(0xFF2563EB),
    text: Color(0xFF101727),
    muted: Color(0xFF8C9CB0),
    muted2: Color(0xFF475569),
  );

  /// html.dark in design-tokens.css
  static const dark = CtColors(
    bg: Color(0xFF070B14),
    s1: Color(0xFF0F1522),
    s2: Color(0xFF141C2D),
    s3: Color(0xFF1D273A),
    border: Color(0xFF202C42),
    border2: Color(0xFF2E3D58),
    primary: Color(0xFF60A5FA),
    primary2: Color(0xFF22D3EE),
    accent: Color(0xFFFB923C),
    onAccent: Color(0xFF060C18),
    green: Color(0xFF00DC82),
    amber: Color(0xFFFFB74D),
    red: Color(0xFFFF6363),
    blue: Color(0xFF60A5FA),
    text: Color(0xFFE2E8F0),
    muted: Color(0xFF64748B),
    muted2: Color(0xFF94A3B8),
  );

  /// The brand blue→cyan gradient (--grad-primary).
  LinearGradient get gradPrimary => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primary, primary2],
      );

  @override
  CtColors copyWith() => this;

  @override
  CtColors lerp(ThemeExtension<CtColors>? other, double t) {
    if (other is! CtColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return CtColors(
      bg: c(bg, other.bg),
      s1: c(s1, other.s1),
      s2: c(s2, other.s2),
      s3: c(s3, other.s3),
      border: c(border, other.border),
      border2: c(border2, other.border2),
      primary: c(primary, other.primary),
      primary2: c(primary2, other.primary2),
      accent: c(accent, other.accent),
      onAccent: c(onAccent, other.onAccent),
      green: c(green, other.green),
      amber: c(amber, other.amber),
      red: c(red, other.red),
      blue: c(blue, other.blue),
      text: c(text, other.text),
      muted: c(muted, other.muted),
      muted2: c(muted2, other.muted2),
    );
  }
}

/// Shorthand: `context.ct.primary`.
extension CtTheme on BuildContext {
  CtColors get ct => Theme.of(this).extension<CtColors>()!;
}

/// Radii from --ct-radius-lg / --ct-radius-xl.
class CtRadius {
  static const lg = 14.0;
  static const xl = 20.0;
}

/// 4/8dp spacing rhythm.
class CtSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}
