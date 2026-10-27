import 'package:flutter_test/flutter_test.dart';
import 'package:yibi/data/app_database.dart';
import 'package:yibi/data/ledger_controller.dart';
import 'package:yibi/data/ledger_repository.dart';
import 'package:yibi/models/ledger_models.dart';
import 'package:yibi/services/voice_entry_parser.dart';

void main() {
  late LedgerController controller;

  setUp(() {
    controller = LedgerController(LedgerRepository(AppDatabase()));
    controller.accounts.addAll(<LedgerAccount>[
      LedgerAccount(id: 1, name: '现金', balance: 100),
      LedgerAccount(id: 2, name: '微信', balance: 200),
    ]);
    controller.members.addAll(<LedgerMember>[
      LedgerMember(id: 1, name: '我', colorValue: 0xFF000000),
      LedgerMember(id: 2, name: '小明', colorValue: 0xFF000000),
    ]);
    controller.categories.addAll(const <LedgerCategory>[
      LedgerCategory(
        name: '餐饮',
        type: EntryType.expense,
        icon: 'restaurant',
        custom: false,
      ),
      LedgerCategory(
        name: '交通',
        type: EntryType.expense,
        icon: 'car',
        custom: false,
      ),
      LedgerCategory(
        name: '工资',
        type: EntryType.income,
        icon: 'salary',
        custom: false,
      ),
    ]);
  });

  tearDown(() => controller.dispose());

  test('解析中文口语金额、分类和日期', () {
    final LedgerEntry? entry = parseVoiceEntry(
      '昨天买菜花了三十五块五毛',
      controller,
      now: DateTime(2026, 10, 27, 12, 30),
    );
    expect(entry, isNotNull);
    expect(entry!.amount, 35.5);
    expect(entry.category, '餐饮');
    expect(entry.type, EntryType.expense);
    expect(entry.occurredAt.day, 26);
  });

  test('解析收入和阿拉伯数字', () {
    final LedgerEntry? entry = parseVoiceEntry(
      '工资到账 5200 元',
      controller,
      now: DateTime(2026, 10, 27),
    );
    expect(entry, isNotNull);
    expect(entry!.amount, 5200);
    expect(entry.category, '工资');
    expect(entry.type, EntryType.income);
  });

  test('识别账户、成员和转账', () {
    final LedgerEntry? entry = parseVoiceEntry(
      '从现金转账 80 元到微信，小明操作',
      controller,
    );
    expect(entry, isNotNull);
    expect(entry!.type, EntryType.transfer);
    expect(entry.accountId, 1);
    expect(entry.toAccountId, 2);
    expect(entry.memberIds, <int>[2]);
  });

  test('没有金额时不生成草稿', () {
    expect(parseVoiceEntry('今天买了东西', controller), isNull);
  });
}
