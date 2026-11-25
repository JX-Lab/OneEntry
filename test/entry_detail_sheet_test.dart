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
    controller.members.add(
      LedgerMember(id: 1, name: '我', colorValue: 0xFF2E7CF6),
    );
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
      memberIds: const <int>[1],
      fundings: const <EntryFunding>[EntryFunding(accountId: 1, amount: 20)],
      walletSources: const <WalletSource>[WalletSource(amount: 20)],
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
    expect(find.text('付款账户'), findsOneWidget);
    expect(find.text('支出归属'), findsOneWidget);
    expect(find.text('扣款荷包'), findsOneWidget);
    expect(find.text('记录者'), findsNothing);
    expect(find.text('预算'), findsNothing);
    expect(find.text('现金 ¥20.00'), findsOneWidget);

    await tester.tap(find.text('再记一笔'));
    await tester.pumpAndSettle();

    expect(repeated, isTrue);
  });
}
