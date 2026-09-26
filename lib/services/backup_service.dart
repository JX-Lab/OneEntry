import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../data/ledger_controller.dart';
import '../models/ledger_models.dart';
import 'system_file_service.dart';
import 'tonglv_importer.dart';

enum ExportFormat { json, zip, xlsx }

enum ImportSource { automatic, oneEntry, tonglv }

class BackupService {
  BackupService._();

  static Future<bool> export(
    LedgerController controller,
    ExportFormat format,
  ) async {
    final Map<String, Object?> backup = await controller.exportBackup();
    final Uint8List jsonBytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(backup)),
    );
    final String stamp = _stamp(DateTime.now());
    switch (format) {
      case ExportFormat.json:
        return SystemFileService.save(
          name: '一笔备份-$stamp.json',
          mimeType: 'application/json',
          bytes: jsonBytes,
        );
      case ExportFormat.zip:
        final Uint8List csv = _csvBytes(controller);
        final Archive archive = Archive()
          ..addFile(ArchiveFile('backup.json', jsonBytes.length, jsonBytes))
          ..addFile(ArchiveFile('transactions.csv', csv.length, csv));
        final Uint8List bytes = ZipEncoder().encodeBytes(archive);
        return SystemFileService.save(
          name: '一笔归档-$stamp.zip',
          mimeType: 'application/zip',
          bytes: bytes,
        );
      case ExportFormat.xlsx:
        final Uint8List bytes = _buildXlsx(controller, jsonBytes);
        return SystemFileService.save(
          name: '一笔数据-$stamp.xlsx',
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          bytes: bytes,
        );
    }
  }

  static Future<String?> importBackup(
    LedgerController controller, {
    ImportSource source = ImportSource.automatic,
  }) async {
    final PickedDocument? document = await SystemFileService.open(
      mimeTypes: const <String>[
        'application/json',
        'application/zip',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ],
    );
    if (document == null) return null;
    Uint8List jsonBytes;
    final String lower = document.name.toLowerCase();
    final bool tonglv =
        lower.endsWith('.zip') &&
        TonglvImporter.looksLikeTonglv(document.bytes);
    if (source == ImportSource.tonglv && !tonglv) {
      throw const FormatException('所选文件不是同旅迁移 ZIP');
    }
    if (source == ImportSource.oneEntry && tonglv) {
      throw const FormatException('这是同旅迁移 ZIP，请选择“同旅”来源');
    }
    if (lower.endsWith('.json')) {
      if (source == ImportSource.tonglv) {
        throw const FormatException('同旅迁移文件应为 ZIP');
      }
      jsonBytes = document.bytes;
    } else if (lower.endsWith('.zip') || lower.endsWith('.xlsx')) {
      if (tonglv) {
        final TonglvImportBundle bundle = TonglvImporter.parse(document.bytes);
        final result = await controller.importTonglv(bundle);
        return '同旅导入 ${result.imported} 条，跳过重复 ${result.skipped} 条；新增成员 ${result.members}、账户 ${result.accounts}';
      }
      final Archive archive = ZipDecoder().decodeBytes(document.bytes);
      final String expected = lower.endsWith('.xlsx')
          ? 'oneentry/backup.json'
          : 'backup.json';
      final ArchiveFile? file = archive.find(expected);
      if (file == null) throw const FormatException('文件中没有一笔完整备份');
      jsonBytes = file.content;
    } else {
      throw const FormatException('不支持的文件格式');
    }
    final Object? decoded = jsonDecode(utf8.decode(jsonBytes));
    await controller.replaceFromBackup(
      Map<String, Object?>.from(decoded as Map),
    );
    return '已从 ${document.name} 恢复数据';
  }

  static Uint8List _csvBytes(LedgerController controller) {
    final List<List<Object?>> rows = <List<Object?>>[
      <Object?>['日期时间', '类型', '分类', '金额', '账户', '转入账户', '成员', '备注'],
      ...controller.entries.map((LedgerEntry entry) {
        final String account = controller.accounts
            .where((item) => item.id == entry.accountId)
            .map((item) => item.name)
            .join();
        final String target = controller.accounts
            .where((item) => item.id == entry.toAccountId)
            .map((item) => item.name)
            .join();
        final String members = entry.memberIds
            .map(
              (int id) => controller.members
                  .where((item) => item.id == id)
                  .map((item) => item.name)
                  .join(),
            )
            .where((String value) => value.isNotEmpty)
            .join('、');
        return <Object?>[
          entry.occurredAt.toIso8601String(),
          entry.type.name,
          entry.category,
          entry.amount,
          account,
          target,
          members,
          entry.note,
        ];
      }),
    ];
    final String csv = rows
        .map((row) => row.map(_csvCell).join(','))
        .join('\r\n');
    return Uint8List.fromList(<int>[0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);
  }

  static Uint8List _buildXlsx(
    LedgerController controller,
    Uint8List backupJson,
  ) {
    final List<_Sheet> sheets = <_Sheet>[
      _Sheet('明细', <List<Object?>>[
        <Object?>['日期时间', '类型', '分类', '金额', '备注'],
        ...controller.entries.map(
          (entry) => <Object?>[
            entry.occurredAt.toIso8601String(),
            entry.type.name,
            entry.category,
            entry.amount,
            entry.note,
          ],
        ),
      ]),
      _Sheet('账户', <List<Object?>>[
        <Object?>['账户', '余额', '已归档'],
        ...controller.accounts.map(
          (item) => <Object?>[
            item.name,
            item.balance,
            item.archived ? '是' : '否',
          ],
        ),
      ]),
      _Sheet('成员', <List<Object?>>[
        <Object?>['成员', '颜色', '已归档'],
        ...controller.members.map(
          (item) => <Object?>[
            item.name,
            '#${item.colorValue.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
            item.archived ? '是' : '否',
          ],
        ),
      ]),
      _Sheet('预算', <List<Object?>>[
        <Object?>['月份', '总预算'],
        <Object?>['当前月份', controller.monthlyBudget],
      ]),
    ];
    final Archive archive = Archive();
    void addText(String name, String value) {
      final List<int> bytes = utf8.encode(value);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    addText('[Content_Types].xml', _contentTypes(sheets.length));
    addText(
      '_rels/.rels',
      '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
    );
    addText('xl/workbook.xml', _workbookXml(sheets));
    addText('xl/_rels/workbook.xml.rels', _workbookRels(sheets.length));
    addText('xl/styles.xml', _stylesXml);
    for (int index = 0; index < sheets.length; index++) {
      addText(
        'xl/worksheets/sheet${index + 1}.xml',
        _sheetXml(sheets[index].rows),
      );
    }
    archive.addFile(
      ArchiveFile('oneentry/backup.json', backupJson.length, backupJson),
    );
    return ZipEncoder().encodeBytes(archive);
  }

  static String _sheetXml(List<List<Object?>> rows) {
    final StringBuffer xml = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>',
    );
    for (int rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      xml.write('<row r="${rowIndex + 1}">');
      for (int column = 0; column < rows[rowIndex].length; column++) {
        final Object? value = rows[rowIndex][column];
        final String ref = '${_columnName(column)}${rowIndex + 1}';
        if (value is num) {
          xml.write('<c r="$ref"><v>$value</v></c>');
        } else {
          xml.write(
            '<c r="$ref" t="inlineStr"><is><t xml:space="preserve">${_xml(value)}</t></is></c>',
          );
        }
      }
      xml.write('</row>');
    }
    return '${xml.toString()}</sheetData></worksheet>';
  }

  static String _contentTypes(int count) =>
      '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>${List<String>.generate(count, (index) => '<Override PartName="/xl/worksheets/sheet${index + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>').join()}</Types>';

  static String _workbookXml(List<_Sheet> sheets) =>
      '<?xml version="1.0" encoding="UTF-8"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>${List<String>.generate(sheets.length, (index) => '<sheet name="${_xml(sheets[index].name)}" sheetId="${index + 1}" r:id="rId${index + 1}"/>').join()}</sheets></workbook>';

  static String _workbookRels(int count) =>
      '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">${List<String>.generate(count, (index) => '<Relationship Id="rId${index + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${index + 1}.xml"/>').join()}<Relationship Id="rId${count + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>';

  static const String _stylesXml =
      '<?xml version="1.0" encoding="UTF-8"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><fonts count="1"><font><sz val="11"/><name val="等线"/></font></fonts><fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills><borders count="1"><border/></borders><cellStyleXfs count="1"><xf/></cellStyleXfs><cellXfs count="1"><xf/></cellXfs></styleSheet>';

  static String _columnName(int index) {
    String value = '';
    int current = index + 1;
    while (current > 0) {
      current--;
      value = String.fromCharCode(65 + current % 26) + value;
      current ~/= 26;
    }
    return value;
  }

  static String _xml(Object? value) => (value ?? '')
      .toString()
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
  static String _csvCell(Object? value) {
    final String text = (value ?? '').toString();
    return text.contains(RegExp('[,"\r\n]'))
        ? '"${text.replaceAll('"', '""')}"'
        : text;
  }

  static String _stamp(DateTime value) =>
      '${value.year}${value.month.toString().padLeft(2, '0')}${value.day.toString().padLeft(2, '0')}-${value.hour.toString().padLeft(2, '0')}${value.minute.toString().padLeft(2, '0')}';
}

class _Sheet {
  const _Sheet(this.name, this.rows);
  final String name;
  final List<List<Object?>> rows;
}
