import 'package:flutter/foundation.dart';

import '../models/ledger_models.dart';
import 'ledger_repository.dart';

class LedgerController extends ChangeNotifier {
  LedgerController(this._repository);

  final LedgerRepository _repository;

  final List<LedgerAccount> accounts = <LedgerAccount>[];
  final List<LedgerMember> members = <LedgerMember>[];
  final List<LedgerEntry> entries = <LedgerEntry>[];

  double monthlyBudget = 0;
  bool dailyReminderEnabled = false;
  int dailyReminderHour = 20;
  int dailyReminderMinute = 0;
  bool initialized = false;

  Future<void> initialize() async {
    final LedgerSnapshot snapshot = await _repository.load();
    accounts
      ..clear()
      ..addAll(snapshot.accounts);
    members
      ..clear()
      ..addAll(snapshot.members);
    entries
      ..clear()
      ..addAll(snapshot.entries);
    monthlyBudget = snapshot.monthlyBudget;
    dailyReminderEnabled = snapshot.dailyReminderEnabled;
    dailyReminderHour = snapshot.dailyReminderHour;
    dailyReminderMinute = snapshot.dailyReminderMinute;
    initialized = true;
    notifyListeners();
  }

  Future<Map<String, Object?>> exportBackup() => _repository.exportBackup();

  Future<void> replaceFromBackup(Map<String, Object?> backup) async {
    await _repository.replaceFromBackup(backup);
    await initialize();
  }

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

  Future<void> addEntry(LedgerEntry draft) async {
    final LedgerEntry saved = await _repository.addEntry(draft);
    entries.add(saved);
    if (saved.type == EntryType.transfer && saved.toAccountId != null) {
      accounts
          .firstWhere((LedgerAccount account) => account.id == saved.accountId)
          .balance -= saved
          .amount;
      accounts
              .firstWhere(
                (LedgerAccount account) => account.id == saved.toAccountId,
              )
              .balance +=
          saved.amount;
    } else if (saved.type == EntryType.expense) {
      accounts
          .firstWhere((LedgerAccount account) => account.id == saved.accountId)
          .balance -= saved
          .amount;
    } else {
      accounts
          .firstWhere((LedgerAccount account) => account.id == saved.accountId)
          .balance += saved
          .amount;
    }
    notifyListeners();
  }

  Future<void> setAccountArchived(int id, bool archived) async {
    await _repository.setAccountArchived(id, archived);
    accounts.firstWhere((LedgerAccount account) => account.id == id).archived =
        archived;
    notifyListeners();
  }

  Future<void> setMemberArchived(int id, bool archived) async {
    await _repository.setMemberArchived(id, archived);
    members.firstWhere((LedgerMember member) => member.id == id).archived =
        archived;
    notifyListeners();
  }

  Future<void> setMonthlyBudget(DateTime month, double amount) async {
    await _repository.setMonthlyBudget(month, amount);
    monthlyBudget = amount;
    notifyListeners();
  }

  Future<void> setDailyReminder({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    await _repository.setDailyReminder(
      enabled: enabled,
      hour: hour,
      minute: minute,
    );
    dailyReminderEnabled = enabled;
    dailyReminderHour = hour;
    dailyReminderMinute = minute;
    notifyListeners();
  }
}
