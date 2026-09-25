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
  final List<String> categories;
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
      columns: <String>['name'],
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
      categories: categoryRows.map((row) => row['name'] as String).toList(),
    );
  }

  Future<LedgerEntry> addEntry(LedgerEntry draft) async {
    final Database db = await _appDatabase.database;
    final int now = DateTime.now().millisecondsSinceEpoch;
    return db.transaction((Transaction txn) async {
      final int? categoryId = draft.type == EntryType.transfer
          ? null
          : await _categoryId(txn, draft.category, now);
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

  Future<void> updateAccount(int id, {required String name}) async {
    final Database db = await _appDatabase.database;
    await db.update(
      'accounts',
      <String, Object?>{
        'name': name,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
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
    final int categoryId = await _categoryId(db, rule.category, now);
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
    TonglvImportBundle bundle,
  ) async {
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

      int imported = 0;
      int skipped = 0;
      for (final TonglvEntry entry in bundle.entries) {
        final int duplicate =
            Sqflite.firstIntValue(
              await txn.rawQuery(
                'SELECT COUNT(*) FROM transactions WHERE source_app = ? AND source_row_key = ?',
                <Object?>['tonglv', entry.sourceId],
              ),
            ) ??
            0;
        if (duplicate > 0) {
          skipped++;
          continue;
        }
        final int categoryId = await _categoryId(txn, entry.category, now);
        final int accountId =
            accountIds[entry.accountSourceId] ?? fallbackAccountId;
        final String type = entry.amount < 0 ? 'expense' : 'income';
        final int amountMinor = _minor(entry.amount.abs());
        final int transactionId = await txn.insert(
          'transactions',
          <String, Object?>{
            'uuid': 'tonglv-transaction-${entry.sourceId}',
            'type': type,
            'amount_minor': amountMinor,
            'account_id': accountId,
            'category_id': categoryId,
            'occurred_at': entry.occurredAt.millisecondsSinceEpoch,
            'local_date': _dateKey(entry.occurredAt),
            'timezone': entry.occurredAt.timeZoneName,
            'note': <String>[
              entry.title,
              entry.note,
            ].where((value) => value.isNotEmpty).join(' · '),
            'source_app': 'tonglv',
            'source_row_key': entry.sourceId,
            'created_at': now,
            'updated_at': now,
          },
        );
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
        'source_app': 'tonglv',
        'file_name': '同旅迁移备份',
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
    archived: row['archived_at'] != null,
  );

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
    accountId: row['account_id'] as int,
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
    );
  }

  Future<int> _categoryId(DatabaseExecutor db, String name, int now) async {
    final List<Map<String, Object?>> rows = await db.query(
      'categories',
      columns: <String>['id'],
      where: 'name = ?',
      whereArgs: <Object?>[name],
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first['id'] as int;
    return db.insert('categories', <String, Object?>{
      'uuid': _uuid('category', now),
      'name': name,
      'type': 'both',
      'icon': 'tag',
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
