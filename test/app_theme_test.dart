import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yibi/theme/app_theme.dart';

void main() {
  test('所有主题色与白色文字对比度至少为 4.5:1', () {
    for (final AppAccent accent in AppTheme.accents) {
      expect(
        AppTheme.contrastRatio(accent.primary, Colors.white),
        greaterThanOrEqualTo(4.5),
        reason: '${accent.label} primary',
      );
      expect(
        AppTheme.contrastRatio(accent.secondary, Colors.white),
        greaterThanOrEqualTo(4.5),
        reason: '${accent.label} secondary',
      );
    }
  });

  test('未知主题色会回退到默认绿色', () {
    expect(AppTheme.accentFor('missing').key, 'green');
  });

  test('危险操作色与白色文字对比度达标', () {
    expect(
      AppTheme.contrastRatio(AppTheme.expense, Colors.white),
      greaterThanOrEqualTo(4.5),
    );
  });
}
