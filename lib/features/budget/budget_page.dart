import 'package:flutter/material.dart';

import '../../data/ledger_controller.dart';
import '../../theme/app_theme.dart';

class BudgetPage extends StatelessWidget {
  const BudgetPage({required this.controller, super.key});
  final LedgerController controller;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final spent = controller.expenseForMonth(now);
    final budget = controller.monthlyBudget;
    final progress = budget == 0 ? 0.0 : spent / budget;
    final categories = <(String, double, double)>[
      ('餐饮', 620, 800),
      ('购物', 380, 500),
      ('交通', 180, 300),
      ('娱乐', 420, 300),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('预算'),
        centerTitle: true,
        actions: <Widget>[
          TextButton(
            onPressed: () => _editBudget(context, now),
            child: const Text('编辑'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: <Widget>[
                Text(
                  '${now.year}年${now.month}月',
                  style: const TextStyle(color: Color(0xFF8A9099)),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    _Value(label: '已支出', value: spent),
                    const SizedBox(width: 36),
                    _Value(label: '预算', value: budget),
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
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Text(
              '消费分类',
              style: TextStyle(fontSize: 12, color: Color(0xFF8A9099)),
            ),
          ),
          ...categories.map(
            (item) =>
                _CategoryBudget(name: item.$1, spent: item.$2, budget: item.$3),
          ),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add),
            label: const Text('添加分类预算'),
          ),
        ],
      ),
    );
  }

  Future<void> _editBudget(BuildContext context, DateTime month) async {
    final TextEditingController input = TextEditingController(
      text: controller.monthlyBudget.toStringAsFixed(2),
    );
    final double? result = await showDialog<double>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('本月总预算'),
        content: TextField(
          controller: input,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: '¥ '),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, double.tryParse(input.text)),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    input.dispose();
    if (result != null && result >= 0)
      await controller.setMonthlyBudget(month, result);
  }
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
  });
  final String name;
  final double spent;
  final double budget;
  @override
  Widget build(BuildContext context) {
    final progress = budget == 0 ? 0.0 : spent / budget;
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
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
