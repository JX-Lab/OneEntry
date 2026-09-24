import 'package:flutter/foundation.dart';

import '../models/ledger_models.dart';

class LedgerController extends ChangeNotifier {
  LedgerController() {
    _seedPreviewData();
  }

  final List<LedgerAccount> accounts = <LedgerAccount>[
    LedgerAccount(id: 1, name: '现金', balance: 3280.50),
    LedgerAccount(id: 2, name: '支付宝', balance: 12560.20),
    LedgerAccount(id: 3, name: '微信', balance: 890),
  ];

  final List<LedgerMember> members = <LedgerMember>[
    LedgerMember(id: 1, name: '我', colorValue: 0xFF2E7CF6),
    LedgerMember(id: 2, name: '小明', colorValue: 0xFFF5A623),
    LedgerMember(id: 3, name: '小红', colorValue: 0xFFEB4E6B),
  ];

  final List<LedgerEntry> entries = <LedgerEntry>[];
  double monthlyBudget = 5000;
  int _nextEntryId = 1000;

  List<LedgerEntry> entriesForMonth(DateTime month) {
    return entries
        .where(
          (LedgerEntry entry) =>
              entry.occurredAt.year == month.year &&
              entry.occurredAt.month == month.month,
        )
        .toList()
      ..sort(
        (LedgerEntry a, LedgerEntry b) => b.occurredAt.compareTo(a.occurredAt),
      );
  }

  double incomeForMonth(DateTime month) => entriesForMonth(month)
      .where((LedgerEntry entry) => entry.type == EntryType.income)
      .fold(0, (double sum, LedgerEntry entry) => sum + entry.amount);

  double expenseForMonth(DateTime month) => entriesForMonth(month)
      .where((LedgerEntry entry) => entry.type == EntryType.expense)
      .fold(0, (double sum, LedgerEntry entry) => sum + entry.amount);

  void addEntry(LedgerEntry draft) {
    final LedgerEntry entry = LedgerEntry(
      id: _nextEntryId++,
      type: draft.type,
      amount: draft.amount,
      category: draft.category,
      occurredAt: draft.occurredAt,
      note: draft.note,
      accountId: draft.accountId,
      toAccountId: draft.toAccountId,
      memberIds: draft.memberIds,
      recurring: draft.recurring,
    );
    entries.add(entry);
    final LedgerAccount from = accounts.firstWhere(
      (LedgerAccount account) => account.id == entry.accountId,
    );
    if (entry.type == EntryType.transfer && entry.toAccountId != null) {
      from.balance -= entry.amount;
      accounts
              .firstWhere(
                (LedgerAccount account) => account.id == entry.toAccountId,
              )
              .balance +=
          entry.amount;
    } else if (entry.type == EntryType.expense) {
      from.balance -= entry.amount;
    } else {
      from.balance += entry.amount;
    }
    notifyListeners();
  }

  void _seedPreviewData() {
    final DateTime now = DateTime.now();
    entries.addAll(<LedgerEntry>[
      LedgerEntry(
        id: _nextEntryId++,
        type: EntryType.expense,
        amount: 268,
        category: '餐饮',
        occurredAt: DateTime(now.year, now.month, now.day, 19, 30),
        note: '和朋友吃饭',
        accountId: 2,
        memberIds: const <int>[1, 2],
      ),
      LedgerEntry(
        id: _nextEntryId++,
        type: EntryType.expense,
        amount: 56.5,
        category: '交通',
        occurredAt: DateTime(now.year, now.month, now.day - 1, 9, 15),
        note: '打车',
        accountId: 3,
        memberIds: const <int>[1],
      ),
      LedgerEntry(
        id: _nextEntryId++,
        type: EntryType.income,
        amount: 12800,
        category: '工资',
        occurredAt: DateTime(now.year, now.month, 8, 8),
        note: '本月工资',
        accountId: 2,
        memberIds: const <int>[1],
      ),
    ]);
  }
}
