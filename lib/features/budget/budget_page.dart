import 'package:flutter/material.dart';

import '../../data/ledger_controller.dart';
import '../../models/ledger_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/swipe_action_tile.dart';

class BudgetPage extends StatefulWidget {
  const BudgetPage({required this.controller, super.key});
  final LedgerController controller;

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  LedgerController get controller => widget.controller;
  bool _editing = false;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (BuildContext context, Widget? child) {
      final DateTime now = DateTime.now();
      final double spent = controller.expenseForMonth(now);
      final double budget = controller.monthlyBudget;
      final double progress = budget == 0 ? 0 : spent / budget;
      final Map<String, double> categorySpent = <String, double>{};
      for (final LedgerEntry entry
          in controller
              .entriesForMonth(now)
              .where((item) => item.type == EntryType.expense)) {
        categorySpent.update(
          entry.category,
          (value) => value + entry.amount,
          ifAbsent: () => entry.amount,
        );
      }
      return Scaffold(
        appBar: AppBar(
          title: const Text('预算'),
          centerTitle: true,
          actions: <Widget>[
            TextButton(
              onPressed: () => setState(() => _editing = !_editing),
              child: Text(_editing ? '完成' : '编辑'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
          children: <Widget>[
            _BudgetHero(
              month: now,
              spent: spent,
              budget: budget,
              progress: progress,
              editing: _editing,
              onTap: _editing ? () => _editTotal(context, now) : null,
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 16, 4, 8),
              child: Text(
                '消费分类',
                style: TextStyle(fontSize: 12, color: Color(0xFF8A9099)),
              ),
            ),
            if (controller.categoryBudgets.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    '还没有分类预算',
                    style: TextStyle(fontSize: 16, color: Color(0xFF8A9099)),
                  ),
                ),
              )
            else
              ...controller.categoryBudgets.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: SwipeActionTile(
                    actionLabel: '删除',
                    onAction: () =>
                        controller.setCategoryBudget(now, entry.key, 0),
                    onTap: _editing
                        ? () => _editCategory(
                            context,
                            now,
                            entry.key,
                            entry.value,
                          )
                        : null,
                    child: _CategoryBudget(
                      name: entry.key,
                      spent: categorySpent[entry.key] ?? 0,
                      budget: entry.value,
                      editing: _editing,
                    ),
                  ),
                ),
              ),
            if (_editing)
              OutlinedButton.icon(
                onPressed: budget <= 0
                    ? null
                    : () => _addCategory(context, now),
                icon: const Icon(Icons.add),
                label: const Text('添加分类预算'),
              ),
          ],
        ),
      );
    },
  );

  Future<void> _editTotal(BuildContext context, DateTime month) async {
    final double? amount = await _amountDialog(
      context,
      '本月总预算',
      controller.monthlyBudget,
    );
    if (amount == null) return;
    final double categoryTotal = controller.categoryBudgets.values.fold(
      0,
      (sum, value) => sum + value,
    );
    if (amount < categoryTotal && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('总预算不能小于分类预算合计 ¥${categoryTotal.toStringAsFixed(2)}'),
        ),
      );
      return;
    }
    await controller.setMonthlyBudget(month, amount);
  }

  Future<void> _addCategory(BuildContext context, DateTime month) async {
    final List<String> available = controller
        .categoriesFor(EntryType.expense)
        .map((item) => item.name)
        .where(
          (name) =>
              !controller.categoryBudgets.containsKey(name) &&
              name != '工资' &&
              name != '转账',
        )
        .toList();
    final String? category = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: available
              .map(
                (name) => ListTile(
                  title: Text(name),
                  onTap: () => Navigator.pop(context, name),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (category == null || !context.mounted) return;
    final double? amount = await _amountDialog(context, '$category预算', 0);
    if (amount != null) await _saveCategory(context, month, category, amount);
  }

  Future<void> _editCategory(
    BuildContext context,
    DateTime month,
    String category,
    double current,
  ) async {
    final double? amount = await _amountDialog(
      context,
      '$category预算（填 0 删除）',
      current,
    );
    if (amount != null) await _saveCategory(context, month, category, amount);
  }

  Future<void> _saveCategory(
    BuildContext context,
    DateTime month,
    String category,
    double amount,
  ) async {
    final bool saved = await controller.setCategoryBudget(
      month,
      category,
      amount,
    );
    if (!saved && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('分类预算合计不能超过总预算')));
    }
  }

  Future<double?> _amountDialog(
    BuildContext context,
    String title,
    double current,
  ) async {
    final TextEditingController input = TextEditingController(
      text: current > 0 ? current.toStringAsFixed(2) : '',
    );
    final double? result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                height: 52,
                child: Row(
                  children: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(context, double.tryParse(input.text)),
                      child: const Text('保存'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                child: TextField(
                  controller: input,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(prefixText: '¥ '),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return result;
  }
}

class _BudgetHero extends StatelessWidget {
  const _BudgetHero({
    required this.month,
    required this.spent,
    required this.budget,
    required this.progress,
    required this.editing,
    required this.onTap,
  });
  final DateTime month;
  final double spent;
  final double budget;
  final double progress;
  final bool editing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: <Widget>[
          Text(
            '${month.year}年${month.month}月',
            style: const TextStyle(color: Color(0xFF8A9099)),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _Value(label: '已支出', value: spent),
              const SizedBox(width: 36),
              _Value(label: editing ? '预算 ›' : '预算', value: budget),
            ],
          ),
          const SizedBox(height: 18),
          LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 11,
            color: progress > 1 ? AppTheme.expense : AppTheme.green,
            borderRadius: BorderRadius.circular(99),
          ),
          const SizedBox(height: 8),
          Text('${(progress * 100).toStringAsFixed(1)}%'),
          const SizedBox(height: 10),
          Text(
            progress > 1
                ? '超支 ¥${(spent - budget).toStringAsFixed(2)}'
                : '剩余 ¥${(budget - spent).toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: progress > 1 ? AppTheme.expense : null,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Value extends StatelessWidget {
  const _Value({required this.label, required this.value});
  final String label;
  final double value;
  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      Text(
        label,
        style: const TextStyle(color: Color(0xFF8A9099), fontSize: 12),
      ),
      const SizedBox(height: 3),
      Text(
        '¥${value.toStringAsFixed(2)}',
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ],
  );
}

class _CategoryBudget extends StatelessWidget {
  const _CategoryBudget({
    required this.name,
    required this.spent,
    required this.budget,
    required this.editing,
  });
  final String name;
  final double spent;
  final double budget;
  final bool editing;
  @override
  Widget build(BuildContext context) {
    final double progress = budget == 0 ? 0 : spent / budget;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '¥${spent.toStringAsFixed(0)} / ¥${budget.toStringAsFixed(0)}',
                style: const TextStyle(color: Color(0xFF8A9099), fontSize: 12),
              ),
              if (editing) const Icon(Icons.chevron_right, size: 18),
            ],
          ),
          const SizedBox(height: 9),
          LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 9,
            color: progress > 1 ? AppTheme.expense : AppTheme.green,
            borderRadius: BorderRadius.circular(99),
          ),
          if (progress > 1)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '超支 ¥${(spent - budget).toStringAsFixed(0)} · ${(progress * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(color: AppTheme.expense, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
