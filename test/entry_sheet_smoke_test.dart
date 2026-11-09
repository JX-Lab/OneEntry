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

    await tester.tap(find.text('成员（可多选）'));
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
}
