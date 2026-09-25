import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

class TonglvMember {
  const TonglvMember({
    required this.sourceId,
    required this.name,
    required this.colorValue,
    required this.archived,
  });
  final String sourceId;
  final String name;
  final int colorValue;
  final bool archived;
}

class TonglvAccount {
  const TonglvAccount({required this.sourceId, required this.name});
  final String sourceId;
  final String name;
}

class TonglvEntry {
  const TonglvEntry({
    required this.sourceId,
    required this.title,
    required this.note,
    required this.amount,
    required this.occurredAt,
    required this.accountSourceId,
    required this.category,
    required this.memberSourceIds,
  });
  final String sourceId;
  final String title;
  final String note;
  final double amount;
  final DateTime occurredAt;
  final String accountSourceId;
  final String category;
  final List<String> memberSourceIds;
}

class TonglvImportBundle {
  const TonglvImportBundle({
    required this.members,
    required this.accounts,
    required this.entries,
    required this.backupVersion,
  });
  final List<TonglvMember> members;
  final List<TonglvAccount> accounts;
  final List<TonglvEntry> entries;
  final int backupVersion;
}

class TonglvImporter {
  TonglvImporter._();

  static TonglvImportBundle parse(Uint8List bytes) {
    final Archive archive = ZipDecoder().decodeBytes(bytes);
    final ArchiveFile? manifestFile = archive.find('manifest.json');
    if (manifestFile == null) throw const FormatException('缺少同旅 manifest.json');
    final Map<String, Object?> manifest = Map<String, Object?>.from(
      jsonDecode(utf8.decode(manifestFile.content)) as Map,
    );
    if (manifest['format'] != 'copath_migration_zip')
      throw const FormatException('不是同旅迁移 ZIP');
    ArchiveFile? backupFile;
    for (final ArchiveFile file in archive.files) {
      if (file.isFile && file.name.toLowerCase().endsWith('_backup.json')) {
        backupFile = file;
        break;
      }
    }
    if (backupFile == null) throw const FormatException('缺少同旅 backup.json');
    final Map<String, Object?> root = Map<String, Object?>.from(
      jsonDecode(utf8.decode(backupFile.content)) as Map,
    );
    final Map<String, Object?> ledger = Map<String, Object?>.from(
      root['ledger'] as Map? ?? const <String, Object?>{},
    );

    final List<TonglvMember> members =
        List<Object?>.from(root['members'] as List? ?? const <Object?>[]).map((
          value,
        ) {
          final Map<String, Object?> row = Map<String, Object?>.from(
            value as Map,
          );
          return TonglvMember(
            sourceId: _text(row['id']),
            name: _text(row['name']).isEmpty ? '未命名成员' : _text(row['name']),
            colorValue: (row['colorValue'] as num?)?.toInt() ?? 0xFF2E7CF6,
            archived: row['archived'] == true,
          );
        }).toList();
    final List<TonglvAccount> accounts =
        List<Object?>.from(
          ledger['accounts'] as List? ?? const <Object?>[],
        ).map((value) {
          final Map<String, Object?> row = Map<String, Object?>.from(
            value as Map,
          );
          return TonglvAccount(
            sourceId: _text(row['id']),
            name: _text(row['name']).isEmpty ? '同旅账本' : _text(row['name']),
          );
        }).toList();
    final Map<String, String> tags = <String, String>{};
    for (final Object? value in List<Object?>.from(
      ledger['tags'] as List? ?? const <Object?>[],
    )) {
      final Map<String, Object?> row = Map<String, Object?>.from(value as Map);
      tags[_text(row['id'])] = _text(row['name']);
    }
    final List<TonglvEntry> entries = <TonglvEntry>[];
    for (final Object? value in List<Object?>.from(
      ledger['entries'] as List? ?? const <Object?>[],
    )) {
      final Map<String, Object?> row = Map<String, Object?>.from(value as Map);
      final double amount = (row['amount'] as num?)?.toDouble() ?? 0;
      final DateTime? occurredAt = DateTime.tryParse(_text(row['createdAt']));
      if (amount == 0 || occurredAt == null) continue;
      final List<String> tagIds =
          List<Object?>.from(row['tagIds'] as List? ?? const <Object?>[])
              .where((value) => value != null)
              .map(_text)
              .where((value) => value.isNotEmpty)
              .toList();
      final List<String> memberIds =
          List<Object?>.from(
                row['relatedMemberIds'] as List? ?? const <Object?>[],
              )
              .where((value) => value != null)
              .map(_text)
              .where((value) => value.isNotEmpty)
              .toList();
      entries.add(
        TonglvEntry(
          sourceId: _text(row['id']),
          title: _text(row['title']),
          note: _text(row['note']),
          amount: amount,
          occurredAt: occurredAt,
          accountSourceId: _text(row['accountId']),
          category: tagIds.isEmpty ? '其他' : (tags[tagIds.first] ?? '其他'),
          memberSourceIds: memberIds,
        ),
      );
    }
    return TonglvImportBundle(
      members: members,
      accounts: accounts,
      entries: entries,
      backupVersion: (manifest['backupVersion'] as num?)?.toInt() ?? 0,
    );
  }

  static bool looksLikeTonglv(Uint8List bytes) {
    try {
      final Archive archive = ZipDecoder().decodeBytes(bytes);
      final ArchiveFile? manifest = archive.find('manifest.json');
      return manifest != null &&
          utf8.decode(manifest.content).contains('copath_migration_zip');
    } catch (_) {
      return false;
    }
  }

  static String _text(Object? value) => (value ?? '')
      .toString()
      .replaceAll(RegExp(r'[\u0000-\u001f\u007f]'), ' ')
      .trim();
}
