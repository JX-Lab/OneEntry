import 'package:flutter_test/flutter_test.dart';
import 'package:yibi/data/app_database.dart';
import 'package:yibi/data/ledger_controller.dart';
import 'package:yibi/data/ledger_repository.dart';

class _FakeLedgerRepository extends LedgerRepository {
  _FakeLedgerRepository() : super(AppDatabase());

  bool? savedDailyEnabled;
  int? savedDailyHour;
  int? savedDailyMinute;

  @override
  Future<({Map<String, double> categories, double total})> loadBudget(
    DateTime month,
  ) async => (
    total: month.year == 2024 && month.month == 3 ? 3200.0 : 0.0,
    categories: <String, double>{'餐饮': 800},
  );

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
}
