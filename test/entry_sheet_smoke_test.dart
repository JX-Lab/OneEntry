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

  testWidgets('收支字段使用统一名称并可查看解释', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final LedgerController controller =
        LedgerController(LedgerRepository(AppDatabase()))
          ..accounts.add(LedgerAccount(id: 1, name: '支付宝', balance: 20))
          ..members.addAll(<LedgerMember>[
            LedgerMember(id: 1, name: 'A', colorValue: 0xFF2E7CF6),
            LedgerMember(id: 2, name: 'B', colorValue: 0xFFF5A623),
          ])
          ..commonFund = 20;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: EntrySheet(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('支出归属'), findsOneWidget);
    expect(find.text('扣款荷包'), findsOneWidget);
    expect(find.text('付款账户'), findsOneWidget);
    expect(find.byTooltip('保存'), findsOneWidget);
    expect(find.text('保存'), findsNothing);
    await tester.tap(find.byTooltip('查看支出归属说明'));
    await tester.pumpAndSettle();
    expect(find.textContaining('计入哪些成员的支出统计'), findsOneWidget);
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('更多信息'));
    await tester.pumpAndSettle();
    final InkWell moreInfo = tester.widget<InkWell>(
      find
          .ancestor(of: find.text('更多信息'), matching: find.byType(InkWell))
          .first,
    );
    expect(moreInfo.splashFactory, NoSplash.splashFactory);
    expect(find.text('发起者'), findsOneWidget);
    expect(find.text('记录者'), findsOneWidget);

    await tester.tap(find.text('收入'));
    await tester.pumpAndSettle();
    expect(find.text('收入归属'), findsOneWidget);
    expect(find.text('入账荷包'), findsOneWidget);
    expect(find.text('收款账户'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('关闭键盘后只有点击金额框才会再次唤起', (WidgetTester tester) async {
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

    await tester.tap(find.text('支出归属'));
    await tester.pumpAndSettle();
    expect(find.text('选择支出归属'), findsOneWidget);
    Navigator.of(tester.element(find.text('选择支出归属'))).pop();
    await tester.pumpAndSettle();

    expect(
      tester.widget<EditableText>(amountInput).focusNode.hasFocus,
      isFalse,
    );
    expect(tester.testTextInput.isVisible, isFalse);

    await tester.scrollUntilVisible(
      find.text('更多信息'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('更多信息'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(amountInput).focusNode.hasFocus,
      isFalse,
    );
    expect(tester.testTextInput.isVisible, isFalse);

    await tester.scrollUntilVisible(
      amountInput,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(amountInput);
    await tester.pump();
    expect(tester.widget<EditableText>(amountInput).focusNode.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
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

    await tester.scrollUntilVisible(
      find.text('时间'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('时间'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(find.text('选择日期'), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_alt_outlined), findsOneWidget);
    Navigator.of(tester.element(find.byType(DatePickerDialog))).pop();
    await tester.pumpAndSettle();

    expect(tester.widget<EditableText>(noteInput).focusNode.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('日期选择可切换键盘自由输入', (WidgetTester tester) async {
    final LedgerController controller = LedgerController(
      LedgerRepository(AppDatabase()),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: EntrySheet(controller: controller)),
    );
    await tester.tap(find.text('时间'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.keyboard_alt_outlined));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.byType(TextField),
      ),
      findsWidgets,
    );
  });

  testWidgets('时间选择可切换键盘自由输入', (WidgetTester tester) async {
    final LedgerController controller = LedgerController(
      LedgerRepository(AppDatabase()),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: EntrySheet(controller: controller)),
    );
    await tester.tap(find.text('时间'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    expect(find.byType(TimePickerDialog), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_alt_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.keyboard_alt_outlined));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(TimePickerDialog),
        matching: find.byType(TextField),
      ),
      findsWidgets,
    );
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
    await tester.tap(find.text('付款账户'));
    await tester.pumpAndSettle();

    expect(find.text('选择付款账户'), findsOneWidget);
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

    await tester.tap(find.text('支出归属'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我').last);
    await tester.pump();
    await tester.tap(find.text('完成 (1)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('付款账户'));
    await tester.pumpAndSettle();
    expect(find.text('有一项超过可用资金'), findsNothing);
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('预算外花销'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('预算外花销'));
    await tester.pump();
    await tester.tap(find.byTooltip('保存'));
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

    expect(find.text('支出归属'), findsNothing);
    expect(find.text('更多信息'), findsNothing);
    expect(find.text('可见范围'), findsNothing);
  });

  testWidgets('账户自动补足且成员荷包不足时回退公共资金', (WidgetTester tester) async {
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
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.fundings, hasLength(2));
    expect(saved!.fundings[0].accountId, 1);
    expect(saved!.fundings[0].amount, 1);
    expect(saved!.fundings[1].accountId, 2);
    expect(saved!.fundings[1].amount, 1);
    expect(saved!.walletSources, hasLength(1));
    expect(saved!.walletSources.single.common, isTrue);
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
    await tester.tap(find.text('支出归属'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我').last);
    await tester.pump();
    await tester.tap(find.text('完成 (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('保存'));
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
          ..splitMode = 'custom'
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
    await tester.tap(find.text('支出归属'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A').last);
    await tester.tap(find.text('B').last);
    await tester.pump();
    await tester.tap(find.text('完成 (2)'));
    await tester.pumpAndSettle();

    expect(find.text('分摊金额'), findsWidgets);
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
    expect(find.text('自由填写'), findsOneWidget);

    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.memberShares, hasLength(2));
    expect(saved!.memberShares[0].amount, 3);
    expect(saved!.memberShares[1].amount, 7);
    expect(saved!.walletSources, hasLength(2));
    expect(saved!.walletSources[0].amount, 3);
    expect(saved!.walletSources[1].amount, 7);
  });

  testWidgets('全局 AA 设置会直接均分多人账目', (WidgetTester tester) async {
    final LedgerController controller =
        LedgerController(LedgerRepository(AppDatabase()))
          ..accounts.add(LedgerAccount(id: 1, name: '现金', balance: 20))
          ..members.addAll(<LedgerMember>[
            LedgerMember(id: 1, name: 'A', colorValue: 0xFF2E7CF6),
            LedgerMember(id: 2, name: 'B', colorValue: 0xFFF5A623),
          ])
          ..splitMode = 'equal'
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
    await tester.tap(find.text('支出归属'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A').last);
    await tester.tap(find.text('B').last);
    await tester.pump();
    await tester.tap(find.text('完成 (2)'));
    await tester.pumpAndSettle();

    expect(find.text('分摊金额'), findsNothing);
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!.memberShares.map((item) => item.amount), <double>[5, 5]);
  });

  testWidgets('全体成员支出可按规则优先扣公共资金', (WidgetTester tester) async {
    final LedgerController controller =
        LedgerController(LedgerRepository(AppDatabase()))
          ..accounts.add(LedgerAccount(id: 1, name: '现金', balance: 40))
          ..members.addAll(<LedgerMember>[
            LedgerMember(id: 1, name: 'A', colorValue: 0xFF2E7CF6),
            LedgerMember(id: 2, name: 'B', colorValue: 0xFFF5A623),
          ])
          ..commonFund = 20
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
    await tester.tap(find.text('支出归属'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A').last);
    await tester.tap(find.text('B').last);
    await tester.pump();
    await tester.tap(find.text('完成 (2)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.walletSources, hasLength(2));
    expect(saved!.walletSources.every((source) => source.common), isTrue);
    expect(
      saved!.walletSources.fold<double>(0, (sum, item) => sum + item.amount),
      10,
    );
  });

  testWidgets('收入归属与入账荷包可以分别选择', (WidgetTester tester) async {
    final LedgerController controller =
        LedgerController(LedgerRepository(AppDatabase()))
          ..accounts.add(LedgerAccount(id: 1, name: '银行卡', balance: 0))
          ..members.addAll(<LedgerMember>[
            LedgerMember(id: 1, name: 'A', colorValue: 0xFF2E7CF6),
            LedgerMember(id: 2, name: 'B', colorValue: 0xFFF5A623),
          ]);
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
    await tester.tap(find.text('收入'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '10');
    await tester.tap(find.text('收入归属'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A').last);
    await tester.pump();
    await tester.tap(find.text('完成 (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('入账荷包'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('公共资金').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.memberIds, <int>[1]);
    expect(saved!.walletSources.single.common, isTrue);
    expect(saved!.walletSources.single.payerMemberId, 1);
  });

  testWidgets('从收支切到转账不会保存隐藏的成员角色', (WidgetTester tester) async {
    final LedgerController controller =
        LedgerController(LedgerRepository(AppDatabase()))
          ..accounts.addAll(<LedgerAccount>[
            LedgerAccount(id: 1, name: '支付宝', balance: 20),
            LedgerAccount(id: 2, name: '银行卡', balance: 20),
          ])
          ..members.addAll(<LedgerMember>[
            LedgerMember(id: 1, name: 'A', colorValue: 0xFF2E7CF6),
            LedgerMember(id: 2, name: 'B', colorValue: 0xFFF5A623),
          ]);
    addTearDown(controller.dispose);
    final LedgerEntry previous = LedgerEntry(
      id: 7,
      type: EntryType.expense,
      amount: 10,
      category: '餐饮',
      occurredAt: DateTime.now(),
      note: '',
      accountId: 1,
      memberIds: const <int>[1],
      initiatedByMemberId: 1,
      recorderIds: const <int>[2],
      recordedByMemberId: 2,
    );
    LedgerEntry? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: _EntryHarness(
          controller: controller,
          initial: previous,
          onSaved: (LedgerEntry value) => saved = value,
        ),
      ),
    );
    await tester.tap(find.text('打开记账'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('转账'));
    await tester.pumpAndSettle();
    expect(find.text('支出归属'), findsNothing);
    expect(find.text('更多信息'), findsNothing);
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!.memberIds, isEmpty);
    expect(saved!.memberShares, isEmpty);
    expect(saved!.recorderIds, isEmpty);
    expect(saved!.recordedByMemberId, isNull);
    expect(saved!.initiatedByMemberId, isNull);
  });
}

class _EntryHarness extends StatelessWidget {
  const _EntryHarness({
    required this.controller,
    required this.onSaved,
    this.initial,
  });

  final LedgerController controller;
  final ValueChanged<LedgerEntry> onSaved;
  final LedgerEntry? initial;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        onPressed: () async {
          final LedgerEntry? result = await Navigator.of(context)
              .push<LedgerEntry>(
                MaterialPageRoute<LedgerEntry>(
                  builder: (_) =>
                      EntrySheet(controller: controller, initial: initial),
                ),
              );
          if (result != null) onSaved(result);
        },
        child: const Text('打开记账'),
      ),
    ),
  );
}
