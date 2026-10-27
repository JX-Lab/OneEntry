import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yibi/data/app_database.dart';
import 'package:yibi/data/ledger_controller.dart';
import 'package:yibi/data/ledger_repository.dart';
import 'package:yibi/features/home/home_page.dart';

void main() {
  testWidgets('首页显示语音和手动记账按钮', (WidgetTester tester) async {
    final LedgerController controller = LedgerController(
      LedgerRepository(AppDatabase()),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          controller: controller,
          onAddEntry: () {},
          onVoiceEntry: (_) {},
          onEditEntry: (_) {},
          onDeleteEntry: (_) {},
          onOpenStatistics: () {},
          onOpenSettings: () {},
          onOpenAccounts: () {},
          onOpenMembers: () {},
          onOpenBudget: () {},
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    expect(find.text('记一笔'), findsOneWidget);
  });
}
