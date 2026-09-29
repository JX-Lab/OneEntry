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
  final List<LedgerCategory> categories = <LedgerCategory>[];
  final Map<String, double> categoryBudgets = <String, double>{};

  double monthlyBudget = 0;
  bool dailyReminderEnabled = false;
  int dailyReminderHour = 20;
  int dailyReminderMinute = 0;
  bool multiEnabled = true;
  String splitMode = 'equal';
  String themeMode = 'system';
  double textScale = 1;
  bool highContrast = false;
  bool readerHints = true;
  bool haptics = true;
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
    multiEnabled = snapshot.multiEnabled;
    splitMode = snapshot.splitMode;
    themeMode = snapshot.themeMode;
    textScale = snapshot.textScale;
    highContrast = snapshot.highContrast;
    readerHints = snapshot.readerHints;
    haptics = snapshot.haptics;
    initialized = true;
    notifyListeners();
  }

  Future<Map<String, Object?>> exportBackup() => _repository.exportBackup();

  Future<void> replaceFromBackup(Map<String, Object?> backup) async {
    await _repository.replaceFromBackup(backup);
    await initialize();
  }

  Future<({int imported, int skipped, int members, int accounts})> importTonglv(
    TonglvImportBundle bundle, {
    String sourceApp = 'tonglv',
    String sourceLabel = '同旅迁移备份',
  }) async {
    final result = await _repository.importTonglv(
      bundle,
      sourceApp: sourceApp,
      sourceLabel: sourceLabel,
    );
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

  Future<void> updateEntry(LedgerEntry previous, LedgerEntry next) async {
    await _repository.updateEntry(previous, next);
    await initialize();
  }

  Future<void> deleteEntry(LedgerEntry entry) async {
    await _repository.deleteEntry(entry);
    await initialize();
  }

  Future<void> setAccountArchived(int id, bool archived) async {
    await _repository.setAccountArchived(id, archived);
    accounts.firstWhere((LedgerAccount account) => account.id == id).archived =
        archived;
    notifyListeners();
  }

  Future<void> reorderAccounts(List<int> ids) async {
    await _repository.reorderAccounts(ids);
    await initialize();
  }

  Future<void> deleteAccount(int id) async {
    await _repository.deleteAccount(id);
    await initialize();
  }

  Future<void> setMemberArchived(int id, bool archived) async {
    await _repository.setMemberArchived(id, archived);
    members.firstWhere((LedgerMember member) => member.id == id).archived =
        archived;
    notifyListeners();
  }

  Future<void> reorderMembers(List<int> ids) async {
    await _repository.reorderMembers(ids);
    await initialize();
  }

  Future<void> deleteMember(int id) async {
    await _repository.deleteMember(id);
    await initialize();
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

  Future<void> addAccount(
    String name,
    double openingBalance,
    String icon,
  ) async {
    await _repository.addAccount(
      name: name,
      openingBalance: openingBalance,
      icon: icon,
    );
    await initialize();
  }

  Future<void> updateAccount(
    int id,
    String name,
    double balance,
    String icon,
  ) async {
    await _repository.updateAccount(
      id,
      name: name,
      balance: balance,
      icon: icon,
    );
    await initialize();
  }

  Future<void> addCategory(String name, EntryType type, String icon) async {
    await _repository.addCategory(name: name, type: type, icon: icon);
    await initialize();
  }

  Future<void> archiveCategory(String name) async {
    await _repository.archiveCategory(name);
    await initialize();
  }

  Future<void> updateCategory(
    String originalName,
    String name,
    String icon,
  ) async {
    await _repository.updateCategory(
      originalName: originalName,
      name: name,
      icon: icon,
    );
    await initialize();
  }

  Future<void> batchUpdateEntries(
    List<LedgerEntry> selected, {
    required bool changeAccount,
    int? accountId,
    required bool changeMembers,
    List<int> memberIds = const <int>[],
    required bool changeNote,
    String note = '',
  }) async {
    await _repository.batchUpdateEntries(
      selected,
      changeAccount: changeAccount,
      accountId: accountId,
      changeMembers: changeMembers,
      memberIds: memberIds,
      changeNote: changeNote,
      note: note,
    );
    await initialize();
  }

  Future<void> deleteEntries(List<LedgerEntry> selected) async {
    await _repository.deleteEntries(selected);
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

  Future<void> setPreference(String key, String value) async {
    await _repository.setPreference(key, value);
    switch (key) {
      case 'multi_enabled':
        multiEnabled = value == '1';
        break;
      case 'split_mode':
        splitMode = value;
        break;
      case 'theme_mode':
        themeMode = value;
        break;
      case 'text_scale':
        textScale = double.tryParse(value) ?? 1;
        break;
      case 'high_contrast':
        highContrast = value == '1';
        break;
      case 'reader_hints':
        readerHints = value == '1';
        break;
      case 'haptics':
        haptics = value == '1';
        break;
    }
    notifyListeners();
  }

  List<LedgerCategory> categoriesFor(EntryType type) => categories
      .where(
        (LedgerCategory category) => category.type == type || category.both,
      )
      .toList();
}
