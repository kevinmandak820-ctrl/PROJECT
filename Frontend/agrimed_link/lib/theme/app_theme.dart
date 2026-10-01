import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors - High-end palette
  static const Color primaryGreen = Color(0xFF0F4C2A); // Premium Emerald Green
  static const Color secondaryGreen = Color(0xFF2E8B57); // Rich Sage Green
  static const Color accentAmber = Color(0xFFE5A93B); // Golden Harvest Amber
  static const Color lightGreen = Color(0xFFEBF5EE); // Light Mint/Sage Surface
  static const Color errorRed = Color(0xFFD32F2F); // Crimson/Ruby red
  static const Color darkText = Color(0xFF1E2822); // Charcoal Green Text
  static const Color lightText = Color(0xFF6B7A70); // Sage Grey slate Text
  static const Color background = Color(0xFFF7FBF8); // Clean Linen light-sage background

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [
      Color(0xFF0F4C2A), // Premium Emerald
      Color(0xFF207442), // Bright Leaf Green
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient softGradient = LinearGradient(
    colors: [Color(0xFFEBF5EE), Color(0xFFF3F9F6)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Styled Decorations for Inputs
  static InputDecoration inputDecoration({
    required String labelText,
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: Icon(prefixIcon, color: secondaryGreen),
      suffixIcon: suffixIcon,
      labelStyle: const TextStyle(
        color: secondaryGreen,
        fontWeight: FontWeight.w600,
        fontSize: 14.0,
      ),
      hintStyle: const TextStyle(color: lightText, fontSize: 13.0),
      filled: true,
      fillColor: Colors.white.withOpacity(0.85),
      contentPadding: const EdgeInsets.symmetric(
        vertical: 18.0,
        horizontal: 20.0,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: BorderSide(
          color: secondaryGreen.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: const BorderSide(color: primaryGreen, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: const BorderSide(color: errorRed, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: const BorderSide(color: errorRed, width: 2.0),
      ),
    );
  }

  // Button Style
  static ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    foregroundColor: Colors.white,
    backgroundColor: Colors.transparent,
    shadowColor: Colors.transparent,
    padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
  );

  // Custom Card Decoration
  static BoxDecoration cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24.0),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF0F4C2A).withOpacity(0.06),
        blurRadius: 24.0,
        offset: const Offset(0, 8),
      ),
    ],
  );

  // Frosted Glass Card Decoration
  static BoxDecoration glassCardDecoration = BoxDecoration(
    color: Colors.white.withOpacity(0.80),
    borderRadius: BorderRadius.circular(24.0),
    border: Border.all(
      color: Colors.white.withOpacity(0.5),
      width: 1.5,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 25.0,
        offset: const Offset(0, 10),
      ),
    ],
  );
}
