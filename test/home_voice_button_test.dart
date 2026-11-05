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
  });

  testWidgets('搜索不受当前时间范围限制', (WidgetTester tester) async {
    final LedgerController controller = LedgerController(
      LedgerRepository(AppDatabase()),
    );
    addTearDown(controller.dispose);
    controller.entries.add(
      LedgerEntry(
        id: 1,
        type: EntryType.expense,
        amount: 18,
        category: '旅行',
        occurredAt: DateTime(2000, 1, 2),
        note: '跨年搜索目标',
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

    expect(find.text('跨年搜索目标'), findsNothing);
    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '跨年搜索目标');
    await tester.pump();

    expect(
      find.descendant(of: find.byType(ListTile), matching: find.text('跨年搜索目标')),
      findsOneWidget,
    );
  });

  testWidgets('首页有明确的多选入口', (WidgetTester tester) async {
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

    expect(find.text('多选'), findsOneWidget);
    await tester.tap(find.text('多选'));
    await tester.pump();

    expect(find.text('条件'), findsOneWidget);
    expect(find.text('全选'), findsOneWidget);
    final Object? layoutException = tester.takeException();
    expect(
      layoutException,
      isNull,
      reason: layoutException is FlutterError
          ? layoutException.toStringDeep()
          : '$layoutException',
    );
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
