import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Single source of truth for visual style. Use `DS.*` everywhere instead
/// of inline color/spacing/radius constants. Designed for dense, serious
/// data UIs (think: POS terminal, ops dashboard) — not consumer apps.
///
/// Rules of thumb when consuming these tokens:
///   • Use [DS.text] / [DS.textMuted] for almost all type. Only state colors
///     (green/amber/red/violet) carry meaning, never decoration.
///   • Borders are 1px and subtle. We do **not** use shadows or blurs.
///   • Spacing is on a 4-pt grid. Stick to the named values below.
///   • Rounded radii are small (4–8). Anything bigger looks consumer.
///   • Numerical values must use [DS.numberStyle] so columns line up.
class DS {
  // ── Surfaces ─────────────────────────────────────────────────
  static const Color bg = Color(0xFFF7F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F3F6);
  static const Color surfaceSunken = Color(0xFFEDEFF2);

  // ── Borders ──────────────────────────────────────────────────
  static const Color border = Color(0xFFE3E6EB);
  static const Color borderStrong = Color(0xFFCDD2DA);
  static const Color divider = Color(0xFFEEF0F3);

  // ── Text ─────────────────────────────────────────────────────
  static const Color text = Color(0xFF0E1116);
  static const Color textMuted = Color(0xFF5B6470);
  static const Color textSubtle = Color(0xFF8B939E);

  // ── Primary action (deliberately dark, not bright) ───────────
  static const Color accent = Color(0xFF111827);
  static const Color accentInk = Color(0xFFFFFFFF);

  // ── Selection / focus ────────────────────────────────────────
  static const Color focus = Color(0xFF1D4ED8);
  static const Color selectionBg = Color(0xFFE7ECFF);

  // ── Semantic state (use only to indicate state, never decoration) ──
  static const Color green = Color(0xFF16A34A);
  static const Color greenSurface = Color(0xFFE3F5E9);
  static const Color amber = Color(0xFFB45309);
  static const Color amberSurface = Color(0xFFFEF1DA);
  static const Color red = Color(0xFFDC2626);
  static const Color redSurface = Color(0xFFFCE7E7);
  static const Color violet = Color(0xFF7C3AED);
  static const Color violetSurface = Color(0xFFEFE5FB);
  static const Color blue = Color(0xFF1D4ED8);
  static const Color blueSurface = Color(0xFFE2EAFB);
  static const Color grey = Color(0xFF64748B);
  static const Color greySurface = Color(0xFFEFF1F4);

  // ── Spacing (4-pt grid) ──────────────────────────────────────
  static const double s2 = 2;
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;

  // ── Radii (kept deliberately small) ──────────────────────────
  static const double r4 = 4;
  static const double r6 = 6;
  static const double r8 = 8;
  static const double r10 = 10;

  // ── Common control sizes ─────────────────────────────────────
  static const double rowHeight = 40;
  static const double rowHeightDense = 32;
  static const double iconBtn = 28;
  static const double sidebarWidth = 56;

  // ── Type scale (Inter for UI, JetBrains Mono for tabular numbers) ──
  static TextStyle display({Color? color}) => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color ?? text,
        height: 1.2,
        letterSpacing: -0.2,
      );

  static TextStyle title({Color? color}) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color ?? text,
        height: 1.25,
      );

  static TextStyle body({Color? color, FontWeight? weight}) =>
      GoogleFonts.inter(
        fontSize: 13,
        fontWeight: weight ?? FontWeight.w400,
        color: color ?? text,
        height: 1.4,
      );

  static TextStyle bodyStrong({Color? color}) => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color ?? text,
        height: 1.4,
      );

  static TextStyle caption({Color? color}) => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: color ?? textMuted,
        height: 1.3,
        letterSpacing: 0.1,
      );

  /// Small caps section eyebrow. Use sparingly, only on group headers.
  static TextStyle eyebrow({Color? color}) => GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: color ?? textMuted,
        letterSpacing: 0.6,
        height: 1.2,
      );

  /// Tabular figures for prices, counts, durations.
  static TextStyle number({
    double size = 13,
    Color? color,
    FontWeight weight = FontWeight.w500,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: weight,
        color: color ?? text,
        height: 1.25,
      );

  // ── ThemeData helpers ────────────────────────────────────────
  static ThemeData buildTheme() {
    final base = ThemeData.light();
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: text,
      displayColor: text,
    );

    return base.copyWith(
      scaffoldBackgroundColor: bg,
      canvasColor: surface,
      dividerColor: divider,
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        onPrimary: accentInk,
        secondary: focus,
        surface: surface,
        error: red,
      ),
      textTheme: textTheme,
      iconTheme: const IconThemeData(color: textMuted, size: 18),
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: s12, vertical: s10),
        labelStyle: caption(),
        hintStyle: body(color: textSubtle),
        border: _input(border),
        enabledBorder: _input(border),
        focusedBorder: _input(focus, width: 1.4),
        errorBorder: _input(red),
        focusedErrorBorder: _input(red, width: 1.4),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: accentInk,
          textStyle: bodyStrong(color: accentInk),
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: s16, vertical: s10),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r6),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          textStyle: bodyStrong(),
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: s16, vertical: s10),
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r6),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: text,
          textStyle: bodyStrong(),
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: s10, vertical: s6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r6),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: accentInk,
          textStyle: bodyStrong(color: accentInk),
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: s16, vertical: s10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r6),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textMuted,
          minimumSize: const Size(iconBtn, iconBtn),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r6),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: border),
          borderRadius: BorderRadius.circular(r10),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: text,
          borderRadius: BorderRadius.circular(r4),
        ),
        textStyle: GoogleFonts.inter(color: surface, fontSize: 11),
        padding: const EdgeInsets.symmetric(horizontal: s8, vertical: s4),
        waitDuration: const Duration(milliseconds: 350),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: text,
        contentTextStyle: GoogleFonts.inter(color: surface, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r6),
        ),
      ),
    );
  }

  static InputBorder _input(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(r6),
        borderSide: BorderSide(color: color, width: width),
      );
}
