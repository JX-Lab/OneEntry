import 'dart:math' as math;

import 'package:sqflite/sqflite.dart';

import '../models/ledger_models.dart';
import '../services/tonglv_importer.dart';
import '../utils/member_debt_calculator.dart';
import 'app_database.dart';

class LedgerSnapshot {
  const LedgerSnapshot({
    required this.accounts,
    required this.members,
    required this.memberDebts,
    required this.debtSettlements,
    required this.entries,
    required this.monthlyBudget,
    required this.dailyReminderEnabled,
    required this.dailyReminderHour,
    required this.dailyReminderMinute,
    required this.categoryBudgets,
    required this.memberBudgets,
    required this.recurringRules,
    required this.categories,
    required this.multiEnabled,
    required this.currentMemberId,
    required this.memberWallets,
    required this.commonFund,
    required this.splitMode,
    required this.themeMode,
    required this.themeColor,
    required this.voiceEnabled,
    required this.textScale,
    required this.highContrast,
    required this.colorVisionMode,
    required this.readerHints,
    required this.haptics,
    required this.lastBackupAt,
  });

  final List<LedgerAccount> accounts;
  final List<LedgerMember> members;
  final List<MemberDebt> memberDebts;
  final List<MemberDebtSettlement> debtSettlements;
  final List<LedgerEntry> entries;
  final double monthlyBudget;
  final bool dailyReminderEnabled;
  final int dailyReminderHour;
  final int dailyReminderMinute;
  final Map<String, double> categoryBudgets;
  final Map<int, double> memberBudgets;
  final List<RecurringRule> recurringRules;
  final List<LedgerCategory> categories;
  final bool multiEnabled;
  final int? currentMemberId;
  final Map<int, double> memberWallets;
  final double commonFund;
  final String splitMode;
  final String themeMode;
  final String themeColor;
  final bool voiceEnabled;
  final double textScale;
  final bool highContrast;
  final String colorVisionMode;
  final bool readerHints;
  final bool haptics;
  final DateTime? lastBackupAt;
}

class LedgerRepository {
  LedgerRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  static const List<String> backupTables = <String>[
    'accounts',
    'members',
    'categories',
    'recurring_rules',
    'transactions',
    'transaction_members',
    'transaction_fundings',
    'account_funds',
    'member_debts',
    'transaction_visible_members',
    'member_budgets',
    'member_debt_settlements',
    'entry_history',
    'member_wallets',
    'wallet_state',
    'transaction_wallet_sources',
    'transaction_recorders',
    'budgets',
    'settings',
    'import_jobs',
  ];

  Future<LedgerSnapshot> load({DateTime? budgetMonth}) async {
    final Database db = await _appDatabase.database;
    final List<LedgerAccount> accounts = (await db.query(
      'accounts',
      orderBy: 'sort_order, id',
    )).map(_accountFromRow).toList();
    final Map<int, LedgerAccount> accountById = <int, LedgerAccount>{
      for (final LedgerAccount account in accounts) account.id: account,
    };
    for (final Map<String, Object?> row in await db.query(
      'account_funds',
      orderBy: 'account_id, member_id',
    )) {
      final int accountId = row['account_id'] as int;
      final LedgerAccount? account = accountById[accountId];
      if (account == null) continue;
      account.funds = <AccountFund>[
        ...account.funds,
        AccountFund(
          accountId: accountId,
          memberId: row['member_id'] as int?,
          balance: (row['balance_minor'] as int) / 100,
        ),
      ];
    }
    final List<LedgerMember> members = (await db.query(
      'members',
      orderBy: 'sort_order, id',
    )).map(_memberFromRow).toList();
    final List<Map<String, Object?>> transactionRows = await db.rawQuery('''
      SELECT t.*, c.name AS category_name, r.frequency AS recurring_frequency
      FROM transactions t
      LEFT JOIN categories c ON c.id = t.category_id
      LEFT JOIN recurring_rules r ON r.id = t.recurring_rule_id
      ORDER BY t.occurred_at DESC, t.id DESC
    ''');
    final List<Map<String, Object?>> memberRows = await db.query(
      'transaction_members',
      orderBy: 'transaction_id, member_id',
    );
    final Map<int, List<int>> transactionMembers = <int, List<int>>{};
    final Map<int, List<MemberShare>> transactionMemberShares =
        <int, List<MemberShare>>{};
    for (final Map<String, Object?> row in memberRows) {
      final int transactionId = row['transaction_id'] as int;
      final int memberId = row['member_id'] as int;
      transactionMembers
          .putIfAbsent(transactionId, () => <int>[])
          .add(memberId);
      transactionMemberShares
          .putIfAbsent(transactionId, () => <MemberShare>[])
          .add(
            MemberShare(
              memberId: memberId,
              amount: ((row['share_minor'] as int?) ?? 0) / 100,
            ),
          );
    }
    final Map<int, List<EntryFunding>> transactionFundings =
        <int, List<EntryFunding>>{};
    for (final Map<String, Object?> row in await db.query(
      'transaction_fundings',
      orderBy: 'transaction_id, sort_order, id',
    )) {
      transactionFundings
          .putIfAbsent(row['transaction_id'] as int, () => <EntryFunding>[])
          .add(
            EntryFunding(
              accountId: row['account_id'] as int,
              memberId: row['member_id'] as int?,
              amount: (row['amount_minor'] as int) / 100,
            ),
          );
    }
    final Map<int, List<WalletSource>> transactionWalletSources =
        <int, List<WalletSource>>{};
    for (final Map<String, Object?> row in await db.query(
      'transaction_wallet_sources',
      orderBy: 'transaction_id, sort_order, id',
    )) {
      transactionWalletSources
          .putIfAbsent(row['transaction_id'] as int, () => <WalletSource>[])
          .add(
            WalletSource(
              sourceMemberId: row['source_member_id'] as int?,
              payerMemberId: row['payer_member_id'] as int?,
              amount: (row['amount_minor'] as int) / 100,
            ),
          );
    }
    final Map<int, List<int>> transactionRecorders = <int, List<int>>{};
    for (final Map<String, Object?> row in await db.query(
      'transaction_recorders',
      orderBy: 'transaction_id, member_id',
    )) {
      transactionRecorders
          .putIfAbsent(row['transaction_id'] as int, () => <int>[])
          .add(row['member_id'] as int);
    }
    final Map<int, List<int>> transactionVisibleMembers = <int, List<int>>{};
    for (final Map<String, Object?> row in await db.query(
      'transaction_visible_members',
      orderBy: 'transaction_id, member_id',
    )) {
      transactionVisibleMembers
          .putIfAbsent(row['transaction_id'] as int, () => <int>[])
          .add(row['member_id'] as int);
    }
    final List<LedgerEntry> entries = transactionRows
        .map(
          (Map<String, Object?> row) => _entryFromRow(
            row,
            transactionMembers[row['id'] as int] ?? const <int>[],
            transactionMemberShares[row['id'] as int] ?? const <MemberShare>[],
            transactionFundings[row['id'] as int] ?? const <EntryFunding>[],
            transactionVisibleMembers[row['id'] as int] ?? const <int>[],
            transactionWalletSources[row['id'] as int] ??
                const <WalletSource>[],
            transactionRecorders[row['id'] as int] ?? const <int>[],
          ),
        )
        .toList();
    final List<MemberDebtSettlement> debtSettlements =
        (await db.query('member_debt_settlements', orderBy: 'occurred_at, id'))
            .map(
              (Map<String, Object?> row) => MemberDebtSettlement(
                creditorMemberId: row['creditor_member_id'] as int,
                debtorMemberId: row['debtor_member_id'] as int,
                amount: (row['amount_minor'] as int) / 100,
                occurredAt: DateTime.fromMillisecondsSinceEpoch(
                  row['occurred_at'] as int,
                ),
                note: row['note'] as String? ?? '',
              ),
            )
            .toList();
    final List<MemberDebt> memberDebts =
        (await db.query('member_debts', orderBy: 'id'))
            .map(
              (Map<String, Object?> row) => MemberDebt(
                transactionId: row['transaction_id'] as int,
                creditorMemberId: row['creditor_member_id'] as int,
                debtorMemberId: row['debtor_member_id'] as int,
                amount: (row['amount_minor'] as int) / 100,
              ),
            )
            .toList();
    final DateTime now = budgetMonth ?? DateTime.now();
    final String period = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final List<Map<String, Object?>> budgetRows = await db.query(
      'budgets',
      columns: <String>['amount_minor'],
      where: 'period = ? AND category_id IS NULL',
      whereArgs: <Object?>[period],
      limit: 1,
    );
    final double budget = budgetRows.isEmpty
        ? 0
        : (budgetRows.first['amount_minor'] as int) / 100;
    final Map<String, String> settings = <String, String>{
      for (final Map<String, Object?> row in await db.query('settings'))
        row['key'] as String: row['value'] as String,
    };
    final Map<int, double> memberWallets = <int, double>{
      for (final Map<String, Object?> row in await db.query('member_wallets'))
        row['member_id'] as int: (row['balance_minor'] as int) / 100,
    };
    final List<Map<String, Object?>> walletRows = await db.query(
      'wallet_state',
      columns: <String>['common_balance_minor'],
      where: 'id = 1',
      limit: 1,
    );
    final double commonFund = walletRows.isEmpty
        ? 0
        : (walletRows.first['common_balance_minor'] as int) / 100;
    final List<Map<String, Object?>> categoryBudgetRows = await db.rawQuery(
      '''
      SELECT c.name, b.amount_minor
      FROM budgets b
      JOIN categories c ON c.id = b.category_id
      WHERE b.period = ?
      ORDER BY c.sort_order, c.id
      ''',
      <Object?>[period],
    );
    final Map<String, double> categoryBudgets = <String, double>{
      for (final Map<String, Object?> row in categoryBudgetRows)
        row['name'] as String: (row['amount_minor'] as int) / 100,
    };
    final Map<int, double> memberBudgets = <int, double>{
      for (final Map<String, Object?> row in await db.query(
        'member_budgets',
        columns: <String>['member_id', 'amount_minor'],
        where: 'period = ?',
        whereArgs: <Object?>[period],
      ))
        row['member_id'] as int: (row['amount_minor'] as int) / 100,
    };
    final List<Map<String, Object?>> categoryRows = await db.query(
      'categories',
      columns: <String>['uuid', 'name', 'type', 'icon', 'member_id'],
      where: 'archived_at IS NULL',
      orderBy: 'sort_order, id',
    );
    final List<Map<String, Object?>> ruleRows = await db.rawQuery('''
      SELECT r.*, c.name AS category_name
      FROM recurring_rules r
      LEFT JOIN categories c ON c.id = r.category_id
      ORDER BY r.enabled DESC, r.id DESC
    ''');
    return LedgerSnapshot(
      accounts: accounts,
      members: members,
      memberDebts: memberDebts,
      debtSettlements: debtSettlements,
      entries: entries,
      monthlyBudget: budget,
      dailyReminderEnabled: settings['daily_reminder_enabled'] == '1',
      dailyReminderHour:
          int.tryParse(settings['daily_reminder_hour'] ?? '') ?? 20,
      dailyReminderMinute:
          int.tryParse(settings['daily_reminder_minute'] ?? '') ?? 0,
      categoryBudgets: categoryBudgets,
      memberBudgets: memberBudgets,
      recurringRules: ruleRows.map(_ruleFromRow).toList(),
      categories: categoryRows.map(_categoryFromRow).toList(),
      multiEnabled: settings['multi_enabled'] != '0',
      currentMemberId: int.tryParse(settings['current_member_id'] ?? ''),
      memberWallets: memberWallets,
      commonFund: commonFund,
      splitMode: settings['split_mode'] ?? 'equal',
      themeMode: settings['theme_mode'] ?? 'system',
      themeColor: settings['theme_color'] ?? 'green',
      voiceEnabled: settings['voice_enabled'] != '0',
      textScale: double.tryParse(settings['text_scale'] ?? '') ?? 1,
      highContrast: settings['high_contrast'] == '1',
      colorVisionMode: settings['color_vision_mode'] ?? 'standard',
      readerHints: settings['reader_hints'] != '0',
      haptics: settings['haptics'] != '0',
      lastBackupAt: _dateTimeFromMilliseconds(settings['last_backup_at']),
    );
  }

  Future<({double total, Map<String, double> categories})> loadBudget(
    DateTime month,
  ) async {
    final Database db = await _appDatabase.database;
    final String period =
        '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final List<Map<String, Object?>> totalRows = await db.query(
      'budgets',
      columns: <String>['amount_minor'],
      where: 'period = ? AND category_id IS NULL',
      whereArgs: <Object?>[period],
      limit: 1,
    );
    final List<Map<String, Object?>> categoryRows = await db.rawQuery(
      '''
      SELECT c.name, b.amount_minor
      FROM budgets b
      JOIN categories c ON c.id = b.category_id
      WHERE b.period = ?
      ORDER BY c.sort_order, c.id
      ''',
      <Object?>[period],
    );
    return (
      total: totalRows.isEmpty
          ? 0.0
          : (totalRows.first['amount_minor'] as int) / 100,
      categories: <String, double>{
        for (final Map<String, Object?> row in categoryRows)
          row['name'] as String: (row['amount_minor'] as int) / 100,
      },
    );
  }

  Future<Map<int, double>> loadMemberBudgets(DateTime month) async {
    final Database db = await _appDatabase.database;
    final String period =
        '${month.year}-${month.month.toString().padLeft(2, '0')}';
    return <int, double>{
      for (final Map<String, Object?> row in await db.query(
        'member_budgets',
        columns: <String>['member_id', 'amount_minor'],
        where: 'period = ?',
        whereArgs: <Object?>[period],
      ))
        row['member_id'] as int: (row['amount_minor'] as int) / 100,
    };
  }

  Future<void> setMemberBudget(
    DateTime month,
    int memberId,
    double amount,
  ) async {
    final Database db = await _appDatabase.database;
    final String period =
        '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final int now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((Transaction txn) async {
      await txn.delete(
        'member_budgets',
        where: 'period = ? AND member_id = ?',
        whereArgs: <Object?>[period, memberId],
      );
      if (amount > 0) {
        await txn.insert('member_budgets', <String, Object?>{
          'period': period,
          'member_id': memberId,
          'amount_minor': _minor(amount),
          'created_at': now,
          'updated_at': now,
        });
      }
    });
  }

  Future<void> settleMemberDebt({
    required int creditorMemberId,
    required int debtorMemberId,
    required double amount,
    String note = '',
  }) async {
    if (amount <= 0) throw StateError('结算金额必须大于 0');
    final Database db = await _appDatabase.database;
    final int now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('member_debt_settlements', <String, Object?>{
      'creditor_member_id': creditorMemberId,
      'debtor_member_id': debtorMemberId,
      'amount_minor': _minor(amount),
      'occurred_at': now,
      'note': note,
      'created_at': now,
    });
  }

  Future<void> setWalletBalances({
    required double commonFund,
    required Map<int, double> memberBalances,
  }) async {
    final Database db = await _appDatabase.database;
    await db.transaction((Transaction txn) async {
      final int currentCommon =
          Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT common_balance_minor FROM wallet_state WHERE id = 1',
            ),
          ) ??
          0;
      final int currentMembers =
          Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COALESCE(SUM(balance_minor), 0) FROM member_wallets',
            ),
          ) ??
          0;
      final int nextCommon = _minor(commonFund);
      final int nextMembers = memberBalances.values.fold<int>(
        0,
        (int sum, double amount) => sum + _minor(amount),
      );
      if (nextCommon < 0 || memberBalances.values.any((value) => value < 0)) {
        throw StateError('荷包金额不能为负数');
      }
      if (currentCommon + currentMembers != nextCommon + nextMembers) {
        throw StateError('荷包与公共资金合计必须保持不变');
      }
      final int now = DateTime.now().millisecondsSinceEpoch;
      await txn.update('wallet_state', <String, Object?>{
        'common_balance_minor': nextCommon,
        'updated_at': now,
      }, where: 'id = 1');
      for (final MapEntry<int, double> item in memberBalances.entries) {
        await txn.insert('member_wallets', <String, Object?>{
          'member_id': item.key,
          'balance_minor': _minor(item.value),
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<EntryHistory>> entryHistory(int transactionId) async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> transactionRows = await db.query(
      'transactions',
      columns: <String>['uuid'],
      where: 'id = ?',
      whereArgs: <Object?>[transactionId],
      limit: 1,
    );
    if (transactionRows.isEmpty) return const <EntryHistory>[];
    final String uuid = transactionRows.first['uuid'] as String;
    return (await db.query(
          'entry_history',
          where: 'transaction_uuid = ?',
          whereArgs: <Object?>[uuid],
          orderBy: 'occurred_at DESC, id DESC',
        ))
        .map(
          (Map<String, Object?> row) => EntryHistory(
            action: row['action'] as String,
            occurredAt: DateTime.fromMillisecondsSinceEpoch(
              row['occurred_at'] as int,
            ),
            summary: row['summary'] as String? ?? '',
            actorMemberId: row['actor_member_id'] as int?,
          ),
        )
        .toList();
  }

  Future<LedgerEntry> addEntry(LedgerEntry draft) async {
    final Database db = await _appDatabase.database;
    final int now = DateTime.now().millisecondsSinceEpoch;
    return db.transaction((Transaction txn) async {
      final List<EntryFunding> fundings = await _resolveFundings(txn, draft);
      final List<MemberShare> memberShares = _resolvedMemberShares(draft);
      final List<WalletSource> walletSources = _resolvedWalletSources(
        draft,
        memberShares,
      );
      final int? categoryId = draft.type == EntryType.transfer
          ? null
          : await _categoryId(txn, draft.category, now, type: draft.type);
      int? recurringRuleId;
      if (draft.recurring && draft.type != EntryType.transfer) {
        recurringRuleId = await txn.insert('recurring_rules', <String, Object?>{
          'uuid': _uuid('rule', now),
          'name': draft.note.isEmpty ? draft.category : draft.note,
          'type': draft.type.name,
          'amount_minor': _minor(draft.amount),
          'account_id': draft.accountId,
          'category_id': categoryId,
          'frequency': draft.recurringFrequency,
          'anchor_date': _dateKey(draft.occurredAt),
          'reminder_hour': draft.occurredAt.hour,
          'reminder_minute': draft.occurredAt.minute,
          'created_at': now,
          'updated_at': now,
        });
      }
      final String transactionUuid = _uuid('transaction', now);
      final int transactionId = await txn
          .insert('transactions', <String, Object?>{
            'uuid': transactionUuid,
            'type': draft.type.name,
            'amount_minor': _minor(draft.amount),
            'account_id': draft.accountId,
            'to_account_id': draft.type == EntryType.transfer
                ? draft.toAccountId
                : null,
            'category_id': categoryId,
            'occurred_at': draft.occurredAt.millisecondsSinceEpoch,
            'local_date': _dateKey(draft.occurredAt),
            'timezone': draft.occurredAt.timeZoneName,
            'note': draft.note,
            'outside_budget': draft.outsideBudget ? 1 : 0,
            'recorded_by_member_id': draft.recordedByMemberId,
            'visibility': draft.visibility.name,
            'recurring_rule_id': recurringRuleId,
            'created_at': now,
            'updated_at': now,
          });
      await _insertMembers(
        txn,
        transactionId,
        draft.memberIds,
        _minor(draft.amount),
        shares: memberShares,
      );
      await _insertFundings(txn, transactionId, fundings);
      await _applyBalance(txn, draft, 1, fundings: fundings);
      await _insertWalletSources(txn, transactionId, walletSources);
      await _insertRecorders(txn, transactionId, draft.recorderIds);
      await _applyWalletBalances(txn, draft.type, walletSources, 1);
      await _insertDebts(txn, transactionId, draft.type, walletSources);
      await _insertVisibleMembers(txn, transactionId, draft.visibleMemberIds);
      await _insertHistory(
        txn,
        transactionId: transactionId,
        transactionUuid: transactionUuid,
        action: 'created',
        actorMemberId: draft.recordedByMemberId,
        summary: '创建账目 ¥${draft.amount.toStringAsFixed(2)}',
        occurredAt: now,
      );
      return LedgerEntry(
        id: transactionId,
        type: draft.type,
        amount: draft.amount,
        category: draft.category,
        occurredAt: draft.occurredAt,
        note: draft.note,
        accountId: draft.accountId,
        toAccountId: draft.toAccountId,
        memberIds: List<int>.from(draft.memberIds),
        memberShares: memberShares,
        fundings: fundings,
        outsideBudget: draft.outsideBudget,
        recordedByMemberId: draft.recordedByMemberId,
        visibility: draft.visibility,
        visibleMemberIds: List<int>.from(draft.visibleMemberIds),
        walletSources: walletSources,
        recorderIds: List<int>.from(draft.recorderIds),
        recurring: draft.recurring,
        recurringFrequency: draft.recurringFrequency,
      );
    });
  }

  Future<void> updateEntry(LedgerEntry previous, LedgerEntry next) async {
    final Database db = await _appDatabase.database;
    final int now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((Transaction txn) async {
      await _applyBalance(txn, previous, -1);
      await _applyWalletBalances(
        txn,
        previous.type,
        previous.walletSources,
        -1,
      );
      final List<EntryFunding> fundings = await _resolveFundings(txn, next);
      final List<MemberShare> memberShares = _resolvedMemberShares(next);
      final List<WalletSource> walletSources = _resolvedWalletSources(
        next,
        memberShares,
      );
      final int? categoryId = next.type == EntryType.transfer
          ? null
          : await _categoryId(txn, next.category, now, type: next.type);
      await txn.update(
        'transactions',
        <String, Object?>{
          'type': next.type.name,
          'amount_minor': _minor(next.amount),
          'account_id': next.accountId,
          'to_account_id': next.type == EntryType.transfer
              ? next.toAccountId
              : null,
          'category_id': categoryId,
          'occurred_at': next.occurredAt.millisecondsSinceEpoch,
          'local_date': _dateKey(next.occurredAt),
          'timezone': next.occurredAt.timeZoneName,
          'note': next.note,
          'outside_budget': next.outsideBudget ? 1 : 0,
          'recorded_by_member_id': next.recordedByMemberId,
          'visibility': next.visibility.name,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: <Object?>[previous.id],
      );
      await txn.delete(
        'transaction_members',
        where: 'transaction_id = ?',
        whereArgs: <Object?>[previous.id],
      );
      await txn.delete(
        'transaction_fundings',
        where: 'transaction_id = ?',
        whereArgs: <Object?>[previous.id],
      );
      await txn.delete(
        'member_debts',
        where: 'transaction_id = ?',
        whereArgs: <Object?>[previous.id],
      );
      await txn.delete(
        'transaction_visible_members',
        where: 'transaction_id = ?',
        whereArgs: <Object?>[previous.id],
      );
      await txn.delete(
        'transaction_wallet_sources',
        where: 'transaction_id = ?',
        whereArgs: <Object?>[previous.id],
      );
      await txn.delete(
        'transaction_recorders',
        where: 'transaction_id = ?',
        whereArgs: <Object?>[previous.id],
      );
      await _insertMembers(
        txn,
        previous.id,
        next.memberIds,
        _minor(next.amount),
        shares: memberShares,
      );
      await _insertFundings(txn, previous.id, fundings);
      await _applyBalance(txn, next, 1, fundings: fundings);
      await _insertWalletSources(txn, previous.id, walletSources);
      await _insertRecorders(txn, previous.id, next.recorderIds);
      await _applyWalletBalances(txn, next.type, walletSources, 1);
      await _insertDebts(txn, previous.id, next.type, walletSources);
      await _insertVisibleMembers(txn, previous.id, next.visibleMemberIds);
      final List<Map<String, Object?>> uuidRows = await txn.query(
        'transactions',
        columns: <String>['uuid'],
        where: 'id = ?',
        whereArgs: <Object?>[previous.id],
        limit: 1,
      );
      await _insertHistory(
        txn,
        transactionId: previous.id,
        transactionUuid: uuidRows.first['uuid'] as String,
        action: 'updated',
        actorMemberId: next.recordedByMemberId,
        summary: _entryUpdateSummary(previous, next),
        occurredAt: now,
      );
    });
  }

  Future<void> deleteEntry(LedgerEntry entry) async {
    final Database db = await _appDatabase.database;
    await db.transaction((Transaction txn) async {
      await _applyBalance(txn, entry, -1);
      await _applyWalletBalances(txn, entry.type, entry.walletSources, -1);
      final List<Map<String, Object?>> rows = await txn.query(
        'transactions',
        columns: <String>['uuid'],
        where: 'id = ?',
        whereArgs: <Object?>[entry.id],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        await _insertHistory(
          txn,
          transactionId: entry.id,
          transactionUuid: rows.first['uuid'] as String,
          action: 'deleted',
          actorMemberId: entry.recordedByMemberId,
          summary: '删除账目 ¥${entry.amount.toStringAsFixed(2)}',
          occurredAt: DateTime.now().millisecondsSinceEpoch,
        );
      }
      await txn.delete(
        'transactions',
        where: 'id = ?',
        whereArgs: <Object?>[entry.id],
      );
    });
  }

  Future<void> setAccountArchived(int id, bool archived) async {
    final Database db = await _appDatabase.database;
    await db.update(
      'accounts',
      <String, Object?>{
        'archived_at': archived ? DateTime.now().millisecondsSinceEpoch : null,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> reorderAccounts(List<int> ids) async {
    final Database db = await _appDatabase.database;
    final Batch batch = db.batch();
    for (int index = 0; index < ids.length; index++) {
      batch.update(
        'accounts',
        <String, Object?>{
          'sort_order': index,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: <Object?>[ids[index]],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteAccount(int id) async {
    final Database db = await _appDatabase.database;
    await db.transaction((Transaction txn) async {
      final List<Map<String, Object?>> transactionRows = await txn.query(
        'transactions',
        columns: <String>[
          'id',
          'type',
          'amount_minor',
          'account_id',
          'to_account_id',
        ],
        where:
            'account_id = ? OR to_account_id = ? OR id IN (SELECT transaction_id FROM transaction_fundings WHERE account_id = ?)',
        whereArgs: <Object?>[id, id, id],
      );
      final List<int> transactionIds = transactionRows
          .map((row) => row['id'] as int)
          .toList();
      for (final Map<String, Object?> row in transactionRows) {
        final int fromId = row['account_id'] as int;
        final List<Map<String, Object?>> fundingRows = await txn.query(
          'transaction_fundings',
          columns: <String>['account_id', 'member_id', 'amount_minor'],
          where: 'transaction_id = ?',
          whereArgs: <Object?>[row['id']],
        );
        final List<Map<String, Object?>> resolvedRows = fundingRows.isEmpty
            ? <Map<String, Object?>>[
                <String, Object?>{
                  'account_id': fromId,
                  'member_id': null,
                  'amount_minor': row['amount_minor'],
                },
              ]
            : fundingRows;
        for (final Map<String, Object?> funding in resolvedRows) {
          final int amount = funding['amount_minor'] as int;
          final int fundingAccountId = funding['account_id'] as int;
          final int counterpartId;
          final int delta;
          if (row['type'] == 'transfer') {
            final int toId = row['to_account_id'] as int;
            counterpartId = fromId == id ? toId : fromId;
            delta = fromId == id ? -amount : amount;
          } else {
            if (fundingAccountId == id) continue;
            counterpartId = fundingAccountId;
            delta = row['type'] == 'expense' ? amount : -amount;
          }
          await txn.rawUpdate(
            'UPDATE accounts SET balance_minor = balance_minor + ? WHERE id = ?',
            <Object?>[delta, counterpartId],
          );
          await txn.rawUpdate(
            '''
            UPDATE account_funds
            SET balance_minor = balance_minor + ?
            WHERE account_id = ? AND (
              (member_id IS NULL AND ? IS NULL) OR member_id = ?
            )
            ''',
            <Object?>[
              delta,
              counterpartId,
              funding['member_id'],
              funding['member_id'],
            ],
          );
        }
      }
      for (final int transactionId in transactionIds) {
        await txn.delete(
          'transaction_members',
          where: 'transaction_id = ?',
          whereArgs: <Object?>[transactionId],
        );
      }
      await txn.delete(
        'transactions',
        where:
            'account_id = ? OR to_account_id = ? OR id IN (SELECT transaction_id FROM transaction_fundings WHERE account_id = ?)',
        whereArgs: <Object?>[id, id, id],
      );
      await txn.update(
        'recurring_rules',
        <String, Object?>{'account_id': null},
        where: 'account_id = ?',
        whereArgs: <Object?>[id],
      );
      await txn.delete('accounts', where: 'id = ?', whereArgs: <Object?>[id]);
    });
  }

  Future<void> setMemberArchived(int id, bool archived) async {
    final Database db = await _appDatabase.database;
    await db.update(
      'members',
      <String, Object?>{
        'archived_at': archived ? DateTime.now().millisecondsSinceEpoch : null,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> reorderMembers(List<int> ids) async {
    final Database db = await _appDatabase.database;
    final Batch batch = db.batch();
    for (int index = 0; index < ids.length; index++) {
      batch.update(
        'members',
        <String, Object?>{
          'sort_order': index,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: <Object?>[ids[index]],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteMember(int id) async {
    final Database db = await _appDatabase.database;
    await db.transaction((Transaction txn) async {
      final int now = DateTime.now().millisecondsSinceEpoch;
      final int walletBalance =
          Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT balance_minor FROM member_wallets WHERE member_id = ?',
              <Object?>[id],
            ),
          ) ??
          0;
      await txn.rawUpdate(
        'UPDATE wallet_state SET common_balance_minor = common_balance_minor + ?, updated_at = ? WHERE id = 1',
        <Object?>[walletBalance, now],
      );
      final List<Map<String, Object?>> funds = await txn.query(
        'account_funds',
        columns: <String>['account_id', 'balance_minor'],
        where: 'member_id = ?',
        whereArgs: <Object?>[id],
      );
      for (final Map<String, Object?> fund in funds) {
        final int accountId = fund['account_id'] as int;
        final int amount = fund['balance_minor'] as int;
        final int updated = await txn.rawUpdate(
          '''
          UPDATE account_funds
          SET balance_minor = balance_minor + ?, updated_at = ?
          WHERE account_id = ? AND member_id IS NULL
          ''',
          <Object?>[amount, now, accountId],
        );
        if (updated == 0) {
          await txn.insert('account_funds', <String, Object?>{
            'account_id': accountId,
            'member_id': null,
            'balance_minor': amount,
            'created_at': now,
            'updated_at': now,
          });
        }
      }
      await txn.update(
        'transaction_fundings',
        <String, Object?>{'member_id': null},
        where: 'member_id = ?',
        whereArgs: <Object?>[id],
      );
      await txn.update(
        'transaction_wallet_sources',
        <String, Object?>{'source_member_id': null},
        where: 'source_member_id = ?',
        whereArgs: <Object?>[id],
      );
      await txn.update(
        'transaction_wallet_sources',
        <String, Object?>{'payer_member_id': null},
        where: 'payer_member_id = ?',
        whereArgs: <Object?>[id],
      );
      await txn.delete(
        'member_debts',
        where: 'creditor_member_id = ? OR debtor_member_id = ?',
        whereArgs: <Object?>[id, id],
      );
      await txn.delete(
        'member_debt_settlements',
        where: 'creditor_member_id = ? OR debtor_member_id = ?',
        whereArgs: <Object?>[id, id],
      );
      await txn.update(
        'transactions',
        <String, Object?>{'recorded_by_member_id': null},
        where: 'recorded_by_member_id = ?',
        whereArgs: <Object?>[id],
      );
      await txn.update(
        'categories',
        <String, Object?>{'member_id': null},
        where: 'member_id = ?',
        whereArgs: <Object?>[id],
      );
      await txn.delete(
        'transaction_members',
        where: 'member_id = ?',
        whereArgs: <Object?>[id],
      );
      await txn.delete('members', where: 'id = ?', whereArgs: <Object?>[id]);
    });
  }

  Future<void> setMonthlyBudget(DateTime month, double amount) async {
    final Database db = await _appDatabase.database;
    final String period =
        '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final int now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((Transaction txn) async {
      await txn.delete(
        'budgets',
        where: 'period = ? AND category_id IS NULL',
        whereArgs: <Object?>[period],
      );
      if (amount > 0) {
        await txn.insert('budgets', <String, Object?>{
          'period': period,
          'category_id': null,
          'amount_minor': _minor(amount),
          'created_at': now,
          'updated_at': now,
        });
      }
    });
  }

  Future<void> setCategoryBudget(
    DateTime month,
    String category,
    double amount,
  ) async {
    final Database db = await _appDatabase.database;
    final int now = DateTime.now().millisecondsSinceEpoch;
    final int categoryId = await _categoryId(db, category, now);
    final String period =
        '${month.year}-${month.month.toString().padLeft(2, '0')}';
    await db.transaction((Transaction txn) async {
      await txn.delete(
        'budgets',
        where: 'period = ? AND category_id = ?',
        whereArgs: <Object?>[period, categoryId],
      );
      if (amount > 0) {
        await txn.insert('budgets', <String, Object?>{
          'period': period,
          'category_id': categoryId,
          'amount_minor': _minor(amount),
          'created_at': now,
          'updated_at': now,
        });
      }
    });
  }

  Future<void> addAccount({
    required String name,
    required double openingBalance,
    String icon = 'wallet',
    AccountKind kind = AccountKind.asset,
    double creditLimit = 0,
  }) async {
    final Database db = await _appDatabase.database;
    final int now = DateTime.now().millisecondsSinceEpoch;
    final int order =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COALESCE(MAX(sort_order), -1) + 1 FROM accounts',
          ),
        ) ??
        0;
    _validateAccountBalance(kind, openingBalance, creditLimit);
    await db.transaction((Transaction txn) async {
      final int accountId = await txn.insert('accounts', <String, Object?>{
        'uuid': _uuid('account', now),
        'name': name,
        'type': 'wallet',
        'icon': icon,
        'kind': kind.name,
        'credit_limit_minor': _minor(creditLimit),
        'opening_balance_minor': _minor(openingBalance),
        'balance_minor': _minor(openingBalance),
        'sort_order': order,
        'created_at': now,
        'updated_at': now,
      });
      await txn.insert('account_funds', <String, Object?>{
        'account_id': accountId,
        'member_id': null,
        'balance_minor': _minor(openingBalance),
        'created_at': now,
        'updated_at': now,
      });
      await txn.rawUpdate(
        'UPDATE wallet_state SET common_balance_minor = common_balance_minor + ?, updated_at = ? WHERE id = 1',
        <Object?>[_minor(openingBalance), now],
      );
    });
  }

  Future<void> updateAccount(
    int id, {
    required String name,
    required String icon,
    required double balance,
    required AccountKind kind,
    required double creditLimit,
  }) async {
    final Database db = await _appDatabase.database;
    final int now = DateTime.now().millisecondsSinceEpoch;
    _validateAccountBalance(kind, balance, creditLimit);
    await db.transaction((Transaction txn) async {
      final List<Map<String, Object?>> rows = await txn.query(
        'accounts',
        columns: <String>['balance_minor'],
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final int oldMinor = rows.first['balance_minor'] as int;
      final int nextMinor = _minor(balance);
      await txn.update(
        'accounts',
        <String, Object?>{
          'name': name,
          'icon': icon,
          'kind': kind.name,
          'credit_limit_minor': _minor(creditLimit),
          'balance_minor': nextMinor,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
      final int delta = nextMinor - oldMinor;
      if (delta != 0) {
        final List<Map<String, Object?>> walletRows = await txn.query(
          'wallet_state',
          columns: <String>['common_balance_minor'],
          where: 'id = 1',
          limit: 1,
        );
        final int common = walletRows.first['common_balance_minor'] as int;
        if (common + delta < 0) throw StateError('公共资金不足，无法减少账户余额');
        await txn.update('wallet_state', <String, Object?>{
          'common_balance_minor': common + delta,
          'updated_at': now,
        }, where: 'id = 1');
        await txn.insert('transactions', <String, Object?>{
          'uuid': _uuid('adjustment', now),
          'type': EntryType.adjustment.name,
          'amount_minor': delta.abs(),
          'adjustment_delta_minor': delta,
          'account_id': id,
          'occurred_at': now,
          'local_date': _dateKey(DateTime.now()),
          'timezone': DateTime.now().timeZoneName,
          'note':
              '$name账户余额由 ¥${(oldMinor / 100).toStringAsFixed(2)} 变更为 ¥${balance.toStringAsFixed(2)}',
          'created_at': now,
          'updated_at': now,
        });
      }
    });
  }

  void _validateAccountBalance(
    AccountKind kind,
    double balance,
    double creditLimit,
  ) {
    if (creditLimit < 0) throw StateError('信用额度不能为负数');
    if (kind == AccountKind.asset && balance < 0) {
      throw StateError('资产账户余额不能小于 0');
    }
    if (kind == AccountKind.credit && balance < -creditLimit) {
      throw StateError('信用账户余额不能低于信用额度');
    }
    if (kind == AccountKind.loan && balance > 0) {
      throw StateError('贷款账户请用负数表示尚未偿还的金额');
    }
  }

  Future<void> addCategory({
    required String name,
    required EntryType type,
    required String icon,
    int? memberId,
  }) async {
    final Database db = await _appDatabase.database;
    final int now = DateTime.now().millisecondsSinceEpoch;
    final int order =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COALESCE(MAX(sort_order), -1) + 1 FROM categories',
          ),
        ) ??
        0;
    await db.insert('categories', <String, Object?>{
      'uuid': _uuid('custom-category', now),
      'name': name,
      'type': type.name,
      'icon': icon,
      'member_id': memberId,
      'sort_order': order,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> archiveCategory(String name) async {
    final Database db = await _appDatabase.database;
    await db.update(
      'categories',
      <String, Object?>{
        'archived_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'name = ?',
      whereArgs: <Object?>[name],
    );
  }

  Future<void> updateCategory({
    required String originalName,
    required String name,
    required String icon,
    int? memberId,
  }) async {
    final Database db = await _appDatabase.database;
    await db.update(
      'categories',
      <String, Object?>{
        'name': name,
        'icon': icon,
        'member_id': memberId,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'name = ?',
      whereArgs: <Object?>[originalName],
    );
  }

  Future<void> reorderCategories(List<String> names) async {
    final Database db = await _appDatabase.database;
    final int now = DateTime.now().millisecondsSinceEpoch;
    final Batch batch = db.batch();
    for (int index = 0; index < names.length; index++) {
      batch.update(
        'categories',
        <String, Object?>{'sort_order': index, 'updated_at': now},
        where: 'name = ?',
        whereArgs: <Object?>[names[index]],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> archiveCategories(List<String> names) async {
    if (names.isEmpty) return;
    final Database db = await _appDatabase.database;
    final int now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'categories',
      <String, Object?>{'archived_at': now, 'updated_at': now},
      where: 'name IN (${List<String>.filled(names.length, '?').join(',')})',
      whereArgs: names,
    );
  }

  Future<void> mergeCategories(
    List<String> sourceNames,
    String targetName,
  ) async {
    final List<String> sources = sourceNames
        .where((name) => name != targetName)
        .toSet()
        .toList();
    if (sources.isEmpty) return;
    final Database db = await _appDatabase.database;
    final int now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((Transaction txn) async {
      final List<Map<String, Object?>> targetRows = await txn.query(
        'categories',
        columns: <String>['id'],
        where: 'name = ?',
        whereArgs: <Object?>[targetName],
        limit: 1,
      );
      if (targetRows.isEmpty) throw StateError('找不到目标标签');
      final int targetId = targetRows.first['id'] as int;
      for (final String sourceName in sources) {
        final List<Map<String, Object?>> sourceRows = await txn.query(
          'categories',
          columns: <String>['id'],
          where: 'name = ?',
          whereArgs: <Object?>[sourceName],
          limit: 1,
        );
        if (sourceRows.isEmpty) continue;
        final int sourceId = sourceRows.first['id'] as int;
        await txn.update(
          'transactions',
          <String, Object?>{'category_id': targetId, 'updated_at': now},
          where: 'category_id = ?',
          whereArgs: <Object?>[sourceId],
        );
        await txn.update(
          'recurring_rules',
          <String, Object?>{'category_id': targetId, 'updated_at': now},
          where: 'category_id = ?',
          whereArgs: <Object?>[sourceId],
        );
        final List<Map<String, Object?>> sourceBudgets = await txn.query(
          'budgets',
          where: 'category_id = ?',
          whereArgs: <Object?>[sourceId],
        );
        for (final Map<String, Object?> budget in sourceBudgets) {
          final List<Map<String, Object?>> targetBudgets = await txn.query(
            'budgets',
            columns: <String>['id', 'amount_minor'],
            where: 'period = ? AND category_id = ?',
            whereArgs: <Object?>[budget['period'], targetId],
            limit: 1,
          );
          if (targetBudgets.isEmpty) {
            await txn.update(
              'budgets',
              <String, Object?>{'category_id': targetId, 'updated_at': now},
              where: 'id = ?',
              whereArgs: <Object?>[budget['id']],
            );
          } else {
            await txn.update(
              'budgets',
              <String, Object?>{
                'amount_minor':
                    (targetBudgets.first['amount_minor'] as int) +
                    (budget['amount_minor'] as int),
                'updated_at': now,
              },
              where: 'id = ?',
              whereArgs: <Object?>[targetBudgets.first['id']],
            );
            await txn.delete(
              'budgets',
              where: 'id = ?',
              whereArgs: <Object?>[budget['id']],
            );
          }
        }
        await txn.delete(
          'categories',
          where: 'id = ?',
          whereArgs: <Object?>[sourceId],
        );
      }
    });
  }

  Future<void> batchUpdateEntries(
    List<LedgerEntry> entries, {
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
    final Database db = await _appDatabase.database;
    final int now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((Transaction txn) async {
      final List<EntryType> editableTypes = entries
          .where(
            (entry) =>
                entry.type == EntryType.expense ||
                entry.type == EntryType.income,
          )
          .map((entry) => entry.type)
          .toList();
      final int? replacementCategoryId = changeCategory && category != null
          ? await _categoryId(
              txn,
              category,
              now,
              type: editableTypes.isEmpty
                  ? EntryType.expense
                  : editableTypes.first,
            )
          : null;
      for (final LedgerEntry entry in entries) {
        final Map<String, Object?> values = <String, Object?>{
          'updated_at': now,
        };
        if (replacementCategoryId != null &&
            entry.type != EntryType.transfer &&
            entry.type != EntryType.adjustment) {
          values['category_id'] = replacementCategoryId;
        }
        if (changeAccount &&
            accountId != null &&
            entry.type != EntryType.transfer &&
            entry.type != EntryType.adjustment &&
            accountId != entry.accountId) {
          await _applyBalance(txn, entry, -1);
          values['account_id'] = accountId;
          final LedgerEntry moved = LedgerEntry(
            id: entry.id,
            type: entry.type,
            amount: entry.amount,
            category: entry.category,
            occurredAt: entry.occurredAt,
            note: entry.note,
            accountId: accountId,
            toAccountId: entry.toAccountId,
            memberIds: entry.memberIds,
            memberShares: entry.memberShares,
            outsideBudget: entry.outsideBudget,
            recurring: entry.recurring,
            recurringFrequency: entry.recurringFrequency,
            adjustmentDelta: entry.adjustmentDelta,
          );
          final List<EntryFunding> movedFundings = await _resolveFundings(
            txn,
            moved,
          );
          await txn.delete(
            'transaction_fundings',
            where: 'transaction_id = ?',
            whereArgs: <Object?>[entry.id],
          );
          await txn.delete(
            'member_debts',
            where: 'transaction_id = ?',
            whereArgs: <Object?>[entry.id],
          );
          await _insertFundings(txn, entry.id, movedFundings);
          await _applyBalance(txn, moved, 1, fundings: movedFundings);
          await _insertDebts(txn, entry.id, moved.type, entry.walletSources);
        }
        if (changeNote) values['note'] = note;
        if (values.length > 1) {
          await txn.update(
            'transactions',
            values,
            where: 'id = ?',
            whereArgs: <Object?>[entry.id],
          );
        }
        if (changePayers && entry.type != EntryType.adjustment) {
          final List<MemberShare> payerShares = _equalMemberShares(
            payerIds,
            _minor(entry.amount),
          );
          await txn.delete(
            'transaction_members',
            where: 'transaction_id = ?',
            whereArgs: <Object?>[entry.id],
          );
          await _insertMembers(
            txn,
            entry.id,
            payerIds,
            _minor(entry.amount),
            shares: payerShares,
          );
          final List<WalletSource> existingSources =
              entry.walletSources.isNotEmpty
              ? entry.walletSources
              : _resolvedWalletSources(entry, _resolvedMemberShares(entry));
          late final List<WalletSource> nextSources;
          if (entry.type == EntryType.income) {
            await _applyWalletBalances(txn, entry.type, existingSources, -1);
            nextSources = payerShares.isEmpty
                ? <WalletSource>[WalletSource(amount: entry.amount)]
                : payerShares
                      .map(
                        (MemberShare share) => WalletSource(
                          sourceMemberId: share.memberId,
                          payerMemberId: share.memberId,
                          amount: share.amount,
                        ),
                      )
                      .toList();
            await _applyWalletBalances(txn, entry.type, nextSources, 1);
          } else if (entry.type == EntryType.expense) {
            nextSources = _retargetWalletSources(existingSources, payerShares);
          } else {
            nextSources = existingSources;
          }
          if (entry.type == EntryType.income ||
              entry.type == EntryType.expense) {
            await txn.delete(
              'transaction_wallet_sources',
              where: 'transaction_id = ?',
              whereArgs: <Object?>[entry.id],
            );
            await _insertWalletSources(txn, entry.id, nextSources);
          }
          await txn.delete(
            'member_debts',
            where: 'transaction_id = ?',
            whereArgs: <Object?>[entry.id],
          );
          await _insertDebts(txn, entry.id, entry.type, nextSources);
        }
        if (changeRecorders) {
          await txn.delete(
            'transaction_recorders',
            where: 'transaction_id = ?',
            whereArgs: <Object?>[entry.id],
          );
          await _insertRecorders(txn, entry.id, recorderIds);
          await txn.update(
            'transactions',
            <String, Object?>{
              'recorded_by_member_id': recorderIds.firstOrNull,
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: <Object?>[entry.id],
          );
        }
        if (values.length > 1 || changePayers || changeRecorders) {
          final List<Map<String, Object?>> uuidRows = await txn.query(
            'transactions',
            columns: <String>['uuid'],
            where: 'id = ?',
            whereArgs: <Object?>[entry.id],
            limit: 1,
          );
          if (uuidRows.isNotEmpty) {
            await _insertHistory(
              txn,
              transactionId: entry.id,
              transactionUuid: uuidRows.first['uuid'] as String,
              action: 'updated',
              actorMemberId: entry.recordedByMemberId,
              summary: '批量修改账目',
              occurredAt: now,
            );
          }
        }
      }
    });
  }

  Future<void> deleteEntries(List<LedgerEntry> entries) async {
    final Database db = await _appDatabase.database;
    await db.transaction((Transaction txn) async {
      for (final LedgerEntry entry in entries) {
        await _applyBalance(txn, entry, -1);
        final List<Map<String, Object?>> uuidRows = await txn.query(
          'transactions',
          columns: <String>['uuid'],
          where: 'id = ?',
          whereArgs: <Object?>[entry.id],
          limit: 1,
        );
        if (uuidRows.isNotEmpty) {
          await _insertHistory(
            txn,
            transactionId: entry.id,
            transactionUuid: uuidRows.first['uuid'] as String,
            action: 'deleted',
            actorMemberId: entry.recordedByMemberId,
            summary: '批量删除账目 ¥${entry.amount.toStringAsFixed(2)}',
            occurredAt: DateTime.now().millisecondsSinceEpoch,
          );
        }
        await txn.delete(
          'transactions',
          where: 'id = ?',
          whereArgs: <Object?>[entry.id],
        );
      }
    });
  }

  Future<void> addMember({
    required String name,
    required int colorValue,
  }) async {
    final Database db = await _appDatabase.database;
    final int now = DateTime.now().millisecondsSinceEpoch;
    final int order =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COALESCE(MAX(sort_order), -1) + 1 FROM members',
          ),
        ) ??
        0;
    await db.transaction((Transaction txn) async {
      final int memberId = await txn.insert('members', <String, Object?>{
        'uuid': _uuid('member', now),
        'name': name,
        'color_value': colorValue,
        'sort_order': order,
        'created_at': now,
        'updated_at': now,
      });
      await txn.insert('member_wallets', <String, Object?>{
        'member_id': memberId,
        'balance_minor': 0,
        'updated_at': now,
      });
    });
  }

  Future<void> updateMember(
    int id, {
    required String name,
    required int colorValue,
  }) async {
    final Database db = await _appDatabase.database;
    await db.update(
      'members',
      <String, Object?>{
        'name': name,
        'color_value': colorValue,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> saveRecurringRule(RecurringRule rule) async {
    final Database db = await _appDatabase.database;
    final int now = DateTime.now().millisecondsSinceEpoch;
    final int categoryId = await _categoryId(
      db,
      rule.category,
      now,
      type: rule.type,
    );
    final Map<String, Object?> values = <String, Object?>{
      'name': rule.name,
      'type': rule.type.name,
      'amount_minor': _minor(rule.amount),
      'account_id': rule.accountId,
      'category_id': categoryId,
      'frequency': rule.frequency,
      'anchor_date': _dateKey(rule.anchorDate),
      'enabled': rule.enabled ? 1 : 0,
      'updated_at': now,
    };
    if (rule.id == 0) {
      await db.insert('recurring_rules', <String, Object?>{
        ...values,
        'uuid': _uuid('rule', now),
        'created_at': now,
      });
    } else {
      await db.update(
        'recurring_rules',
        values,
        where: 'id = ?',
        whereArgs: <Object?>[rule.id],
      );
    }
  }

  Future<void> deleteRecurringRule(int id) async {
    final Database db = await _appDatabase.database;
    await db.delete(
      'recurring_rules',
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> clearAllData() async {
    final Database db = await _appDatabase.database;
    final int now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((Transaction txn) async {
      for (final String table in <String>[
        'transaction_recorders',
        'transaction_wallet_sources',
        'entry_history',
        'transaction_visible_members',
        'member_debt_settlements',
        'member_budgets',
        'member_debts',
        'transaction_fundings',
        'transaction_members',
        'transactions',
        'budgets',
        'recurring_rules',
        'import_jobs',
        'categories',
        'account_funds',
        'member_wallets',
        'wallet_state',
        'members',
        'accounts',
        'settings',
      ]) {
        await txn.delete(table);
      }
      final int accountId = await txn.insert('accounts', <String, Object?>{
        'uuid': _uuid('account', now),
        'name': '现金',
        'type': 'cash',
        'icon': 'cash',
        'opening_balance_minor': 0,
        'balance_minor': 0,
        'sort_order': 0,
        'created_at': now,
        'updated_at': now,
      });
      await txn.insert('account_funds', <String, Object?>{
        'account_id': accountId,
        'member_id': null,
        'balance_minor': 0,
        'created_at': now,
        'updated_at': now,
      });
      await txn.insert('wallet_state', <String, Object?>{
        'id': 1,
        'common_balance_minor': 0,
        'updated_at': now,
      });
      final int memberId = await txn.insert('members', <String, Object?>{
        'uuid': _uuid('member', now),
        'name': '我',
        'color_value': 0xFF2E7CF6,
        'sort_order': 0,
        'created_at': now,
        'updated_at': now,
      });
      await txn.insert('member_wallets', <String, Object?>{
        'member_id': memberId,
        'balance_minor': 0,
        'updated_at': now,
      });
      await txn.insert('settings', <String, Object?>{
        'key': 'current_member_id',
        'value': '$memberId',
        'updated_at': now,
      });
      const List<(String, String, String)> defaults =
          <(String, String, String)>[
            ('餐饮', 'expense', 'restaurant'),
            ('交通', 'expense', 'car'),
            ('购物', 'expense', 'shopping'),
            ('住房', 'expense', 'home'),
            ('娱乐', 'expense', 'game'),
            ('医疗', 'expense', 'medical'),
            ('学习', 'expense', 'book'),
            ('旅行', 'expense', 'flight'),
            ('通讯', 'expense', 'phone'),
            ('健身', 'expense', 'fitness'),
            ('美妆', 'expense', 'beauty'),
            ('服饰', 'expense', 'clothes'),
            ('红包', 'income', 'red_packet'),
            ('工资', 'income', 'salary'),
            ('理财', 'income', 'chart'),
            ('打赏', 'income', 'tip'),
            ('报销', 'income', 'reimbursement'),
            ('礼物', 'income', 'gift'),
            ('兼职', 'income', 'part_time'),
            ('其他', 'both', 'more'),
          ];
      for (int index = 0; index < defaults.length; index++) {
        await txn.insert('categories', <String, Object?>{
          'uuid': 'default-category-${index + 1}-$now',
          'name': defaults[index].$1,
          'type': defaults[index].$2,
          'icon': defaults[index].$3,
          'sort_order': index,
          'created_at': now,
          'updated_at': now,
        });
      }
    });
  }

  Future<void> setPreference(String key, String value) async {
    final Database db = await _appDatabase.database;
    await db.insert('settings', <String, Object?>{
      'key': key,
      'value': value,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> setDailyReminder({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    final Database db = await _appDatabase.database;
    final int now = DateTime.now().millisecondsSinceEpoch;
    final Batch batch = db.batch();
    for (final MapEntry<String, String> entry in <String, String>{
      'daily_reminder_enabled': enabled ? '1' : '0',
      'daily_reminder_hour': '${hour.clamp(0, 23)}',
      'daily_reminder_minute': '${minute.clamp(0, 59)}',
    }.entries) {
      batch.insert('settings', <String, Object?>{
        'key': entry.key,
        'value': entry.value,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<Map<String, Object?>> exportBackup() async {
    final Database db = await _appDatabase.database;
    final Map<String, Object?> tables = <String, Object?>{};
    for (final String table in backupTables) {
      tables[table] = await db.query(table);
    }
    return <String, Object?>{
      'format': 'oneentry-backup',
      'schemaVersion': AppDatabase.schemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'tables': tables,
    };
  }

  Future<void> replaceFromBackup(Map<String, Object?> backup) async {
    if (backup['format'] != 'oneentry-backup') {
      throw const FormatException('不是一笔的完整备份');
    }
    final int sourceVersion = (backup['schemaVersion'] as num?)?.toInt() ?? 0;
    if (sourceVersion > AppDatabase.schemaVersion) {
      throw FormatException(
        '备份版本 $sourceVersion 高于当前数据库版本 ${AppDatabase.schemaVersion}',
      );
    }
    final Map<String, Object?> tables = Map<String, Object?>.from(
      backup['tables'] as Map,
    );
    final Database db = await _appDatabase.database;
    await db.transaction((Transaction txn) async {
      for (final String table in <String>[
        'transaction_recorders',
        'transaction_wallet_sources',
        'entry_history',
        'transaction_visible_members',
        'member_debt_settlements',
        'member_budgets',
        'member_debts',
        'transaction_fundings',
        'transaction_members',
        'transactions',
        'budgets',
        'recurring_rules',
        'import_jobs',
        'categories',
        'account_funds',
        'member_wallets',
        'wallet_state',
        'members',
        'accounts',
        'settings',
      ]) {
        await txn.delete(table);
      }
      for (final String table in backupTables) {
        final List<Object?> rows = List<Object?>.from(
          tables[table] as List? ?? const <Object?>[],
        );
        for (final Object? value in rows) {
          await txn.insert(table, Map<String, Object?>.from(value as Map));
        }
      }
      if (sourceVersion < 6) await _backfillV6Tables(txn);
      if (sourceVersion < 7) await _backfillV7Tables(txn);
      if (sourceVersion < 8) await _backfillV8Tables(txn);
    });
  }

  Future<void> _backfillV6Tables(DatabaseExecutor db) async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    await db.execute(
      '''
      INSERT INTO account_funds (
        account_id, member_id, balance_minor, created_at, updated_at
      )
      SELECT id, NULL, balance_minor, ?, ? FROM accounts
      WHERE NOT EXISTS (
        SELECT 1 FROM account_funds f WHERE f.account_id = accounts.id
      )
    ''',
      <Object?>[now, now],
    );
    await db.execute('''
      INSERT INTO transaction_fundings (
        transaction_id, account_id, member_id, amount_minor, sort_order
      )
      SELECT id, account_id, NULL, amount_minor, 0
      FROM transactions
      WHERE type IN ('expense', 'income')
        AND account_id IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM transaction_fundings f
          WHERE f.transaction_id = transactions.id
        )
    ''');
  }

  Future<void> _backfillV7Tables(DatabaseExecutor db) async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final List<Map<String, Object?>> members = await db.query(
      'members',
      columns: <String>['id'],
      where: 'archived_at IS NULL',
      orderBy: 'sort_order, id',
      limit: 1,
    );
    if (members.isNotEmpty) {
      await db.insert('settings', <String, Object?>{
        'key': 'current_member_id',
        'value': '${members.first['id']}',
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _backfillV8Tables(DatabaseExecutor db) async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    await db.execute(
      '''
      INSERT INTO member_wallets(member_id, balance_minor, updated_at)
      SELECT m.id, COALESCE(SUM(f.balance_minor), 0), ?
      FROM members m
      LEFT JOIN account_funds f ON f.member_id = m.id
      GROUP BY m.id
    ''',
      <Object?>[now],
    );
    final int common =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COALESCE(SUM(balance_minor), 0) FROM account_funds WHERE member_id IS NULL',
          ),
        ) ??
        0;
    await db.insert('wallet_state', <String, Object?>{
      'id': 1,
      'common_balance_minor': common,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.execute('''
      INSERT INTO transaction_wallet_sources(
        transaction_id, source_member_id, payer_member_id, amount_minor, sort_order
      )
      SELECT transaction_id, member_id, member_id, SUM(amount_minor), MIN(sort_order)
      FROM transaction_fundings
      GROUP BY transaction_id, member_id
    ''');
    await db.execute('''
      INSERT INTO transaction_recorders(transaction_id, member_id)
      SELECT id, recorded_by_member_id FROM transactions
      WHERE recorded_by_member_id IS NOT NULL
    ''');
  }

  Future<({int imported, int skipped, int members, int accounts})> importTonglv(
    TonglvImportBundle bundle, {
    String sourceApp = 'tonglv',
    String sourceLabel = '同旅迁移备份',
  }) async {
    final Database db = await _appDatabase.database;
    return db.transaction((Transaction txn) async {
      final int now = DateTime.now().millisecondsSinceEpoch;
      final Map<String, int> memberIds = <String, int>{};
      int newMembers = 0;
      for (final TonglvMember member in bundle.members) {
        final List<Map<String, Object?>> rows = await txn.query(
          'members',
          columns: <String>['id'],
          where: 'name = ?',
          whereArgs: <Object?>[member.name],
          limit: 1,
        );
        final int localId;
        if (rows.isNotEmpty) {
          localId = rows.first['id'] as int;
          await txn.update(
            'members',
            <String, Object?>{
              'color_value': member.colorValue,
              'archived_at': member.archived ? now : null,
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: <Object?>[localId],
          );
        } else {
          localId = await txn.insert('members', <String, Object?>{
            'uuid': 'tonglv-member-${member.sourceId}',
            'name': member.name,
            'color_value': member.colorValue,
            'sort_order': memberIds.length,
            'archived_at': member.archived ? now : null,
            'created_at': now,
            'updated_at': now,
          });
          newMembers++;
        }
        await txn.insert('member_wallets', <String, Object?>{
          'member_id': localId,
          'balance_minor': 0,
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        memberIds[member.sourceId] = localId;
      }

      final Map<String, int> accountIds = <String, int>{};
      int newAccounts = 0;
      for (final TonglvAccount account in bundle.accounts) {
        final List<Map<String, Object?>> rows = await txn.query(
          'accounts',
          columns: <String>['id'],
          where: 'name = ?',
          whereArgs: <Object?>[account.name],
          limit: 1,
        );
        final int localId;
        if (rows.isNotEmpty) {
          localId = rows.first['id'] as int;
        } else {
          localId = await txn.insert('accounts', <String, Object?>{
            'uuid': 'tonglv-account-${account.sourceId}',
            'name': account.name,
            'type': 'wallet',
            'icon': 'wallet',
            'opening_balance_minor': 0,
            'balance_minor': 0,
            'sort_order': accountIds.length,
            'created_at': now,
            'updated_at': now,
          });
          await txn.insert('account_funds', <String, Object?>{
            'account_id': localId,
            'member_id': null,
            'balance_minor': 0,
            'created_at': now,
            'updated_at': now,
          });
          newAccounts++;
        }
        accountIds[account.sourceId] = localId;
      }
      final int fallbackAccountId = accountIds.values.isNotEmpty
          ? accountIds.values.first
          : ((await txn.query(
                  'accounts',
                  columns: <String>['id'],
                  where: 'archived_at IS NULL',
                  orderBy: 'sort_order, id',
                  limit: 1,
                )).first['id']
                as int);

      final Set<String> activeCategoryNames = (await txn.query(
        'categories',
        columns: <String>['name'],
        where: 'archived_at IS NULL',
      )).map((row) => row['name'] as String).toSet();

      int imported = 0;
      int skipped = 0;
      for (final TonglvEntry entry in bundle.entries) {
        final int duplicate =
            Sqflite.firstIntValue(
              await txn.rawQuery(
                'SELECT COUNT(*) FROM transactions WHERE source_app = ? AND source_row_key = ?',
                <Object?>[sourceApp, entry.sourceId],
              ),
            ) ??
            0;
        if (duplicate > 0) {
          skipped++;
          continue;
        }
        final EntryType entryType = entry.amount < 0
            ? EntryType.expense
            : EntryType.income;
        String category = entry.category;
        String importedNote = <String>[
          entry.title,
          entry.note,
        ].where((value) => value.isNotEmpty).join(' · ');
        if (sourceApp == 'generic_table') {
          final List<String> candidates = <String>[
            entry.category,
            entry.secondaryCategory,
          ].where((value) => value.isNotEmpty).toSet().toList();
          category = candidates.firstWhere(
            activeCategoryNames.contains,
            orElse: () => '其他',
          );
          final List<String> unmatched = candidates
              .where((value) => value != category)
              .toList();
          if (unmatched.isNotEmpty) {
            importedNote = <String>[
              importedNote,
              '原分类：${unmatched.join(' / ')}',
            ].where((value) => value.isNotEmpty).join(' · ');
          }
        }
        final int categoryId = await _categoryId(
          txn,
          category,
          now,
          type: entryType,
        );
        final int accountId =
            accountIds[entry.accountSourceId] ?? fallbackAccountId;
        final String type = entryType.name;
        final int amountMinor = _minor(entry.amount.abs());
        final int transactionId = await txn
            .insert('transactions', <String, Object?>{
              'uuid': '$sourceApp-transaction-${entry.sourceId}',
              'type': type,
              'amount_minor': amountMinor,
              'account_id': accountId,
              'category_id': categoryId,
              'occurred_at': entry.occurredAt.millisecondsSinceEpoch,
              'local_date': _dateKey(entry.occurredAt),
              'timezone': entry.occurredAt.timeZoneName,
              'note': importedNote,
              'source_app': sourceApp,
              'source_row_key': entry.sourceId,
              'created_at': now,
              'updated_at': now,
            });
        final List<int> linkedMembers = entry.memberSourceIds
            .map((sourceId) => memberIds[sourceId])
            .whereType<int>()
            .toList();
        await _insertMembers(txn, transactionId, linkedMembers, amountMinor);
        await txn.insert('transaction_fundings', <String, Object?>{
          'transaction_id': transactionId,
          'account_id': accountId,
          'member_id': null,
          'amount_minor': amountMinor,
          'sort_order': 0,
        });
        await txn.insert('transaction_wallet_sources', <String, Object?>{
          'transaction_id': transactionId,
          'source_member_id': null,
          'payer_member_id': null,
          'amount_minor': amountMinor,
          'sort_order': 0,
        });
        final int delta = type == 'expense' ? -amountMinor : amountMinor;
        await txn.rawUpdate(
          'UPDATE accounts SET balance_minor = balance_minor + ?, updated_at = ? WHERE id = ?',
          <Object?>[delta, now, accountId],
        );
        await txn.rawUpdate(
          'UPDATE wallet_state SET common_balance_minor = common_balance_minor + ?, updated_at = ? WHERE id = 1',
          <Object?>[delta, now],
        );
        await txn.rawUpdate(
          '''
          UPDATE account_funds
          SET balance_minor = balance_minor + ?, updated_at = ?
          WHERE account_id = ? AND member_id IS NULL
          ''',
          <Object?>[delta, now, accountId],
        );
        imported++;
      }
      final String signature =
          'v${bundle.backupVersion}-${bundle.entries.length}-${bundle.entries.isEmpty ? 'empty' : bundle.entries.first.sourceId}';
      await txn.insert('import_jobs', <String, Object?>{
        'uuid': _uuid('import', now),
        'source_app': sourceApp,
        'file_name': sourceLabel,
        'file_hash': signature,
        'status': 'complete',
        'summary_json': '{"imported":$imported,"skipped":$skipped}',
        'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      return (
        imported: imported,
        skipped: skipped,
        members: newMembers,
        accounts: newAccounts,
      );
    });
  }

  LedgerAccount _accountFromRow(Map<String, Object?> row) => LedgerAccount(
    id: row['id'] as int,
    name: row['name'] as String,
    balance: (row['balance_minor'] as int) / 100,
    icon: row['icon'] as String? ?? 'wallet',
    kind: AccountKind.values.byName(row['kind'] as String? ?? 'asset'),
    creditLimit: ((row['credit_limit_minor'] as int?) ?? 0) / 100,
    archived: row['archived_at'] != null,
  );

  LedgerCategory _categoryFromRow(Map<String, Object?> row) {
    final String rawType = row['type'] as String? ?? 'expense';
    final String name = row['name'] as String;
    final EntryType type =
        rawType == 'income' ||
            (rawType == 'both' &&
                <String>[
                  '工资',
                  '红包',
                  '理财',
                  '打赏',
                  '报销',
                  '礼物',
                  '兼职',
                ].contains(name))
        ? EntryType.income
        : rawType == 'transfer'
        ? EntryType.transfer
        : EntryType.expense;
    return LedgerCategory(
      name: name,
      type: type,
      icon: row['icon'] as String? ?? 'tag',
      custom: (row['uuid'] as String? ?? '').startsWith('custom-category-'),
      both: rawType == 'both',
      memberId: row['member_id'] as int?,
    );
  }

  LedgerMember _memberFromRow(Map<String, Object?> row) => LedgerMember(
    id: row['id'] as int,
    name: row['name'] as String,
    colorValue: row['color_value'] as int,
    archived: row['archived_at'] != null,
  );

  RecurringRule _ruleFromRow(Map<String, Object?> row) => RecurringRule(
    id: row['id'] as int,
    name: row['name'] as String,
    type: EntryType.values.byName(row['type'] as String),
    amount: (row['amount_minor'] as int) / 100,
    frequency: row['frequency'] as String,
    anchorDate: DateTime.parse(row['anchor_date'] as String),
    accountId: row['account_id'] as int?,
    category: (row['category_name'] as String?) ?? '其他',
    enabled: (row['enabled'] as int) == 1,
  );

  LedgerEntry _entryFromRow(
    Map<String, Object?> row,
    List<int> memberIds,
    List<MemberShare> memberShares,
    List<EntryFunding> fundings,
    List<int> visibleMemberIds,
    List<WalletSource> walletSources,
    List<int> recorderIds,
  ) {
    final EntryType type = EntryType.values.byName(row['type'] as String);
    return LedgerEntry(
      id: row['id'] as int,
      type: type,
      amount: (row['amount_minor'] as int) / 100,
      category:
          (row['category_name'] as String?) ??
          (type == EntryType.transfer ? '转账' : '其他'),
      occurredAt: DateTime.fromMillisecondsSinceEpoch(
        row['occurred_at'] as int,
      ),
      note: row['note'] as String,
      accountId: row['account_id'] as int,
      toAccountId: row['to_account_id'] as int?,
      memberIds: memberIds,
      memberShares: memberShares,
      fundings: fundings,
      outsideBudget: ((row['outside_budget'] as int?) ?? 0) == 1,
      recordedByMemberId: row['recorded_by_member_id'] as int?,
      visibility: EntryVisibility.values.byName(
        row['visibility'] as String? ?? 'all',
      ),
      visibleMemberIds: visibleMemberIds,
      walletSources: walletSources,
      recorderIds: recorderIds,
      recurring: row['recurring_rule_id'] != null,
      recurringFrequency: (row['recurring_frequency'] as String?) ?? 'month',
      adjustmentDelta: ((row['adjustment_delta_minor'] as int?) ?? 0) / 100,
    );
  }

  Future<int> _categoryId(
    DatabaseExecutor db,
    String name,
    int now, {
    EntryType type = EntryType.expense,
    String icon = 'tag',
  }) async {
    final String normalizedName = name == '教育'
        ? '学习'
        : name == '居住'
        ? '住房'
        : name;
    final List<Map<String, Object?>> rows = await db.query(
      'categories',
      columns: <String>['id'],
      where: 'name = ?',
      whereArgs: <Object?>[normalizedName],
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first['id'] as int;
    return db.insert('categories', <String, Object?>{
      'uuid': _uuid('category', now),
      'name': normalizedName,
      'type': type.name,
      'icon': icon,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> _insertMembers(
    DatabaseExecutor db,
    int transactionId,
    List<int> memberIds,
    int amountMinor, {
    List<MemberShare> shares = const <MemberShare>[],
  }) async {
    final List<MemberShare> resolved = shares.isNotEmpty
        ? shares
        : _equalMemberShares(memberIds, amountMinor);
    if (resolved.isEmpty) return;
    for (final MemberShare item in resolved) {
      final int share = _minor(item.amount);
      await db.insert('transaction_members', <String, Object?>{
        'transaction_id': transactionId,
        'member_id': item.memberId,
        'share_minor': share,
        'share_ratio': amountMinor == 0 ? 0 : share / amountMinor,
      });
    }
  }

  List<MemberShare> _equalMemberShares(List<int> memberIds, int amountMinor) {
    final List<int> ids = memberIds.toSet().toList();
    if (ids.isEmpty) return const <MemberShare>[];
    final int base = amountMinor ~/ ids.length;
    int remainder = amountMinor % ids.length;
    return ids.map((int memberId) {
      final int share = base + (remainder > 0 ? 1 : 0);
      if (remainder > 0) remainder--;
      return MemberShare(memberId: memberId, amount: share / 100);
    }).toList();
  }

  List<MemberShare> _resolvedMemberShares(LedgerEntry entry) {
    final int amountMinor = _minor(entry.amount);
    if (entry.memberShares.isNotEmpty) {
      final int total = entry.memberShares.fold<int>(
        0,
        (int sum, MemberShare share) => sum + _minor(share.amount),
      );
      if (total == amountMinor) return entry.memberShares;
      if (total != 0) {
        throw StateError('付款或归属金额合计必须等于账目金额');
      }
    }
    return _equalMemberShares(entry.memberIds, amountMinor);
  }

  Future<List<EntryFunding>> _resolveFundings(
    DatabaseExecutor db,
    LedgerEntry entry,
  ) async {
    if (entry.type == EntryType.adjustment) return const <EntryFunding>[];
    final int amountMinor = _minor(entry.amount);
    if (entry.fundings.isNotEmpty) {
      final int total = entry.fundings.fold<int>(
        0,
        (int sum, EntryFunding funding) => sum + _minor(funding.amount),
      );
      if (total != amountMinor) {
        throw StateError('支付明细合计必须等于账目金额');
      }
      for (final EntryFunding funding in entry.fundings) {
        if (funding.amount <= 0) throw StateError('支付金额必须大于 0');
        await _validateFundingAccount(db, entry.type, funding.accountId);
      }
      return entry.fundings;
    }

    await _validateFundingAccount(db, entry.type, entry.accountId);
    if (entry.type == EntryType.income) {
      return <EntryFunding>[
        EntryFunding(accountId: entry.accountId, amount: entry.amount),
      ];
    }

    final List<Map<String, Object?>> accountRows = await db.query(
      'accounts',
      columns: <String>['kind', 'balance_minor', 'credit_limit_minor'],
      where: 'id = ?',
      whereArgs: <Object?>[entry.accountId],
      limit: 1,
    );
    if (accountRows.isEmpty) throw StateError('账户不存在');
    final Map<String, Object?> account = accountRows.first;
    final AccountKind kind = AccountKind.values.byName(
      account['kind'] as String? ?? 'asset',
    );
    final int available = kind == AccountKind.credit
        ? (account['balance_minor'] as int) +
              (account['credit_limit_minor'] as int)
        : account['balance_minor'] as int;
    if (available < amountMinor) {
      throw StateError('账户中的可用资金不足，请使用组合付款或明确借用其他成员资金');
    }
    return <EntryFunding>[
      EntryFunding(accountId: entry.accountId, amount: entry.amount),
    ];
  }

  Future<void> _validateFundingAccount(
    DatabaseExecutor db,
    EntryType type,
    int accountId,
  ) async {
    final List<Map<String, Object?>> rows = await db.query(
      'accounts',
      columns: <String>['kind', 'archived_at'],
      where: 'id = ?',
      whereArgs: <Object?>[accountId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('账户不存在');
    if (rows.first['archived_at'] != null) throw StateError('归档账户不能用于新账目');
    final AccountKind kind = AccountKind.values.byName(
      rows.first['kind'] as String? ?? 'asset',
    );
    if ((type == EntryType.expense || type == EntryType.transfer) &&
        kind == AccountKind.loan) {
      throw StateError('贷款账户不能直接用于支付');
    }
  }

  Future<void> _insertFundings(
    DatabaseExecutor db,
    int transactionId,
    List<EntryFunding> fundings,
  ) async {
    for (int index = 0; index < fundings.length; index++) {
      final EntryFunding funding = fundings[index];
      await db.insert('transaction_fundings', <String, Object?>{
        'transaction_id': transactionId,
        'account_id': funding.accountId,
        'member_id': null,
        'amount_minor': _minor(funding.amount),
        'sort_order': index,
      });
    }
  }

  Future<void> _insertVisibleMembers(
    DatabaseExecutor db,
    int transactionId,
    List<int> memberIds,
  ) async {
    for (final int memberId in memberIds.toSet()) {
      await db.insert('transaction_visible_members', <String, Object?>{
        'transaction_id': transactionId,
        'member_id': memberId,
      });
    }
  }

  List<WalletSource> _resolvedWalletSources(
    LedgerEntry entry,
    List<MemberShare> memberShares,
  ) {
    if (entry.type == EntryType.transfer ||
        entry.type == EntryType.adjustment) {
      return const <WalletSource>[];
    }
    if (entry.walletSources.isNotEmpty) {
      final int total = entry.walletSources.fold<int>(
        0,
        (int sum, WalletSource source) => sum + _minor(source.amount),
      );
      if (total != _minor(entry.amount)) {
        throw StateError('荷包资金来源合计必须等于账目金额');
      }
      return entry.walletSources;
    }
    if (memberShares.isEmpty) {
      return <WalletSource>[WalletSource(amount: entry.amount)];
    }
    return memberShares
        .map(
          (MemberShare share) => WalletSource(
            sourceMemberId: share.memberId,
            payerMemberId: share.memberId,
            amount: share.amount,
          ),
        )
        .toList();
  }

  List<WalletSource> _retargetWalletSources(
    List<WalletSource> sources,
    List<MemberShare> payerShares,
  ) {
    if (payerShares.isEmpty) {
      return sources
          .map(
            (WalletSource source) => WalletSource(
              sourceMemberId: source.sourceMemberId,
              amount: source.amount,
            ),
          )
          .toList();
    }
    final List<(int, int)> remaining = payerShares
        .map((MemberShare share) => (share.memberId, _minor(share.amount)))
        .toList();
    final List<WalletSource> result = <WalletSource>[];
    int payerIndex = 0;
    for (final WalletSource source in sources) {
      int sourceRemaining = _minor(source.amount);
      while (sourceRemaining > 0 && payerIndex < remaining.length) {
        final (int memberId, int payerRemaining) = remaining[payerIndex];
        if (payerRemaining <= 0) {
          payerIndex++;
          continue;
        }
        final int allocated = math.min(sourceRemaining, payerRemaining);
        result.add(
          WalletSource(
            sourceMemberId: source.sourceMemberId,
            payerMemberId: memberId,
            amount: allocated / 100,
          ),
        );
        sourceRemaining -= allocated;
        remaining[payerIndex] = (memberId, payerRemaining - allocated);
      }
    }
    return result;
  }

  Future<void> _insertWalletSources(
    DatabaseExecutor db,
    int transactionId,
    List<WalletSource> sources,
  ) async {
    for (int index = 0; index < sources.length; index++) {
      final WalletSource source = sources[index];
      await db.insert('transaction_wallet_sources', <String, Object?>{
        'transaction_id': transactionId,
        'source_member_id': source.sourceMemberId,
        'payer_member_id': source.payerMemberId,
        'amount_minor': _minor(source.amount),
        'sort_order': index,
      });
    }
  }

  Future<void> _insertRecorders(
    DatabaseExecutor db,
    int transactionId,
    List<int> recorderIds,
  ) async {
    for (final int memberId in recorderIds.toSet()) {
      await db.insert('transaction_recorders', <String, Object?>{
        'transaction_id': transactionId,
        'member_id': memberId,
      });
    }
  }

  Future<void> _applyWalletBalances(
    DatabaseExecutor db,
    EntryType type,
    List<WalletSource> sources,
    int direction,
  ) async {
    if (type == EntryType.transfer || type == EntryType.adjustment) return;
    final int sign = type == EntryType.expense ? -direction : direction;
    final int now = DateTime.now().millisecondsSinceEpoch;
    for (final WalletSource source in sources) {
      final int delta = _minor(source.amount) * sign;
      if (source.sourceMemberId == null) {
        final List<Map<String, Object?>> rows = await db.query(
          'wallet_state',
          columns: <String>['common_balance_minor'],
          where: 'id = 1',
          limit: 1,
        );
        final int current = rows.isEmpty
            ? 0
            : rows.first['common_balance_minor'] as int;
        if (current + delta < 0) throw StateError('公共资金不足');
        await db.update('wallet_state', <String, Object?>{
          'common_balance_minor': current + delta,
          'updated_at': now,
        }, where: 'id = 1');
      } else {
        final List<Map<String, Object?>> rows = await db.query(
          'member_wallets',
          columns: <String>['balance_minor'],
          where: 'member_id = ?',
          whereArgs: <Object?>[source.sourceMemberId],
          limit: 1,
        );
        final int current = rows.isEmpty
            ? 0
            : rows.first['balance_minor'] as int;
        if (current + delta < 0) throw StateError('成员荷包余额不足');
        await db.insert('member_wallets', <String, Object?>{
          'member_id': source.sourceMemberId,
          'balance_minor': current + delta,
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
  }

  Future<void> _insertHistory(
    DatabaseExecutor db, {
    required int transactionId,
    required String transactionUuid,
    required String action,
    required int? actorMemberId,
    required String summary,
    required int occurredAt,
  }) async {
    await db.insert('entry_history', <String, Object?>{
      'transaction_id': transactionId,
      'transaction_uuid': transactionUuid,
      'action': action,
      'actor_member_id': actorMemberId,
      'summary': summary,
      'occurred_at': occurredAt,
    });
  }

  String _entryUpdateSummary(LedgerEntry previous, LedgerEntry next) {
    final List<String> changes = <String>[];
    if (_minor(previous.amount) != _minor(next.amount)) changes.add('金额');
    if (previous.category != next.category) changes.add('分类');
    if (previous.memberIds
            .toSet()
            .difference(next.memberIds.toSet())
            .isNotEmpty ||
        next.memberIds
            .toSet()
            .difference(previous.memberIds.toSet())
            .isNotEmpty) {
      changes.add('付款／归属');
    }
    if (previous.fundings.length != next.fundings.length ||
        previous.accountId != next.accountId) {
      changes.add('账户');
    }
    if (previous.walletSources.length != next.walletSources.length) {
      changes.add('荷包来源');
    }
    if (previous.note != next.note) changes.add('备注');
    return changes.isEmpty ? '保存账目' : '修改${changes.join('、')}';
  }

  Future<void> _insertDebts(
    DatabaseExecutor db,
    int transactionId,
    EntryType type,
    List<WalletSource> walletSources,
  ) async {
    if (type != EntryType.expense) return;
    for (final MemberDebt debt in calculateMemberDebts(
      walletSources: walletSources,
    )) {
      await db.insert('member_debts', <String, Object?>{
        'transaction_id': transactionId,
        'creditor_member_id': debt.creditorMemberId,
        'debtor_member_id': debt.debtorMemberId,
        'amount_minor': _minor(debt.amount),
      });
    }
  }

  Future<void> _applyBalance(
    DatabaseExecutor db,
    LedgerEntry entry,
    int direction, {
    List<EntryFunding>? fundings,
  }) async {
    if (entry.type == EntryType.adjustment) return;
    final List<EntryFunding> resolved =
        fundings ??
        (entry.fundings.isNotEmpty
            ? entry.fundings
            : await _resolveFundings(db, entry));
    if (entry.type == EntryType.transfer) {
      if (entry.toAccountId == null) throw StateError('请选择转入账户');
      for (final EntryFunding funding in resolved) {
        final int amount = _minor(funding.amount) * direction;
        await _changeAccountFund(db, funding.accountId, -amount);
        await _changeAccountFund(db, entry.toAccountId!, amount);
      }
    } else {
      for (final EntryFunding funding in resolved) {
        final int amount = _minor(funding.amount) * direction;
        final int delta = entry.type == EntryType.expense ? -amount : amount;
        await _changeAccountFund(db, funding.accountId, delta);
      }
    }
  }

  Future<void> _changeAccountFund(
    DatabaseExecutor db,
    int accountId,
    int deltaMinor,
  ) async {
    final List<Map<String, Object?>> accountRows = await db.query(
      'accounts',
      columns: <String>['balance_minor', 'kind', 'credit_limit_minor'],
      where: 'id = ?',
      whereArgs: <Object?>[accountId],
      limit: 1,
    );
    if (accountRows.isEmpty) throw StateError('账户不存在');
    final Map<String, Object?> account = accountRows.first;
    final AccountKind kind = AccountKind.values.byName(
      account['kind'] as String? ?? 'asset',
    );
    final int nextBalance = (account['balance_minor'] as int) + deltaMinor;
    if (kind == AccountKind.asset && nextBalance < 0) {
      throw StateError('资产账户余额不足');
    }
    if (kind == AccountKind.credit &&
        nextBalance < -(account['credit_limit_minor'] as int)) {
      throw StateError('已超过信用账户额度');
    }

    final int now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'accounts',
      <String, Object?>{'balance_minor': nextBalance, 'updated_at': now},
      where: 'id = ?',
      whereArgs: <Object?>[accountId],
    );
  }

  int _minor(double amount) => (amount * 100).round();
  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  String _uuid(String prefix, int timestamp) =>
      '$prefix-$timestamp-${DateTime.now().microsecondsSinceEpoch}';

  static DateTime? _dateTimeFromMilliseconds(String? value) {
    final int? milliseconds = int.tryParse(value ?? '');
    return milliseconds == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }
}
