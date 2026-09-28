enum EntryType { expense, income, transfer, adjustment }

class LedgerAccount {
  LedgerAccount({
    required this.id,
    required this.name,
    required this.balance,
    this.icon = 'wallet',
    this.archived = false,
  });

  final int id;
  final String name;
  double balance;
  String icon;
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
  final bool recurring;
  final String recurringFrequency;
  final double adjustmentDelta;
}

class LedgerCategory {
  const LedgerCategory({
    required this.name,
    required this.type,
    required this.icon,
    required this.custom,
    this.both = false,
  });

  final String name;
  final EntryType type;
  final String icon;
  final bool custom;
  final bool both;
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
