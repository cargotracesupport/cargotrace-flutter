import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Light/dark ThemeData built from the ported CargoTrace tokens. Typography is
/// Plus Jakarta Sans (--ct-font-sans) with DM Mono reserved for reference
/// numbers, matching the web.
class AppTheme {
  static ThemeData light() => _build(CtColors.light, Brightness.light);
  static ThemeData dark() => _build(CtColors.dark, Brightness.dark);

  static ThemeData _build(CtColors c, Brightness brightness) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final text = GoogleFonts.plusJakartaSansTextTheme(base.textTheme)
        .apply(bodyColor: c.text, displayColor: c.text);

    return base.copyWith(
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      extensions: [c],
      textTheme: text,
      colorScheme: ColorScheme.fromSeed(
        seedColor: c.primary,
        brightness: brightness,
      ).copyWith(
        primary: c.primary,
        onPrimary: c.onAccent,
        surface: c.s1,
        onSurface: c.text,
        error: c.red,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: c.text,
        ),
        iconTheme: IconThemeData(color: c.muted2),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.s1,
        // 48dp+ tap height (Material minimum).
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        labelStyle: TextStyle(color: c.muted2),
        floatingLabelStyle: TextStyle(color: c.primary),
        border: _outline(c.border),
        enabledBorder: _outline(c.border),
        focusedBorder: _outline(c.primary, width: 2),
        errorBorder: _outline(c.red),
        focusedErrorBorder: _outline(c.red, width: 2),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.s3,
        contentTextStyle: TextStyle(color: c.text),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary),
    );
  }

  static OutlineInputBorder _outline(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(CtRadius.lg),
        borderSide: BorderSide(color: color, width: width),
      );
}
