import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yibi/features/home/period_picker_sheet.dart';

void main() {
  testWidgets('时间筛选使用短横表示未选择', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PeriodPickerSheet(
            initial: (year: null, month: null, day: null),
            allowUnselectedYear: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('不选'), findsNothing);
    expect(find.text('—'), findsWidgets);
  });
}
