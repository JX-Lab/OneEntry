import 'package:flutter/foundation.dart';

import '../models/ledger_models.dart';
import '../services/tonglv_importer.dart';
import 'ledger_repository.dart';

class LedgerController extends ChangeNotifier {
  LedgerController(this._repository);

  final LedgerRepository _repository;

  final List<LedgerAccount> accounts = <LedgerAccount>[];
  final List<LedgerMember> members = <LedgerMember>[];
  final List<MemberDebt> memberDebts = <MemberDebt>[];
  final List<MemberDebtSettlement> debtSettlements = <MemberDebtSettlement>[];
  final List<LedgerEntry> entries = <LedgerEntry>[];
  final List<RecurringRule> recurringRules = <RecurringRule>[];
  final List<LedgerCategory> categories = <LedgerCategory>[];
  final Map<String, double> categoryBudgets = <String, double>{};
  final Map<int, double> memberBudgets = <int, double>{};
  final Map<int, double> memberWallets = <int, double>{};
  double commonFund = 0;

  double monthlyBudget = 0;
  DateTime budgetMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool dailyReminderEnabled = false;
  int dailyReminderHour = 20;
  int dailyReminderMinute = 0;
  bool get multiEnabled => members.length > 1;
  int? currentMemberId;
  String splitMode = 'equal';
  String themeMode = 'system';
  String themeColor = 'green';
  bool voiceEnabled = true;
  double textScale = 1;
  bool highContrast = false;
  String colorVisionMode = 'standard';
  bool readerHints = true;
  bool haptics = true;
  DateTime? lastBackupAt;
  bool initialized = false;

  Future<void> initialize() async {
    final LedgerSnapshot snapshot = await _repository.load(
      budgetMonth: budgetMonth,
    );
    accounts
      ..clear()
      ..addAll(snapshot.accounts);
    members
      ..clear()
      ..addAll(snapshot.members);
    memberDebts
      ..clear()
      ..addAll(snapshot.memberDebts);
    debtSettlements
      ..clear()
      ..addAll(snapshot.debtSettlements);
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
    memberBudgets
      ..clear()
      ..addAll(snapshot.memberBudgets);
    memberWallets
      ..clear()
      ..addAll(snapshot.memberWallets);
    commonFund = snapshot.commonFund;
    monthlyBudget = snapshot.monthlyBudget;
    dailyReminderEnabled = snapshot.dailyReminderEnabled;
    dailyReminderHour = snapshot.dailyReminderHour;
    dailyReminderMinute = snapshot.dailyReminderMinute;
    final int? savedCurrent = snapshot.currentMemberId;
    currentMemberId =
        members.any(
          (LedgerMember member) =>
              !member.archived && member.id == savedCurrent,
        )
        ? savedCurrent
        : members
              .where((LedgerMember member) => !member.archived)
              .map((LedgerMember member) => member.id)
              .firstOrNull;
    splitMode = snapshot.splitMode;
    themeMode = snapshot.themeMode;
    themeColor = snapshot.themeColor;
    voiceEnabled = snapshot.voiceEnabled;
    textScale = snapshot.textScale;
    highContrast = snapshot.highContrast;
    colorVisionMode = snapshot.colorVisionMode;
    readerHints = snapshot.readerHints;
    haptics = snapshot.haptics;
    lastBackupAt = snapshot.lastBackupAt;
    initialized = true;
    notifyListeners();
  }

  Future<Map<String, Object?>> exportBackup() => _repository.exportBackup();

  Future<String> databasePath() => _repository.databasePath();

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
    return visibleEntries
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

  List<LedgerEntry> get visibleEntries => entries;

  double incomeForMonth(DateTime month) => entriesForMonth(month)
      .where((LedgerEntry entry) => entry.type == EntryType.income)
      .fold(0, (double sum, LedgerEntry entry) => sum + entry.amount);

  double expenseForMonth(DateTime month) => entriesForMonth(month)
      .where((LedgerEntry entry) => entry.type == EntryType.expense)
      .fold(0, (double sum, LedgerEntry entry) => sum + entry.amount);

  double budgetExpenseForMonth(DateTime month) => entriesForMonth(month)
      .where(
        (LedgerEntry entry) =>
            entry.type == EntryType.expense && !entry.outsideBudget,
      )
      .fold(0, (double sum, LedgerEntry entry) => sum + entry.amount);

  double outsideBudgetExpenseForMonth(DateTime month) => entriesForMonth(month)
      .where(
        (LedgerEntry entry) =>
            entry.type == EntryType.expense && entry.outsideBudget,
      )
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
    if (isBudgetMonth(month)) monthlyBudget = amount;
    notifyListeners();
  }

  Future<void> setMemberBudget(
    DateTime month,
    int memberId,
    double amount,
  ) async {
    await _repository.setMemberBudget(month, memberId, amount);
    if (isBudgetMonth(month)) {
      if (amount <= 0) {
        memberBudgets.remove(memberId);
      } else {
        memberBudgets[memberId] = amount;
      }
      notifyListeners();
    }
  }

  Future<void> setCurrentMember(int memberId) async {
    await setPreference('current_member_id', '$memberId');
  }

  Future<void> settleMemberDebt({
    required int creditorMemberId,
    required int debtorMemberId,
    required double amount,
    String note = '',
  }) async {
    await _repository.settleMemberDebt(
      creditorMemberId: creditorMemberId,
      debtorMemberId: debtorMemberId,
      amount: amount,
      note: note,
    );
    await initialize();
  }

  Future<void> setWalletBalances({
    required double commonFund,
    required Map<int, double> memberBalances,
  }) async {
    await _repository.setWalletBalances(
      commonFund: commonFund,
      memberBalances: memberBalances,
    );
    await initialize();
  }

  Future<List<EntryHistory>> entryHistory(LedgerEntry entry) =>
      _repository.entryHistory(entry.id);

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
    dailyReminderHour = hour.clamp(0, 23).toInt();
    dailyReminderMinute = minute.clamp(0, 59).toInt();
    notifyListeners();
  }

  bool isBudgetMonth(DateTime month) =>
      budgetMonth.year == month.year && budgetMonth.month == month.month;

  Future<void> loadBudgetForMonth(DateTime month) async {
    final DateTime normalized = DateTime(month.year, month.month);
    if (isBudgetMonth(normalized) && initialized) return;
    final result = await _repository.loadBudget(normalized);
    final Map<int, double> loadedMemberBudgets = await _repository
        .loadMemberBudgets(normalized);
    budgetMonth = normalized;
    monthlyBudget = result.total;
    categoryBudgets
      ..clear()
      ..addAll(result.categories);
    memberBudgets
      ..clear()
      ..addAll(loadedMemberBudgets);
    notifyListeners();
  }

  Future<bool> setCategoryBudget(
    DateTime month,
    String category,
    double amount,
  ) async {
    if (!isBudgetMonth(month)) await loadBudgetForMonth(month);
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
    String icon, {
    AccountKind kind = AccountKind.asset,
    double creditLimit = 0,
  }) async {
    await _repository.addAccount(
      name: name,
      openingBalance: openingBalance,
      icon: icon,
      kind: kind,
      creditLimit: creditLimit,
    );
    await initialize();
  }

  Future<void> updateAccount(
    int id,
    String name,
    double balance,
    String icon, {
    required AccountKind kind,
    double creditLimit = 0,
  }) async {
    await _repository.updateAccount(
      id,
      name: name,
      balance: balance,
      icon: icon,
      kind: kind,
      creditLimit: creditLimit,
    );
    await initialize();
  }

  Future<void> addCategory(
    String name,
    EntryType type,
    String icon, {
    int? memberId,
  }) async {
    await _repository.addCategory(
      name: name,
      type: type,
      icon: icon,
      memberId: memberId,
    );
    await initialize();
  }

  Future<void> archiveCategory(String name) async {
    await _repository.archiveCategory(name);
    await initialize();
  }

  Future<void> updateCategory(
    String originalName,
    String name,
    String icon, {
    int? memberId,
  }) async {
    await _repository.updateCategory(
      originalName: originalName,
      name: name,
      icon: icon,
      memberId: memberId,
    );
    await initialize();
  }

  Future<void> reorderCategories(List<String> names) async {
    await _repository.reorderCategories(names);
    await initialize();
  }

  Future<void> archiveCategories(List<String> names) async {
    await _repository.archiveCategories(names);
    await initialize();
  }

  Future<void> mergeCategories(
    List<String> sourceNames,
    String targetName,
  ) async {
    await _repository.mergeCategories(sourceNames, targetName);
    await initialize();
  }

  Future<void> batchUpdateEntries(
    List<LedgerEntry> selected, {
    required bool changeCategory,
    String? category,
    required bool changeAccount,
    int? accountId,
    required bool changePayers,
    List<int> payerIds = const <int>[],
    required bool changeRecorders,
    List<int> recorderIds = const <int>[],
    required bool changeNote,
    String note = '',
  }) async {
    await _repository.batchUpdateEntries(
      selected,
      changeCategory: changeCategory,
      category: category,
      changeAccount: changeAccount,
      accountId: accountId,
      changePayers: changePayers,
      payerIds: payerIds,
      changeRecorders: changeRecorders,
      recorderIds: recorderIds,
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

  Future<void> setPreference(String key, String value) async {
    await _repository.setPreference(key, value);
    switch (key) {
      case 'current_member_id':
        currentMemberId = int.tryParse(value);
        break;
      case 'split_mode':
        splitMode = value;
        break;
      case 'theme_mode':
        themeMode = value;
        break;
      case 'theme_color':
        themeColor = value;
        break;
      case 'voice_enabled':
        voiceEnabled = value != '0';
        break;
      case 'text_scale':
        textScale = double.tryParse(value) ?? 1;
        break;
      case 'high_contrast':
        highContrast = value == '1';
        break;
      case 'color_vision_mode':
        colorVisionMode = value;
        break;
      case 'reader_hints':
        readerHints = value == '1';
        break;
      case 'haptics':
        haptics = value == '1';
        break;
      case 'last_backup_at':
        final int? milliseconds = int.tryParse(value);
        lastBackupAt = milliseconds == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(milliseconds);
        break;
    }
    notifyListeners();
  }

  List<LedgerCategory> categoriesFor(EntryType type, {int? memberId}) =>
      categories
          .where(
            (LedgerCategory category) =>
                (category.type == type || category.both) &&
                (category.memberId == null || category.memberId == memberId),
          )
          .toList();
}
