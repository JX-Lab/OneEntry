import 'package:flutter/material.dart';

@immutable
class AppAccent {
  const AppAccent({
    required this.key,
    required this.label,
    required this.primary,
    required this.secondary,
  });

  final String key;
  final String label;
  final Color primary;
  final Color secondary;
}

@immutable
class AppAccentTheme extends ThemeExtension<AppAccentTheme> {
  const AppAccentTheme({required this.primary, required this.secondary});

  final Color primary;
  final Color secondary;

  @override
  AppAccentTheme copyWith({Color? primary, Color? secondary}) => AppAccentTheme(
    primary: primary ?? this.primary,
    secondary: secondary ?? this.secondary,
  );

  @override
  AppAccentTheme lerp(AppAccentTheme? other, double t) => AppAccentTheme(
    primary: Color.lerp(primary, other?.primary, t) ?? primary,
    secondary: Color.lerp(secondary, other?.secondary, t) ?? secondary,
  );
}

abstract final class AppTheme {
  static const Color green = Color(0xFF087F5B);
  static const Color greenLight = Color(0xFF0F766E);
  static const Color expense = Color(0xFFC62828);
  static const Color income = Color(0xFF2E7CF6);

  // Both gradient endpoints keep at least 5:1 contrast against white.
  static const List<AppAccent> accents = <AppAccent>[
    AppAccent(
      key: 'green',
      label: '翡翠绿',
      primary: Color(0xFF087F5B),
      secondary: Color(0xFF0F766E),
    ),
    AppAccent(
      key: 'blue',
      label: '湛蓝',
      primary: Color(0xFF1D4ED8),
      secondary: Color(0xFF2563EB),
    ),
    AppAccent(
      key: 'purple',
      label: '紫罗兰',
      primary: Color(0xFF6D28D9),
      secondary: Color(0xFF7C3AED),
    ),
    AppAccent(
      key: 'orange',
      label: '暖橙',
      primary: Color(0xFF9A3412),
      secondary: Color(0xFFC2410C),
    ),
    AppAccent(
      key: 'rose',
      label: '玫红',
      primary: Color(0xFF9F1239),
      secondary: Color(0xFFBE123C),
    ),
  ];

  static AppAccent accentFor(String key) => accents.firstWhere(
    (AppAccent accent) => accent.key == key,
    orElse: () => accents.first,
  );

  static AppAccentTheme accentOf(BuildContext context) =>
      Theme.of(context).extension<AppAccentTheme>() ??
      const AppAccentTheme(primary: green, secondary: greenLight);

  static double contrastRatio(Color first, Color second) {
    final double firstLuminance = first.computeLuminance();
    final double secondLuminance = second.computeLuminance();
    final double lighter = firstLuminance > secondLuminance
        ? firstLuminance
        : secondLuminance;
    final double darker = firstLuminance > secondLuminance
        ? secondLuminance
        : firstLuminance;
    return (lighter + .05) / (darker + .05);
  }

  static ThemeData light({
    bool highContrast = false,
    String accentKey = 'green',
  }) => _theme(
    brightness: Brightness.light,
    highContrast: highContrast,
    accent: accentFor(accentKey),
  );

  static ThemeData dark({
    bool highContrast = false,
    String accentKey = 'green',
  }) => _theme(
    brightness: Brightness.dark,
    highContrast: highContrast,
    accent: accentFor(accentKey),
  );

  static ThemeData _theme({
    required Brightness brightness,
    required bool highContrast,
    required AppAccent accent,
  }) {
    final bool dark = brightness == Brightness.dark;
    ColorScheme colors = ColorScheme.fromSeed(
      seedColor: accent.primary,
      brightness: brightness,
      surface: dark ? const Color(0xFF1A1F27) : const Color(0xFFFFFFFF),
    );
    if (!dark) {
      colors = colors.copyWith(
        primary: accent.primary,
        onPrimary: Colors.white,
      );
    }
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: dark
          ? highContrast
                ? const Color(0xFF050607)
                : const Color(0xFF101318)
          : highContrast
          ? const Color(0xFFE9EDF2)
          : const Color(0xFFF2F4F7),
      fontFamilyFallback: const <String>['PingFang SC', 'Microsoft YaHei'],
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: dark
            ? const Color(0xFF1A1F27)
            : const Color(0xFFFFFFFF),
        foregroundColor: dark
            ? const Color(0xFFE7ECF3)
            : const Color(0xFF1B1D21),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: dark ? const Color(0xFF1A1F27) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF252B34) : const Color(0xFFF1F3F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(showDragHandle: true),
      extensions: <ThemeExtension<dynamic>>[
        AppAccentTheme(primary: accent.primary, secondary: accent.secondary),
      ],
    );
  }
}
