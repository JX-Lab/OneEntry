import 'package:sqflite/sqflite.dart';

import '../models/ledger_models.dart';
import '../services/tonglv_importer.dart';
import 'app_database.dart';

class LedgerSnapshot {
  const LedgerSnapshot({
    required this.accounts,
    required this.members,
    required this.entries,
    required this.monthlyBudget,
    required this.dailyReminderEnabled,
    required this.dailyReminderHour,
    required this.dailyReminderMinute,
    required this.categoryBudgets,
    required this.recurringRules,
    required this.categories,
    required this.multiEnabled,
    required this.splitMode,
    required this.themeMode,
    required this.textScale,
    required this.highContrast,
    required this.readerHints,
    required this.haptics,
  });

  final List<LedgerAccount> accounts;
  final List<LedgerMember> members;
  final List<LedgerEntry> entries;
  final double monthlyBudget;
  final bool dailyReminderEnabled;
  final int dailyReminderHour;
  final int dailyReminderMinute;
  final Map<String, double> categoryBudgets;
  final List<RecurringRule> recurringRules;
  final List<LedgerCategory> categories;
  final bool multiEnabled;
  final String splitMode;
  final String themeMode;
  final double textScale;
  final bool highContrast;
  final bool readerHints;
  final bool haptics;
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
    'budgets',
    'settings',
    'import_jobs',
  ];

  Future<LedgerSnapshot> load() async {
    final Database db = await _appDatabase.database;
    final List<LedgerAccount> accounts = (await db.query(
      'accounts',
      orderBy: 'sort_order, id',
    )).map(_accountFromRow).toList();
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
    for (final Map<String, Object?> row in memberRows) {
      transactionMembers
          .putIfAbsent(row['transaction_id'] as int, () => <int>[])
          .add(row['member_id'] as int);
    }
    final List<LedgerEntry> entries = transactionRows
        .map(
          (Map<String, Object?> row) => _entryFromRow(
            row,
            transactionMembers[row['id'] as int] ?? const <int>[],
          ),
        )
        .toList();
    final DateTime now = DateTime.now();
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
    final List<Map<String, Object?>> categoryRows = await db.query(
      'categories',
      columns: <String>['uuid', 'name', 'type', 'icon'],
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
      entries: entries,
      monthlyBudget: budget,
      dailyReminderEnabled: settings['daily_reminder_enabled'] == '1',
      dailyReminderHour:
          int.tryParse(settings['daily_reminder_hour'] ?? '') ?? 20,
      dailyReminderMinute:
          int.tryParse(settings['daily_reminder_minute'] ?? '') ?? 0,
      categoryBudgets: categoryBudgets,
      recurringRules: ruleRows.map(_ruleFromRow).toList(),
      categories: categoryRows.map(_categoryFromRow).toList(),
      multiEnabled: settings['multi_enabled'] != '0',
      splitMode: settings['split_mode'] ?? 'equal',
      themeMode: settings['theme_mode'] ?? 'system',
      textScale: double.tryParse(settings['text_scale'] ?? '') ?? 1,
      highContrast: settings['high_contrast'] == '1',
      readerHints: settings['reader_hints'] != '0',
      haptics: settings['haptics'] != '0',
    );
  }

  Future<LedgerEntry> addEntry(LedgerEntry draft) async {
    final Database db = await _appDatabase.database;
    final int now = DateTime.now().millisecondsSinceEpoch;
    return db.transaction((Transaction txn) async {
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
          'account_id': null,
          'category_id': categoryId,
          'frequency': draft.recurringFrequency,
          'anchor_date': _dateKey(draft.occurredAt),
          'reminder_hour': draft.occurredAt.hour,
          'reminder_minute': draft.occurredAt.minute,
          'created_at': now,
          'updated_at': now,
        });
      }
      final int transactionId = await txn
          .insert('transactions', <String, Object?>{
            'uuid': _uuid('transaction', now),
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
            'recurring_rule_id': recurringRuleId,
            'created_at': now,
            'updated_at': now,
          });
      await _insertMembers(
        txn,
        transactionId,
        draft.memberIds,
        _minor(draft.amount),
      );
      await _applyBalance(txn, draft, 1);
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
      await _insertMembers(
        txn,
        previous.id,
        next.memberIds,
        _minor(next.amount),
      );
      await _applyBalance(txn, next, 1);
    });
  }

  Future<void> deleteEntry(LedgerEntry entry) async {
    final Database db = await _appDatabase.database;
    await db.transaction((Transaction txn) async {
      await _applyBalance(txn, entry, -1);
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
        where: 'account_id = ? OR to_account_id = ?',
        whereArgs: <Object?>[id, id],
      );
      final List<int> transactionIds = transactionRows
          .map((row) => row['id'] as int)
          .toList();
      for (final Map<String, Object?> row in transactionRows) {
        if (row['type'] != 'transfer') continue;
        final int amount = row['amount_minor'] as int;
        final int fromId = row['account_id'] as int;
        final int toId = row['to_account_id'] as int;
        if (fromId == id) {
          await txn.rawUpdate(
            'UPDATE accounts SET balance_minor = balance_minor - ? WHERE id = ?',
            <Object?>[amount, toId],
          );
        } else {
          await txn.rawUpdate(
            'UPDATE accounts SET balance_minor = balance_minor + ? WHERE id = ?',
            <Object?>[amount, fromId],
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
        where: 'account_id = ? OR to_account_id = ?',
        whereArgs: <Object?>[id, id],
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
    await db.insert('accounts', <String, Object?>{
      'uuid': _uuid('account', now),
      'name': name,
      'type': 'wallet',
      'icon': icon,
      'opening_balance_minor': _minor(openingBalance),
      'balance_minor': _minor(openingBalance),
      'sort_order': order,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> updateAccount(
    int id, {
    required String name,
    required String icon,
    required double balance,
  }) async {
    final Database db = await _appDatabase.database;
    final int now = DateTime.now().millisecondsSinceEpoch;
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
          'balance_minor': nextMinor,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
      final int delta = nextMinor - oldMinor;
      if (delta != 0) {
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

  Future<void> addCategory({
    required String name,
    required EntryType type,
    required String icon,
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
  }) async {
    final Database db = await _appDatabase.database;
    await db.update(
      'categories',
      <String, Object?>{
        'name': name,
        'icon': icon,
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
    required bool changeMembers,
    List<int> memberIds = const <int>[],
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
            recurring: entry.recurring,
            recurringFrequency: entry.recurringFrequency,
            adjustmentDelta: entry.adjustmentDelta,
          );
          await _applyBalance(txn, moved, 1);
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
        if (changeMembers && entry.type != EntryType.adjustment) {
          await txn.delete(
            'transaction_members',
            where: 'transaction_id = ?',
            whereArgs: <Object?>[entry.id],
          );
          await _insertMembers(txn, entry.id, memberIds, _minor(entry.amount));
        }
      }
    });
  }

  Future<void> deleteEntries(List<LedgerEntry> entries) async {
    final Database db = await _appDatabase.database;
    await db.transaction((Transaction txn) async {
      for (final LedgerEntry entry in entries) {
        await _applyBalance(txn, entry, -1);
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
    await db.insert('members', <String, Object?>{
      'uuid': _uuid('member', now),
      'name': name,
      'color_value': colorValue,
      'sort_order': order,
      'created_at': now,
      'updated_at': now,
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
        'transaction_members',
        'transactions',
        'budgets',
        'recurring_rules',
        'import_jobs',
        'categories',
        'members',
        'accounts',
        'settings',
      ]) {
        await txn.delete(table);
      }
      await txn.insert('accounts', <String, Object?>{
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
      await txn.insert('members', <String, Object?>{
        'uuid': _uuid('member', now),
        'name': '我',
        'color_value': 0xFF2E7CF6,
        'sort_order': 0,
        'created_at': now,
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
      'daily_reminder_hour': '$hour',
      'daily_reminder_minute': '$minute',
    }.entries) {
      batch.insert('settings', <String, Object?>{
        'key': entry.key,
        'value': entry.value,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> setPreference(String key, String value) async {
    final Database db = await _appDatabase.database;
    await db.insert('settings', <String, Object?>{
      'key': key,
      'value': value,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
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
        'transaction_members',
        'transactions',
        'budgets',
        'recurring_rules',
        'import_jobs',
        'categories',
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
    });
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
        final int delta = type == 'expense' ? -amountMinor : amountMinor;
        await txn.rawUpdate(
          'UPDATE accounts SET balance_minor = balance_minor + ?, updated_at = ? WHERE id = ?',
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

  LedgerEntry _entryFromRow(Map<String, Object?> row, List<int> memberIds) {
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
    int amountMinor,
  ) async {
    if (memberIds.isEmpty) return;
    final int base = amountMinor ~/ memberIds.length;
    int remainder = amountMinor % memberIds.length;
    for (final int memberId in memberIds) {
      final int share = base + (remainder > 0 ? 1 : 0);
      if (remainder > 0) remainder--;
      await db.insert('transaction_members', <String, Object?>{
        'transaction_id': transactionId,
        'member_id': memberId,
        'share_minor': share,
        'share_ratio': 1 / memberIds.length,
      });
    }
  }

  Future<void> _applyBalance(
    DatabaseExecutor db,
    LedgerEntry entry,
    int direction,
  ) async {
    final int amount = _minor(entry.amount) * direction;
    if (entry.type == EntryType.adjustment) return;
    if (entry.type == EntryType.transfer) {
      await db.rawUpdate(
        'UPDATE accounts SET balance_minor = balance_minor - ?, updated_at = ? WHERE id = ?',
        <Object?>[
          amount,
          DateTime.now().millisecondsSinceEpoch,
          entry.accountId,
        ],
      );
      await db.rawUpdate(
        'UPDATE accounts SET balance_minor = balance_minor + ?, updated_at = ? WHERE id = ?',
        <Object?>[
          amount,
          DateTime.now().millisecondsSinceEpoch,
          entry.toAccountId,
        ],
      );
    } else {
      final int delta = entry.type == EntryType.expense ? -amount : amount;
      await db.rawUpdate(
        'UPDATE accounts SET balance_minor = balance_minor + ?, updated_at = ? WHERE id = ?',
        <Object?>[
          delta,
          DateTime.now().millisecondsSinceEpoch,
          entry.accountId,
        ],
      );
    }
  }

  int _minor(double amount) => (amount * 100).round();
  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  String _uuid(String prefix, int timestamp) =>
      '$prefix-$timestamp-${DateTime.now().microsecondsSinceEpoch}';
}
