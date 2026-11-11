import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yibi/data/app_database.dart';
import 'package:yibi/data/ledger_controller.dart';
import 'package:yibi/data/ledger_repository.dart';
import 'package:yibi/services/snapshot_service.dart';

class _SnapshotRepository extends LedgerRepository {
  _SnapshotRepository() : super(AppDatabase());

  @override
  Future<Map<String, Object?>> exportBackup() async => <String, Object?>{
    'format': 'oneentry-backup',
    'schemaVersion': AppDatabase.schemaVersion,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'tables': <String, Object?>{},
  };
}

void main() {
  test('快照使用完整备份并最多保留 8 份', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'oneentry-snapshots-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final LedgerController controller = LedgerController(_SnapshotRepository());
    addTearDown(controller.dispose);

    for (int index = 0; index < 10; index++) {
      await SnapshotService.create(
        controller,
        reason: index.isEven ? 'manual' : 'before_import',
        directory: directory,
      );
    }
    final List<LedgerSnapshotInfo> snapshots = await SnapshotService.list(
      directory: directory,
    );

    expect(snapshots, hasLength(SnapshotService.maxSnapshots));
    expect(snapshots.first.createdAt.isAfter(snapshots.last.createdAt), isTrue);
    expect(
      await File(snapshots.first.path).readAsString(),
      contains('oneentry-snapshot'),
    );
  });

  test('自动快照在周期内不重复创建', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'oneentry-auto-snapshot-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final LedgerController controller = LedgerController(_SnapshotRepository());
    addTearDown(controller.dispose);

    final LedgerSnapshotInfo? first = await SnapshotService.createIfDue(
      controller,
      directory: directory,
    );
    final LedgerSnapshotInfo? second = await SnapshotService.createIfDue(
      controller,
      directory: directory,
    );

    expect(first, isNotNull);
    expect(second, isNull);
  });
}
