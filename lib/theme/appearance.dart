import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppAppearance {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    // textTheme: GoogleFonts.sourceSans3TextTheme(),
    // textTheme: GoogleFonts.notoSansTextTheme(),
    // textTheme: GoogleFonts.interTextTheme(),
    // textTheme: GoogleFonts.figtreeTextTheme(),
    // textTheme: GoogleFonts.publicSansTextTheme(),
    textTheme: GoogleFonts.publicSansTextTheme(
      ThemeData.light().textTheme,
    ).copyWith(
      titleLarge: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.4,
      ),
    ),
    // textTheme: GoogleFonts.rubikTextTheme(),

    splashColor: Colors.transparent,
    highlightColor: Colors.grey.shade200,
    hoverColor: Colors.grey.shade100,

    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Colors.black,
      selectionHandleColor: Colors.black,
    ),

    // Global colors
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.black,
      brightness: Brightness.light,
    ),

    scaffoldBackgroundColor: Colors.white,

    // AppBar styling
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      centerTitle: true,

      // Subtle divider instead of shadow
      surfaceTintColor: Colors.transparent,

      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: Colors.black,
      ),

      iconTheme: IconThemeData(
        color: Colors.black,
        size: 22,
      ),
    ),

    // Buttons (for consistency)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 20,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 4,
        sizeConstraints: BoxConstraints.tightFor(width: 56, height: 56),
        shape: CircleBorder()
    ),

    // Inputs
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF5F5F5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(
        vertical: 14,
        horizontal: 16,
      ),
    ),

    // ✅ Bottom bar styling
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 6,
      selectedItemColor: Colors.black,
      unselectedItemColor: Colors.grey[500],
      selectedIconTheme: const IconThemeData(size: 28),
      unselectedIconTheme: const IconThemeData(size: 28),
      showUnselectedLabels: false,
      type: BottomNavigationBarType.fixed,
      landscapeLayout: BottomNavigationBarLandscapeLayout.centered,
    ),

  );
}