import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yibi/data/app_database.dart';
import 'package:yibi/data/ledger_controller.dart';
import 'package:yibi/data/ledger_repository.dart';
import 'package:yibi/features/entry/entry_sheet.dart';

void main() {
  testWidgets('记一笔页面可以正常渲染', (WidgetTester tester) async {
    final LedgerController controller = LedgerController(
      LedgerRepository(AppDatabase()),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: EntrySheet(controller: controller)),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('记一笔'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
  });
}
