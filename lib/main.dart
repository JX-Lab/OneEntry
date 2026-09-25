import 'package:flutter/material.dart';

import 'app.dart';
import 'data/app_database.dart';
import 'data/ledger_controller.dart';
import 'data/ledger_repository.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppDatabase database = AppDatabase();
  final LedgerController controller = LedgerController(
    LedgerRepository(database),
  );
  await controller.initialize();
  await NotificationService.initialize();
  await NotificationService.scheduleDaily(
    enabled: controller.dailyReminderEnabled,
    hour: controller.dailyReminderHour,
    minute: controller.dailyReminderMinute,
  );
  await NotificationService.scheduleRecurringCheck();
  runApp(OneEntryApp(controller: controller));
}
