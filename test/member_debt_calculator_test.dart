import 'package:flutter_test/flutter_test.dart';
import 'package:yibi/models/ledger_models.dart';
import 'package:yibi/utils/member_debt_calculator.dart';

void main() {
  test('使用另一成员资金时生成成员欠款', () {
    final List<MemberDebt> debts = calculateMemberDebts(
      amount: 10,
      memberShares: const <MemberShare>[MemberShare(memberId: 1, amount: 10)],
      fundings: const <EntryFunding>[
        EntryFunding(accountId: 1, memberId: 2, amount: 10),
      ],
    );

    expect(debts, hasLength(1));
    expect(debts.single.debtorMemberId, 1);
    expect(debts.single.creditorMemberId, 2);
    expect(debts.single.amount, 10);
  });

  test('共同资金不产生成员欠款', () {
    final List<MemberDebt> debts = calculateMemberDebts(
      amount: 10,
      memberShares: const <MemberShare>[
        MemberShare(memberId: 1, amount: 6),
        MemberShare(memberId: 2, amount: 4),
      ],
      fundings: const <EntryFunding>[EntryFunding(accountId: 1, amount: 10)],
    );

    expect(debts, isEmpty);
  });

  test('共同资金先按承担比例抵扣后再计算欠款', () {
    final List<MemberDebt> debts = calculateMemberDebts(
      amount: 10,
      memberShares: const <MemberShare>[
        MemberShare(memberId: 1, amount: 6),
        MemberShare(memberId: 2, amount: 4),
      ],
      fundings: const <EntryFunding>[
        EntryFunding(accountId: 1, amount: 4),
        EntryFunding(accountId: 2, memberId: 1, amount: 6),
      ],
    );

    expect(debts, hasLength(1));
    expect(debts.single.debtorMemberId, 2);
    expect(debts.single.creditorMemberId, 1);
    expect(debts.single.amount, 2.4);
  });
}
