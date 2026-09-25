import 'package:flutter/material.dart';

import '../../data/ledger_controller.dart';
import '../../services/notification_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.controller,
    required this.themeMode,
    required this.onThemeModeChanged,
    super.key,
  });

  final LedgerController controller;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _multi = true;
  bool _highContrast = false;
  bool _readerHints = true;
  bool _haptics = true;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: <Widget>[
        const SliverAppBar(title: Text('设置'), floating: true),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
          sliver: SliverList.list(
            children: <Widget>[
              _Section(
                title: '记账方式',
                children: <Widget>[
                  SwitchListTile(
                    title: const Text('多人记账'),
                    subtitle: const Text('每笔账目可关联多个成员'),
                    value: _multi,
                    onChanged: (bool value) => setState(() => _multi = value),
                  ),
                  const ListTile(
                    title: Text('多人统计'),
                    subtitle: Text('默认按参与人数 AA 均摊'),
                    trailing: Icon(Icons.chevron_right),
                  ),
                ],
              ),
              _Section(
                title: '提醒',
                children: <Widget>[
                  SwitchListTile(
                    title: const Text('提醒记账'),
                    subtitle: const Text('今天没有记账时提醒'),
                    value: widget.controller.dailyReminderEnabled,
                    onChanged: _toggleDailyReminder,
                  ),
                  if (widget.controller.dailyReminderEnabled)
                    ListTile(
                      title: const Text('每天提醒时间'),
                      trailing: Text(
                        '${widget.controller.dailyReminderHour.toString().padLeft(2, '0')}:${widget.controller.dailyReminderMinute.toString().padLeft(2, '0')}  ›',
                      ),
                      onTap: _pickReminderTime,
                    ),
                  ListTile(
                    title: const Text('周期账目'),
                    trailing: Text(
                      '${widget.controller.entries.where((entry) => entry.recurring).length} 笔  ›',
                    ),
                  ),
                ],
              ),
              _Section(
                title: '显示与语言',
                children: <Widget>[
                  ListTile(
                    title: const Text('主题'),
                    trailing: DropdownButton<ThemeMode>(
                      value: widget.themeMode,
                      underline: const SizedBox.shrink(),
                      items: const <DropdownMenuItem<ThemeMode>>[
                        DropdownMenuItem(
                          value: ThemeMode.system,
                          child: Text('跟随系统'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.light,
                          child: Text('日间'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.dark,
                          child: Text('夜间'),
                        ),
                      ],
                      onChanged: (ThemeMode? value) {
                        if (value != null) widget.onThemeModeChanged(value);
                      },
                    ),
                  ),
                  const ListTile(title: Text('语言'), trailing: Text('简体中文  ›')),
                ],
              ),
              _Section(
                title: '无障碍',
                children: <Widget>[
                  const ListTile(title: Text('文字大小'), trailing: Text('标准  ›')),
                  SwitchListTile(
                    title: const Text('增强颜色对比'),
                    value: _highContrast,
                    onChanged: (bool value) =>
                        setState(() => _highContrast = value),
                  ),
                  SwitchListTile(
                    title: const Text('屏幕朗读增强'),
                    value: _readerHints,
                    onChanged: (bool value) =>
                        setState(() => _readerHints = value),
                  ),
                  SwitchListTile(
                    title: const Text('震动反馈'),
                    value: _haptics,
                    onChanged: (bool value) => setState(() => _haptics = value),
                  ),
                ],
              ),
              const _Section(
                title: '数据',
                children: <Widget>[
                  ListTile(
                    title: Text('数据保存位置'),
                    subtitle: Text('主数据库保存在应用内部'),
                    trailing: Icon(Icons.chevron_right),
                  ),
                  ListTile(
                    title: Text('数据导出'),
                    trailing: Icon(Icons.chevron_right),
                  ),
                  ListTile(
                    title: Text('数据导入'),
                    trailing: Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _toggleDailyReminder(bool enabled) async {
    if (enabled && !await NotificationService.requestPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('需要通知权限才能开启提醒')));
      }
      return;
    }
    await widget.controller.setDailyReminder(
      enabled: enabled,
      hour: widget.controller.dailyReminderHour,
      minute: widget.controller.dailyReminderMinute,
    );
    await NotificationService.scheduleDaily(
      enabled: enabled,
      hour: widget.controller.dailyReminderHour,
      minute: widget.controller.dailyReminderMinute,
    );
    if (mounted) setState(() {});
  }

  Future<void> _pickReminderTime() async {
    final TimeOfDay? selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: widget.controller.dailyReminderHour,
        minute: widget.controller.dailyReminderMinute,
      ),
    );
    if (selected == null) return;
    await widget.controller.setDailyReminder(
      enabled: true,
      hour: selected.hour,
      minute: selected.minute,
    );
    await NotificationService.scheduleDaily(
      enabled: true,
      hour: selected.hour,
      minute: selected.minute,
    );
    if (mounted) setState(() {});
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    ),
  );
}
