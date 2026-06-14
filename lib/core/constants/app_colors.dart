// Design token constants for InkFlow's warm & friendly note-taking aesthetic.
//
// Design language from the "Noted" landing (pill buttons, cream surfaces,
// doodle accents); color + type authority from the "Notely" mobile app
// (coral/terracotta primary on warm cream, periwinkle secondary).
//
// NOTE: the original semantic names (background/surface/accent/…) are kept so
// the whole app re-skins from this one file; their *values* are now warm.

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Warm surfaces (light, paper-like) ──────────────────────
  static const background = Color(0xFFF4ECE1); // app background — soft warm cream
  static const surface = Color(0xFFFFFFFF); // cards, sheets, app bar
  static const surfaceWarm = Color(0xFFFCF8F3); // subtly warm white for large fills
  static const surfaceAlt = Color(0xFFF8EFE6); // peach — alt section band
  static const surfaceHighlight = Color(0xFFEFE5D8); // sand — pressed / raised tint
  static const border = Color(0xFFEBE1D4); // hairline / card outline on cream
  static const borderStrong = Color(0xFFE0D5C5);

  // ── Text (warm charcoal ramp) ──────────────────────────────
  static const textPrimary = Color(0xFF33302E); // headings, primary text
  static const textSecondary = Color(0xFF6E6660); // secondary / body-supporting
  static const textMuted = Color(0xFFA89F95); // captions, placeholders, disabled
  static const textOnAccent = Color(0xFFFFFFFF); // white rides on the coral button

  // ── Primary: coral / terracotta ────────────────────────────
  static const accent = Color(0xFFD9654E); // primary — buttons, links, highlight
  static const accentStrong = Color(0xFFC5543D); // hover / pressed
  static const accentSoft = Color(0xFFF0C9BF); // tint borders, subtle fills
  static const accentWash = Color(0xFFFBEDE8); // selected/active background wash

  // ── Secondary: periwinkle (from the doodle illustrations) ──
  static const accentPurple = Color(0xFF8B8BD8);
  static const accentPurpleStrong = Color(0xFF6F6FC4);
  static const accentPurpleWash = Color(0xFFECECF8);

  // ── Supporting / status hues (warm) ────────────────────────
  static const sunny = Color(0xFFF2802E);
  static const sunnyWash = Color(0xFFFBE9D9);
  static const accentGreen = Color(0xFF5BA672); // leaf — success
  static const accentGreenWash = Color(0xFFE6F1E8);
  static const accentYellow = Color(0xFFE3A53D); // honey — warning
  static const accentYellowWash = Color(0xFFFBF0D9);
  static const accentRed = Color(0xFFCF4A36); // berry — danger
  static const accentRedWash = Color(0xFFFAE4DF);

  // ── Tool hues (the Inkflow editor keeps per-tool color, warmed) ──
  static const toolPen = accent; // coral
  static const toolPenWash = accentWash;
  static const toolEraser = accentYellow; // honey
  static const toolEraserWash = accentYellowWash;
  static const toolShape = accentGreen; // leaf
  static const toolShapeWash = accentGreenWash;
  static const toolLasso = accentPurple; // periwinkle
  static const toolLassoWash = accentPurpleWash;

  // ── Pen / ink palette (warm, friendly set) ─────────────────
  static const penPalette = <Color>[
    Color(0xFF33302E), // ink
    Color(0xFFD9654E), // coral
    Color(0xFFF2802E), // sunny
    Color(0xFFE3A53D), // honey
    Color(0xFF5BA672), // leaf
    Color(0xFF3FA6A0), // teal
    Color(0xFF8B8BD8), // periwinkle
    Color(0xFFC0497E), // berry
    Color(0xFF5B9BD5), // sky
    Color(0xFFFFFFFF), // white
  ];

  // ── Paper colors (canvas backgrounds) ──────────────────────
  static const paperWhite = Color(0xFFFFFFFF);
  static const paperCream = Color(0xFFFAF4EA);
  static const paperBlush = Color(0xFFFBEFEA);

  // ── Warm-tinted shadow (never harsh black) ─────────────────
  static const shadowTint = Color(0xFF4A3628);

  static List<BoxShadow> get shadowCard => [
        BoxShadow(
          color: shadowTint.withValues(alpha: 0.08),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: shadowTint.withValues(alpha: 0.05),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get shadowFloat => [
        BoxShadow(
          color: shadowTint.withValues(alpha: 0.12),
          blurRadius: 32,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: shadowTint.withValues(alpha: 0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get shadowCta => [
        BoxShadow(
          color: accent.withValues(alpha: 0.28),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];
}
