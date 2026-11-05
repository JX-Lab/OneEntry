import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yibi/data/app_database.dart';
import 'package:yibi/data/ledger_controller.dart';
import 'package:yibi/data/ledger_repository.dart';
import 'package:yibi/features/settings/settings_page.dart';
import 'package:yibi/theme/app_theme.dart';

void main() {
  testWidgets('设置页可以打开主题色选择', (WidgetTester tester) async {
    final LedgerController controller = LedgerController(
      LedgerRepository(AppDatabase()),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: SettingsPage(controller: controller),
      ),
    );
    expect(find.text('每日记账提醒'), findsOneWidget);
    expect(find.text('通知权限'), findsOneWidget);
    expect(find.text('麦克风权限'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('主题色'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('主题色'));
    await tester.pumpAndSettle();

    expect(find.text('选择主题色'), findsOneWidget);
    for (final AppAccent accent in AppTheme.accents) {
      expect(find.text(accent.label), findsWidgets);
    }
  });
}
