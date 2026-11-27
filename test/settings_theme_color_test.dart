import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yibi/data/app_database.dart';
import 'package:yibi/data/ledger_controller.dart';
import 'package:yibi/data/ledger_repository.dart';
import 'package:yibi/features/settings/settings_page.dart';
import 'package:yibi/services/launcher_icon_service.dart';
import 'package:yibi/theme/app_theme.dart';

class _ReminderRepository extends LedgerRepository {
  _ReminderRepository() : super(AppDatabase());

  bool? enabled;

  @override
  Future<void> setDailyReminder({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    this.enabled = enabled;
  }
}

class _PathRepository extends LedgerRepository {
  _PathRepository() : super(AppDatabase());

  @override
  Future<String> databasePath() async =>
      '/data/user/0/com.junxu.yibi/databases/oneentry.db';
}

void main() {
  testWidgets('设置页显示并可复制QQ反馈群号', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall call,
        ) async {
          if (call.method == 'Clipboard.setData') return null;
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final LedgerController controller = LedgerController(
      LedgerRepository(AppDatabase()),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: SettingsPage(controller: controller)),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('一笔反馈交流群'),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('一笔反馈交流群'));
    await tester.pumpAndSettle();

    expect(find.text('QQ群：1049149714'), findsOneWidget);
    expect(find.text('QQ群号已复制'), findsOneWidget);
  });

  testWidgets('设置页显示主数据库实际路径', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final LedgerController controller = LedgerController(_PathRepository());
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: SettingsPage(controller: controller)),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('数据保存位置'),
      320,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.text('/data/user/0/com.junxu.yibi/databases/oneentry.db'),
      findsOneWidget,
    );
  });

  testWidgets('设置页可以打开主题色选择', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final LedgerController controller = LedgerController(
      LedgerRepository(AppDatabase()),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: SettingsPage(controller: controller),
      ),
    );
    expect(find.text('语音记账'), findsNothing);
    expect(find.text('多人金额分配'), findsOneWidget);
    expect(find.text('每日记账提醒'), findsOneWidget);
    expect(find.text('周期账目管理'), findsOneWidget);
    expect(find.text('通知权限'), findsNothing);
    expect(find.text('麦克风权限'), findsNothing);
    expect(find.text('测试通知'), findsNothing);
    expect(find.text('色觉模式'), findsOneWidget);
    expect(find.text('桌面图标'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('主题色'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('主题色'));
    await tester.pumpAndSettle();

    expect(find.text('选择主题色'), findsOneWidget);
    for (final AppAccent accent in AppTheme.accents) {
      expect(find.text(accent.label), findsWidgets);
    }
    expect(find.text('自定义颜色'), findsOneWidget);
  });

  testWidgets('设置页显示应用版本和手动更新入口', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const MethodChannel channel = MethodChannel('com.junxu.yibi/app_info');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          if (call.method == 'getVersion') {
            return <String, Object?>{'name': '0.2.0', 'build': 2053};
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final LedgerController controller = LedgerController(
      LedgerRepository(AppDatabase()),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: SettingsPage(controller: controller)),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('检查更新'),
      320,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('版本 0.2.0 · Build 53'), findsOneWidget);
    expect(find.text('检查更新'), findsOneWidget);
    expect(find.text('手动检查 GitHub Releases；不会后台联网'), findsOneWidget);
  });

  testWidgets('桌面图标可以切换为跟随界面主题', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const MethodChannel channel = MethodChannel('com.junxu.yibi/launcher_icon');
    String? selectedMode;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          if (call.method == 'getMode') return 'brand';
          if (call.method == 'setMode') {
            selectedMode =
                (call.arguments as Map<Object?, Object?>)['mode'] as String?;
            return true;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final LedgerController controller = LedgerController(
      LedgerRepository(AppDatabase()),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: SettingsPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('桌面图标'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('桌面图标'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('跟随界面主题'));
    await tester.pumpAndSettle();

    expect(selectedMode, 'theme');
    expect(find.text('跟随主题  ›'), findsOneWidget);
    expect(await LauncherIconService.currentMode(), 'brand');
  });

  testWidgets('没有精确闹钟权限也能开启每日提醒', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const MethodChannel channel = MethodChannel('com.junxu.yibi/notifications');
    bool? scheduled;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          if (call.method == 'requestPermission') return true;
          if (call.method == 'canScheduleExactAlarms') return false;
          if (call.method == 'scheduleDaily') {
            scheduled =
                (call.arguments as Map<Object?, Object?>)['enabled'] as bool?;
            return null;
          }
          if (call.method == 'dailyReminderStatus') {
            return <String, int>{};
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final _ReminderRepository repository = _ReminderRepository();
    final LedgerController controller = LedgerController(repository);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: SettingsPage(controller: controller)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('每日记账提醒'));
    await tester.pumpAndSettle();

    expect(repository.enabled, isTrue);
    expect(scheduled, isTrue);
    expect(controller.dailyReminderEnabled, isTrue);
    expect(find.text('提升提醒准时性（可选）'), findsOneWidget);
  });
}
