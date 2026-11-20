import '../models/ledger_models.dart';

List<MemberDebt> calculateMemberDebts({
  required List<WalletSource> walletSources,
}) {
  final Map<(int, int), int> totals = <(int, int), int>{};
  for (final WalletSource source in walletSources) {
    final int? creditor = source.sourceMemberId;
    final int? debtor = source.payerMemberId;
    if (creditor == null || debtor == null || creditor == debtor) continue;
    totals.update(
      (creditor, debtor),
      (int value) => value + _minor(source.amount),
      ifAbsent: () => _minor(source.amount),
    );
  }
  return totals.entries
      .where((MapEntry<(int, int), int> item) => item.value > 0)
      .map(
        (MapEntry<(int, int), int> item) => MemberDebt(
          creditorMemberId: item.key.$1,
          debtorMemberId: item.key.$2,
          amount: item.value / 100,
        ),
      )
      .toList();
}

int _minor(double amount) => (amount * 100).round();
