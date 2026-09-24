import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const Color green = Color(0xFF0EB078);
  static const Color greenLight = Color(0xFF35D3A0);
  static const Color expense = Color(0xFFFA5151);
  static const Color income = Color(0xFF2E7CF6);

  static ThemeData light() {
    final ColorScheme colors = ColorScheme.fromSeed(
      seedColor: green,
      brightness: Brightness.light,
      surface: const Color(0xFFFFFFFF),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: const Color(0xFFF2F4F7),
      fontFamilyFallback: const <String>['PingFang SC', 'Microsoft YaHei'],
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF1B1D21),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F3F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(showDragHandle: true),
    );
  }

  static ThemeData dark() {
    final ColorScheme colors = ColorScheme.fromSeed(
      seedColor: green,
      brightness: Brightness.dark,
      surface: const Color(0xFF1A1F27),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: const Color(0xFF101318),
      fontFamilyFallback: const <String>['PingFang SC', 'Microsoft YaHei'],
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Color(0xFF1A1F27),
        foregroundColor: Color(0xFFE7ECF3),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF1A1F27),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF252B34),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(showDragHandle: true),
    );
  }
}
