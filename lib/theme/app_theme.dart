import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- Colors ---
  // Deep Backgrounds
  static const Color background = Color(0xFF0B101E);
  static const Color surface1 = Color(0xFF131A2A);
  static const Color surface2 = Color(0xFF1A2235);
  
  // Vibrant Accents
  static const Color cyanAccent = Color(0xFF00F0FF);
  static const Color emeraldAccent = Color(0xFF00FF87);
  static const Color orangeAccent = Color(0xFFFF5E00);
  static const Color purpleAccent = Color(0xFF9D00FF);

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8B9BB4);

  // Status
  static const Color error = Color(0xFFFF3366);

  // --- Theme Data ---
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: cyanAccent,
      colorScheme: const ColorScheme.dark(
        primary: cyanAccent,
        secondary: emeraldAccent,
        surface: surface1,
        background: background,
        error: error,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.bold),
        titleLarge: GoogleFonts.outfit(color: textPrimary, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(color: textPrimary),
        bodyMedium: GoogleFonts.inter(color: textSecondary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: surface2.withValues(alpha: 0.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: background.withValues(alpha: 0.8),
        selectedItemColor: cyanAccent,
        unselectedItemColor: textSecondary,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cyanAccent,
          foregroundColor: background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0EA5E9)),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
    );
  }
}

// --- Glassmorphism Extension ---
extension Glassmorphism on Widget {
  Widget asGlass({
    BuildContext? context,
    double blurX = 10.0,
    double blurY = 10.0,
    Color? color,
    BorderRadius? borderRadius,
    Border? border,
  }) {
    final isDark = context != null ? Theme.of(context).brightness == Brightness.dark : true;
    
    if (!isDark) {
      // In light mode, just return a standard elevated white container to match the old theme
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius ?? BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
          border: border ?? Border.all(color: Colors.grey.withValues(alpha: 0.2), width: 1.0),
        ),
        child: this,
      );
    }

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurX, sigmaY: blurY),
        child: Container(
          decoration: BoxDecoration(
            color: color ?? AppTheme.surface2.withValues(alpha: 0.3),
            borderRadius: borderRadius ?? BorderRadius.circular(20),
            border: border ?? Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1.0,
            ),
          ),
          child: this,
        ),
      ),
    );
  }
}
