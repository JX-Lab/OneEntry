import 'package:flutter/material.dart';

import '../../data/ledger_controller.dart';
import '../categories/categories_page.dart';
import '../recurring/recurring_rules_page.dart';
import '../../services/backup_service.dart';
import '../../services/notification_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({required this.controller, super.key});

  final LedgerController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (BuildContext context, Widget? child) => Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          const SliverAppBar(title: Text('设置'), pinned: true, floating: false),
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
                      value: widget.controller.multiEnabled,
                      onChanged: (bool value) => widget.controller
                          .setPreference('multi_enabled', value ? '1' : '0'),
                    ),
                    ListTile(
                      title: const Text('多人统计'),
                      subtitle: const Text('选择成员金额的统计方式'),
                      trailing: Text(
                        widget.controller.splitMode == 'full'
                            ? '整笔计入  ›'
                            : 'AA 均摊  ›',
                      ),
                      onTap: _pickSplitMode,
                    ),
                    ListTile(
                      title: const Text('标签管理'),
                      subtitle: const Text('批量合并、移除和调整显示顺序'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              CategoriesPage(controller: widget.controller),
                        ),
                      ),
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
                        '${widget.controller.recurringRules.length} 笔  ›',
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              RecurringRulesPage(controller: widget.controller),
                        ),
                      ),
                    ),
                  ],
                ),
                _Section(
                  title: '显示与语言',
                  children: <Widget>[
                    ListTile(
                      title: const Text('主题'),
                      trailing: Text('${_themeName()}  ›'),
                      onTap: _pickTheme,
                    ),
                    const ListTile(
                      title: Text('语言'),
                      trailing: Text('简体中文  ›'),
                    ),
                  ],
                ),
                _Section(
                  title: '无障碍',
                  children: <Widget>[
                    ListTile(
                      title: const Text('文字大小'),
                      subtitle: const Text('调整正文与操作文字'),
                      trailing: Text('${_textScaleName()}  ›'),
                      onTap: _pickTextScale,
                    ),
                    SwitchListTile(
                      title: const Text('增强颜色对比'),
                      value: widget.controller.highContrast,
                      onChanged: (bool value) => widget.controller
                          .setPreference('high_contrast', value ? '1' : '0'),
                    ),
                  ],
                ),
                _Section(
                  title: '数据',
                  children: <Widget>[
                    const ListTile(
                      title: Text('数据保存位置'),
                      subtitle: Text('主数据库保存在应用内部'),
                      trailing: Icon(Icons.chevron_right),
                    ),
                    ListTile(
                      title: const Text('数据导出'),
                      subtitle: const Text('JSON / ZIP / XLSX'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _showExport,
                    ),
                    ListTile(
                      title: const Text('数据导入'),
                      subtitle: const Text('从系统文件选择器恢复'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _importBackup,
                    ),
                    ListTile(
                      title: const Text(
                        '清除全部数据',
                        style: TextStyle(color: Color(0xFFFA5151)),
                      ),
                      subtitle: const Text('删除全部本地记账数据'),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: Color(0xFFFA5151),
                      ),
                      onTap: _clearAllData,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  String _themeName() => switch (widget.controller.themeMode) {
    'light' => '日间',
    'dark' => '夜间',
    _ => '跟随系统',
  };

  String _textScaleName() {
    if (widget.controller.textScale >= 1.3) return '特大';
    if (widget.controller.textScale >= 1.15) return '较大';
    return '标准';
  }

  Future<void> _pickSplitMode() async {
    final String? value = await _simpleChoice(
      '多人统计',
      const <MapEntry<String, String>>[
        MapEntry('equal', 'AA 均摊'),
        MapEntry('full', '整笔计入每位成员'),
      ],
    );
    if (value != null)
      await widget.controller.setPreference('split_mode', value);
  }

  Future<void> _pickTheme() async {
    final String? value = await _simpleChoice(
      '主题',
      const <MapEntry<String, String>>[
        MapEntry('system', '跟随系统'),
        MapEntry('light', '日间'),
        MapEntry('dark', '夜间'),
      ],
    );
    if (value != null)
      await widget.controller.setPreference('theme_mode', value);
  }

  Future<void> _pickTextScale() async {
    final String? value = await _simpleChoice(
      '文字大小',
      const <MapEntry<String, String>>[
        MapEntry('1.0', '标准'),
        MapEntry('1.15', '较大'),
        MapEntry('1.3', '特大'),
      ],
    );
    if (value != null)
      await widget.controller.setPreference('text_scale', value);
  }

  Future<String?> _simpleChoice(
    String title,
    List<MapEntry<String, String>> items,
  ) => showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              title: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ...items.map(
              (item) => ListTile(
                title: Text(item.value),
                onTap: () => Navigator.pop(context, item.key),
              ),
            ),
          ],
        ),
      ),
    ),
  );

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

  Future<void> _showExport() async {
    final ExportFormat? format = await showModalBottomSheet<ExportFormat>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const ListTile(
                title: Text(
                  '导出数据',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              ListTile(
                title: const Text('JSON 完整备份'),
                subtitle: const Text('最适合恢复'),
                onTap: () => Navigator.pop(context, ExportFormat.json),
              ),
              ListTile(
                title: const Text('ZIP 归档'),
                subtitle: const Text('包含 JSON 与 CSV'),
                onTap: () => Navigator.pop(context, ExportFormat.zip),
              ),
              ListTile(
                title: const Text('XLSX 表格'),
                subtitle: const Text('可用 Excel 阅读，也可原样导回'),
                onTap: () => Navigator.pop(context, ExportFormat.xlsx),
              ),
            ],
          ),
        ),
      ),
    );
    if (format == null) return;
    final bool saved = await BackupService.export(widget.controller, format);
    if (mounted && saved) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('导出完成')));
    }
  }

  Future<void> _importBackup() async {
    final ImportSource? source = await showModalBottomSheet<ImportSource>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const ListTile(
                title: Text(
                  '选择导入来源',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '自动识别可解析任意含日期和金额列的 XLS / XLSX / CSV 表格',
                  textAlign: TextAlign.center,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome_outlined),
                title: const Text('自动识别'),
                subtitle: const Text('抓取表头关键词；分类、账户、成员和备注均可选'),
                onTap: () => Navigator.pop(context, ImportSource.automatic),
              ),
              ListTile(
                leading: const Icon(Icons.archive_outlined),
                title: const Text('同旅'),
                subtitle: const Text('迁移 ZIP；只读取账本与成员颜色'),
                onTap: () => Navigator.pop(context, ImportSource.tonglv),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: const Text('时光序'),
                subtitle: const Text('账本导出 ZIP / XLSX；自动读取明细表'),
                onTap: () => Navigator.pop(context, ImportSource.shiguangxu),
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('一笔完整备份'),
                subtitle: const Text('JSON / ZIP / XLSX，可完整覆盖恢复'),
                onTap: () => Navigator.pop(context, ImportSource.oneEntry),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('导入数据？'),
        content: const Text(
          '导入前建议先导出 ZIP 备份。一笔完整备份会覆盖数据库；同旅和时光序会追加账目并自动跳过重复记录。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('选择文件'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final String? message = await BackupService.importBackup(
        widget.controller,
        source: source,
      );
      await NotificationService.scheduleDaily(
        enabled: widget.controller.dailyReminderEnabled,
        hour: widget.controller.dailyReminderHour,
        minute: widget.controller.dailyReminderMinute,
      );
      await NotificationService.scheduleRecurringCheck();
      if (mounted && message != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导入失败：$error')));
      }
    }
  }

  Future<void> _clearAllData() async {
    final bool? first = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('清除全部数据？'),
        content: const Text('全部账目、账户、成员、预算和周期规则将被永久删除。建议先导出 ZIP 备份。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('继续'),
          ),
        ],
      ),
    );
    if (first != true || !mounted) return;
    final bool? second = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('再次确认'),
        content: const Text('此操作无法撤销。确定永久清除全部本地数据？'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFA5151),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('永久清除'),
          ),
        ],
      ),
    );
    if (second != true) return;
    await widget.controller.clearAllData();
    await NotificationService.scheduleDaily(
      enabled: false,
      hour: 20,
      minute: 0,
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('全部数据已清除')));
    }
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
