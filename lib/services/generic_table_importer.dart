import 'dart:convert';
import 'dart:typed_data';

import 'shiguangxu_importer.dart';
import 'tonglv_importer.dart';

class GenericTableImporter {
  GenericTableImporter._();

  static const List<String> _dateAliases = <String>[
    '日期',
    '时间',
    '日期时间',
    '交易时间',
    '记账时间',
    '记录时间',
    '记账日期',
    '交易日期',
    '创建时间',
    '账单时间',
    '发生时间',
    'date',
    'datetime',
    'time',
  ];
  static const List<String> _amountAliases = <String>[
    '金额',
    '数额',
    '钱数',
    '价格',
    'amount',
    'money',
    'value',
    'total',
  ];
  static const List<String> _incomeAliases = <String>[
    '收入',
    '收入金额',
    'income',
    'deposit',
  ];
  static const List<String> _expenseAliases = <String>[
    '支出',
    '支出金额',
    'expense',
    'withdrawal',
    'payment',
  ];
  static const List<String> _typeAliases = <String>[
    '类型',
    '收支',
    '收支类型',
    '交易类型',
    '收入支出',
    '方向',
    'type',
    'transactiontype',
  ];
  static const List<String> _categoryAliases = <String>[
    '分类',
    '类别',
    '大类',
    '标签',
    '消费分类',
    '交易分类',
    '项目',
    'category',
    'subcategory',
  ];
  static const List<String> _subCategoryAliases = <String>[
    '二级分类',
    '子分类',
    '小类',
    '细分类',
  ];
  static const List<String> _accountAliases = <String>[
    '账户',
    '账户名称',
    '账本',
    '钱包',
    '支付方式',
    '付款方式',
    '支付账户',
    '收款账户',
    '银行卡',
    'account',
    'wallet',
    'paymentmethod',
  ];
  static const List<String> _memberAliases = <String>[
    '成员',
    '消费人',
    '参与人',
    '人员',
    '用户',
    '昵称',
    'member',
    'person',
    'payer',
  ];
  static const List<String> _noteAliases = <String>[
    '备注',
    '交易备注',
    '说明',
    '描述',
    '摘要',
    '用途',
    'note',
    'remark',
    'comment',
    'description',
    'memo',
  ];

  static TonglvImportBundle parse(Uint8List bytes, String fileName) {
    final String lower = fileName.toLowerCase();
    final List<List<String>> rows =
        lower.endsWith('.csv') ||
            lower.endsWith('.txt') ||
            lower.endsWith('.tsv')
        ? _csvRows(bytes)
        : ShiguangxuImporter.readSpreadsheetRows(bytes);
    if (rows.isEmpty) throw const FormatException('表格中没有数据');

    final _Mapping mapping = _findMapping(rows);
    if (mapping.date < 0 ||
        (mapping.amount < 0 && mapping.income < 0 && mapping.expense < 0)) {
      throw const FormatException('无法识别日期列和金额列；请确认表格至少包含这两个字段');
    }
    final List<List<String>> body = mapping.headerRow >= 0
        ? rows.skip(mapping.headerRow + 1).toList()
        : rows;
    final bool signedAmounts =
        mapping.amount >= 0 &&
        mapping.type < 0 &&
        mapping.income < 0 &&
        mapping.expense < 0 &&
        body.any((row) => (_number(_cell(row, mapping.amount)) ?? 0) < 0);

    final Map<String, TonglvAccount> accounts = <String, TonglvAccount>{};
    final Map<String, TonglvMember> members = <String, TonglvMember>{};
    final List<TonglvEntry> entries = <TonglvEntry>[];
    for (int rowIndex = 0; rowIndex < body.length; rowIndex++) {
      final List<String> row = body[rowIndex];
      final DateTime? date = _date(_cell(row, mapping.date));
      if (date == null) continue;
      final String type = _cell(row, mapping.type).toLowerCase();
      double? amount;
      final double? income = _number(_cell(row, mapping.income));
      final double? expense = _number(_cell(row, mapping.expense));
      if (expense != null && expense != 0) {
        amount = -expense.abs();
      } else if (income != null && income != 0) {
        amount = income.abs();
      } else {
        final String rawAmount = _cell(row, mapping.amount);
        final double? value = _number(rawAmount);
        if (value == null || value == 0) continue;
        if (_isExpenseType(type)) {
          amount = -value.abs();
        } else if (_isIncomeType(type)) {
          amount = value.abs();
        } else {
          final String trimmed = rawAmount.trim();
          final bool explicitSign =
              trimmed.startsWith('+') ||
              trimmed.startsWith('-') ||
              (trimmed.startsWith('(') && trimmed.endsWith(')'));
          amount = signedAmounts || explicitSign ? value : -value.abs();
        }
      }

      String category = _clean(_cell(row, mapping.category));
      final String subCategory = _clean(_cell(row, mapping.subCategory));
      if (category.isEmpty) category = subCategory;
      if (category.isEmpty) category = '其他';
      if (category == '教育') category = '学习';
      if (category == '居住') category = '住房';
      if (subCategory.isNotEmpty && subCategory != category) {
        category = '$category-$subCategory';
      }
      String account = _clean(_cell(row, mapping.account));
      if (account.isEmpty) account = '通用导入账户';
      accounts.putIfAbsent(
        account,
        () => TonglvAccount(sourceId: account, name: account),
      );
      final List<String> memberNames = _clean(_cell(row, mapping.member))
          .split(RegExp(r'[、,，/|;；]+'))
          .map((name) => name.trim())
          .where((name) => name.isNotEmpty)
          .toList();
      for (final String name in memberNames) {
        members.putIfAbsent(
          name,
          () => TonglvMember(
            sourceId: name,
            name: name,
            colorValue: _memberColor(members.length),
            archived: false,
          ),
        );
      }
      final String note = _clean(_cell(row, mapping.note));
      final String canonical = row.join('\u001f');
      entries.add(
        TonglvEntry(
          sourceId: '${mapping.headerRow + rowIndex + 2}-${_fnv1a(canonical)}',
          title: '',
          note: note,
          amount: amount,
          occurredAt: date,
          accountSourceId: account,
          category: category,
          memberSourceIds: memberNames,
        ),
      );
    }
    if (entries.isEmpty) {
      throw const FormatException('找到了日期和金额列，但没有解析出有效账目');
    }
    return TonglvImportBundle(
      members: members.values.toList(),
      accounts: accounts.values.toList(),
      entries: entries,
      backupVersion: 1,
    );
  }

  static _Mapping _findMapping(List<List<String>> rows) {
    int bestRow = -1;
    int bestScore = -1;
    _Mapping? best;
    for (int index = 0; index < rows.length && index < 200; index++) {
      final List<String> header = rows[index];
      final _Mapping candidate = _mappingFromHeader(header, index);
      final int score = candidate.score;
      if (candidate.date >= 0 &&
          (candidate.amount >= 0 ||
              candidate.income >= 0 ||
              candidate.expense >= 0) &&
          score > bestScore) {
        bestRow = index;
        bestScore = score;
        best = candidate;
      }
    }
    if (best != null) return best;
    return _guessColumns(rows, bestRow);
  }

  static _Mapping _mappingFromHeader(List<String> header, int row) => _Mapping(
    headerRow: row,
    date: _findColumn(header, _dateAliases),
    amount: _findColumn(header, _amountAliases),
    income: _findColumn(header, _incomeAliases),
    expense: _findColumn(header, _expenseAliases),
    type: _findColumn(header, _typeAliases),
    category: _findColumn(header, _categoryAliases),
    subCategory: _findColumn(header, _subCategoryAliases),
    account: _findColumn(header, _accountAliases),
    member: _findColumn(header, _memberAliases),
    note: _findColumn(header, _noteAliases),
  );

  static _Mapping _guessColumns(List<List<String>> rows, int _) {
    final int width = rows.fold<int>(
      0,
      (max, row) => row.length > max ? row.length : max,
    );
    int dateColumn = -1;
    int dateScore = 0;
    for (int column = 0; column < width; column++) {
      final int score = rows
          .take(80)
          .where((row) => _date(_cell(row, column)) != null)
          .length;
      if (score > dateScore) {
        dateColumn = column;
        dateScore = score;
      }
    }
    int amountColumn = -1;
    int amountScore = 0;
    for (int column = 0; column < width; column++) {
      if (column == dateColumn) continue;
      final int score = rows.take(80).where((row) {
        final double? value = _number(_cell(row, column));
        return value != null && value != 0;
      }).length;
      if (score > amountScore) {
        amountColumn = column;
        amountScore = score;
      }
    }
    if (dateScore < 2 || amountScore < 2) return const _Mapping();
    return _Mapping(headerRow: -1, date: dateColumn, amount: amountColumn);
  }

  static int _findColumn(List<String> header, List<String> aliases) {
    final List<String> normalizedHeader = header.map(_normalize).toList();
    final List<String> normalizedAliases = aliases.map(_normalize).toList();
    for (final String alias in normalizedAliases) {
      final int index = normalizedHeader.indexOf(alias);
      if (index >= 0) return index;
    }
    for (int index = 0; index < normalizedHeader.length; index++) {
      final String value = normalizedHeader[index];
      if (value.isEmpty) continue;
      if (normalizedAliases.any(value.contains)) return index;
    }
    return -1;
  }

  static List<List<String>> _csvRows(Uint8List bytes) {
    final String text = utf8
        .decode(bytes, allowMalformed: true)
        .replaceFirst('\ufeff', '');
    final List<List<String>> rows = <List<String>>[];
    List<String> row = <String>[];
    final StringBuffer cell = StringBuffer();
    bool quoted = false;
    for (int index = 0; index < text.length; index++) {
      final String char = text[index];
      if (quoted) {
        if (char == '"') {
          if (index + 1 < text.length && text[index + 1] == '"') {
            cell.write('"');
            index++;
          } else {
            quoted = false;
          }
        } else {
          cell.write(char);
        }
      } else if (char == '"') {
        quoted = true;
      } else if (char == ',' || char == '\t' || char == ';') {
        row.add(cell.toString());
        cell.clear();
      } else if (char == '\n') {
        row.add(cell.toString());
        rows.add(row);
        row = <String>[];
        cell.clear();
      } else if (char != '\r') {
        cell.write(char);
      }
    }
    if (cell.isNotEmpty || row.isNotEmpty) {
      row.add(cell.toString());
      rows.add(row);
    }
    return rows
        .where((row) => row.any((cell) => cell.trim().isNotEmpty))
        .toList();
  }

  static DateTime? _date(String value) {
    final String text = value.trim();
    if (text.isEmpty) return null;
    final double? number = double.tryParse(text);
    if (number != null && number > 20000 && number < 80000) {
      return DateTime.utc(
        1899,
        12,
        30,
      ).add(Duration(milliseconds: (number * 86400000).round())).toLocal();
    }
    if (RegExp(r'^\d{10}$').hasMatch(text)) {
      return DateTime.fromMillisecondsSinceEpoch(int.parse(text) * 1000);
    }
    if (RegExp(r'^\d{13}$').hasMatch(text)) {
      return DateTime.fromMillisecondsSinceEpoch(int.parse(text));
    }
    String normalized = text
        .replaceAll('年', '-')
        .replaceAll('月', '-')
        .replaceAll('日', ' ')
        .replaceAll('/', '-')
        .replaceAll('.', '-');
    if (RegExp(r'^\d{8}$').hasMatch(normalized)) {
      normalized =
          '${normalized.substring(0, 4)}-${normalized.substring(4, 6)}-${normalized.substring(6, 8)}';
    }
    final RegExpMatch? match = RegExp(
      r'(\d{4})-(\d{1,2})-(\d{1,2})(?:\s+(\d{1,2}):(\d{1,2}))?',
    ).firstMatch(normalized);
    if (match == null) return null;
    final int year = int.parse(match.group(1)!);
    final int month = int.parse(match.group(2)!);
    final int day = int.parse(match.group(3)!);
    if (year < 1970 ||
        year > 2099 ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31) {
      return null;
    }
    return DateTime(
      year,
      month,
      day,
      int.tryParse(match.group(4) ?? '') ?? 12,
      int.tryParse(match.group(5) ?? '') ?? 0,
    );
  }

  static double? _number(String value) {
    String text = value.replaceAll(RegExp(r'[¥￥$€,，\s元]'), '').trim();
    if (text.startsWith('(') && text.endsWith(')')) {
      text = '-${text.substring(1, text.length - 1)}';
    }
    return double.tryParse(text);
  }

  static bool _isExpenseType(String value) =>
      RegExp(r'支出|消费|支付|expense|withdraw|payment').hasMatch(value);

  static bool _isIncomeType(String value) =>
      RegExp(r'收入|退款|income|deposit|refund').hasMatch(value);

  static String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s_\-—:：()（）\[\]【】/]'), '');

  static String _clean(String value) =>
      value.replaceAll(RegExp(r'[\u0000-\u001f\u007f]'), ' ').trim();

  static String _cell(List<String> row, int index) =>
      index < 0 || index >= row.length ? '' : row[index];

  static int _memberColor(int index) => const <int>[
    0xFF2E7CF6,
    0xFFF5A623,
    0xFFEB4E6B,
    0xFF18B681,
    0xFF8E6BE0,
    0xFF00B0D6,
    0xFFE8652B,
    0xFF5B6B7A,
  ][index % 8];

  static String _fnv1a(String value) {
    int hash = 0x811C9DC5;
    for (final int byte in utf8.encode(value)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

class _Mapping {
  const _Mapping({
    this.headerRow = -1,
    this.date = -1,
    this.amount = -1,
    this.income = -1,
    this.expense = -1,
    this.type = -1,
    this.category = -1,
    this.subCategory = -1,
    this.account = -1,
    this.member = -1,
    this.note = -1,
  });

  final int headerRow;
  final int date;
  final int amount;
  final int income;
  final int expense;
  final int type;
  final int category;
  final int subCategory;
  final int account;
  final int member;
  final int note;

  int get score => <int>[
    date,
    amount,
    income,
    expense,
    type,
    category,
    subCategory,
    account,
    member,
    note,
  ].where((value) => value >= 0).length;
}
