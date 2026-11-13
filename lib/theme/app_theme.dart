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
  static const Color green = Color(0xFF0EB078);
  static const Color greenLight = Color(0xFF35D3A0);
  static const Color expense = Color(0xFFD32F2F);
  static const Color income = Color(0xFF2E7CF6);

  // Gradients stay bright; action colors are the accessible white-text layer.
  static const List<AppAccent> accents = <AppAccent>[
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
      key: 'indigo',
      label: '靛青',
      primary: Color(0xFF4F46E5),
      secondary: Color(0xFF818CF8),
      action: Color(0xFF4338CA),
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

  static AppAccent accentFor(String key) => accents.firstWhere(
    (AppAccent accent) => accent.key == key,
    orElse: () => accents.first,
  );

  static AppAccentTheme accentOf(BuildContext context) =>
      Theme.of(context).extension<AppAccentTheme>() ??
      const AppAccentTheme(
        primary: green,
        secondary: greenLight,
        action: Color(0xFF087F5B),
      );

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
    String accentKey = 'green',
    String colorVisionMode = 'standard',
  }) => _theme(
    brightness: Brightness.light,
    highContrast: highContrast,
    accent: accentFor(accentKey),
    colorVisionMode: colorVisionMode,
  );

  static ThemeData dark({
    bool highContrast = false,
    String accentKey = 'green',
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
      surface: dark ? const Color(0xFF1A1F27) : const Color(0xFFFFFFFF),
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
