import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yibi/data/app_database.dart';
import 'package:yibi/data/ledger_controller.dart';
import 'package:yibi/data/ledger_repository.dart';
import 'package:yibi/features/entry/entry_detail_sheet.dart';
import 'package:yibi/models/ledger_models.dart';

void main() {
  testWidgets('账目详情可以再记一笔', (WidgetTester tester) async {
    final LedgerController controller = LedgerController(
      LedgerRepository(AppDatabase()),
    );
    controller.accounts.add(LedgerAccount(id: 1, name: '现金', balance: 100));
    addTearDown(controller.dispose);
    bool repeated = false;
    final LedgerEntry entry = LedgerEntry(
      id: 1,
      type: EntryType.expense,
      amount: 20,
      category: '餐饮',
      occurredAt: DateTime(2026, 1, 1),
      note: '午餐',
      accountId: 1,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: TextButton(
              onPressed: () => showEntryDetailSheet(
                context: context,
                controller: controller,
                entry: entry,
                onEdit: () {},
                onRepeat: () => repeated = true,
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('再记一笔'), findsOneWidget);

    await tester.tap(find.text('再记一笔'));
    await tester.pumpAndSettle();

    expect(repeated, isTrue);
  });
}
