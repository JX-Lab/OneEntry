import 'package:flutter/material.dart';

import '../../data/ledger_controller.dart';
import '../../models/ledger_models.dart';
import '../../theme/app_theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    required this.controller,
    required this.onAddEntry,
    required this.onOpenStatistics,
    required this.onOpenSettings,
    required this.onOpenAccounts,
    required this.onOpenMembers,
    required this.onOpenBudget,
    super.key,
  });

  final LedgerController controller;
  final VoidCallback onAddEntry;
  final VoidCallback onOpenStatistics;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenAccounts;
  final VoidCallback onOpenMembers;
  final VoidCallback onOpenBudget;

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
        final String query = _searchController.text.trim().toLowerCase();
        final List<LedgerEntry>
        entries = widget.controller.entriesForMonth(month).where((
          LedgerEntry entry,
        ) {
          if (query.isEmpty) return true;
          final String members = entry.memberIds
              .map(
                (int id) => widget.controller.members
                    .where((member) => member.id == id)
                    .map((member) => member.name)
                    .join(),
              )
              .join(' ');
          return '${entry.category} ${entry.note} $members ${entry.occurredAt.year}-${entry.occurredAt.month}-${entry.occurredAt.day}'
              .toLowerCase()
              .contains(query);
        }).toList();
        final double income = widget.controller.incomeForMonth(month);
        final double expense = widget.controller.expenseForMonth(month);
        return Scaffold(
          appBar: AppBar(
            centerTitle: true,
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
                : Text(
                    '${month.year}年${month.month}月',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
            actions: <Widget>[
              IconButton(
                tooltip: _searching ? '关闭搜索' : '搜索',
                onPressed: () => setState(() {
                  _searching = !_searching;
                  if (!_searching) _searchController.clear();
                }),
                icon: Icon(_searching ? Icons.close : Icons.search),
              ),
              IconButton(
                tooltip: '设置',
                onPressed: widget.onOpenSettings,
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 92),
            children: <Widget>[
              _SummaryCard(
                income: income,
                expense: expense,
                spent: expense,
                budget: widget.controller.monthlyBudget,
                onBudgetTap: widget.onOpenBudget,
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _QuickButton(
                      icon: Icons.people_outline,
                      label: '成员',
                      onTap: widget.onOpenMembers,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickButton(
                      icon: Icons.account_balance_wallet_outlined,
                      label: '账户',
                      onTap: widget.onOpenAccounts,
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
              const SizedBox(height: 16),
              if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 72),
                  child: Center(child: Text('本月还没有匹配的账目')),
                )
              else
                ..._groupedEntries(entries),
            ],
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: widget.onAddEntry,
              child: Ink(
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[AppTheme.green, AppTheme.greenLight],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x420EB078),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(Icons.edit_outlined, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      '记一笔',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _groupedEntries(List<LedgerEntry> entries) {
    final Map<String, List<LedgerEntry>> groups = <String, List<LedgerEntry>>{};
    for (final LedgerEntry entry in entries) {
      final String key = '${entry.occurredAt.month}月${entry.occurredAt.day}日';
      groups.putIfAbsent(key, () => <LedgerEntry>[]).add(entry);
    }
    return groups.entries
        .expand(
          (entry) => <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
              child: Text(
                entry.key,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8A9099),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ...entry.value.map((LedgerEntry item) => _EntryTile(entry: item)),
          ],
        )
        .toList();
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.income,
    required this.expense,
    required this.spent,
    required this.budget,
    required this.onBudgetTap,
  });
  final double income;
  final double expense;
  final double spent;
  final double budget;
  final VoidCallback onBudgetTap;

  @override
  Widget build(BuildContext context) {
    final bool over = spent > budget;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[AppTheme.green, AppTheme.greenLight],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x330EB078),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _SummaryValue(label: '↓ 收入', value: income),
                ),
                Container(width: .5, height: 54, color: Colors.white38),
                Expanded(
                  child: _SummaryValue(label: '↑ 支出', value: expense),
                ),
              ],
            ),
          ),
          Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: InkWell(
              onTap: onBudgetTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 9,
                ),
                child: Row(
                  children: <Widget>[
                    Text(
                      '本月预算 ¥${budget.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      over
                          ? '超支 ¥${(spent - budget).toStringAsFixed(2)}'
                          : '剩余 ¥${(budget - spent).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: over ? AppTheme.expense : null,
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 20),
                  ],
                ),
              ),
            ),
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
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value.toStringAsFixed(2),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
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
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Column(
          children: <Widget>[
            Icon(icon, size: 21),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 13)),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            transfer
                ? Icons.swap_horiz
                : expense
                ? Icons.restaurant_outlined
                : Icons.payments_outlined,
            size: 21,
          ),
        ),
        title: Text(
          transfer ? '转账' : entry.category,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          entry.note.isEmpty ? '无备注' : entry.note,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              '${expense
                  ? '-'
                  : transfer
                  ? ''
                  : '+'}${entry.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: expense
                    ? AppTheme.expense
                    : transfer
                    ? null
                    : AppTheme.income,
              ),
            ),
            Text(
              '${entry.occurredAt.hour.toString().padLeft(2, '0')}:${entry.occurredAt.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF8A9099)),
            ),
          ],
        ),
      ),
    );
  }
}
