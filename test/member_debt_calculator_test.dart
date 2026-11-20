import 'package:flutter_test/flutter_test.dart';
import 'package:yibi/models/ledger_models.dart';
import 'package:yibi/utils/member_debt_calculator.dart';

void main() {
  test('使用另一成员荷包时生成借款', () {
    final List<MemberDebt> debts = calculateMemberDebts(
      walletSources: const <WalletSource>[
        WalletSource(sourceMemberId: 2, payerMemberId: 1, amount: 10),
      ],
    );

    expect(debts, hasLength(1));
    expect(debts.single.debtorMemberId, 1);
    expect(debts.single.creditorMemberId, 2);
    expect(debts.single.amount, 10);
  });

  test('使用公共资金不产生借款', () {
    final List<MemberDebt> debts = calculateMemberDebts(
      walletSources: const <WalletSource>[
        WalletSource(payerMemberId: 1, amount: 10),
      ],
    );

    expect(debts, isEmpty);
  });

  test('自己的荷包和其他成员代付可以混合', () {
    final List<MemberDebt> debts = calculateMemberDebts(
      walletSources: const <WalletSource>[
        WalletSource(sourceMemberId: 1, payerMemberId: 1, amount: 4),
        WalletSource(sourceMemberId: 2, payerMemberId: 1, amount: 6),
      ],
    );

    expect(debts, hasLength(1));
    expect(debts.single.debtorMemberId, 1);
    expect(debts.single.creditorMemberId, 2);
    expect(debts.single.amount, 6);
  });
}
