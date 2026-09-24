import 'package:flutter/material.dart';

import 'app.dart';
import 'data/app_database.dart';
import 'data/ledger_controller.dart';
import 'data/ledger_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppDatabase database = AppDatabase();
  final LedgerController controller = LedgerController(
    LedgerRepository(database),
  );
  await controller.initialize();
  runApp(OneEntryApp(controller: controller));
}
