import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yibi/data/app_database.dart';
import 'package:yibi/data/ledger_repository.dart';
import 'package:yibi/models/ledger_models.dart';

const List<String> version5Tables = <String>[
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

Future<void> writeSanitizedVersion5Data(Database db) async {
  const int now = 1763880000000;
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
      'id': 1,
      'uuid': 'fixture-account-wallet',
      'name': '测试钱包',
      'type': 'wallet',
      'icon': 'wallet',
      'opening_balance_minor': 5000,
      'balance_minor': 4300,
      'sort_order': 0,
      'created_at': now,
      'updated_at': now,
    });
    await txn.insert('accounts', <String, Object?>{
      'id': 2,
      'uuid': 'fixture-account-bank',
      'name': '测试银行卡',
      'type': 'bank',
      'icon': 'bank',
      'opening_balance_minor': 2000,
      'balance_minor': 3200,
      'sort_order': 1,
      'created_at': now,
      'updated_at': now,
    });
    for (final (int, String, int) member in <(int, String, int)>[
      (1, '成员甲', 0xFF2E7CF6),
      (2, '成员乙', 0xFFF5A623),
    ]) {
      await txn.insert('members', <String, Object?>{
        'id': member.$1,
        'uuid': 'fixture-member-${member.$1}',
        'name': member.$2,
        'color_value': member.$3,
        'sort_order': member.$1 - 1,
        'created_at': now,
        'updated_at': now,
      });
    }
    for (final (int, String, String, String) category
        in <(int, String, String, String)>[
          (1, '测试支出', 'expense', 'shopping'),
          (2, '测试收入', 'income', 'salary'),
        ]) {
      await txn.insert('categories', <String, Object?>{
        'id': category.$1,
        'uuid': 'fixture-category-${category.$1}',
        'name': category.$2,
        'type': category.$3,
        'icon': category.$4,
        'sort_order': category.$1 - 1,
        'created_at': now,
        'updated_at': now,
      });
    }
    await txn.insert('transactions', <String, Object?>{
      'id': 1,
      'uuid': 'fixture-expense',
      'type': 'expense',
      'amount_minor': 500,
      'account_id': 1,
      'category_id': 1,
      'occurred_at': now,
      'local_date': '2025-11-23',
      'timezone': 'UTC',
      'note': '脱敏支出',
      'created_at': now,
      'updated_at': now,
    });
    await txn.insert('transactions', <String, Object?>{
      'id': 2,
      'uuid': 'fixture-income',
      'type': 'income',
      'amount_minor': 1000,
      'account_id': 2,
      'category_id': 2,
      'occurred_at': now + 1000,
      'local_date': '2025-11-23',
      'timezone': 'UTC',
      'note': '脱敏收入',
      'created_at': now,
      'updated_at': now,
    });
    await txn.insert('transactions', <String, Object?>{
      'id': 3,
      'uuid': 'fixture-transfer',
      'type': 'transfer',
      'amount_minor': 200,
      'account_id': 1,
      'to_account_id': 2,
      'occurred_at': now + 2000,
      'local_date': '2025-11-23',
      'timezone': 'UTC',
      'note': '脱敏转账',
      'created_at': now,
      'updated_at': now,
    });
    await txn.insert('transaction_members', <String, Object?>{
      'transaction_id': 1,
      'member_id': 1,
      'share_minor': 500,
    });
    await txn.insert('transaction_members', <String, Object?>{
      'transaction_id': 2,
      'member_id': 2,
      'share_minor': 1000,
    });
    await txn.insert('budgets', <String, Object?>{
      'period': '2025-11',
      'amount_minor': 3000,
      'created_at': now,
      'updated_at': now,
    });
    await txn.insert('settings', <String, Object?>{
      'key': 'theme_mode',
      'value': 'system',
      'updated_at': now,
    });
  });
}

Future<Map<String, Object?>> exportVersion5Fixture(Database db) async =>
    <String, Object?>{
      'format': 'oneentry-backup',
      'schemaVersion': 5,
      'exportedAt': '2025-11-23T00:00:00.000Z',
      'tables': <String, Object?>{
        for (final String table in version5Tables) table: await db.query(table),
      },
    };

void expectMigratedFixture(LedgerSnapshot snapshot) {
  expect(snapshot.accounts, hasLength(2));
  expect(snapshot.members, hasLength(2));
  expect(snapshot.entries, hasLength(3));
  expect(snapshot.commonFund, 75);
  expect(snapshot.memberWallets.values, everyElement(0));
  expect(
    snapshot.entries.where(
      (LedgerEntry entry) =>
          entry.type == EntryType.expense || entry.type == EntryType.income,
    ),
    everyElement(
      predicate<LedgerEntry>(
        (LedgerEntry entry) =>
            entry.walletSources.length == 1 &&
            entry.walletSources.single.common &&
            (entry.walletSources.single.amount - entry.amount).abs() < .005,
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('v5 数据库可连续升级到 v9', () async {
    final Directory temp = Directory.systemTemp.createTempSync(
      'oneentry-migration-fixture-',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    final String path = p.join(temp.path, 'upgrade.db');
    final AppDatabase version5 = AppDatabase(
      path: path,
      version: 5,
      seedOnCreate: false,
    );
    await writeSanitizedVersion5Data(await version5.database);
    await version5.close();

    final AppDatabase version8 = AppDatabase(path: path, seedOnCreate: false);
    addTearDown(version8.close);
    expectMigratedFixture(await LedgerRepository(version8).load());
  });

  test('v5 完整备份可恢复到 v9', () async {
    final Directory temp = Directory.systemTemp.createTempSync(
      'oneentry-restore-fixture-',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    final AppDatabase source = AppDatabase(
      path: p.join(temp.path, 'source.db'),
      version: 5,
      seedOnCreate: false,
    );
    await writeSanitizedVersion5Data(await source.database);
    final Map<String, Object?> backup = await exportVersion5Fixture(
      await source.database,
    );
    await source.close();

    final AppDatabase destination = AppDatabase(
      path: p.join(temp.path, 'destination.db'),
      seedOnCreate: false,
    );
    addTearDown(destination.close);
    final LedgerRepository repository = LedgerRepository(destination);
    await repository.replaceFromBackup(backup);
    expectMigratedFixture(await repository.load());
  });

  test('永久删除账户只允许无余额且无历史账目的空账户', () async {
    final Directory temp = Directory.systemTemp.createTempSync(
      'oneentry-account-delete-',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    final AppDatabase database = AppDatabase(
      path: p.join(temp.path, 'delete.db'),
      seedOnCreate: false,
    );
    addTearDown(database.close);
    final LedgerRepository repository = LedgerRepository(database);
    await repository.addAccount(name: '有余额', openingBalance: 10);
    final LedgerSnapshot first = await repository.load();
    await expectLater(
      repository.deleteAccount(first.accounts.single.id),
      throwsA(isA<StateError>()),
    );
    final LedgerAccount funded = first.accounts.single;
    await repository.updateAccount(
      funded.id,
      name: funded.name,
      icon: funded.icon,
      balance: 0,
      kind: funded.kind,
      creditLimit: funded.creditLimit,
    );
    await expectLater(
      repository.deleteAccount(funded.id),
      throwsA(isA<StateError>()),
    );

    await repository.addAccount(name: '空账户', openingBalance: 0);
    final LedgerSnapshot second = await repository.load();
    final int emptyId = second.accounts
        .firstWhere((LedgerAccount account) => account.name == '空账户')
        .id;
    await repository.deleteAccount(emptyId);
    expect(
      (await repository.load()).accounts.any(
        (LedgerAccount account) => account.id == emptyId,
      ),
      isFalse,
    );
  });

  test('减少账户余额不会静默扣除成员荷包', () async {
    final Directory temp = Directory.systemTemp.createTempSync(
      'oneentry-account-adjust-',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    final AppDatabase database = AppDatabase(
      path: p.join(temp.path, 'adjust.db'),
      seedOnCreate: false,
    );
    addTearDown(database.close);
    final LedgerRepository repository = LedgerRepository(database);
    await repository.addMember(name: '成员甲', colorValue: 0xFF2E7CF6);
    await repository.addAccount(name: '测试账户', openingBalance: 10);
    LedgerSnapshot snapshot = await repository.load();
    final int memberId = snapshot.members.single.id;
    final LedgerAccount account = snapshot.accounts.single;
    await repository.setWalletBalances(
      commonFund: 0,
      memberBalances: <int, double>{memberId: 10},
    );
    await expectLater(
      repository.updateAccount(
        account.id,
        name: account.name,
        icon: account.icon,
        balance: 5,
        kind: account.kind,
        creditLimit: account.creditLimit,
      ),
      throwsA(isA<StateError>()),
    );
    snapshot = await repository.load();
    expect(snapshot.accounts.single.balance, 10);
    expect(snapshot.memberWallets[memberId], 10);

    await repository.setWalletBalances(
      commonFund: 10,
      memberBalances: <int, double>{memberId: 0},
    );
    await repository.updateAccount(
      account.id,
      name: account.name,
      icon: account.icon,
      balance: 5,
      kind: account.kind,
      creditLimit: account.creditLimit,
    );
    snapshot = await repository.load();
    expect(snapshot.accounts.single.balance, 5);
    expect(snapshot.commonFund, 5);
    expect(snapshot.memberWallets[memberId], 0);
  });

  test('加载时会把未分配资金校准为账户余额', () async {
    final Directory temp = Directory.systemTemp.createTempSync(
      'oneentry-wallet-reconcile-',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    final AppDatabase database = AppDatabase(
      path: p.join(temp.path, 'reconcile.db'),
      seedOnCreate: false,
    );
    addTearDown(database.close);
    final LedgerRepository repository = LedgerRepository(database);
    await repository.addAccount(name: '现金', openingBalance: 100);
    final Database db = await database.database;
    await db.update('wallet_state', <String, Object?>{
      'common_balance_minor': 2500,
    }, where: 'id = 1');

    final LedgerSnapshot snapshot = await repository.load();

    expect(snapshot.accounts.single.balance, 100);
    expect(snapshot.memberWallets.values.fold<double>(0, (a, b) => a + b), 0);
    expect(snapshot.commonFund, 100);
  });

  test('发起者会独立保存并重新载入', () async {
    final Directory temp = Directory.systemTemp.createTempSync(
      'oneentry-initiator-',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    final AppDatabase database = AppDatabase(
      path: p.join(temp.path, 'initiator.db'),
      seedOnCreate: false,
    );
    addTearDown(database.close);
    final LedgerRepository repository = LedgerRepository(database);
    await repository.addMember(name: '成员甲', colorValue: 0xFF2E7CF6);
    await repository.addAccount(name: '现金', openingBalance: 10);
    final LedgerSnapshot initial = await repository.load();
    final int memberId = initial.members.single.id;
    final int accountId = initial.accounts.single.id;

    await repository.addEntry(
      LedgerEntry(
        id: 0,
        type: EntryType.expense,
        amount: 1,
        category: '其他',
        occurredAt: DateTime(2026, 11, 25),
        note: '',
        accountId: accountId,
        initiatedByMemberId: memberId,
        walletSources: const <WalletSource>[WalletSource(amount: 1)],
      ),
    );

    expect(
      (await repository.load()).entries.single.initiatedByMemberId,
      memberId,
    );
  });

  test('归档账户会从当前账户净额和公共资金中移除', () async {
    final Directory temp = Directory.systemTemp.createTempSync(
      'oneentry-archive-balance-',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    final AppDatabase database = AppDatabase(
      path: p.join(temp.path, 'archive.db'),
      seedOnCreate: false,
    );
    addTearDown(database.close);
    final LedgerRepository repository = LedgerRepository(database);
    await repository.addAccount(name: '常用账户', openingBalance: 100);
    await repository.addAccount(name: '旧账户', openingBalance: 50);
    LedgerSnapshot snapshot = await repository.load();
    final int archivedId = snapshot.accounts
        .firstWhere((LedgerAccount item) => item.name == '旧账户')
        .id;

    await repository.setAccountArchived(archivedId, true);
    snapshot = await repository.load();
    expect(
      snapshot.accounts
          .where((LedgerAccount item) => !item.archived)
          .fold<double>(
            0,
            (double sum, LedgerAccount item) => sum + item.balance,
          ),
      100,
    );
    expect(snapshot.commonFund, 100);

    await repository.setAccountArchived(archivedId, false);
    snapshot = await repository.load();
    expect(snapshot.commonFund, 150);
  });

  test('公共资金不足时不会静默扣成员荷包来归档账户', () async {
    final Directory temp = Directory.systemTemp.createTempSync(
      'oneentry-archive-wallet-',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    final AppDatabase database = AppDatabase(
      path: p.join(temp.path, 'archive-wallet.db'),
      seedOnCreate: false,
    );
    addTearDown(database.close);
    final LedgerRepository repository = LedgerRepository(database);
    await repository.addMember(name: '成员甲', colorValue: 0xFF2E7CF6);
    await repository.addAccount(name: '常用账户', openingBalance: 100);
    await repository.addAccount(name: '旧账户', openingBalance: 50);
    LedgerSnapshot snapshot = await repository.load();
    final int memberId = snapshot.members.single.id;
    final int archivedId = snapshot.accounts
        .firstWhere((LedgerAccount item) => item.name == '旧账户')
        .id;
    await repository.setWalletBalances(
      commonFund: 10,
      memberBalances: <int, double>{memberId: 140},
    );

    await expectLater(
      repository.setAccountArchived(archivedId, true),
      throwsA(isA<StateError>()),
    );
    snapshot = await repository.load();
    expect(snapshot.commonFund, 10);
    expect(snapshot.memberWallets[memberId], 140);
    expect(
      snapshot.accounts.firstWhere((item) => item.id == archivedId).archived,
      isFalse,
    );
  });
}
