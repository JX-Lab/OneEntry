import 'package:flutter/material.dart';

import 'data/ledger_controller.dart';
import 'features/accounts/accounts_page.dart';
import 'features/budget/budget_page.dart';
import 'features/entry/entry_sheet.dart';
import 'features/home/home_page.dart';
import 'features/members/members_page.dart';
import 'features/settings/settings_page.dart';
import 'features/statistics/statistics_page.dart';
import 'models/ledger_models.dart';
import 'theme/app_theme.dart';

class OneEntryApp extends StatefulWidget {
  const OneEntryApp({required this.controller, super.key});

  final LedgerController controller;

  @override
  State<OneEntryApp> createState() => _OneEntryAppState();
}

class _OneEntryAppState extends State<OneEntryApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  Future<void> _push(Widget page) async {
    await _navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  Future<void> _addEntry() async {
    final LedgerEntry? result = await _navigatorKey.currentState!
        .push<LedgerEntry>(
          MaterialPageRoute<LedgerEntry>(
            builder: (_) => EntrySheet(controller: widget.controller),
          ),
        );
    if (result != null) await widget.controller.addEntry(result);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: '一笔',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      home: HomePage(
        controller: widget.controller,
        onAddEntry: _addEntry,
        onOpenStatistics: () =>
            _push(StatisticsPage(controller: widget.controller)),
        onOpenSettings: () => _push(
          SettingsPage(
            controller: widget.controller,
            themeMode: _themeMode,
            onThemeModeChanged: (ThemeMode value) =>
                setState(() => _themeMode = value),
          ),
        ),
        onOpenAccounts: () =>
            _push(AccountsPage(controller: widget.controller)),
        onOpenMembers: () => _push(MembersPage(controller: widget.controller)),
        onOpenBudget: () => _push(BudgetPage(controller: widget.controller)),
      ),
    );
  }
}
