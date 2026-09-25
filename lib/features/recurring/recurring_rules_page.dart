import 'package:flutter/material.dart';

import '../../data/ledger_controller.dart';
import '../../models/ledger_models.dart';
import '../../theme/app_theme.dart';

class RecurringRulesPage extends StatelessWidget {
  const RecurringRulesPage({required this.controller, super.key});
  final LedgerController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (BuildContext context, Widget? child) => Scaffold(
      appBar: AppBar(
        title: const Text('周期账目'),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            onPressed: () => _edit(context),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: controller.recurringRules.isEmpty
          ? const Center(child: Text('还没有周期账目'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text(
                    '到期时发送提醒，确认后仍由你手动记账',
                    style: TextStyle(fontSize: 12, color: Color(0xFF8A9099)),
                  ),
                ),
                ...controller.recurringRules.map(
                  (rule) => _RuleTile(
                    rule: rule,
                    onTap: () => _edit(context, rule),
                    onDelete: () => _delete(context, rule),
                    onToggle: (value) => controller.saveRecurringRule(
                      _copy(rule, enabled: value),
                    ),
                  ),
                ),
              ],
            ),
    ),
  );

  Future<void> _edit(BuildContext context, [RecurringRule? rule]) async {
    final List<LedgerAccount> accounts = controller.accounts
        .where((item) => !item.archived)
        .toList();
    if (accounts.isEmpty) return;
    final TextEditingController name = TextEditingController(
      text: rule?.name ?? '',
    );
    final TextEditingController amount = TextEditingController(
      text: rule == null ? '' : rule.amount.toStringAsFixed(2),
    );
    EntryType type = rule?.type ?? EntryType.expense;
    String frequency = rule?.frequency ?? 'month';
    int accountId = rule?.accountId ?? accounts.first.id;
    String category =
        rule?.category ??
        (controller.categories.isEmpty ? '其他' : controller.categories.first);
    final bool? save = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) =>
            AlertDialog(
              title: Text(rule == null ? '新增周期账目' : '编辑周期账目'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: name,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: '名称'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: '金额',
                        prefixText: '¥ ',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<EntryType>(
                      segments: const <ButtonSegment<EntryType>>[
                        ButtonSegment(
                          value: EntryType.expense,
                          label: Text('支出'),
                        ),
                        ButtonSegment(
                          value: EntryType.income,
                          label: Text('收入'),
                        ),
                      ],
                      selected: <EntryType>{type},
                      onSelectionChanged: (value) =>
                          setDialogState(() => type = value.first),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: frequency,
                      decoration: const InputDecoration(labelText: '周期'),
                      items:
                          const <MapEntry<String, String>>[
                                MapEntry('day', '每天'),
                                MapEntry('week', '每周'),
                                MapEntry('month', '每月'),
                                MapEntry('year', '每年'),
                              ]
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item.key,
                                  child: Text(item.value),
                                ),
                              )
                              .toList(),
                      onChanged: (value) =>
                          setDialogState(() => frequency = value ?? frequency),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: accountId,
                      decoration: const InputDecoration(labelText: '账户'),
                      items: accounts
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => accountId = value ?? accountId),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: '分类'),
                      items: controller.categories
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => category = value ?? category),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('保存'),
                ),
              ],
            ),
      ),
    );
    final String title = name.text.trim();
    final double value = double.tryParse(amount.text) ?? 0;
    if (save != true || title.isEmpty || value <= 0) return;
    await controller.saveRecurringRule(
      RecurringRule(
        id: rule?.id ?? 0,
        name: title,
        type: type,
        amount: value,
        frequency: frequency,
        anchorDate: rule?.anchorDate ?? DateTime.now(),
        accountId: accountId,
        category: category,
        enabled: rule?.enabled ?? true,
      ),
    );
  }

  Future<void> _delete(BuildContext context, RecurringRule rule) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('删除「${rule.name}」？'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.deleteRecurringRule(rule.id);
  }

  RecurringRule _copy(RecurringRule rule, {required bool enabled}) =>
      RecurringRule(
        id: rule.id,
        name: rule.name,
        type: rule.type,
        amount: rule.amount,
        frequency: rule.frequency,
        anchorDate: rule.anchorDate,
        accountId: rule.accountId,
        category: rule.category,
        enabled: enabled,
      );
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.rule,
    required this.onTap,
    required this.onDelete,
    required this.onToggle,
  });
  final RecurringRule rule;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
    ),
    child: ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        child: Icon(
          rule.type == EntryType.expense
              ? Icons.arrow_upward
              : Icons.arrow_downward,
        ),
      ),
      title: Text(rule.name),
      subtitle: Text('${_frequencyName(rule.frequency)} · ${rule.category}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '¥${rule.amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: rule.type == EntryType.expense
                  ? AppTheme.expense
                  : AppTheme.income,
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) =>
                value == 'toggle' ? onToggle(!rule.enabled) : onDelete(),
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              PopupMenuItem(
                value: 'toggle',
                child: Text(rule.enabled ? '停用' : '启用'),
              ),
              const PopupMenuItem(value: 'delete', child: Text('删除')),
            ],
          ),
        ],
      ),
    ),
  );

  String _frequencyName(String value) => switch (value) {
    'day' => '每天',
    'week' => '每周',
    'year' => '每年',
    _ => '每月',
  };
}
