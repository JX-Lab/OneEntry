import 'package:flutter/material.dart';

import 'data/ledger_controller.dart';
import 'features/entry/entry_sheet.dart';
import 'features/home/home_page.dart';
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
  ThemeMode _themeMode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '一笔',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      home: OneEntryShell(
        themeMode: _themeMode,
        onThemeModeChanged: (ThemeMode value) =>
            setState(() => _themeMode = value),
      ),
    );
  }
}

class OneEntryShell extends StatefulWidget {
  const OneEntryShell({
    required this.themeMode,
    required this.onThemeModeChanged,
    super.key,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<OneEntryShell> createState() => _OneEntryShellState();
}

class _OneEntryShellState extends State<OneEntryShell> {
  final LedgerController _controller = LedgerController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addEntry() async {
    final LedgerEntry? result = await showModalBottomSheet<LedgerEntry>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) => EntrySheet(controller: _controller),
    );
    if (result != null && mounted) {
      _controller.addEntry(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      HomePage(
        controller: _controller,
        onOpenStatistics: () => setState(() => _index = 1),
      ),
      StatisticsPage(controller: _controller),
      SettingsPage(
        controller: _controller,
        themeMode: widget.themeMode,
        onThemeModeChanged: widget.onThemeModeChanged,
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _index, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int value) => setState(() => _index = value),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: '账目',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: '统计',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              onPressed: _addEntry,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('记一笔'),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
