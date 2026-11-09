import 'package:flutter/material.dart';

/// Rayna app color palette.
///
/// Minimalis modern — soft, warm, dan personal.
class AppColors {
  AppColors._();

  // ── Primary palette ──────────────────────────────────────────────────
  static const Color softIvory = Color(0xFFF8F6F2);
  static const Color charcoal = Color(0xFF252525);
  static const Color dustyRose = Color(0xFFC98491);
  static const Color warmGray = Color(0xFFE8E3DC);
  static const Color softSage = Color(0xFFDCE8DF);
  static const Color white = Color(0xFFFFFFFF);

  // ── Functional colors ────────────────────────────────────────────────
  static const Color error = Color(0xFFD94F4F);
  static const Color success = Color(0xFF5CAB7D);
  static const Color warning = Color(0xFFE6A84C);
  static const Color info = Color(0xFF6BA3C9);

  // ── Derived / helper colors ──────────────────────────────────────────
  static const Color textPrimary = charcoal;
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textHint = Color(0xFFA0A0A0);
  static const Color divider = Color(0xFFE0DDD8);
  static const Color scaffoldBackground = softIvory;
  static const Color cardBackground = white;
  static const Color inputFill = Color(0xFFF2F0EC);
}
