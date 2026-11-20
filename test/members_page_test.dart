import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yibi/data/app_database.dart';
import 'package:yibi/data/ledger_controller.dart';
import 'package:yibi/data/ledger_repository.dart';
import 'package:yibi/features/members/members_page.dart';
import 'package:yibi/models/ledger_models.dart';

class _MembersController extends LedgerController {
  _MembersController() : super(LedgerRepository(AppDatabase()));

  @override
  Future<void> settleMemberDebt({
    required int creditorMemberId,
    required int debtorMemberId,
    required double amount,
    String note = '',
  }) async {
    debtSettlements.add(
      MemberDebtSettlement(
        creditorMemberId: creditorMemberId,
        debtorMemberId: debtorMemberId,
        amount: amount,
        occurredAt: DateTime.now(),
        note: note,
      ),
    );
    notifyListeners();
  }

  @override
  Future<void> setWalletBalances({
    required double commonFund,
    required Map<int, double> memberBalances,
  }) async {
    this.commonFund = commonFund;
    memberWallets
      ..clear()
      ..addAll(memberBalances);
    notifyListeners();
  }
}

void main() {
  testWidgets('成员页以荷包与往来为入口且结算后不会红屏', (WidgetTester tester) async {
    final _MembersController controller = _MembersController()
      ..commonFund = 80
      ..members.addAll(<LedgerMember>[
        LedgerMember(id: 1, name: '我', colorValue: 0xFF2E7CF6),
        LedgerMember(id: 2, name: '小明', colorValue: 0xFFF5A623),
      ])
      ..memberWallets.addAll(<int, double>{1: 10, 2: 10})
      ..memberDebts.add(
        const MemberDebt(creditorMemberId: 2, debtorMemberId: 1, amount: 10),
      );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: MembersPage(controller: controller)),
    );
    expect(find.text('成员概况'), findsNothing);
    expect(find.text('荷包与往来'), findsOneWidget);

    await tester.tap(find.text('荷包与往来'));
    await tester.pumpAndSettle();
    expect(find.text('公共资金'), findsOneWidget);
    expect(find.text('我的荷包'), findsOneWidget);
    expect(find.text('我 欠 小明'), findsOneWidget);

    await tester.tap(find.text('分配'));
    await tester.pumpAndSettle();
    final Finder walletInputs = find.byType(TextField);
    expect(walletInputs, findsNWidgets(2));
    await tester.enterText(walletInputs.first, '30');
    await tester.pump();
    expect(find.text('未分配的 ¥60.00 将保留为公共资金'), findsOneWidget);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(controller.commonFund, 60);

    await tester.tap(find.text('我 欠 小明'));
    await tester.pumpAndSettle();
    expect(find.text('我 向 小明 结算'), findsOneWidget);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('我 欠 小明'), findsNothing);
    expect(find.text('暂无成员借款'), findsOneWidget);
  });
}
