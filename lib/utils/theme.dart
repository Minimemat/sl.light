import 'package:flutter/material.dart';

final ThemeData appTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: const Color(0xFF2C2C2C),
  scaffoldBackgroundColor: const Color(0xFF2C2C2C),
  cardColor: const Color(0xFF3A3A3A),
  canvasColor: const Color(0xFF2C2C2C),

  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF2C2C2C),
    elevation: 0,
    iconTheme: IconThemeData(color: Colors.white),
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 20,
    ),
  ),

  colorScheme: ColorScheme.dark(
    primary: const Color(0xFF5865F2), // Blue accent
    secondary: const Color(0xFF43B581), // Green accent
    surface: const Color(0xFF3A3A3A),
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: Colors.white,
    error: Colors.redAccent,
    onError: Colors.white,
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF5865F2),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
    ),
  ),

  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF5865F2),
      side: const BorderSide(color: Color(0xFF5865F2), width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    ),
  ),

  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: const Color(0xFF43B581),
      textStyle: const TextStyle(fontWeight: FontWeight.bold),
    ),
  ),

  inputDecorationTheme: const InputDecorationTheme(
    filled: true,
    fillColor: Color(0xFF3A3A3A),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: Color(0xFF5865F2)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: Color(0xFF5865F2)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: Color(0xFF43B581), width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: Colors.redAccent),
    ),
    labelStyle: TextStyle(color: Colors.white70),
    hintStyle: TextStyle(color: Colors.white38),
  ),

  cardTheme: CardThemeData(
    color: const Color(0xFF3A3A3A),
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
  ),

  iconTheme: const IconThemeData(color: Colors.white70),
  dividerColor: Colors.white12,

  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: Color(0xFF5865F2),
    foregroundColor: Colors.white,
    elevation: 4,
  ),

  snackBarTheme: const SnackBarThemeData(
    backgroundColor: Color(0xFF3A3A3A),
    contentTextStyle: TextStyle(color: Colors.white),
    behavior: SnackBarBehavior.floating,
  ),

  fontFamily: 'Roboto',
);
