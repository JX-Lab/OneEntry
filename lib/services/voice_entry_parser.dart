import '../data/ledger_controller.dart';
import '../models/ledger_models.dart';

LedgerEntry? parseVoiceEntry(
  String transcript,
  LedgerController controller, {
  DateTime? now,
}) {
  final String text = transcript.trim();
  final double? amount = _extractAmount(text);
  if (text.isEmpty || amount == null || amount <= 0) return null;

  final DateTime current = now ?? DateTime.now();
  final EntryType type = _entryType(text);
  final List<LedgerAccount> activeAccounts = controller.accounts
      .where((account) => !account.archived)
      .toList();
  if (activeAccounts.isEmpty) return null;

  final List<LedgerAccount> mentionedAccounts =
      activeAccounts.where((account) => text.contains(account.name)).toList()
        ..sort((a, b) => text.indexOf(a.name).compareTo(text.indexOf(b.name)));
  final int defaultAccountId = _defaultAccountId(controller, activeAccounts);
  final int accountId = mentionedAccounts.isEmpty
      ? defaultAccountId
      : mentionedAccounts.first.id;
  final int? toAccountId = type == EntryType.transfer
      ? _targetAccountId(activeAccounts, mentionedAccounts, accountId)
      : null;

  final List<LedgerMember> activeMembers = controller.members
      .where((member) => !member.archived)
      .toList();
  final List<int> memberIds = activeMembers
      .where((member) => member.name.length > 1 && text.contains(member.name))
      .map((member) => member.id)
      .toList();

  return LedgerEntry(
    id: 0,
    type: type,
    amount: amount,
    category: type == EntryType.transfer
        ? '转账'
        : _category(text, type, controller),
    occurredAt: _date(text, current),
    note: text,
    accountId: accountId,
    toAccountId: toAccountId,
    memberIds: memberIds,
  );
}

EntryType _entryType(String text) {
  if (_containsAny(text, const <String>['转账', '转到', '转入', '转出'])) {
    return EntryType.transfer;
  }
  if (_containsAny(text, const <String>[
    '收入',
    '收到',
    '到账',
    '工资',
    '奖金',
    '报销',
    '红包',
    '赚了',
    '入账',
  ])) {
    return EntryType.income;
  }
  return EntryType.expense;
}

String _category(String text, EntryType type, LedgerController controller) {
  final List<LedgerCategory> available = controller.categoriesFor(type);
  for (final LedgerCategory category in available) {
    if (text.contains(category.name)) return category.name;
  }
  const Map<String, List<String>> keywords = <String, List<String>>{
    '餐饮': <String>['吃饭', '早餐', '午餐', '晚餐', '外卖', '买菜', '奶茶', '咖啡', '饭'],
    '交通': <String>['打车', '地铁', '公交', '加油', '停车', '高速', '火车', '机票'],
    '购物': <String>['购物', '买了', '淘宝', '京东', '超市', '商场'],
    '住房': <String>['房租', '物业', '水费', '电费', '燃气', '家具'],
    '娱乐': <String>['电影', '游戏', 'KTV', '演出', '会员'],
    '医疗': <String>['看病', '医院', '药', '挂号', '体检'],
    '学习': <String>['书', '课程', '培训', '学费', '考试'],
    '旅行': <String>['酒店', '旅游', '景点', '门票', '民宿'],
    '通讯': <String>['话费', '宽带', '流量'],
    '健身': <String>['健身', '跑步', '游泳', '球馆'],
    '工资': <String>['工资', '薪水'],
    '红包': <String>['红包'],
    '报销': <String>['报销'],
    '兼职': <String>['兼职', '外快'],
  };
  for (final MapEntry<String, List<String>> item in keywords.entries) {
    if (!available.any((category) => category.name == item.key)) continue;
    if (_containsAny(text, item.value)) return item.key;
  }
  return available.isEmpty ? '其他' : available.first.name;
}

DateTime _date(String text, DateTime now) {
  final int daysAgo = text.contains('大前天')
      ? 3
      : text.contains('前天')
      ? 2
      : text.contains('昨天')
      ? 1
      : 0;
  final DateTime day = now.subtract(Duration(days: daysAgo));
  return DateTime(day.year, day.month, day.day, now.hour, now.minute);
}

int _defaultAccountId(
  LedgerController controller,
  List<LedgerAccount> activeAccounts,
) {
  final Set<int> activeIds = activeAccounts
      .map((account) => account.id)
      .toSet();
  for (final LedgerEntry entry in controller.entries) {
    if ((entry.type == EntryType.expense || entry.type == EntryType.income) &&
        activeIds.contains(entry.accountId)) {
      return entry.accountId;
    }
  }
  return activeAccounts.first.id;
}

int? _targetAccountId(
  List<LedgerAccount> activeAccounts,
  List<LedgerAccount> mentioned,
  int sourceId,
) {
  for (final LedgerAccount account in mentioned) {
    if (account.id != sourceId) return account.id;
  }
  for (final LedgerAccount account in activeAccounts) {
    if (account.id != sourceId) return account.id;
  }
  return null;
}

double? _extractAmount(String text) {
  final RegExp arabicWithUnit = RegExp(r'(\d+(?:\.\d+)?)\s*(?:元|块钱|块|圆)');
  final List<RegExpMatch> unitMatches = arabicWithUnit
      .allMatches(text)
      .toList();
  if (unitMatches.isNotEmpty) {
    return double.tryParse(unitMatches.last.group(1)!);
  }

  final RegExp chineseMoney = RegExp(
    r'([零〇一二两三四五六七八九十百千万亿]+)(?:元|块钱|块|圆)(?:([零〇一二两三四五六七八九十]+)(?:角|毛))?(?:([零〇一二两三四五六七八九十]+)分?)?',
  );
  final RegExpMatch? moneyMatch = chineseMoney.firstMatch(text);
  if (moneyMatch != null) {
    final double yuan = _parseChineseNumber(moneyMatch.group(1)!) ?? 0;
    final double jiao = moneyMatch.group(2) == null
        ? 0
        : (_parseChineseNumber(moneyMatch.group(2)!) ?? 0) / 10;
    final double fen = moneyMatch.group(3) == null
        ? 0
        : (_parseChineseNumber(moneyMatch.group(3)!) ?? 0) / 100;
    return yuan + jiao + fen;
  }

  final RegExp arabic = RegExp(r'\d+(?:\.\d+)?');
  final List<RegExpMatch> arabicMatches = arabic.allMatches(text).toList();
  if (arabicMatches.isNotEmpty) {
    return double.tryParse(arabicMatches.last.group(0)!);
  }

  final RegExp spokenAmount = RegExp(
    r'(?:花了|消费|用了|收入|赚了|收到|工资)([零〇一二两三四五六七八九十百千万亿点]+)',
  );
  final RegExpMatch? spokenMatch = spokenAmount.firstMatch(text);
  return spokenMatch == null
      ? null
      : _parseChineseNumber(spokenMatch.group(1)!);
}

double? _parseChineseNumber(String value) {
  if (value.isEmpty) return null;
  final List<String> decimalParts = value.split('点');
  if (decimalParts.length > 2) return null;
  final double? integer = _parseChineseInteger(decimalParts.first);
  if (integer == null) return null;
  if (decimalParts.length == 1) return integer;
  double decimal = 0;
  double place = .1;
  for (final int rune in decimalParts.last.runes) {
    final int? digit = _chineseDigit(String.fromCharCode(rune));
    if (digit == null) return null;
    decimal += digit * place;
    place /= 10;
  }
  return integer + decimal;
}

double? _parseChineseInteger(String value) {
  if (value.isEmpty) return 0;
  final int? direct = int.tryParse(value);
  if (direct != null) return direct.toDouble();

  final List<String> characters = value.runes.map(String.fromCharCode).toList();
  double total = 0;
  double section = 0;
  double number = 0;
  for (final String character in characters) {
    final int? digit = _chineseDigit(character);
    if (digit != null) {
      number = digit.toDouble();
      continue;
    }
    final int? unit = const <String, int>{
      '十': 10,
      '百': 100,
      '千': 1000,
      '万': 10000,
      '亿': 100000000,
    }[character];
    if (unit == null) return null;
    if (unit < 10000) {
      if (number == 0) number = 1;
      section += number * unit;
    } else {
      section += number;
      if (section == 0) section = 1;
      total += section * unit;
      section = 0;
    }
    number = 0;
  }

  if (characters.length >= 2 && _chineseDigit(characters.last) != null) {
    final String beforeLast = characters
        .sublist(0, characters.length - 1)
        .join();
    if (!beforeLast.endsWith('零')) {
      final int lastUnit = beforeLast.endsWith('百')
          ? 100
          : beforeLast.endsWith('千')
          ? 1000
          : beforeLast.endsWith('万')
          ? 10000
          : beforeLast.endsWith('亿')
          ? 100000000
          : 0;
      if (lastUnit > 10) number *= lastUnit / 10;
    }
  }
  return total + section + number;
}

int? _chineseDigit(String value) => const <String, int>{
  '零': 0,
  '〇': 0,
  '一': 1,
  '二': 2,
  '两': 2,
  '三': 3,
  '四': 4,
  '五': 5,
  '六': 6,
  '七': 7,
  '八': 8,
  '九': 9,
}[value];

bool _containsAny(String text, List<String> values) =>
    values.any(text.contains);
