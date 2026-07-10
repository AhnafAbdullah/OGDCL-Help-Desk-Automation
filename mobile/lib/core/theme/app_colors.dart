import 'package:flutter/material.dart';

/// OGDCL brand palette — mirrors the Blazor web dashboard so the mobile app
/// reads as the same product.
class AppColors {
  AppColors._();

  static const brand = Color(0xFF1F4E5F);
  static const brandDark = Color(0xFF163946);
  static const accent = Color(0xFF2E86AB);

  static const ok = Color(0xFF2E7D32);
  static const warn = Color(0xFFB26A00);
  static const bad = Color(0xFFC62828);
  static const neutral = Color(0xFF616161);

  static const surfaceLight = Color(0xFFF5F7F8);

  /// A light tinted background for a status/priority chip built from its base color.
  static Color tint(Color color, {double opacity = 0.14}) =>
      Color.alphaBlend(color.withValues(alpha: opacity), Colors.white);
}
