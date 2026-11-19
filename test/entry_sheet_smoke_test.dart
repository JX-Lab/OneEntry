import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yibi/data/app_database.dart';
import 'package:yibi/data/ledger_controller.dart';
import 'package:yibi/data/ledger_repository.dart';
import 'package:yibi/features/entry/entry_sheet.dart';
import 'package:yibi/models/ledger_models.dart';

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
    final EditableText amountInput = tester.widget<EditableText>(
      find.byType(EditableText).first,
    );
    expect(amountInput.focusNode.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('选择成员后不会重新唤起金额键盘', (WidgetTester tester) async {
    final LedgerController controller = LedgerController(
      LedgerRepository(AppDatabase()),
    );
    controller.members.add(
      LedgerMember(id: 1, name: '我', colorValue: 0xFF2E7CF6),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: EntrySheet(controller: controller)),
    );
    await tester.pump();
    final Finder amountInput = find.byType(EditableText).first;
    expect(tester.widget<EditableText>(amountInput).focusNode.hasFocus, isTrue);
    tester.testTextInput.hide();
    await tester.pump();

    await tester.tap(find.text('承担成员（可多选）'));
    await tester.pumpAndSettle();
    expect(find.text('选择成员'), findsOneWidget);
    Navigator.of(tester.element(find.text('选择成员'))).pop();
    await tester.pumpAndSettle();

    expect(
      tester.widget<EditableText>(amountInput).focusNode.hasFocus,
      isFalse,
    );
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('选择时间前会清除输入框焦点', (WidgetTester tester) async {
    final LedgerController controller = LedgerController(
      LedgerRepository(AppDatabase()),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: EntrySheet(controller: controller)),
    );
    final Finder noteField = find.byType(TextField).last;
    final Finder noteInput = find.descendant(
      of: noteField,
      matching: find.byType(EditableText),
    );

    await tester.tap(noteField);
    await tester.pump();
    expect(tester.widget<EditableText>(noteInput).focusNode.hasFocus, isTrue);
    tester.testTextInput.hide();
    await tester.pump();

    await tester.tap(find.text('时间'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    Navigator.of(tester.element(find.byType(DatePickerDialog))).pop();
    await tester.pumpAndSettle();

    expect(tester.widget<EditableText>(noteInput).focusNode.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('支出可以打开组合付款并标记预算外', (WidgetTester tester) async {
    final LedgerController controller = LedgerController(
      LedgerRepository(AppDatabase()),
    );
    controller.accounts.add(
      LedgerAccount(
        id: 1,
        name: '支付宝',
        balance: 6,
        funds: const <AccountFund>[
          AccountFund(accountId: 1, balance: 1),
          AccountFund(accountId: 1, memberId: 1, balance: 5),
        ],
      ),
    );
    controller.members.add(
      LedgerMember(id: 1, name: '我', colorValue: 0xFF2E7CF6),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: EntrySheet(controller: controller)),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, '2');
    expect(find.text('预算外花销'), findsOneWidget);
    await tester.tap(find.text('支付来源'));
    await tester.pumpAndSettle();

    expect(find.text('组合付款'), findsOneWidget);
    expect(find.text('按账户顺序自动补足'), findsOneWidget);
  });

  testWidgets('组合付款可自动补足并保存预算外账目', (WidgetTester tester) async {
    final LedgerController controller = LedgerController(
      LedgerRepository(AppDatabase()),
    );
    controller.accounts.add(
      LedgerAccount(
        id: 1,
        name: '支付宝',
        balance: 6,
        funds: const <AccountFund>[
          AccountFund(accountId: 1, balance: 1),
          AccountFund(accountId: 1, memberId: 1, balance: 5),
        ],
      ),
    );
    controller.members.add(
      LedgerMember(id: 1, name: '我', colorValue: 0xFF2E7CF6),
    );
    addTearDown(controller.dispose);
    LedgerEntry? saved;

    await tester.pumpWidget(
      MaterialApp(
        home: _EntryHarness(
          controller: controller,
          onSaved: (LedgerEntry value) => saved = value,
        ),
      ),
    );
    await tester.tap(find.text('打开记账'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '2');

    await tester.tap(find.text('承担成员（可多选）'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我'));
    await tester.pump();
    await tester.tap(find.text('完成 (1)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('支付来源'));
    await tester.pumpAndSettle();
    expect(find.text('有一项超过可用资金'), findsOneWidget);
    await tester.tap(find.text('按账户顺序自动补足'));
    await tester.pump();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('预算外花销'));
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.outsideBudget, isTrue);
    expect(saved!.fundings, hasLength(2));
    expect(
      saved!.fundings.fold<double>(0, (sum, item) => sum + item.amount),
      2,
    );
  });
}

class _EntryHarness extends StatelessWidget {
  const _EntryHarness({required this.controller, required this.onSaved});

  final LedgerController controller;
  final ValueChanged<LedgerEntry> onSaved;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        onPressed: () async {
          final LedgerEntry? result = await Navigator.of(context)
              .push<LedgerEntry>(
                MaterialPageRoute<LedgerEntry>(
                  builder: (_) => EntrySheet(controller: controller),
                ),
              );
          if (result != null) onSaved(result);
        },
        child: const Text('打开记账'),
      ),
    ),
  );
}
