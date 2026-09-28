import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static const int schemaVersion = 4;
  static const String fileName = 'oneentry.db';

  Database? _database;

  Future<Database> get database async => _database ??= await _open();

  Future<Database> _open() async {
    final String root = await getDatabasesPath();
    return openDatabase(
      p.join(root, fileName),
      version: schemaVersion,
      onConfigure: (Database db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (Database db, int version) async {
        await _createVersion1(db);
        if (version >= 2) await _migrate1To2(db);
        if (version >= 3) await _migrate2To3(db);
        if (version >= 4) await _migrate3To4(db);
        await _seed(db);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        await db.transaction((Transaction txn) async {
          int version = oldVersion;
          if (version < 2 && newVersion >= 2) {
            await _migrate1To2(txn);
            version = 2;
          }
          if (version < 3 && newVersion >= 3) {
            await _migrate2To3(txn);
            version = 3;
          }
          if (version < 4 && newVersion >= 4) {
            await _migrate3To4(txn);
            version = 4;
          }
          if (version != newVersion) {
            throw StateError(
              'Missing database migration: $version → $newVersion',
            );
          }
        });
      },
    );
  }

  Future<void> close() async {
    final Database? db = _database;
    _database = null;
    await db?.close();
  }

  Future<void> _createVersion1(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'cash',
        icon TEXT NOT NULL DEFAULT 'cash',
        opening_balance_minor INTEGER NOT NULL DEFAULT 0,
        balance_minor INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        archived_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        color_value INTEGER NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        archived_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL UNIQUE,
        type TEXT NOT NULL DEFAULT 'both',
        icon TEXT NOT NULL DEFAULT 'tag',
        color_value INTEGER,
        parent_id INTEGER REFERENCES categories(id),
        sort_order INTEGER NOT NULL DEFAULT 0,
        archived_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        type TEXT NOT NULL CHECK(type IN ('expense','income','transfer','adjustment')),
        amount_minor INTEGER NOT NULL CHECK(amount_minor >= 0),
        account_id INTEGER REFERENCES accounts(id),
        to_account_id INTEGER REFERENCES accounts(id),
        category_id INTEGER REFERENCES categories(id),
        occurred_at INTEGER NOT NULL,
        local_date TEXT NOT NULL,
        timezone TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        CHECK(type != 'transfer' OR (account_id IS NOT NULL AND to_account_id IS NOT NULL AND account_id != to_account_id))
      )
    ''');
    await db.execute('''
      CREATE TABLE transaction_members (
        transaction_id INTEGER NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
        member_id INTEGER NOT NULL REFERENCES members(id),
        share_minor INTEGER,
        share_ratio REAL,
        PRIMARY KEY(transaction_id, member_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        period TEXT NOT NULL,
        category_id INTEGER REFERENCES categories(id),
        amount_minor INTEGER NOT NULL CHECK(amount_minor >= 0),
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        UNIQUE(period, category_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _migrate1To2(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE recurring_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('expense','income')),
        amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
        account_id INTEGER REFERENCES accounts(id),
        category_id INTEGER REFERENCES categories(id),
        frequency TEXT NOT NULL CHECK(frequency IN ('day','week','month','year')),
        anchor_date TEXT NOT NULL,
        reminder_hour INTEGER NOT NULL DEFAULT 9,
        reminder_minute INTEGER NOT NULL DEFAULT 0,
        enabled INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE import_jobs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        source_app TEXT NOT NULL,
        file_name TEXT NOT NULL,
        file_hash TEXT NOT NULL,
        status TEXT NOT NULL,
        summary_json TEXT NOT NULL DEFAULT '{}',
        created_at INTEGER NOT NULL,
        UNIQUE(source_app, file_hash)
      )
    ''');
    await db.execute(
      'ALTER TABLE transactions ADD COLUMN recurring_rule_id INTEGER',
    );
    await db.execute('ALTER TABLE transactions ADD COLUMN source_app TEXT');
    await db.execute('ALTER TABLE transactions ADD COLUMN source_row_key TEXT');
    await db.execute(
      'CREATE INDEX idx_transactions_occurred_at ON transactions(occurred_at DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_transactions_account ON transactions(account_id, occurred_at DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_transactions_category ON transactions(category_id, occurred_at DESC)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX idx_transactions_source ON transactions(source_app, source_row_key) WHERE source_app IS NOT NULL AND source_row_key IS NOT NULL',
    );
    await db.execute(
      'CREATE INDEX idx_transaction_members_member ON transaction_members(member_id, transaction_id)',
    );
    await db.execute('CREATE INDEX idx_budgets_period ON budgets(period)');
  }

  Future<void> _migrate2To3(DatabaseExecutor db) async {
    await db.execute(
      'ALTER TABLE transactions ADD COLUMN adjustment_delta_minor INTEGER NOT NULL DEFAULT 0',
    );
    const Map<String, String> expenseIcons = <String, String>{
      '餐饮': 'restaurant',
      '交通': 'car',
      '购物': 'shopping',
      '居住': 'home',
      '娱乐': 'game',
      '医疗': 'medical',
      '学习': 'book',
      '旅行': 'flight',
      '其他': 'tag',
    };
    const Map<String, String> incomeIcons = <String, String>{
      '红包': 'gift',
      '工资': 'salary',
      '理财': 'chart',
    };
    for (final MapEntry<String, String> item in expenseIcons.entries) {
      await db.update(
        'categories',
        <String, Object?>{'type': 'expense', 'icon': item.value},
        where: 'name = ?',
        whereArgs: <Object?>[item.key],
      );
    }
    for (final MapEntry<String, String> item in incomeIcons.entries) {
      await db.update(
        'categories',
        <String, Object?>{'type': 'income', 'icon': item.value},
        where: 'name = ?',
        whereArgs: <Object?>[item.key],
      );
    }
    await db.update(
      'categories',
      <String, Object?>{'type': 'transfer', 'icon': 'transfer'},
      where: 'name = ?',
      whereArgs: <Object?>['转账'],
    );
  }

  Future<void> _migrate3To4(DatabaseExecutor db) async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final List<Map<String, Object?>> learningRows = await db.query(
      'categories',
      columns: <String>['id'],
      where: 'name = ?',
      whereArgs: <Object?>['学习'],
      limit: 1,
    );
    final List<Map<String, Object?>> educationRows = await db.query(
      'categories',
      columns: <String>['id'],
      where: 'name = ?',
      whereArgs: <Object?>['教育'],
      limit: 1,
    );
    if (educationRows.isNotEmpty && learningRows.isEmpty) {
      await db.update(
        'categories',
        <String, Object?>{
          'name': '学习',
          'type': 'expense',
          'icon': 'book',
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: <Object?>[educationRows.first['id']],
      );
    } else if (educationRows.isNotEmpty && learningRows.isNotEmpty) {
      final int educationId = educationRows.first['id'] as int;
      final int learningId = learningRows.first['id'] as int;
      await db.update(
        'transactions',
        <String, Object?>{'category_id': learningId},
        where: 'category_id = ?',
        whereArgs: <Object?>[educationId],
      );
      await db.update(
        'recurring_rules',
        <String, Object?>{'category_id': learningId},
        where: 'category_id = ?',
        whereArgs: <Object?>[educationId],
      );
      final List<Map<String, Object?>> educationBudgets = await db.query(
        'budgets',
        where: 'category_id = ?',
        whereArgs: <Object?>[educationId],
      );
      for (final Map<String, Object?> budget in educationBudgets) {
        final String period = budget['period'] as String;
        final List<Map<String, Object?>> existing = await db.query(
          'budgets',
          columns: <String>['id', 'amount_minor'],
          where: 'period = ? AND category_id = ?',
          whereArgs: <Object?>[period, learningId],
          limit: 1,
        );
        if (existing.isEmpty) {
          await db.update(
            'budgets',
            <String, Object?>{'category_id': learningId, 'updated_at': now},
            where: 'id = ?',
            whereArgs: <Object?>[budget['id']],
          );
        } else {
          await db.update(
            'budgets',
            <String, Object?>{
              'amount_minor':
                  (existing.first['amount_minor'] as int) +
                  (budget['amount_minor'] as int),
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: <Object?>[existing.first['id']],
          );
          await db.delete(
            'budgets',
            where: 'id = ?',
            whereArgs: <Object?>[budget['id']],
          );
        }
      }
      await db.delete(
        'categories',
        where: 'id = ?',
        whereArgs: <Object?>[educationId],
      );
    }

    const List<(String, String, String)> defaults = <(String, String, String)>[
      ('餐饮', 'expense', 'restaurant'),
      ('交通', 'expense', 'car'),
      ('购物', 'expense', 'shopping'),
      ('居住', 'expense', 'home'),
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
      final item = defaults[index];
      final List<Map<String, Object?>> rows = await db.query(
        'categories',
        columns: <String>['id'],
        where: 'name = ?',
        whereArgs: <Object?>[item.$1],
        limit: 1,
      );
      if (rows.isEmpty) {
        await db.insert('categories', <String, Object?>{
          'uuid': 'default-v4-category-${index + 1}-$now',
          'name': item.$1,
          'type': item.$2,
          'icon': item.$3,
          'sort_order': index,
          'created_at': now,
          'updated_at': now,
        });
      } else {
        await db.update(
          'categories',
          <String, Object?>{
            'type': item.$2,
            'icon': item.$3,
            'sort_order': index,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: <Object?>[rows.first['id']],
        );
      }
    }
  }

  Future<void> _seed(Database db) async {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final DateTime current = DateTime.now();
    final String period =
        '${current.year}-${current.month.toString().padLeft(2, '0')}';
    final Batch batch = db.batch();
    final List<(String, String, int)> accountSeeds = <(String, String, int)>[
      ('现金', 'cash', 328050),
      ('支付宝', 'wallet', 1256020),
      ('微信', 'chat', 89000),
      ('招商银行', 'bank', 4523000),
      ('信用卡', 'card', -218060),
    ];
    for (int index = 0; index < accountSeeds.length; index++) {
      final seed = accountSeeds[index];
      batch.insert('accounts', <String, Object?>{
        'uuid': 'seed-account-${index + 1}',
        'name': seed.$1,
        'icon': seed.$2,
        'opening_balance_minor': seed.$3,
        'balance_minor': seed.$3,
        'sort_order': index,
        'created_at': now,
        'updated_at': now,
      });
    }
    final List<(String, int)> memberSeeds = <(String, int)>[
      ('我', 0xFF2E7CF6),
      ('小明', 0xFFF5A623),
      ('小红', 0xFFEB4E6B),
      ('爸妈', 0xFF18B681),
      ('室友', 0xFF8E6BE0),
    ];
    for (int index = 0; index < memberSeeds.length; index++) {
      batch.insert('members', <String, Object?>{
        'uuid': 'seed-member-${index + 1}',
        'name': memberSeeds[index].$1,
        'color_value': memberSeeds[index].$2,
        'sort_order': index,
        'created_at': now,
        'updated_at': now,
      });
    }
    const List<(String, String, String)> categories =
        <(String, String, String)>[
          ('餐饮', 'expense', 'restaurant'),
          ('交通', 'expense', 'car'),
          ('购物', 'expense', 'shopping'),
          ('居住', 'expense', 'home'),
          ('娱乐', 'expense', 'game'),
          ('医疗', 'expense', 'medical'),
          ('学习', 'expense', 'book'),
          ('旅行', 'expense', 'flight'),
          ('通讯', 'expense', 'phone'),
          ('健身', 'expense', 'fitness'),
          ('美妆', 'expense', 'beauty'),
          ('服饰', 'expense', 'clothes'),
          ('红包', 'income', 'red_packet'),
          ('转账', 'transfer', 'transfer'),
          ('工资', 'income', 'salary'),
          ('理财', 'income', 'chart'),
          ('打赏', 'income', 'tip'),
          ('报销', 'income', 'reimbursement'),
          ('礼物', 'income', 'gift'),
          ('兼职', 'income', 'part_time'),
          ('其他', 'both', 'more'),
        ];
    for (int index = 0; index < categories.length; index++) {
      batch.insert('categories', <String, Object?>{
        'uuid': 'seed-category-${index + 1}',
        'name': categories[index].$1,
        'type': categories[index].$2,
        'icon': categories[index].$3,
        'sort_order': index,
        'created_at': now,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    batch.insert('budgets', <String, Object?>{
      'period': period,
      'category_id': null,
      'amount_minor': 500000,
      'created_at': now,
      'updated_at': now,
    });
    await batch.commit(noResult: true);
    await _seedPreviewEntries(db, current, now);
  }

  Future<void> _seedPreviewEntries(
    Database db,
    DateTime current,
    int now,
  ) async {
    final List<(String, int, String, int, String, List<int>)> seeds =
        <(String, int, String, int, String, List<int>)>[
          ('expense', 26800, '餐饮', 2, '和朋友吃饭', <int>[1, 2]),
          ('expense', 5650, '交通', 3, '打车', <int>[1]),
          ('income', 1280000, '工资', 2, '本月工资', <int>[1]),
        ];
    for (int index = 0; index < seeds.length; index++) {
      final seed = seeds[index];
      final List<Map<String, Object?>> categoryRows = await db.query(
        'categories',
        columns: <String>['id'],
        where: 'name = ?',
        whereArgs: <Object?>[seed.$3],
        limit: 1,
      );
      final DateTime occurred = index == 0
          ? DateTime(current.year, current.month, current.day, 19, 30)
          : index == 1
          ? DateTime(
              current.year,
              current.month,
              current.day > 1 ? current.day - 1 : 1,
              9,
              15,
            )
          : DateTime(current.year, current.month, 8, 8);
      final int
      transactionId = await db.insert('transactions', <String, Object?>{
        'uuid': 'seed-transaction-${index + 1}-$now',
        'type': seed.$1,
        'amount_minor': seed.$2,
        'account_id': seed.$4,
        'category_id': categoryRows.first['id'],
        'occurred_at': occurred.millisecondsSinceEpoch,
        'local_date':
            '${occurred.year}-${occurred.month.toString().padLeft(2, '0')}-${occurred.day.toString().padLeft(2, '0')}',
        'timezone': occurred.timeZoneName,
        'note': seed.$5,
        'created_at': now,
        'updated_at': now,
      });
      for (final int memberId in seed.$6) {
        await db.insert('transaction_members', <String, Object?>{
          'transaction_id': transactionId,
          'member_id': memberId,
        });
      }
    }
  }
}
