import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yibi/data/app_database.dart';
import 'package:yibi/data/ledger_controller.dart';
import 'package:yibi/data/ledger_repository.dart';
import 'package:yibi/features/budget/budget_page.dart';
import 'package:yibi/models/ledger_models.dart';

void main() {
  testWidgets('预算页在手机宽度和 200% 字号下不溢出', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final LedgerController controller =
        LedgerController(LedgerRepository(AppDatabase()))
          ..initialized = true
          ..budgetMonth = DateTime(2026, 11)
          ..monthlyBudget = 12345
          ..categoryBudgets['一项名称比较长的分类预算'] = 6789
          ..entries.addAll(<LedgerEntry>[
            LedgerEntry(
              id: 1,
              type: EntryType.expense,
              amount: 4321,
              category: '一项名称比较长的分类预算',
              occurredAt: DateTime(2026, 11, 3),
              note: '',
              accountId: 1,
            ),
            LedgerEntry(
              id: 2,
              type: EntryType.expense,
              amount: 987,
              category: '旅行',
              occurredAt: DateTime(2026, 11, 5),
              note: '',
              accountId: 1,
              outsideBudget: true,
            ),
          ]);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: BudgetPage(controller: controller, month: DateTime(2026, 11)),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
