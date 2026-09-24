import 'package:flutter/material.dart';

import '../../data/ledger_controller.dart';
import '../../models/ledger_models.dart';
import '../../theme/app_theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    required this.controller,
    required this.onOpenStatistics,
    super.key,
  });

  final LedgerController controller;
  final VoidCallback onOpenStatistics;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final List<LedgerEntry> source = widget.controller.entriesForMonth(
          month,
        );
        final String query = _searchController.text.trim().toLowerCase();
        final List<LedgerEntry> entries = source.where((LedgerEntry entry) {
          if (query.isEmpty) return true;
          final String members = entry.memberIds
              .map(
                (int id) => widget.controller.members
                    .where((member) => member.id == id)
                    .map((member) => member.name)
                    .join(),
              )
              .join(' ');
          return '${entry.category} ${entry.note} $members ${entry.occurredAt.month}月${entry.occurredAt.day}日'
              .toLowerCase()
              .contains(query);
        }).toList();
        final double income = widget.controller.incomeForMonth(month);
        final double expense = widget.controller.expenseForMonth(month);
        return CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              floating: true,
              title: _searching
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: '搜索标签、成员、备注或日期',
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    )
                  : Text('${month.year}年${month.month}月'),
              actions: <Widget>[
                IconButton(
                  tooltip: _searching ? '关闭搜索' : '搜索',
                  onPressed: () => setState(() {
                    _searching = !_searching;
                    if (!_searching) _searchController.clear();
                  }),
                  icon: Icon(_searching ? Icons.close : Icons.search),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
              sliver: SliverList.list(
                children: <Widget>[
                  _SummaryCard(income: income, expense: expense),
                  const SizedBox(height: 10),
                  _BudgetBar(
                    spent: expense,
                    budget: widget.controller.monthlyBudget,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _QuickButton(
                          icon: Icons.people_outline,
                          label: '成员',
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickButton(
                          icon: Icons.account_balance_wallet_outlined,
                          label: '账户',
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickButton(
                          icon: Icons.insights_outlined,
                          label: '统计',
                          onTap: widget.onOpenStatistics,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (entries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 72),
                      child: Center(child: Text('本月还没有匹配的账目')),
                    )
                  else
                    ...entries.map(
                      (LedgerEntry entry) => _EntryTile(entry: entry),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.income, required this.expense});

  final double income;
  final double expense;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[AppTheme.green, AppTheme.greenLight],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _SummaryValue(label: '收入', value: income),
          ),
          Container(width: .5, height: 52, color: Colors.white38),
          Expanded(
            child: _SummaryValue(label: '支出', value: expense),
          ),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 5),
        Text(
          '¥${value.toStringAsFixed(2)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _BudgetBar extends StatelessWidget {
  const _BudgetBar({required this.spent, required this.budget});
  final double spent;
  final double budget;

  @override
  Widget build(BuildContext context) {
    final double progress = budget == 0 ? 0 : spent / budget;
    final bool over = progress > 1;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                const Text(
                  '本月预算',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  over
                      ? '超支 ¥${(spent - budget).toStringAsFixed(2)}'
                      : '剩余 ¥${(budget - spent).toStringAsFixed(2)}',
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 8,
              color: over ? AppTheme.expense : AppTheme.green,
              borderRadius: BorderRadius.circular(99),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: <Widget>[
            Icon(icon),
            const SizedBox(height: 6),
            Text(label),
          ],
        ),
      ),
    ),
  );
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});
  final LedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final bool expense = entry.type == EntryType.expense;
    final bool transfer = entry.type == EntryType.transfer;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            transfer
                ? Icons.swap_horiz
                : expense
                ? Icons.arrow_upward
                : Icons.arrow_downward,
          ),
        ),
        title: Text(transfer ? '转账' : entry.category),
        subtitle: Text(
          entry.note.isEmpty
              ? '${entry.occurredAt.month}月${entry.occurredAt.day}日'
              : entry.note,
        ),
        trailing: Text(
          '${expense
              ? '-'
              : transfer
              ? ''
              : '+'}¥${entry.amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: expense
                ? AppTheme.expense
                : transfer
                ? null
                : AppTheme.income,
          ),
        ),
      ),
    );
  }
}
