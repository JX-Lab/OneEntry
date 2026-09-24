enum EntryType { expense, income, transfer }

class LedgerAccount {
  LedgerAccount({
    required this.id,
    required this.name,
    required this.balance,
    this.archived = false,
  });

  final int id;
  final String name;
  double balance;
  bool archived;
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
    this.recurring = false,
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
  final bool recurring;
}
