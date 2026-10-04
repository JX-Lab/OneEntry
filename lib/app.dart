import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

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
    if (result != null) {
      await widget.controller.addEntry(result);
    }
  }

  Future<void> _editEntry(LedgerEntry entry) async {
    if (entry.type == EntryType.adjustment) return;
    final LedgerEntry? result = await _navigatorKey.currentState!
        .push<LedgerEntry>(
          MaterialPageRoute<LedgerEntry>(
            builder: (_) =>
                EntrySheet(controller: widget.controller, initial: entry),
          ),
        );
    if (result != null) {
      await widget.controller.updateEntry(entry, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) => MaterialApp(
        navigatorKey: _navigatorKey,
        title: '一笔',
        debugShowCheckedModeBanner: false,
        locale: const Locale('zh', 'CN'),
        supportedLocales: const <Locale>[Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: AppTheme.light(highContrast: widget.controller.highContrast),
        darkTheme: AppTheme.dark(highContrast: widget.controller.highContrast),
        themeMode: switch (widget.controller.themeMode) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        },
        builder: (BuildContext context, Widget? child) {
          final MediaQueryData media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              textScaler: TextScaler.linear(widget.controller.textScale),
            ),
            child: child!,
          );
        },
        home: HomePage(
          controller: widget.controller,
          onAddEntry: _addEntry,
          onEditEntry: _editEntry,
          onDeleteEntry: widget.controller.deleteEntry,
          onOpenStatistics: () =>
              _push(StatisticsPage(controller: widget.controller)),
          onOpenSettings: () =>
              _push(SettingsPage(controller: widget.controller)),
          onOpenAccounts: () =>
              _push(AccountsPage(controller: widget.controller)),
          onOpenMembers: () =>
              _push(MembersPage(controller: widget.controller)),
          onOpenBudget: () => _push(BudgetPage(controller: widget.controller)),
        ),
      ),
    );
  }
}
