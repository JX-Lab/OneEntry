import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'data/app_database.dart';
import 'data/ledger_controller.dart';
import 'data/ledger_repository.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OneEntryBootstrap());
}

class OneEntryBootstrap extends StatefulWidget {
  const OneEntryBootstrap({super.key});

  @override
  State<OneEntryBootstrap> createState() => _OneEntryBootstrapState();
}

class _OneEntryBootstrapState extends State<OneEntryBootstrap> {
  LedgerController? _controller;
  Object? _error;
  StackTrace? _stackTrace;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      _controller = null;
      _error = null;
      _stackTrace = null;
    });
    try {
      final AppDatabase database = AppDatabase();
      final LedgerController controller = LedgerController(
        LedgerRepository(database),
      );
      await controller.initialize();
      try {
        await NotificationService.initialize();
        await NotificationService.scheduleDaily(
          enabled: controller.dailyReminderEnabled,
          hour: controller.dailyReminderHour,
          minute: controller.dailyReminderMinute,
        );
        await NotificationService.scheduleRecurringCheck();
      } catch (error, stackTrace) {
        // A device-specific notification failure must never block bookkeeping.
        debugPrint('Notification initialization failed: $error\n$stackTrace');
      }
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (error, stackTrace) {
      debugPrint('OneEntry startup failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _error = error;
        _stackTrace = stackTrace;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final LedgerController? controller = _controller;
    if (controller != null) return OneEntryApp(controller: controller);
    return MaterialApp(
      title: '一笔',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: _error == null
          ? const _LoadingPage()
          : _StartupErrorPage(
              error: _error!,
              stackTrace: _stackTrace,
              onRetry: _initialize,
            ),
    );
  }
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppTheme.green, AppTheme.greenLight],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Image.asset(
              'assets/branding/oneentry_icon.png',
              width: 112,
              height: 112,
            ),
            const SizedBox(height: 22),
            const Text(
              '一笔',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _StartupErrorPage extends StatelessWidget {
  const _StartupErrorPage({
    required this.error,
    required this.onRetry,
    this.stackTrace,
  });
  final Object error;
  final StackTrace? stackTrace;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('启动失败')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        const Icon(Icons.error_outline, size: 52, color: AppTheme.expense),
        const SizedBox(height: 16),
        const Text(
          '本地数据初始化没有完成',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Text('$error', textAlign: TextAlign.center),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('重试'),
        ),
        if (kDebugMode && stackTrace != null) ...<Widget>[
          const SizedBox(height: 20),
          SelectableText('$stackTrace', style: const TextStyle(fontSize: 11)),
        ],
      ],
    ),
  );
}
