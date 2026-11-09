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

  test('未知主题色会回退到默认绿色', () {
    expect(AppTheme.accentFor('missing').key, 'green');
  });

  test('默认主题恢复原始绿色渐变', () {
    final AppAccent green = AppTheme.accentFor('green');
    expect(green.primary, const Color(0xFF0EB078));
    expect(green.secondary, const Color(0xFF35D3A0));
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
