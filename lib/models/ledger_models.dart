enum EntryType { expense, income, transfer, adjustment }

enum AccountKind { asset, credit, loan }

enum EntryVisibility { all, private, selected, shared }

class AccountFund {
  const AccountFund({
    required this.accountId,
    required this.balance,
    this.memberId,
  });

  final int accountId;
  final int? memberId;
  final double balance;

  bool get shared => memberId == null;
}

class EntryFunding {
  const EntryFunding({
    required this.accountId,
    required this.amount,
    this.memberId,
  });

  final int accountId;
  final int? memberId;
  final double amount;
}

class MemberShare {
  const MemberShare({required this.memberId, required this.amount});

  final int memberId;
  final double amount;
}

class WalletSource {
  const WalletSource({
    required this.amount,
    this.sourceMemberId,
    this.payerMemberId,
  });

  final int? sourceMemberId;
  final int? payerMemberId;
  final double amount;

  bool get common => sourceMemberId == null;
}

class MemberDebt {
  const MemberDebt({
    required this.creditorMemberId,
    required this.debtorMemberId,
    required this.amount,
    this.transactionId,
  });

  final int creditorMemberId;
  final int debtorMemberId;
  final double amount;
  final int? transactionId;
}

class MemberDebtSettlement {
  const MemberDebtSettlement({
    required this.creditorMemberId,
    required this.debtorMemberId,
    required this.amount,
    required this.occurredAt,
    this.note = '',
  });

  final int creditorMemberId;
  final int debtorMemberId;
  final double amount;
  final DateTime occurredAt;
  final String note;
}

class EntryHistory {
  const EntryHistory({
    required this.action,
    required this.occurredAt,
    required this.summary,
    this.actorMemberId,
  });

  final String action;
  final DateTime occurredAt;
  final String summary;
  final int? actorMemberId;
}

class LedgerAccount {
  LedgerAccount({
    required this.id,
    required this.name,
    required this.balance,
    this.icon = 'wallet',
    this.kind = AccountKind.asset,
    this.creditLimit = 0,
    this.funds = const <AccountFund>[],
    this.archived = false,
  });

  final int id;
  final String name;
  double balance;
  String icon;
  AccountKind kind;
  double creditLimit;
  List<AccountFund> funds;
  bool archived;

  double get availableToSpend => switch (kind) {
    AccountKind.asset => balance,
    AccountKind.credit => balance + creditLimit,
    AccountKind.loan => 0,
  };
}

class LedgerMember {
  LedgerMember({
    required this.id,
    required this.name,
    required this.colorValue,
    this.archived = false,
  });

  final int id;
  final String name;
  final int colorValue;
  bool archived;
}

class LedgerEntry {
  LedgerEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.occurredAt,
    required this.note,
    required this.accountId,
    this.toAccountId,
    this.memberIds = const <int>[],
    this.memberShares = const <MemberShare>[],
    this.fundings = const <EntryFunding>[],
    this.outsideBudget = false,
    this.recordedByMemberId,
    this.visibility = EntryVisibility.all,
    this.visibleMemberIds = const <int>[],
    this.walletSources = const <WalletSource>[],
    this.recorderIds = const <int>[],
    this.recurring = false,
    this.recurringFrequency = 'month',
    this.adjustmentDelta = 0,
  });

  final int id;
  final EntryType type;
  final double amount;
  final String category;
  final DateTime occurredAt;
  final String note;
  final int accountId;
  final int? toAccountId;
  final List<int> memberIds;
  final List<MemberShare> memberShares;
  final List<EntryFunding> fundings;
  final bool outsideBudget;
  final int? recordedByMemberId;
  final EntryVisibility visibility;
  final List<int> visibleMemberIds;
  final List<WalletSource> walletSources;
  final List<int> recorderIds;
  final bool recurring;
  final String recurringFrequency;
  final double adjustmentDelta;

  List<int> get effectiveMemberIds => memberShares.isEmpty
      ? memberIds
      : memberShares.map((MemberShare share) => share.memberId).toList();
}

class LedgerCategory {
  const LedgerCategory({
    required this.name,
    required this.type,
    required this.icon,
    required this.custom,
    this.both = false,
    this.memberId,
  });

  final String name;
  final EntryType type;
  final String icon;
  final bool custom;
  final bool both;
  final int? memberId;
}

class RecurringRule {
  RecurringRule({
    required this.id,
    required this.name,
    required this.type,
    required this.amount,
    required this.frequency,
    required this.anchorDate,
    this.accountId,
    required this.category,
    required this.enabled,
  });

  final int id;
  String name;
  EntryType type;
  double amount;
  String frequency;
  DateTime anchorDate;
  int? accountId;
  String category;
  bool enabled;
}
