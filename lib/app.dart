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
  const OneEntryApp({super.key});

  @override
  State<OneEntryApp> createState() => _OneEntryAppState();
}

class _OneEntryAppState extends State<OneEntryApp> {
  final LedgerController _controller = LedgerController();
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _push(Widget page) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Future<void> _addEntry() async {
    final LedgerEntry? result = await Navigator.of(context).push<LedgerEntry>(
      MaterialPageRoute<LedgerEntry>(
        builder: (_) => EntrySheet(controller: _controller),
      ),
    );
    if (result != null) _controller.addEntry(result);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '一笔',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      home: HomePage(
        controller: _controller,
        onAddEntry: _addEntry,
        onOpenStatistics: () => _push(StatisticsPage(controller: _controller)),
        onOpenSettings: () => _push(
          SettingsPage(
            controller: _controller,
            themeMode: _themeMode,
            onThemeModeChanged: (ThemeMode value) =>
                setState(() => _themeMode = value),
          ),
        ),
        onOpenAccounts: () => _push(AccountsPage(controller: _controller)),
        onOpenMembers: () => _push(MembersPage(controller: _controller)),
        onOpenBudget: () => _push(BudgetPage(controller: _controller)),
      ),
    );
  }
}
