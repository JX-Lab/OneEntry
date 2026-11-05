import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yibi/data/app_database.dart';
import 'package:yibi/data/ledger_controller.dart';
import 'package:yibi/data/ledger_repository.dart';
import 'package:yibi/features/home/home_page.dart';
import 'package:yibi/models/ledger_models.dart';

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
          onOpenBudget: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    expect(find.text('记一笔'), findsOneWidget);
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).extendBody, isTrue);
    expect(tester.widget<AppBar>(find.byType(AppBar)).centerTitle, isFalse);
  });

  testWidgets('搜索不受当前时间范围限制', (WidgetTester tester) async {
    final LedgerController controller = LedgerController(
      LedgerRepository(AppDatabase()),
    );
    addTearDown(controller.dispose);
    controller.entries.addAll(<LedgerEntry>[
      LedgerEntry(
        id: 1,
        type: EntryType.expense,
        amount: 18,
        category: '旅行',
        occurredAt: DateTime(2000, 1, 2),
        note: '跨年搜索目标',
        accountId: 1,
      ),
      LedgerEntry(
        id: 2,
        type: EntryType.income,
        amount: 200,
        category: '其他',
        occurredAt: DateTime(2001, 2, 3),
        note: '另一笔历史账目',
        accountId: 1,
      ),
    ]);

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
          onOpenBudget: (_) {},
        ),
      ),
    );

    expect(find.text('跨年搜索目标'), findsNothing);
    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();
    expect(find.text('共 2 笔'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '跨年搜索目标');
    await tester.pump();

    expect(
      find.descendant(of: find.byType(ListTile), matching: find.text('跨年搜索目标')),
      findsOneWidget,
    );
    expect(find.text('共 1 笔'), findsOneWidget);
  });

  testWidgets('首页有明确的多选图标入口', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
          onOpenBudget: (_) {},
        ),
      ),
    );

    expect(find.byTooltip('多选'), findsOneWidget);
    await tester.tap(find.byTooltip('多选'));
    await tester.pumpAndSettle();

    expect(find.text('条件'), findsOneWidget);
    expect(find.text('全选'), findsOneWidget);
    expect(find.text('本月预算 ¥0.00'), findsNothing);
    final Object? layoutException = tester.takeException();
    expect(
      layoutException,
      isNull,
      reason: layoutException is FlutterError
          ? layoutException.toStringDeep()
          : '$layoutException',
    );
  });

  testWidgets('首页卡片和主按钮使用纵向渐变', (WidgetTester tester) async {
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
          onOpenBudget: (_) {},
        ),
      ),
    );

    final Iterable<LinearGradient> boxGradients = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((DecoratedBox box) => box.decoration)
        .whereType<BoxDecoration>()
        .map((BoxDecoration decoration) => decoration.gradient)
        .whereType<LinearGradient>();
    final Iterable<LinearGradient> inkGradients = tester
        .widgetList<Ink>(find.byType(Ink))
        .map((Ink ink) => ink.decoration)
        .whereType<BoxDecoration>()
        .map((BoxDecoration decoration) => decoration.gradient)
        .whereType<LinearGradient>();
    bool isVertical(LinearGradient gradient) =>
        gradient.begin == Alignment.topCenter &&
        gradient.end == Alignment.bottomCenter;

    final int verticalBoxCount = boxGradients.where(isVertical).length;
    final int verticalInkCount = inkGradients.where(isVertical).length;

    expect(verticalBoxCount, greaterThanOrEqualTo(1));
    expect(verticalInkCount, greaterThanOrEqualTo(1));
  });

  testWidgets('四位数月预算在手机宽度下不溢出', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final LedgerController controller = LedgerController(
      LedgerRepository(AppDatabase()),
    );
    addTearDown(controller.dispose);
    controller.monthlyBudget = 5000;
    final DateTime now = DateTime.now();
    controller.entries.add(
      LedgerEntry(
        id: 1,
        type: EntryType.expense,
        amount: 502.6,
        category: '购物',
        occurredAt: now,
        note: '',
        accountId: 1,
      ),
    );

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
          onOpenBudget: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('本月预算 ¥5000.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
