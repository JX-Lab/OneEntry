import '../models/ledger_models.dart';

List<MemberDebt> calculateMemberDebts({
  required double amount,
  required List<MemberShare> memberShares,
  required List<EntryFunding> fundings,
}) {
  final int amountMinor = _minor(amount);
  if (memberShares.isEmpty || amountMinor <= 0) return const <MemberDebt>[];

  final int sharedFunding = fundings
      .where((EntryFunding funding) => funding.memberId == null)
      .fold<int>(0, (int sum, EntryFunding item) => sum + _minor(item.amount));
  final int personalTotal = (amountMinor - sharedFunding).clamp(0, amountMinor);
  if (personalTotal == 0) return const <MemberDebt>[];

  final Map<int, int> burden = <int, int>{};
  int assigned = 0;
  for (int index = 0; index < memberShares.length; index++) {
    final MemberShare share = memberShares[index];
    final int target = index == memberShares.length - 1
        ? personalTotal - assigned
        : (_minor(share.amount) * personalTotal) ~/ amountMinor;
    burden[share.memberId] = target;
    assigned += target;
  }
  final Map<int, int> funded = <int, int>{};
  for (final EntryFunding funding in fundings) {
    final int? memberId = funding.memberId;
    if (memberId == null) continue;
    funded.update(
      memberId,
      (int value) => value + _minor(funding.amount),
      ifAbsent: () => _minor(funding.amount),
    );
  }

  final Set<int> memberIds = <int>{...burden.keys, ...funded.keys};
  final List<(int, int)> creditors = <(int, int)>[];
  final List<(int, int)> debtors = <(int, int)>[];
  for (final int memberId in memberIds) {
    final int net = (burden[memberId] ?? 0) - (funded[memberId] ?? 0);
    if (net > 0) debtors.add((memberId, net));
    if (net < 0) creditors.add((memberId, -net));
  }

  int creditorIndex = 0;
  int debtorIndex = 0;
  final List<MemberDebt> result = <MemberDebt>[];
  while (creditorIndex < creditors.length && debtorIndex < debtors.length) {
    final (int creditorId, int credit) = creditors[creditorIndex];
    final (int debtorId, int debt) = debtors[debtorIndex];
    final int settled = credit < debt ? credit : debt;
    if (settled > 0) {
      result.add(
        MemberDebt(
          creditorMemberId: creditorId,
          debtorMemberId: debtorId,
          amount: settled / 100,
        ),
      );
    }
    creditors[creditorIndex] = (creditorId, credit - settled);
    debtors[debtorIndex] = (debtorId, debt - settled);
    if (credit == settled) creditorIndex++;
    if (debt == settled) debtorIndex++;
  }
  return result;
}

int _minor(double amount) => (amount * 100).round();
