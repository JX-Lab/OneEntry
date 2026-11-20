import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yibi/data/app_database.dart';
import 'package:yibi/data/ledger_controller.dart';
import 'package:yibi/data/ledger_repository.dart';
import 'package:yibi/features/accounts/accounts_page.dart';
import 'package:yibi/models/ledger_models.dart';

class _FundRepository extends LedgerRepository {
  _FundRepository(this.accounts, this.members) : super(AppDatabase());

  final List<LedgerAccount> accounts;
  final List<LedgerMember> members;
  Map<int?, double>? saved;

  @override
  Future<void> setAccountFunds(
    int accountId,
    Map<int?, double> balances,
  ) async {
    saved = balances;
    accounts.first.funds = balances.entries
        .map(
          (item) => AccountFund(
            accountId: accountId,
            memberId: item.key,
            balance: item.value,
          ),
        )
        .toList();
  }

  @override
  Future<LedgerSnapshot> load({DateTime? budgetMonth}) async => LedgerSnapshot(
    accounts: accounts,
    members: members,
    memberDebts: const <MemberDebt>[],
    debtSettlements: const <MemberDebtSettlement>[],
    entries: const <LedgerEntry>[],
    monthlyBudget: 0,
    dailyReminderEnabled: false,
    dailyReminderHour: 20,
    dailyReminderMinute: 0,
    categoryBudgets: const <String, double>{},
    memberBudgets: const <int, double>{},
    recurringRules: const <RecurringRule>[],
    categories: const <LedgerCategory>[],
    multiEnabled: true,
    currentMemberId: 1,
    splitMode: 'equal',
    themeMode: 'system',
    themeColor: 'teal',
    voiceEnabled: true,
    textScale: 1,
    highContrast: false,
    colorVisionMode: 'standard',
    readerHints: true,
    haptics: true,
    lastBackupAt: null,
  );
}

void main() {
  testWidgets('资金分配保存时输入框仍聚焦也不会红屏', (WidgetTester tester) async {
    final List<LedgerAccount> accounts = <LedgerAccount>[
      LedgerAccount(
        id: 1,
        name: '现金',
        balance: 100,
        funds: const <AccountFund>[AccountFund(accountId: 1, balance: 100)],
      ),
    ];
    final List<LedgerMember> members = <LedgerMember>[
      LedgerMember(id: 1, name: '我', colorValue: 0xFF2E7CF6),
      LedgerMember(id: 2, name: '小明', colorValue: 0xFFF5A623),
    ];
    final _FundRepository repository = _FundRepository(accounts, members);
    final LedgerController controller = LedgerController(repository)
      ..accounts.addAll(accounts)
      ..members.addAll(members);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: AccountsPage(controller: controller)),
    );
    await tester.tap(find.text('现金').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('调整'));
    await tester.pumpAndSettle();

    final Finder fields = find.byType(TextField);
    expect(fields, findsNWidgets(3));
    await tester.enterText(fields.at(0), '80');
    await tester.enterText(fields.at(1), '20');
    await tester.enterText(fields.at(2), '0');
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(repository.saved?[null], 80);
    expect(repository.saved?[1], 20);
  });
}
