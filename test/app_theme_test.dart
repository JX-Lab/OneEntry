import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yibi/theme/app_theme.dart';

void main() {
  test('所有主题的实心操作色与白字对比度达标', () {
    for (final AppAccent accent in AppTheme.accents) {
      expect(
        AppTheme.contrastRatio(accent.action, Colors.white),
        greaterThanOrEqualTo(4.5),
        reason: accent.label,
      );
    }
  });

  test('所有主题的卡片渐变端点与白字对比度达标', () {
    for (final AppAccent accent in AppTheme.accents) {
      final List<Color> colors = AppTheme.accessibleGradientFor(accent);
      expect(colors, hasLength(2));
      for (final Color color in colors) {
        expect(
          AppTheme.contrastRatio(color, Colors.white),
          greaterThanOrEqualTo(4.5),
          reason: '${accent.label} $color',
        );
      }
    }
  });

  test('未知主题色会回退到默认翡翠绿', () {
    expect(AppTheme.accentFor('missing').key, AppTheme.defaultAccentKey);
  });

  test('默认主题使用最初的翡翠绿品牌色', () {
    final AppAccent accent = AppTheme.accentFor(AppTheme.defaultAccentKey);
    expect(accent.primary, AppTheme.green);
    expect(accent.secondary, AppTheme.greenLight);
  });

  test('自定义主题会匹配最接近的桌面图标预设', () {
    expect(AppTheme.launcherAccentKey('custom:135E5B'), 'teal');
    expect(AppTheme.launcherAccentKey('custom:6A43E8'), 'indigo');
  });

  test('自定义主题色会生成可读的实心操作色', () {
    final AppAccent accent = AppTheme.accentFor('custom:F4C542');
    expect(accent.primary, const Color(0xFFF4C542));
    expect(accent.key, 'custom:F4C542');
    expect(
      AppTheme.contrastRatio(accent.action, Colors.white),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('危险操作色与白色文字对比度达标', () {
    expect(
      AppTheme.contrastRatio(AppTheme.expense, Colors.white),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('各色觉模式的账目语义色在明暗主题中均可读', () {
    for (final String mode in <String>[
      'standard',
      'protan',
      'deutan',
      'tritan',
      'mono',
    ]) {
      for (final ThemeData theme in <ThemeData>[
        AppTheme.light(colorVisionMode: mode),
        AppTheme.dark(colorVisionMode: mode),
      ]) {
        final LedgerSemanticColors colors = theme
            .extension<LedgerSemanticColors>()!;
        final Color surface = theme.colorScheme.surface;
        expect(colors.expense, isNot(colors.income), reason: mode);
        expect(
          AppTheme.contrastRatio(colors.expense, surface),
          greaterThanOrEqualTo(4.5),
          reason: '$mode expense ${theme.brightness}',
        );
        expect(
          AppTheme.contrastRatio(colors.income, surface),
          greaterThanOrEqualTo(4.5),
          reason: '$mode income ${theme.brightness}',
        );
      }
    }
  });
}
