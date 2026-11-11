import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../data/ledger_controller.dart';

class LedgerSnapshotInfo {
  const LedgerSnapshotInfo({
    required this.path,
    required this.createdAt,
    required this.reason,
    required this.size,
  });

  final String path;
  final DateTime createdAt;
  final String reason;
  final int size;

  String get reasonLabel => switch (reason) {
    'auto' => '自动快照',
    'before_import' => '导入前',
    'before_clear' => '清空前',
    'before_restore' => '恢复前',
    _ => '手动快照',
  };
}

class SnapshotService {
  SnapshotService._();

  static const int maxSnapshots = 8;

  static Future<LedgerSnapshotInfo> create(
    LedgerController controller, {
    String reason = 'manual',
    Directory? directory,
  }) async {
    final Directory target = directory ?? await _defaultDirectory();
    await target.create(recursive: true);
    final DateTime now = DateTime.now();
    final Map<String, Object?> payload = <String, Object?>{
      'format': 'oneentry-snapshot',
      'createdAt': now.toUtc().toIso8601String(),
      'reason': reason,
      'backup': await controller.exportBackup(),
    };
    final String name =
        'snapshot_${now.microsecondsSinceEpoch}_${_safeReason(reason)}.json';
    final File file = File(p.join(target.path, name));
    final File temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(payload), flush: true);
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
    await _trim(target);
    final FileStat stat = await file.stat();
    return LedgerSnapshotInfo(
      path: file.path,
      createdAt: now,
      reason: reason,
      size: stat.size,
    );
  }

  static Future<LedgerSnapshotInfo?> createIfDue(
    LedgerController controller, {
    Duration interval = const Duration(days: 7),
    Directory? directory,
  }) async {
    final List<LedgerSnapshotInfo> snapshots = await list(directory: directory);
    final List<LedgerSnapshotInfo> automatic = snapshots
        .where((LedgerSnapshotInfo item) => item.reason == 'auto')
        .toList();
    if (automatic.isNotEmpty &&
        DateTime.now().difference(automatic.first.createdAt) < interval) {
      return null;
    }
    return create(controller, reason: 'auto', directory: directory);
  }

  static Future<List<LedgerSnapshotInfo>> list({Directory? directory}) async {
    final Directory target = directory ?? await _defaultDirectory();
    if (!await target.exists()) return <LedgerSnapshotInfo>[];
    final List<LedgerSnapshotInfo> result = <LedgerSnapshotInfo>[];
    await for (final FileSystemEntity entity in target.list()) {
      if (entity is! File ||
          !p.basename(entity.path).startsWith('snapshot_') ||
          !entity.path.endsWith('.json')) {
        continue;
      }
      final RegExpMatch? match = RegExp(
        r'^snapshot_(\d+)_([a-z_]+)\.json$',
      ).firstMatch(p.basename(entity.path));
      if (match == null) continue;
      final int? microseconds = int.tryParse(match.group(1)!);
      if (microseconds == null) continue;
      final FileStat stat = await entity.stat();
      result.add(
        LedgerSnapshotInfo(
          path: entity.path,
          createdAt: DateTime.fromMicrosecondsSinceEpoch(microseconds),
          reason: match.group(2)!,
          size: stat.size,
        ),
      );
    }
    result.sort(
      (LedgerSnapshotInfo a, LedgerSnapshotInfo b) =>
          b.createdAt.compareTo(a.createdAt),
    );
    return result;
  }

  static Future<void> restore(
    LedgerController controller,
    LedgerSnapshotInfo snapshot, {
    Directory? directory,
  }) async {
    final Object? decoded = jsonDecode(
      await File(snapshot.path).readAsString(),
    );
    final Map<String, Object?> wrapper = Map<String, Object?>.from(
      decoded as Map,
    );
    if (wrapper['format'] != 'oneentry-snapshot') {
      throw const FormatException('不是有效的一笔快照');
    }
    await create(controller, reason: 'before_restore', directory: directory);
    await controller.replaceFromBackup(
      Map<String, Object?>.from(wrapper['backup'] as Map),
    );
  }

  static Future<void> delete(LedgerSnapshotInfo snapshot) async {
    final File file = File(snapshot.path);
    if (await file.exists()) await file.delete();
  }

  static Future<Directory> _defaultDirectory() async {
    final String root = await getDatabasesPath();
    return Directory(p.join(root, 'oneentry_snapshots'));
  }

  static Future<void> _trim(Directory directory) async {
    final List<LedgerSnapshotInfo> snapshots = await list(directory: directory);
    for (final LedgerSnapshotInfo snapshot in snapshots.skip(maxSnapshots)) {
      await delete(snapshot);
    }
  }

  static String _safeReason(String value) => value
      .toLowerCase()
      .replaceAll(RegExp('[^a-z_]'), '_')
      .replaceAll(RegExp('_+'), '_');
}
