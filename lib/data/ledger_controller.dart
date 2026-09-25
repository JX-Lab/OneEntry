import 'package:flutter/foundation.dart';

import '../models/ledger_models.dart';
import '../services/tonglv_importer.dart';
import 'ledger_repository.dart';

class LedgerController extends ChangeNotifier {
  LedgerController(this._repository);

  final LedgerRepository _repository;

  final List<LedgerAccount> accounts = <LedgerAccount>[];
  final List<LedgerMember> members = <LedgerMember>[];
  final List<LedgerEntry> entries = <LedgerEntry>[];
  final List<RecurringRule> recurringRules = <RecurringRule>[];
  final List<String> categories = <String>[];
  final Map<String, double> categoryBudgets = <String, double>{};

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
    recurringRules
      ..clear()
      ..addAll(snapshot.recurringRules);
    categories
      ..clear()
      ..addAll(snapshot.categories);
    categoryBudgets
      ..clear()
      ..addAll(snapshot.categoryBudgets);
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

  Future<({int imported, int skipped, int members, int accounts})> importTonglv(
    TonglvImportBundle bundle,
  ) async {
    final result = await _repository.importTonglv(bundle);
    await initialize();
    return result;
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
    await _repository.addEntry(draft);
    await initialize();
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

  Future<bool> setCategoryBudget(
    DateTime month,
    String category,
    double amount,
  ) async {
    final double existing = categoryBudgets[category] ?? 0;
    final double nextTotal =
        categoryBudgets.values.fold(0.0, (sum, value) => sum + value) -
        existing +
        amount;
    if (nextTotal > monthlyBudget) return false;
    await _repository.setCategoryBudget(month, category, amount);
    if (amount <= 0) {
      categoryBudgets.remove(category);
    } else {
      categoryBudgets[category] = amount;
    }
    notifyListeners();
    return true;
  }

  Future<void> addAccount(String name, double openingBalance) async {
    await _repository.addAccount(name: name, openingBalance: openingBalance);
    await initialize();
  }

  Future<void> updateAccount(int id, String name) async {
    await _repository.updateAccount(id, name: name);
    await initialize();
  }

  Future<void> addMember(String name, int colorValue) async {
    await _repository.addMember(name: name, colorValue: colorValue);
    await initialize();
  }

  Future<void> updateMember(int id, String name, int colorValue) async {
    await _repository.updateMember(id, name: name, colorValue: colorValue);
    await initialize();
  }

  Future<void> saveRecurringRule(RecurringRule rule) async {
    await _repository.saveRecurringRule(rule);
    await initialize();
  }

  Future<void> deleteRecurringRule(int id) async {
    await _repository.deleteRecurringRule(id);
    await initialize();
  }

  Future<void> clearAllData() async {
    await _repository.clearAllData();
    await initialize();
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
