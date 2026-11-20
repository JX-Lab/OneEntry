import 'package:flutter_test/flutter_test.dart';
import 'package:yibi/data/app_database.dart';
import 'package:yibi/data/ledger_controller.dart';
import 'package:yibi/data/ledger_repository.dart';
import 'package:yibi/models/ledger_models.dart';

class _FakeLedgerRepository extends LedgerRepository {
  _FakeLedgerRepository() : super(AppDatabase());

  bool? savedDailyEnabled;
  int? savedDailyHour;
  int? savedDailyMinute;
  int? savedMemberBudgetId;
  double? savedMemberBudgetAmount;

  @override
  Future<({Map<String, double> categories, double total})> loadBudget(
    DateTime month,
  ) async => (
    total: month.year == 2024 && month.month == 3 ? 3200.0 : 0.0,
    categories: <String, double>{'餐饮': 800},
  );

  @override
  Future<Map<int, double>> loadMemberBudgets(DateTime month) async =>
      <int, double>{};

  @override
  Future<void> setPreference(String key, String value) async {}

  @override
  Future<void> setDailyReminder({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    savedDailyEnabled = enabled;
    savedDailyHour = hour;
    savedDailyMinute = minute;
  }

  @override
  Future<void> setMemberBudget(
    DateTime month,
    int memberId,
    double amount,
  ) async {
    savedMemberBudgetId = memberId;
    savedMemberBudgetAmount = amount;
  }
}

void main() {
  test('可按首页选中月份切换预算', () async {
    final LedgerController controller = LedgerController(
      _FakeLedgerRepository(),
    );
    addTearDown(controller.dispose);

    await controller.loadBudgetForMonth(DateTime(2024, 3, 20));

    expect(controller.budgetMonth, DateTime(2024, 3));
    expect(controller.monthlyBudget, 3200);
    expect(controller.categoryBudgets, <String, double>{'餐饮': 800});
  });

  test('主题色偏好会立即更新控制器', () async {
    final LedgerController controller = LedgerController(
      _FakeLedgerRepository(),
    );
    addTearDown(controller.dispose);

    await controller.setPreference('theme_color', 'purple');

    expect(controller.themeColor, 'purple');
  });

  test('语音记账偏好会立即更新控制器', () async {
    final LedgerController controller = LedgerController(
      _FakeLedgerRepository(),
    );
    addTearDown(controller.dispose);

    await controller.setPreference('voice_enabled', '0');

    expect(controller.voiceEnabled, isFalse);
  });

  test('色觉模式偏好会立即更新控制器', () async {
    final LedgerController controller = LedgerController(
      _FakeLedgerRepository(),
    );
    addTearDown(controller.dispose);

    await controller.setPreference('color_vision_mode', 'deutan');

    expect(controller.colorVisionMode, 'deutan');
  });

  test('每日提醒设置会保存并更新控制器', () async {
    final _FakeLedgerRepository repository = _FakeLedgerRepository();
    final LedgerController controller = LedgerController(repository);
    addTearDown(controller.dispose);

    await controller.setDailyReminder(enabled: true, hour: 21, minute: 30);

    expect(controller.dailyReminderEnabled, isTrue);
    expect(controller.dailyReminderHour, 21);
    expect(controller.dailyReminderMinute, 30);
    expect(repository.savedDailyEnabled, isTrue);
  });

  test('预算外花销计入总支出但不占用预算', () {
    final LedgerController controller = LedgerController(
      _FakeLedgerRepository(),
    );
    addTearDown(controller.dispose);
    final DateTime month = DateTime(2026, 11);
    controller.entries.addAll(<LedgerEntry>[
      LedgerEntry(
        id: 1,
        type: EntryType.expense,
        amount: 80,
        category: '餐饮',
        occurredAt: DateTime(2026, 11, 3),
        note: '',
        accountId: 1,
      ),
      LedgerEntry(
        id: 2,
        type: EntryType.expense,
        amount: 35,
        category: '旅行',
        occurredAt: DateTime(2026, 11, 5),
        note: '',
        accountId: 1,
        outsideBudget: true,
      ),
    ]);

    expect(controller.expenseForMonth(month), 115);
    expect(controller.budgetExpenseForMonth(month), 80);
    expect(controller.outsideBudgetExpenseForMonth(month), 35);
  });

  test('一个成员自然退化为个人账本，多个成员显示多主体功能', () {
    final LedgerController controller = LedgerController(
      _FakeLedgerRepository(),
    );
    addTearDown(controller.dispose);
    controller.members.add(
      LedgerMember(id: 1, name: '我', colorValue: 0xFF2E7CF6),
    );
    expect(controller.multiEnabled, isFalse);
    controller.members.add(
      LedgerMember(id: 2, name: '另一身份', colorValue: 0xFFF5A623),
    );
    expect(controller.multiEnabled, isTrue);
  });

  test('共同账本中的历史可见性标记不会隐藏账目', () {
    final LedgerController controller = LedgerController(
      _FakeLedgerRepository(),
    );
    addTearDown(controller.dispose);
    controller.entries.addAll(<LedgerEntry>[
      LedgerEntry(
        id: 1,
        type: EntryType.expense,
        amount: 10,
        category: '餐饮',
        occurredAt: DateTime(2026, 11, 3),
        note: '',
        accountId: 1,
        recordedByMemberId: 1,
        visibility: EntryVisibility.private,
      ),
      LedgerEntry(
        id: 2,
        type: EntryType.expense,
        amount: 20,
        category: '购物',
        occurredAt: DateTime(2026, 11, 3),
        note: '',
        accountId: 1,
      ),
    ]);
    controller.currentMemberId = 1;
    expect(controller.visibleEntries.map((entry) => entry.id), <int>[1, 2]);
    controller.currentMemberId = 2;
    expect(controller.visibleEntries.map((entry) => entry.id), <int>[1, 2]);
  });

  test('成员专属分类只对当前身份显示', () {
    final LedgerController controller = LedgerController(
      _FakeLedgerRepository(),
    );
    addTearDown(controller.dispose);
    controller.categories.addAll(const <LedgerCategory>[
      LedgerCategory(
        name: '餐饮',
        type: EntryType.expense,
        icon: 'restaurant',
        custom: false,
      ),
      LedgerCategory(
        name: 'A 专属',
        type: EntryType.expense,
        icon: 'tag',
        custom: true,
        memberId: 1,
      ),
      LedgerCategory(
        name: 'B 专属',
        type: EntryType.expense,
        icon: 'tag',
        custom: true,
        memberId: 2,
      ),
    ]);

    controller.currentMemberId = 1;
    expect(
      controller
          .categoriesFor(EntryType.expense, memberId: 1)
          .map((item) => item.name),
      <String>['餐饮', 'A 专属'],
    );
  });

  test('成员预算会保存并立即更新', () async {
    final _FakeLedgerRepository repository = _FakeLedgerRepository();
    final LedgerController controller = LedgerController(repository)
      ..budgetMonth = DateTime(2026, 11);
    addTearDown(controller.dispose);

    await controller.setMemberBudget(DateTime(2026, 11), 2, 860);

    expect(repository.savedMemberBudgetId, 2);
    expect(repository.savedMemberBudgetAmount, 860);
    expect(controller.memberBudgets[2], 860);
  });
}
