import 'package:flutter/material.dart';

import '../../data/ledger_controller.dart';
import '../../models/ledger_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/swipe_action_tile.dart';
import '../entry/entry_sheet.dart';
import '../entry/entry_detail_sheet.dart';

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
      final List<LedgerAccount> allActive = widget.controller.accounts
          .where((item) => !item.archived)
          .toList();
      final List<LedgerAccount> active = allActive
          .where((item) => item.name.toLowerCase().contains(query))
          .toList();
      final List<LedgerAccount> archived = widget.controller.accounts
          .where(
            (item) => item.archived && item.name.toLowerCase().contains(query),
          )
          .toList();
      final double total = widget.controller.accounts.fold(
        0,
        (sum, item) => sum + item.balance,
      );
      final double debt = widget.controller.accounts
          .where((item) => item.balance < 0)
          .fold(0, (sum, item) => sum + item.balance.abs());
      return Scaffold(
        appBar: AppBar(
          title: _searching
              ? TextField(
                  controller: _search,
                  autofocus: false,
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
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '账户净额',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (archived.isNotEmpty ||
                      widget.controller.accounts.any(
                        (LedgerAccount item) => item.archived,
                      ))
                    Text(
                      '含已归档账户',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    '¥${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _AccountSummaryValue(
                          label: '账户数',
                          value: '${allActive.length}',
                        ),
                      ),
                      Expanded(
                        child: _AccountSummaryValue(
                          label: '负债',
                          value: '¥${debt.toStringAsFixed(2)}',
                          color: debt > 0
                              ? AppTheme.ledgerOf(context).expense
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 18, 4, 9),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: <Widget>[
                  const Text(
                    '实际账户',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '点开查看 · 左滑归档',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
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
      actionColor: account.archived
          ? AppTheme.accentOf(context).action
          : AppTheme.expense,
      onAction: () =>
          widget.controller.setAccountArchived(account.id, !account.archived),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _AccountDetailPage(
            controller: widget.controller,
            accountId: account.id,
            onEdit: () => _edit(
              context,
              widget.controller.accounts.firstWhere(
                (item) => item.id == account.id,
              ),
            ),
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: MediaQuery.textScalerOf(context).scale(16) > 24
            ? Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: .11),
                          child: Icon(
                            _accountIcon(account.icon),
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            account.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '¥${account.balance.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: account.balance < 0
                              ? AppTheme.ledgerOf(context).expense
                              : null,
                        ),
                      ),
                    ),
                    Text(
                      <String>[
                        _accountKindLabel(account.kind),
                        if (account.archived) '已归档',
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            : ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: .11),
                  child: Icon(
                    _accountIcon(account.icon),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: Text(
                  account.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  <String>[
                    _accountKindLabel(account.kind),
                    if (account.archived) '已归档',
                  ].join(' · '),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '¥${account.balance.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: account.balance < 0
                            ? AppTheme.ledgerOf(context).expense
                            : null,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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
    final TextEditingController creditLimit = TextEditingController(
      text: account?.creditLimit == null || account!.creditLimit <= 0
          ? ''
          : account.creditLimit.toStringAsFixed(2),
    );
    String icon = account?.icon ?? 'cash';
    AccountKind kind = account?.kind ?? AccountKind.asset;
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
                          autofocus: false,
                          decoration: const InputDecoration(labelText: '名称'),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<AccountKind>(
                          initialValue: kind,
                          decoration: const InputDecoration(labelText: '账户类型'),
                          items: const <DropdownMenuItem<AccountKind>>[
                            DropdownMenuItem(
                              value: AccountKind.asset,
                              child: Text('资产账户'),
                            ),
                            DropdownMenuItem(
                              value: AccountKind.credit,
                              child: Text('信用/透支账户'),
                            ),
                            DropdownMenuItem(
                              value: AccountKind.loan,
                              child: Text('贷款/负债账户'),
                            ),
                          ],
                          onChanged: (AccountKind? value) =>
                              update(() => kind = value ?? kind),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            switch (kind) {
                              AccountKind.asset => '存放实际资金，用于日常收支，余额最低为 0。',
                              AccountKind.credit => '可直接付款并在额度内透支，例如信用卡、花呗。',
                              AccountKind.loan => '只追踪尚未偿还的本金，不作为日常付款账户，例如房贷。',
                            },
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: Color(0xFF8A9099),
                            ),
                          ),
                        ),
                        if (kind == AccountKind.credit) ...<Widget>[
                          const SizedBox(height: 12),
                          TextField(
                            controller: creditLimit,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: '信用额度',
                              prefixText: '¥ ',
                            ),
                          ),
                        ],
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
                            helperText: switch (kind) {
                              AccountKind.asset => '资产账户最低为 0',
                              AccountKind.credit => '欠款用负数表示',
                              AccountKind.loan => '待还本金用负数表示',
                            },
                          ),
                        ),
                        if (account != null) ...<Widget>[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '余额调整会同步公共资金；若减少额超过公共资金，请先到“荷包与往来”重新分配。',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
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
                                      ? Theme.of(context).colorScheme.primary
                                            .withValues(alpha: .12)
                                      : Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: icon == item
                                        ? Theme.of(context).colorScheme.primary
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
    final double limit = double.tryParse(creditLimit.text) ?? 0;
    if (save != true || value.isEmpty) return;
    try {
      if (account == null) {
        await widget.controller.addAccount(
          value,
          amount,
          icon,
          kind: kind,
          creditLimit: limit,
        );
      } else {
        await widget.controller.updateAccount(
          account.id,
          value,
          amount,
          icon,
          kind: kind,
          creditLimit: limit,
        );
      }
    } on StateError catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${error.message}')));
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
      final List<LedgerEntry> entries = controller.visibleEntries
          .where(
            (entry) =>
                entry.accountId == accountId ||
                entry.toAccountId == accountId ||
                entry.fundings.any(
                  (EntryFunding funding) => funding.accountId == accountId,
                ),
          )
          .toList();
      double accountAmount(LedgerEntry entry) {
        if (entry.fundings.isNotEmpty) {
          return entry.fundings
              .where((EntryFunding item) => item.accountId == accountId)
              .fold(0, (double sum, EntryFunding item) => sum + item.amount);
        }
        return entry.accountId == accountId ? entry.amount : 0;
      }

      final double income = entries
          .where((entry) => entry.type == EntryType.income)
          .fold(0, (sum, entry) => sum + accountAmount(entry));
      final double expense = entries
          .where((entry) => entry.type == EntryType.expense)
          .fold(0, (sum, entry) => sum + accountAmount(entry));
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
                          '${account.name}${account.archived ? '（已归档）' : ''}',
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
                            color: AppTheme.ledgerOf(context).income,
                          ),
                        ),
                        Expanded(
                          child: _AccountMetric(
                            label: '流出',
                            value: expense,
                            color: AppTheme.ledgerOf(context).expense,
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
              ...months.entries.map((month) {
                final double monthIncome = month.value
                    .where((entry) => entry.type == EntryType.income)
                    .fold(0, (sum, entry) => sum + accountAmount(entry));
                final double monthExpense = month.value
                    .where((entry) => entry.type == EntryType.expense)
                    .fold(0, (sum, entry) => sum + accountAmount(entry));
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    initiallyExpanded: month.key == months.keys.first,
                    title: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            month.key,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Flexible(
                          flex: 2,
                          child: Text(
                            '收 ${monthIncome.toStringAsFixed(2)}  支 ${monthExpense.toStringAsFixed(2)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8A9099),
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text('${month.value.length} 笔'),
                    children: month.value
                        .map(
                          (entry) => ListTile(
                            onTap: () => showEntryDetailSheet(
                              context: context,
                              controller: controller,
                              entry: entry,
                              onEdit: () => _openEntry(context, entry),
                            ),
                            onLongPress: entry.type == EntryType.adjustment
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
                                        ? AppTheme.ledgerOf(context).expense
                                        : entry.type == EntryType.income ||
                                              entry.adjustmentDelta > 0
                                        ? AppTheme.ledgerOf(context).income
                                        : AppTheme.ledgerOf(context).transfer,
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
                );
              }),
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
    if (account.balance.abs() >= .005) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先把账户余额调整为 0')));
      return;
    }
    final bool hasHistory = controller.visibleEntries.any(
      (LedgerEntry entry) =>
          entry.accountId == account.id ||
          entry.toAccountId == account.id ||
          entry.fundings.any(
            (EntryFunding funding) => funding.accountId == account.id,
          ),
    );
    if (hasHistory) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('账户已有历史账目，请使用归档保留记录')));
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('永久删除「${account.name}」？'),
        content: const Text('仅余额为 0 且没有历史账目的账户可以永久删除；其他账户请使用归档。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.expense,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('永久删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await controller.deleteAccount(account.id);
      if (context.mounted) Navigator.pop(context);
    } on StateError catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${error.message}')));
    }
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

class _AccountSummaryValue extends StatelessWidget {
  const _AccountSummaryValue({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: Color(0xFF8A9099)),
      ),
      const SizedBox(height: 3),
      Text(
        value,
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
  'phone',
  'piggy',
  'ticket',
  'investment',
  'loan',
  'house',
  'car',
  'travel',
  'digital',
  'crypto',
  'insurance',
  'business',
];

IconData _accountIcon(String value) => switch (value) {
  'cash' => Icons.payments_outlined,
  'chat' => Icons.chat_bubble_outline,
  'bank' => Icons.account_balance_outlined,
  'card' => Icons.credit_card,
  'saving' => Icons.savings_outlined,
  'coin' => Icons.monetization_on_outlined,
  'online' => Icons.language,
  'phone' => Icons.phone_android_outlined,
  'piggy' => Icons.savings_outlined,
  'ticket' => Icons.confirmation_number_outlined,
  'investment' => Icons.trending_up,
  'loan' => Icons.request_quote_outlined,
  'house' => Icons.home_work_outlined,
  'car' => Icons.directions_car_outlined,
  'travel' => Icons.flight_takeoff_outlined,
  'digital' => Icons.cloud_outlined,
  'crypto' => Icons.currency_bitcoin,
  'insurance' => Icons.health_and_safety_outlined,
  'business' => Icons.business_center_outlined,
  _ => Icons.account_balance_wallet_outlined,
};

String _accountKindLabel(AccountKind kind) => switch (kind) {
  AccountKind.asset => '资产账户',
  AccountKind.credit => '信用/透支账户',
  AccountKind.loan => '贷款/负债账户',
};

IconData _detailCategoryIcon(String category) => switch (category) {
  '餐饮' => Icons.restaurant_outlined,
  '交通' => Icons.directions_car_outlined,
  '购物' => Icons.shopping_bag_outlined,
  '住房' => Icons.home_outlined,
  '居住' => Icons.home_outlined,
  '娱乐' => Icons.sports_esports_outlined,
  '医疗' => Icons.medical_services_outlined,
  '学习' => Icons.menu_book_outlined,
  '旅行' => Icons.flight_outlined,
  '工资' => Icons.payments_outlined,
  '通讯' => Icons.phone_android_outlined,
  '健身' => Icons.fitness_center_outlined,
  '美妆' => Icons.brush_outlined,
  '服饰' => Icons.checkroom_outlined,
  '打赏' => Icons.volunteer_activism_outlined,
  '报销' => Icons.receipt_long_outlined,
  '礼物' => Icons.card_giftcard_outlined,
  '兼职' => Icons.work_history_outlined,
  '其他' => Icons.more_horiz,
  _ => Icons.label_outline,
};
