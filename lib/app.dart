import 'dart:async';

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
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

class OneEntryApp extends StatefulWidget {
  const OneEntryApp({required this.controller, super.key});

  final LedgerController controller;

  @override
  State<OneEntryApp> createState() => _OneEntryAppState();
}

class _OneEntryAppState extends State<OneEntryApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<NotificationLaunchAction>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _notificationSubscription = NotificationService.launchEvents.listen(
      _handleNotificationLaunch,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final NotificationLaunchAction? action =
            await NotificationService.takeLaunchAction();
        if (action != null) await _handleNotificationLaunch(action);
      } on Object {
        // Notification launch actions are optional on unsupported platforms.
      }
    });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
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
      await _handleRecurringNotification(result);
    }
  }

  Future<void> _addVoiceEntry(LedgerEntry draft) async {
    final LedgerEntry? result = await _navigatorKey.currentState!
        .push<LedgerEntry>(
          MaterialPageRoute<LedgerEntry>(
            builder: (_) =>
                EntrySheet(controller: widget.controller, draft: draft),
          ),
        );
    if (result != null) {
      await widget.controller.addEntry(result);
      await _handleRecurringNotification(result);
    }
  }

  Future<void> _handleRecurringNotification(LedgerEntry entry) async {
    if (!entry.recurring) return;
    try {
      await NotificationService.scheduleRecurringCheck();
      if (await NotificationService.requestPermission()) return;
    } on Object {
      // Saving an entry must not fail because a device notification API failed.
    }
    final BuildContext? notificationContext = _navigatorKey.currentContext;
    if (!mounted || notificationContext == null) return;
    ScaffoldMessenger.of(notificationContext).showSnackBar(
      const SnackBar(
        content: Text('周期账目已保存，但系统通知尚未开启'),
        action: SnackBarAction(
          label: '打开设置',
          onPressed: NotificationService.openSettings,
        ),
      ),
    );
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

  Future<void> _repeatEntry(LedgerEntry entry) async {
    if (entry.type == EntryType.adjustment) return;
    final LedgerEntry draft = LedgerEntry(
      id: 0,
      type: entry.type,
      amount: entry.amount,
      category: entry.category,
      occurredAt: DateTime.now(),
      note: entry.note,
      accountId: entry.accountId,
      toAccountId: entry.toAccountId,
      memberIds: List<int>.from(entry.memberIds),
    );
    final LedgerEntry? result = await _navigatorKey.currentState!
        .push<LedgerEntry>(
          MaterialPageRoute<LedgerEntry>(
            builder: (_) =>
                EntrySheet(controller: widget.controller, draft: draft),
          ),
        );
    if (result != null) await widget.controller.addEntry(result);
  }

  Future<void> _handleNotificationLaunch(
    NotificationLaunchAction action,
  ) async {
    if (!mounted || _navigatorKey.currentState == null) return;
    if (action.type == 'new_entry') {
      await _addEntry();
      return;
    }
    if (action.type != 'recurring_rule' || action.recurringRuleId == null) {
      return;
    }
    final List<RecurringRule> rules = widget.controller.recurringRules
        .where((RecurringRule rule) => rule.id == action.recurringRuleId)
        .toList();
    if (rules.isEmpty) return;
    final List<LedgerAccount> accounts = widget.controller.accounts
        .where((LedgerAccount account) => !account.archived)
        .toList();
    if (accounts.isEmpty) return;
    final RecurringRule rule = rules.first;
    final int accountId =
        accounts.any((LedgerAccount account) => account.id == rule.accountId)
        ? rule.accountId!
        : accounts.first.id;
    final LedgerEntry draft = LedgerEntry(
      id: 0,
      type: rule.type,
      amount: rule.amount,
      category: rule.category,
      occurredAt: DateTime.now(),
      note: rule.name,
      accountId: accountId,
    );
    final LedgerEntry? result = await _navigatorKey.currentState!
        .push<LedgerEntry>(
          MaterialPageRoute<LedgerEntry>(
            builder: (_) =>
                EntrySheet(controller: widget.controller, draft: draft),
          ),
        );
    if (result != null) await widget.controller.addEntry(result);
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
        theme: AppTheme.light(
          highContrast: widget.controller.highContrast,
          accentKey: widget.controller.themeColor,
          colorVisionMode: widget.controller.colorVisionMode,
        ),
        darkTheme: AppTheme.dark(
          highContrast: widget.controller.highContrast,
          accentKey: widget.controller.themeColor,
          colorVisionMode: widget.controller.colorVisionMode,
        ),
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
          onVoiceEntry: _addVoiceEntry,
          onEditEntry: _editEntry,
          onDeleteEntry: widget.controller.deleteEntry,
          onRepeatEntry: _repeatEntry,
          onOpenStatistics: () =>
              _push(StatisticsPage(controller: widget.controller)),
          onOpenSettings: () =>
              _push(SettingsPage(controller: widget.controller)),
          onOpenAccounts: () =>
              _push(AccountsPage(controller: widget.controller)),
          onOpenMembers: () =>
              _push(MembersPage(controller: widget.controller)),
          onOpenBudget: (DateTime month) =>
              _push(BudgetPage(controller: widget.controller, month: month)),
        ),
      ),
    );
  }
}
