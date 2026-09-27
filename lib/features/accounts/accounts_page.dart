import 'package:flutter/material.dart';

import '../../data/ledger_controller.dart';
import '../../models/ledger_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/swipe_action_tile.dart';
import '../entry/entry_sheet.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({required this.controller, super.key});
  final LedgerController controller;

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  final TextEditingController _search = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (BuildContext context, Widget? child) {
      final String query = _search.text.trim().toLowerCase();
      final List<LedgerAccount> active = widget.controller.accounts
          .where(
            (item) => !item.archived && item.name.toLowerCase().contains(query),
          )
          .toList();
      final List<LedgerAccount> archived = widget.controller.accounts
          .where(
            (item) => item.archived && item.name.toLowerCase().contains(query),
          )
          .toList();
      final double total = widget.controller.accounts
          .where((item) => !item.archived)
          .fold(0, (sum, item) => sum + item.balance);
      return Scaffold(
        appBar: AppBar(
          title: _searching
              ? TextField(
                  controller: _search,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: '搜索账户',
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => setState(() {}),
                )
              : const Text('账户'),
          centerTitle: true,
          actions: <Widget>[
            IconButton(
              onPressed: () => _edit(context),
              icon: const Icon(Icons.add),
            ),
            IconButton(
              onPressed: () => setState(() {
                _searching = !_searching;
                if (!_searching) _search.clear();
              }),
              icon: Icon(_searching ? Icons.close : Icons.search),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    '总资产',
                    style: TextStyle(color: Color(0xFF8A9099), fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '¥${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 14, 4, 8),
              child: Text(
                '点卡片查看详情；左滑后点击“归档”',
                style: TextStyle(fontSize: 12, color: Color(0xFF8A9099)),
              ),
            ),
            if (query.isEmpty)
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: active.length,
                itemBuilder: (BuildContext context, int index) =>
                    ReorderableDelayedDragStartListener(
                      key: ValueKey('reorder-account-${active[index].id}'),
                      index: index,
                      child: _tile(context, active[index]),
                    ),
                onReorder: (int oldIndex, int newIndex) {
                  if (newIndex > oldIndex) newIndex--;
                  final LedgerAccount item = active.removeAt(oldIndex);
                  active.insert(newIndex, item);
                  widget.controller.reorderAccounts(
                    active.map((item) => item.id).toList(),
                  );
                },
              )
            else
              ...active.map((item) => _tile(context, item)),
            if (archived.isNotEmpty) ...<Widget>[
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 16, 4, 8),
                child: Text(
                  '已归档账户',
                  style: TextStyle(fontSize: 12, color: Color(0xFF8A9099)),
                ),
              ),
              ...archived.map((item) => _tile(context, item)),
            ],
          ],
        ),
      );
    },
  );

  Widget _tile(BuildContext context, LedgerAccount account) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: SwipeActionTile(
      key: ValueKey('account-${account.id}-${account.archived}'),
      actionLabel: account.archived ? '恢复' : '归档',
      actionColor: account.archived ? AppTheme.green : AppTheme.expense,
      onAction: () =>
          widget.controller.setAccountArchived(account.id, !account.archived),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _AccountDetailPage(
            controller: widget.controller,
            accountId: account.id,
            onEdit: () => _edit(context, account),
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: ListTile(
          leading: CircleAvatar(child: Icon(_accountIcon(account.icon))),
          title: Text(account.name),
          subtitle: account.archived ? const Text('已归档') : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '¥${account.balance.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: account.balance < 0 ? AppTheme.expense : null,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _edit(BuildContext context, [LedgerAccount? account]) async {
    final TextEditingController name = TextEditingController(
      text: account?.name ?? '',
    );
    final TextEditingController balance = TextEditingController(
      text: account == null ? '' : account.balance.toStringAsFixed(2),
    );
    String icon = account?.icon ?? 'cash';
    final bool? save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter update) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _SheetBar(
                    title: account == null ? '新增账户' : '编辑账户',
                    onSave: () => Navigator.pop(context, true),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Column(
                      children: <Widget>[
                        TextField(
                          controller: name,
                          autofocus: true,
                          decoration: const InputDecoration(labelText: '名称'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: balance,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: InputDecoration(
                            labelText: account == null ? '初始余额' : '余额',
                            prefixText: '¥ ',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(18, 4, 18, 8),
                      child: Text(
                        '图标',
                        style: TextStyle(color: Color(0xFF8A9099)),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _accountIcons
                          .map(
                            (String item) => InkWell(
                              onTap: () => update(() => icon = item),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: icon == item
                                      ? AppTheme.green.withValues(alpha: .12)
                                      : Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: icon == item
                                        ? AppTheme.green
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(_accountIcon(item), size: 22),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final String value = name.text.trim();
    final double amount = double.tryParse(balance.text) ?? 0;
    if (save != true || value.isEmpty) return;
    if (account == null) {
      await widget.controller.addAccount(value, amount, icon);
    } else {
      await widget.controller.updateAccount(account.id, value, amount, icon);
    }
  }
}

class _AccountDetailPage extends StatelessWidget {
  const _AccountDetailPage({
    required this.controller,
    required this.accountId,
    required this.onEdit,
  });
  final LedgerController controller;
  final int accountId;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (BuildContext context, Widget? child) {
      final LedgerAccount account = controller.accounts.firstWhere(
        (item) => item.id == accountId,
      );
      final List<LedgerEntry> entries = controller.entries
          .where(
            (entry) =>
                entry.accountId == accountId || entry.toAccountId == accountId,
          )
          .toList();
      final double income = entries
          .where((entry) => entry.type == EntryType.income)
          .fold(0, (sum, entry) => sum + entry.amount);
      final double expense = entries
          .where((entry) => entry.type == EntryType.expense)
          .fold(0, (sum, entry) => sum + entry.amount);
      final Map<String, List<LedgerEntry>> months =
          <String, List<LedgerEntry>>{};
      for (final LedgerEntry entry in entries) {
        final String key =
            '${entry.occurredAt.year}年${entry.occurredAt.month}月';
        months.putIfAbsent(key, () => <LedgerEntry>[]).add(entry);
      }
      return Scaffold(
        appBar: AppBar(
          title: Text(account.name),
          actions: <Widget>[
            PopupMenuButton<String>(
              onSelected: (String value) {
                if (value == 'edit') {
                  onEdit();
                } else if (value == 'archive') {
                  controller.setAccountArchived(account.id, !account.archived);
                } else {
                  _deleteAccount(context, account);
                }
              },
              itemBuilder: (_) => <PopupMenuEntry<String>>[
                const PopupMenuItem(value: 'edit', child: Text('编辑')),
                PopupMenuItem(
                  value: 'archive',
                  child: Text(account.archived ? '取消归档' : '归档账户'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    '永久删除',
                    style: TextStyle(color: AppTheme.expense),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(_accountIcon(account.icon), size: 28),
                        const SizedBox(width: 10),
                        Text(
                          '${account.name}${account.archived ? ' · 已归档' : ''}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '账户余额',
                      style: TextStyle(color: Color(0xFF8A9099)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '¥${account.balance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _AccountMetric(
                            label: '流入',
                            value: income,
                            color: AppTheme.income,
                          ),
                        ),
                        Expanded(
                          child: _AccountMetric(
                            label: '流出',
                            value: expense,
                            color: AppTheme.expense,
                          ),
                        ),
                        Expanded(
                          child: _AccountMetric(
                            label: '笔数',
                            text: '${entries.length}',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 14, 4, 8),
              child: Text('相关账目'),
            ),
            if (entries.isEmpty)
              const Center(child: Text('还没有相关账目'))
            else
              ...months.entries.map(
                (month) => Card(
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    initiallyExpanded: month.key == months.keys.first,
                    title: Text(
                      month.key,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text('${month.value.length} 笔'),
                    children: month.value
                        .map(
                          (entry) => ListTile(
                            onTap: entry.type == EntryType.adjustment
                                ? null
                                : () => _openEntry(context, entry),
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(
                                entry.type == EntryType.adjustment
                                    ? Icons.account_balance_wallet_outlined
                                    : _detailCategoryIcon(entry.category),
                                size: 20,
                              ),
                            ),
                            title: Text(
                              entry.type == EntryType.adjustment
                                  ? '余额调整'
                                  : entry.category,
                            ),
                            subtitle: entry.note.isEmpty
                                ? null
                                : Text(entry.note),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: <Widget>[
                                Text(
                                  entry.type == EntryType.adjustment
                                      ? '${entry.adjustmentDelta >= 0 ? '+' : '-'}¥${entry.adjustmentDelta.abs().toStringAsFixed(2)}'
                                      : '${entry.type == EntryType.expense
                                            ? '-'
                                            : entry.type == EntryType.income
                                            ? '+'
                                            : ''}¥${entry.amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color:
                                        entry.type == EntryType.expense ||
                                            entry.adjustmentDelta < 0
                                        ? AppTheme.expense
                                        : entry.type == EntryType.income ||
                                              entry.adjustmentDelta > 0
                                        ? AppTheme.income
                                        : null,
                                  ),
                                ),
                                Text(
                                  '余额 ¥${account.balance.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF8A9099),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );

  Future<void> _openEntry(BuildContext context, LedgerEntry entry) async {
    final LedgerEntry? updated = await Navigator.of(context).push<LedgerEntry>(
      MaterialPageRoute<LedgerEntry>(
        builder: (_) => EntrySheet(controller: controller, initial: entry),
      ),
    );
    if (updated != null) await controller.updateEntry(entry, updated);
  }

  Future<void> _deleteAccount(
    BuildContext context,
    LedgerAccount account,
  ) async {
    if (controller.accounts.where((item) => !item.archived).length <= 1 &&
        !account.archived) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('至少保留一个可用账户')));
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('永久删除「${account.name}」？'),
        content: const Text('该账户及其相关账目将被永久删除，此操作无法撤销。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.expense),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('永久删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await controller.deleteAccount(account.id);
    if (context.mounted) Navigator.pop(context);
  }
}

class _AccountMetric extends StatelessWidget {
  const _AccountMetric({
    required this.label,
    this.value,
    this.text,
    this.color,
  });
  final String label;
  final double? value;
  final String? text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(label, style: const TextStyle(color: Color(0xFF8A9099))),
      const SizedBox(height: 3),
      Text(
        text ?? '¥${value!.toStringAsFixed(2)}',
        style: TextStyle(fontWeight: FontWeight.w700, color: color),
      ),
    ],
  );
}

class _SheetBar extends StatelessWidget {
  const _SheetBar({required this.title, required this.onSave});
  final String title;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    child: Row(
      children: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        TextButton(onPressed: onSave, child: const Text('保存')),
      ],
    ),
  );
}

const List<String> _accountIcons = <String>[
  'cash',
  'wallet',
  'chat',
  'bank',
  'card',
  'saving',
  'coin',
  'online',
];

IconData _accountIcon(String value) => switch (value) {
  'cash' => Icons.payments_outlined,
  'chat' => Icons.chat_bubble_outline,
  'bank' => Icons.account_balance_outlined,
  'card' => Icons.credit_card,
  'saving' => Icons.savings_outlined,
  'coin' => Icons.monetization_on_outlined,
  'online' => Icons.language,
  _ => Icons.account_balance_wallet_outlined,
};

IconData _detailCategoryIcon(String category) => switch (category) {
  '交通' => Icons.directions_car_outlined,
  '购物' => Icons.shopping_bag_outlined,
  '居住' => Icons.home_outlined,
  '娱乐' => Icons.sports_esports_outlined,
  '医疗' => Icons.medical_services_outlined,
  '学习' => Icons.menu_book_outlined,
  '旅行' => Icons.flight_outlined,
  '工资' => Icons.payments_outlined,
  _ => Icons.restaurant_outlined,
};
