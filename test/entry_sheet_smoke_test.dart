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
    controller.members.add(
      LedgerMember(id: 2, name: '小明', colorValue: 0xFFF5A623),
    );
    controller.currentMemberId = 1;
    controller.memberWallets[1] = 5;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: EntrySheet(controller: controller)),
    );
    await tester.pump();
    final Finder amountInput = find.byType(EditableText).first;
    expect(tester.widget<EditableText>(amountInput).focusNode.hasFocus, isTrue);
    tester.testTextInput.hide();
    await tester.pump();

    await tester.tap(find.text('付款成员（可多选）'));
    await tester.pumpAndSettle();
    expect(find.text('选择付款成员'), findsOneWidget);
    Navigator.of(tester.element(find.text('选择付款成员'))).pop();
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
    expect(find.text('日期与时间'), findsOneWidget);
    Navigator.of(tester.element(find.text('日期与时间'))).pop();
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
    controller.members.add(
      LedgerMember(id: 2, name: '小明', colorValue: 0xFFF5A623),
    );
    controller.currentMemberId = 1;
    controller.memberWallets[1] = 5;
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
    expect(find.text('已分配 ¥2.00'), findsOneWidget);
    expect(find.text('添加账户'), findsNothing);
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
    controller.members.add(
      LedgerMember(id: 2, name: '小明', colorValue: 0xFFF5A623),
    );
    controller.currentMemberId = 1;
    controller.memberWallets[1] = 5;
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

    await tester.tap(find.text('付款成员（可多选）'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我').last);
    await tester.pump();
    await tester.tap(find.text('完成 (1)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('支付来源'));
    await tester.pumpAndSettle();
    expect(find.text('有一项超过可用资金'), findsNothing);
    await tester.tap(find.text('按账户顺序自动补足'));
    await tester.pump();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('预算外花销'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('预算外花销'));
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.outsideBudget, isTrue);
    expect(saved!.recordedByMemberId, isNull);
    expect(saved!.fundings, hasLength(1));
    expect(
      saved!.fundings.fold<double>(0, (sum, item) => sum + item.amount),
      2,
    );
  });

  testWidgets('只有一个成员时保持普通个人记账界面', (WidgetTester tester) async {
    final LedgerController controller =
        LedgerController(LedgerRepository(AppDatabase()))
          ..currentMemberId = 1
          ..members.add(LedgerMember(id: 1, name: '我', colorValue: 0xFF2E7CF6));
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: EntrySheet(controller: controller)),
    );
    await tester.pump();

    expect(find.text('付款成员（可多选）'), findsNothing);
    expect(find.text('记录者（可不选）'), findsNothing);
    expect(find.text('可见范围'), findsNothing);
  });

  testWidgets('默认账户余额不足时按账户顺序自动补足', (WidgetTester tester) async {
    final LedgerController controller =
        LedgerController(LedgerRepository(AppDatabase()))
          ..accounts.addAll(<LedgerAccount>[
            LedgerAccount(
              id: 1,
              name: '支付宝',
              balance: 1,
              funds: const <AccountFund>[AccountFund(accountId: 1, balance: 1)],
            ),
            LedgerAccount(
              id: 2,
              name: '银行卡',
              balance: 9,
              funds: const <AccountFund>[AccountFund(accountId: 2, balance: 9)],
            ),
          ])
          ..members.add(LedgerMember(id: 1, name: '我', colorValue: 0xFF2E7CF6))
          ..commonFund = 10;
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
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('我的荷包还差 ¥2.00'), findsOneWidget);
    await tester.tap(find.text('公共资金'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.fundings, hasLength(2));
    expect(saved!.fundings[0].accountId, 1);
    expect(saved!.fundings[0].amount, 1);
    expect(saved!.fundings[1].accountId, 2);
    expect(saved!.fundings[1].amount, 1);
  });

  testWidgets('成员荷包不足时选择其他成员会记录代付来源', (WidgetTester tester) async {
    final LedgerController controller =
        LedgerController(LedgerRepository(AppDatabase()))
          ..accounts.add(LedgerAccount(id: 1, name: '现金', balance: 10))
          ..members.addAll(<LedgerMember>[
            LedgerMember(id: 1, name: '我', colorValue: 0xFF2E7CF6),
            LedgerMember(id: 2, name: '小明', colorValue: 0xFFF5A623),
          ])
          ..memberWallets[1] = 0
          ..memberWallets[2] = 10;
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
    await tester.tap(find.text('付款成员（可多选）'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我').last);
    await tester.pump();
    await tester.tap(find.text('完成 (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('我的荷包还差 ¥2.00'), findsOneWidget);
    await tester.tap(find.text('小明的荷包'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.walletSources, hasLength(1));
    expect(saved!.walletSources.single.sourceMemberId, 2);
    expect(saved!.walletSources.single.payerMemberId, 1);
    expect(saved!.walletSources.single.amount, 2);
  });

  testWidgets('多名付款成员可以在单笔账内选择自定义金额', (WidgetTester tester) async {
    final LedgerController controller =
        LedgerController(LedgerRepository(AppDatabase()))
          ..accounts.add(LedgerAccount(id: 1, name: '现金', balance: 20))
          ..members.addAll(<LedgerMember>[
            LedgerMember(id: 1, name: 'A', colorValue: 0xFF2E7CF6),
            LedgerMember(id: 2, name: 'B', colorValue: 0xFFF5A623),
          ])
          ..memberWallets[1] = 10
          ..memberWallets[2] = 10;
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
    await tester.enterText(find.byType(TextField).first, '10');
    await tester.tap(find.text('付款成员（可多选）'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A').last);
    await tester.tap(find.text('B').last);
    await tester.pump();
    await tester.tap(find.text('完成 (2)'));
    await tester.pumpAndSettle();

    expect(find.text('付款分摊'), findsWidgets);
    await tester.tap(find.text('自定义金额'));
    await tester.pump();
    final Finder splitInputs = find.descendant(
      of: find.byType(FractionallySizedBox),
      matching: find.byType(TextField),
    );
    expect(splitInputs, findsNWidgets(2));
    await tester.enterText(splitInputs.at(0), '3');
    await tester.enterText(splitInputs.at(1), '7');
    await tester.pump();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(find.text('自定义金额'), findsOneWidget);

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.memberShares, hasLength(2));
    expect(saved!.memberShares[0].amount, 3);
    expect(saved!.memberShares[1].amount, 7);
    expect(saved!.walletSources, hasLength(2));
    expect(saved!.walletSources[0].amount, 3);
    expect(saved!.walletSources[1].amount, 7);
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
