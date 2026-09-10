import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryPurple = Color(0xFF8B5CF6);
  static const Color accentNeon = Color(0xFF38BDF8);
  
  // Standard Dark (Dark Gray)
  static const Color backgroundDark = Color(0xFF12121A); 
  static const Color surfaceDark = Color(0xFF1E1E28);
  
  // AMOLED Black (Pitch Black for OLED screens)
  static const Color backgroundAmoled = Colors.black; 

  // Shared Text Theme
  static TextTheme _buildTextTheme() {
    return TextTheme(
      displayLarge: GoogleFonts.cinzel(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 1.5),
      bodyLarge: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w400),
      bodyMedium: GoogleFonts.outfit(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w300),
    );
  }

  // 1. Standard Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundDark,
      primaryColor: primaryPurple,
      textTheme: _buildTextTheme(),
      appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, centerTitle: true),
    );
  }

  // 2. AMOLED Pitch Black Theme
  static ThemeData get amoledTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundAmoled, // Pitch Black!
      primaryColor: primaryPurple,
      textTheme: _buildTextTheme(),
      appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, centerTitle: true),
    );
  }
}