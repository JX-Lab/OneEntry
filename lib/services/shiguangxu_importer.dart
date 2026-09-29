import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'tonglv_importer.dart';

class ShiguangxuImporter {
  ShiguangxuImporter._();

  static bool looksLike(Uint8List bytes) {
    try {
      final Uint8List xlsx = _unwrapXlsx(bytes);
      final List<List<String>> rows = _readRows(xlsx);
      return rows.any(_isHeaderRow);
    } catch (_) {
      return false;
    }
  }

  static TonglvImportBundle parse(Uint8List bytes) {
    final Uint8List xlsx = _unwrapXlsx(bytes);
    final List<List<String>> rows = _readRows(xlsx);
    final int headerIndex = rows.indexWhere(_isHeaderRow);
    if (headerIndex < 0) {
      throw const FormatException('时光序表格中没有找到日期、账户、分类、金额等字段');
    }
    final Map<String, int> columns = <String, int>{};
    for (int index = 0; index < rows[headerIndex].length; index++) {
      final String name = rows[headerIndex][index].trim();
      if (name.isNotEmpty) columns[name] = index;
    }
    final List<_ShiguangxuRow> parsedRows = <_ShiguangxuRow>[];
    for (int index = headerIndex + 1; index < rows.length; index++) {
      final List<String> row = rows[index];
      final DateTime? date = _date(_value(row, columns['日期']));
      final double? rawAmount = _amount(_value(row, columns['金额']));
      if (date == null || rawAmount == null || rawAmount == 0) continue;
      final String type = _value(row, columns['类型']);
      final double amount = type.contains('支出')
          ? -rawAmount.abs()
          : type.contains('收入')
          ? rawAmount.abs()
          : rawAmount;
      parsedRows.add(
        _ShiguangxuRow(
          rowNumber: index + 1,
          occurredAt: date,
          ledger: _value(row, columns['账本']),
          account: _value(row, columns['账户']),
          category: _value(row, columns['分类']),
          amount: amount,
          note: _value(row, columns['备注']),
        ),
      );
    }
    if (parsedRows.isEmpty) throw const FormatException('时光序表格中没有可导入的账目');

    final Set<String> ledgerNames = parsedRows
        .map((row) => row.ledger)
        .where((name) => name.isNotEmpty)
        .toSet();
    String accountName(_ShiguangxuRow row) {
      final String account = row.account.isEmpty ? '时光序账户' : row.account;
      if (ledgerNames.length <= 1 || row.ledger.isEmpty) return account;
      return '${row.ledger} · $account';
    }

    final Map<String, TonglvAccount> accounts = <String, TonglvAccount>{};
    final List<TonglvEntry> entries = <TonglvEntry>[];
    for (final _ShiguangxuRow row in parsedRows) {
      final String account = accountName(row);
      accounts.putIfAbsent(
        account,
        () => TonglvAccount(sourceId: account, name: account),
      );
      String category = row.category.isEmpty ? '其他' : row.category;
      if (category == '教育') category = '学习';
      String note = row.note;
      if (category == '转账') {
        category = '其他';
        note = <String>[
          '原分类：转账',
          note,
        ].where((value) => value.isNotEmpty).join(' · ');
      }
      final String canonical = <Object>[
        row.occurredAt.toIso8601String(),
        row.ledger,
        row.account,
        row.category,
        row.amount.toStringAsFixed(2),
        row.note,
      ].join('|');
      entries.add(
        TonglvEntry(
          sourceId: '${row.rowNumber}-${_fnv1a(canonical)}',
          title: '',
          note: note,
          amount: row.amount,
          occurredAt: row.occurredAt,
          accountSourceId: account,
          category: category,
          memberSourceIds: const <String>[],
        ),
      );
    }
    return TonglvImportBundle(
      members: const <TonglvMember>[],
      accounts: accounts.values.toList(),
      entries: entries,
      backupVersion: 1,
    );
  }

  static Uint8List _unwrapXlsx(Uint8List bytes) {
    final Archive archive = ZipDecoder().decodeBytes(bytes);
    if (archive.find('[Content_Types].xml') != null &&
        archive.find('xl/workbook.xml') != null) {
      return bytes;
    }
    for (final ArchiveFile file in archive.files) {
      if (file.isFile && file.name.toLowerCase().endsWith('.xlsx')) {
        return Uint8List.fromList(file.content as List<int>);
      }
    }
    throw const FormatException('ZIP 中没有找到 XLSX 账本');
  }

  static List<List<String>> _readRows(Uint8List xlsx) {
    final Archive archive = ZipDecoder().decodeBytes(xlsx);
    final List<String> sharedStrings = _sharedStrings(archive);
    final List<ArchiveFile> sheets = archive.files
        .where(
          (file) =>
              file.isFile &&
              RegExp(r'^xl/worksheets/sheet\d+\.xml$').hasMatch(file.name),
        )
        .toList();
    final List<List<String>> allRows = <List<String>>[];
    for (final ArchiveFile sheet in sheets) {
      final String xml = utf8.decode(sheet.content as List<int>);
      final List<List<String>> rows = _sheetRows(xml, sharedStrings);
      if (rows.any(_isHeaderRow)) return rows;
      allRows.addAll(rows);
    }
    return allRows;
  }

  static List<String> _sharedStrings(Archive archive) {
    final ArchiveFile? file = archive.find('xl/sharedStrings.xml');
    if (file == null) return const <String>[];
    final String xml = utf8.decode(file.content as List<int>);
    return RegExp(r'<si(?:\s[^>]*)?>([\s\S]*?)</si>')
        .allMatches(xml)
        .map(
          (match) => RegExp(r'<t(?:\s[^>]*)?>([\s\S]*?)</t>')
              .allMatches(match.group(1) ?? '')
              .map((text) => _xmlText(text.group(1) ?? ''))
              .join(),
        )
        .toList();
  }

  static List<List<String>> _sheetRows(String xml, List<String> sharedStrings) {
    final List<List<String>> rows = <List<String>>[];
    for (final RegExpMatch rowMatch in RegExp(
      r'<row(?:\s[^>]*)?>([\s\S]*?)</row>',
    ).allMatches(xml)) {
      final Map<int, String> values = <int, String>{};
      int sequentialColumn = 0;
      for (final RegExpMatch cellMatch in RegExp(
        r'<c([^>]*)>([\s\S]*?)</c>',
      ).allMatches(rowMatch.group(1) ?? '')) {
        final String attributes = cellMatch.group(1) ?? '';
        final String content = cellMatch.group(2) ?? '';
        final RegExpMatch? ref = RegExp(
          r'\br="([A-Z]+)\d+"',
        ).firstMatch(attributes);
        final int column = ref == null
            ? sequentialColumn
            : _columnIndex(ref.group(1)!);
        sequentialColumn = column + 1;
        final String type =
            RegExp(r'\bt="([^"]+)"').firstMatch(attributes)?.group(1) ?? '';
        String value = '';
        if (type == 'inlineStr') {
          value =
              RegExp(
                r'<t(?:\s[^>]*)?>([\s\S]*?)</t>',
              ).firstMatch(content)?.group(1) ??
              '';
          value = _xmlText(value);
        } else {
          final String raw =
              RegExp(r'<v>([\s\S]*?)</v>').firstMatch(content)?.group(1) ?? '';
          if (type == 's') {
            final int? index = int.tryParse(raw);
            value = index != null && index >= 0 && index < sharedStrings.length
                ? sharedStrings[index]
                : '';
          } else {
            value = _xmlText(raw);
          }
        }
        values[column] = value.trim();
      }
      if (values.isEmpty) {
        rows.add(const <String>[]);
      } else {
        final int width = values.keys.reduce((a, b) => a > b ? a : b) + 1;
        rows.add(List<String>.generate(width, (index) => values[index] ?? ''));
      }
    }
    return rows;
  }

  static bool _isHeaderRow(List<String> row) {
    final Set<String> values = row.map((value) => value.trim()).toSet();
    return <String>[
      '日期',
      '账本',
      '账户',
      '分类',
      '金额',
      '备注',
      '类型',
    ].every(values.contains);
  }

  static String _value(List<String> row, int? index) =>
      index == null || index < 0 || index >= row.length
      ? ''
      : row[index].trim();

  static DateTime? _date(String value) {
    final RegExpMatch? match = RegExp(
      r'^(\d{4})[/-](\d{1,2})[/-](\d{1,2})',
    ).firstMatch(value.trim());
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      12,
    );
  }

  static double? _amount(String value) => double.tryParse(
    value.replaceAll(',', '').replaceAll('¥', '').replaceAll('元', '').trim(),
  );

  static int _columnIndex(String letters) {
    int value = 0;
    for (final int code in letters.codeUnits) {
      value = value * 26 + code - 64;
    }
    return value - 1;
  }

  static String _xmlText(String value) => value
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');

  static String _fnv1a(String value) {
    int hash = 0x811C9DC5;
    for (final int byte in utf8.encode(value)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

class _ShiguangxuRow {
  const _ShiguangxuRow({
    required this.rowNumber,
    required this.occurredAt,
    required this.ledger,
    required this.account,
    required this.category,
    required this.amount,
    required this.note,
  });

  final int rowNumber;
  final DateTime occurredAt;
  final String ledger;
  final String account;
  final String category;
  final double amount;
  final String note;
}
