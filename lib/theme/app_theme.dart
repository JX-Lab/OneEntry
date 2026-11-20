import 'package:flutter/material.dart';

@immutable
class AppAccent {
  const AppAccent({
    required this.key,
    required this.label,
    required this.primary,
    required this.secondary,
    required this.action,
  });

  final String key;
  final String label;
  final Color primary;
  final Color secondary;
  final Color action;
}

@immutable
class AppAccentTheme extends ThemeExtension<AppAccentTheme> {
  const AppAccentTheme({
    required this.primary,
    required this.secondary,
    required this.action,
  });

  final Color primary;
  final Color secondary;
  final Color action;

  @override
  AppAccentTheme copyWith({Color? primary, Color? secondary, Color? action}) =>
      AppAccentTheme(
        primary: primary ?? this.primary,
        secondary: secondary ?? this.secondary,
        action: action ?? this.action,
      );

  @override
  AppAccentTheme lerp(AppAccentTheme? other, double t) => AppAccentTheme(
    primary: Color.lerp(primary, other?.primary, t) ?? primary,
    secondary: Color.lerp(secondary, other?.secondary, t) ?? secondary,
    action: Color.lerp(action, other?.action, t) ?? action,
  );
}

@immutable
class LedgerSemanticColors extends ThemeExtension<LedgerSemanticColors> {
  const LedgerSemanticColors({
    required this.income,
    required this.expense,
    required this.transfer,
  });

  final Color income;
  final Color expense;
  final Color transfer;

  @override
  LedgerSemanticColors copyWith({
    Color? income,
    Color? expense,
    Color? transfer,
  }) => LedgerSemanticColors(
    income: income ?? this.income,
    expense: expense ?? this.expense,
    transfer: transfer ?? this.transfer,
  );

  @override
  LedgerSemanticColors lerp(LedgerSemanticColors? other, double t) =>
      LedgerSemanticColors(
        income: Color.lerp(income, other?.income, t) ?? income,
        expense: Color.lerp(expense, other?.expense, t) ?? expense,
        transfer: Color.lerp(transfer, other?.transfer, t) ?? transfer,
      );
}

abstract final class AppTheme {
  static const String defaultAccentKey = 'green';
  static const Color brandDeepTeal = Color(0xFF073A39);
  static const Color brandTeal = Color(0xFF0D514E);
  static const Color brandTealLight = Color(0xFF1A6B67);
  static const Color brandWarmWhite = Color(0xFFF7F5EF);
  static const Color green = Color(0xFF0EB078);
  static const Color greenLight = Color(0xFF35D3A0);
  static const Color expense = Color(0xFFD32F2F);
  static const Color income = Color(0xFF2E7CF6);

  // Gradients stay bright; action colors are the accessible white-text layer.
  static const List<AppAccent> accents = <AppAccent>[
    AppAccent(
      key: 'teal',
      label: '深海青',
      primary: brandTeal,
      secondary: brandTealLight,
      action: Color(0xFF0D4B49),
    ),
    AppAccent(
      key: 'indigo',
      label: '静谧靛',
      primary: Color(0xFF4F46E5),
      secondary: Color(0xFF818CF8),
      action: Color(0xFF4338CA),
    ),
    AppAccent(
      key: 'green',
      label: '翡翠绿',
      primary: Color(0xFF0EB078),
      secondary: Color(0xFF35D3A0),
      action: Color(0xFF087F5B),
    ),
    AppAccent(
      key: 'blue',
      label: '天空蓝',
      primary: Color(0xFF2E7CF6),
      secondary: Color(0xFF60A5FA),
      action: Color(0xFF1D4ED8),
    ),
    AppAccent(
      key: 'cyan',
      label: '湖水青',
      primary: Color(0xFF06B6D4),
      secondary: Color(0xFF22D3EE),
      action: Color(0xFF0E7490),
    ),
    AppAccent(
      key: 'purple',
      label: '薰衣紫',
      primary: Color(0xFF7C4DFF),
      secondary: Color(0xFFA78BFA),
      action: Color(0xFF6D28D9),
    ),
    AppAccent(
      key: 'orange',
      label: '琥珀橙',
      primary: Color(0xFFF59E0B),
      secondary: Color(0xFFFBBF24),
      action: Color(0xFFB45309),
    ),
    AppAccent(
      key: 'rose',
      label: '莓果红',
      primary: Color(0xFFE11D48),
      secondary: Color(0xFFFB7185),
      action: Color(0xFFBE123C),
    ),
  ];

  static AppAccent accentFor(String key) {
    final AppAccent? custom = _customAccent(key);
    if (custom != null) return custom;
    return accents.firstWhere(
      (AppAccent accent) => accent.key == key,
      orElse: () => accents.firstWhere(
        (AppAccent accent) => accent.key == defaultAccentKey,
      ),
    );
  }

  static String launcherAccentKey(String key) {
    if (!key.startsWith('custom:')) {
      return accents.any((AppAccent accent) => accent.key == key)
          ? key
          : defaultAccentKey;
    }
    final int target = accentFor(key).primary.toARGB32();
    int distance(AppAccent accent) {
      final int value = accent.primary.toARGB32();
      final int red = ((target >> 16) & 0xFF) - ((value >> 16) & 0xFF);
      final int green = ((target >> 8) & 0xFF) - ((value >> 8) & 0xFF);
      final int blue = (target & 0xFF) - (value & 0xFF);
      return red * red + green * green + blue * blue;
    }

    return accents
        .reduce(
          (AppAccent best, AppAccent candidate) =>
              distance(candidate) < distance(best) ? candidate : best,
        )
        .key;
  }

  static String customAccentKey(Color color) =>
      'custom:${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  static AppAccent? _customAccent(String key) {
    if (!key.startsWith('custom:')) return null;
    final String hex = key.substring('custom:'.length).replaceFirst('#', '');
    if (!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(hex)) return null;
    final Color primary = Color(0xFF000000 | int.parse(hex, radix: 16));
    final HSLColor hsl = HSLColor.fromColor(primary);
    final double secondaryLightness = hsl.lightness < .58
        ? (hsl.lightness + .16).clamp(0.0, .82)
        : (hsl.lightness - .12).clamp(.24, 1.0);
    final Color secondary = hsl
        .withSaturation((hsl.saturation * .86).clamp(.18, .82))
        .withLightness(secondaryLightness)
        .toColor();
    Color action = primary;
    double lightness = hsl.lightness;
    while (contrastRatio(action, Colors.white) < 4.5 && lightness > .12) {
      lightness -= .025;
      action = hsl.withLightness(lightness).toColor();
    }
    return AppAccent(
      key: customAccentKey(primary),
      label: '自定义 #${hex.toUpperCase()}',
      primary: primary,
      secondary: secondary,
      action: action,
    );
  }

  static AppAccentTheme accentOf(BuildContext context) =>
      Theme.of(context).extension<AppAccentTheme>() ??
      const AppAccentTheme(
        primary: brandTeal,
        secondary: brandTealLight,
        action: Color(0xFF0D4B49),
      );

  static List<Color> accessibleGradientFor(AppAccent accent) => <Color>[
    _withWhiteContrast(accent.action),
    _withWhiteContrast(accent.secondary),
  ];

  static List<Color> accessibleGradientOf(BuildContext context) {
    final AppAccentTheme accent = accentOf(context);
    return <Color>[
      _withWhiteContrast(accent.action),
      _withWhiteContrast(accent.secondary),
    ];
  }

  static Color _withWhiteContrast(Color source) {
    Color result = source;
    for (int step = 1; step <= 12; step++) {
      if (contrastRatio(result, Colors.white) >= 4.5) return result;
      result = Color.lerp(source, Colors.black, step * .05) ?? result;
    }
    return result;
  }

  static LedgerSemanticColors ledgerOf(BuildContext context) =>
      Theme.of(context).extension<LedgerSemanticColors>() ??
      const LedgerSemanticColors(
        income: Color(0xFF1769AA),
        expense: Color(0xFFD32F2F),
        transfer: Color(0xFF667085),
      );

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
    String accentKey = defaultAccentKey,
    String colorVisionMode = 'standard',
  }) => _theme(
    brightness: Brightness.light,
    highContrast: highContrast,
    accent: accentFor(accentKey),
    colorVisionMode: colorVisionMode,
  );

  static ThemeData dark({
    bool highContrast = false,
    String accentKey = defaultAccentKey,
    String colorVisionMode = 'standard',
  }) => _theme(
    brightness: Brightness.dark,
    highContrast: highContrast,
    accent: accentFor(accentKey),
    colorVisionMode: colorVisionMode,
  );

  static ThemeData _theme({
    required Brightness brightness,
    required bool highContrast,
    required AppAccent accent,
    required String colorVisionMode,
  }) {
    final bool dark = brightness == Brightness.dark;
    ColorScheme colors = ColorScheme.fromSeed(
      seedColor: accent.primary,
      brightness: brightness,
      surface: dark ? const Color(0xFF1C1B27) : const Color(0xFFFFFFFF),
    );
    if (!dark) {
      colors = colors.copyWith(primary: accent.action, onPrimary: Colors.white);
    }
    final LedgerSemanticColors ledgerColors = _ledgerColors(
      brightness: brightness,
      mode: colorVisionMode,
      highContrast: highContrast,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: dark
          ? highContrast
                ? const Color(0xFF050607)
                : const Color(0xFF11101A)
          : highContrast
          ? const Color(0xFFE9EDF2)
          : const Color(0xFFF4F4FA),
      fontFamilyFallback: const <String>['PingFang SC', 'Microsoft YaHei'],
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: dark
            ? const Color(0xFF1C1B27)
            : const Color(0xFFFFFFFF),
        foregroundColor: dark
            ? const Color(0xFFE7ECF3)
            : const Color(0xFF1B1D21),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: dark ? const Color(0xFF1C1B27) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF282634) : const Color(0xFFF0F0F7),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: colors.outlineVariant.withValues(alpha: .55),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          side: BorderSide(color: colors.outlineVariant),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        minTileHeight: 58,
        contentPadding: EdgeInsets.symmetric(horizontal: 18),
        minVerticalPadding: 10,
      ),
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant.withValues(alpha: .65),
        space: 1,
        thickness: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: colors.surface,
        modalBackgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark
            ? const Color(0xFFE8E5F4)
            : const Color(0xFF252236),
        contentTextStyle: TextStyle(
          color: dark ? const Color(0xFF211E2C) : Colors.white,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: colors.surface,
        indicatorColor: colors.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[
        AppAccentTheme(
          primary: accent.primary,
          secondary: accent.secondary,
          action: accent.action,
        ),
        ledgerColors,
      ],
    );
  }

  static LedgerSemanticColors _ledgerColors({
    required Brightness brightness,
    required String mode,
    required bool highContrast,
  }) {
    final bool dark = brightness == Brightness.dark;
    LedgerSemanticColors colors = switch (mode) {
      'protan' || 'deutan' =>
        dark
            ? const LedgerSemanticColors(
                income: Color(0xFF63B3ED),
                expense: Color(0xFFFFC857),
                transfer: Color(0xFFB8C0CC),
              )
            : const LedgerSemanticColors(
                income: Color(0xFF005FAF),
                expense: Color(0xFF8A5100),
                transfer: Color(0xFF5F6670),
              ),
      'tritan' =>
        dark
            ? const LedgerSemanticColors(
                income: Color(0xFF62D6A9),
                expense: Color(0xFFF78ACB),
                transfer: Color(0xFFB8C0CC),
              )
            : const LedgerSemanticColors(
                income: Color(0xFF007A5E),
                expense: Color(0xFF9C1C83),
                transfer: Color(0xFF5F6670),
              ),
      'mono' =>
        dark
            ? const LedgerSemanticColors(
                income: Color(0xFFAEB7C2),
                expense: Color(0xFFFFFFFF),
                transfer: Color(0xFF7E8793),
              )
            : const LedgerSemanticColors(
                income: Color(0xFF5F6670),
                expense: Color(0xFF20242A),
                transfer: Color(0xFF8A929D),
              ),
      _ =>
        dark
            ? const LedgerSemanticColors(
                income: Color(0xFF74C0FC),
                expense: Color(0xFFFF8A8A),
                transfer: Color(0xFFB8C0CC),
              )
            : const LedgerSemanticColors(
                income: Color(0xFF1769AA),
                expense: Color(0xFFD32F2F),
                transfer: Color(0xFF667085),
              ),
    };
    if (!highContrast) return colors;
    Color boost(Color color) =>
        Color.lerp(color, dark ? Colors.white : Colors.black, .16) ?? color;
    colors = colors.copyWith(
      income: boost(colors.income),
      expense: boost(colors.expense),
      transfer: boost(colors.transfer),
    );
    return colors;
  }
}
