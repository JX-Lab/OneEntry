import 'package:flutter/material.dart';

import '../../data/ledger_controller.dart';
import '../../models/ledger_models.dart';
import '../../theme/app_theme.dart';

class AccountsPage extends StatelessWidget {
  const AccountsPage({required this.controller, super.key});
  final LedgerController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (BuildContext context, Widget? child) {
      final List<LedgerAccount> active = controller.accounts
          .where((item) => !item.archived)
          .toList();
      final List<LedgerAccount> archived = controller.accounts
          .where((item) => item.archived)
          .toList();
      final double total = active.fold(0, (sum, item) => sum + item.balance);
      return Scaffold(
        appBar: AppBar(
          title: const Text('账户'),
          centerTitle: true,
          actions: <Widget>[
            IconButton(
              onPressed: () => _edit(context),
              icon: const Icon(Icons.add),
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
                '点卡片编辑；左滑归档会保留历史账目',
                style: TextStyle(fontSize: 12, color: Color(0xFF8A9099)),
              ),
            ),
            ...active.map(
              (item) => _AccountTile(
                account: item,
                onTap: () => _edit(context, item),
                onArchive: () => controller.setAccountArchived(item.id, true),
              ),
            ),
            if (archived.isNotEmpty) ...<Widget>[
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 16, 4, 8),
                child: Text(
                  '已归档账户',
                  style: TextStyle(fontSize: 12, color: Color(0xFF8A9099)),
                ),
              ),
              ...archived.map(
                (item) => _AccountTile(
                  account: item,
                  archived: true,
                  onTap: () => _edit(context, item),
                  onArchive: () =>
                      controller.setAccountArchived(item.id, false),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );

  Future<void> _edit(BuildContext context, [LedgerAccount? account]) async {
    final TextEditingController name = TextEditingController(
      text: account?.name ?? '',
    );
    final TextEditingController balance = TextEditingController();
    final bool? save = await showModalBottomSheet<bool>(
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
              _SheetBar(
                title: account == null ? '新增账户' : '编辑账户',
                onSave: () => Navigator.pop(context, true),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                child: Column(
                  children: <Widget>[
                    TextField(
                      controller: name,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: '名称'),
                    ),
                    if (account == null) ...<Widget>[
                      const SizedBox(height: 12),
                      TextField(
                        controller: balance,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(labelText: '初始余额'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final String value = name.text.trim();
    final double opening = double.tryParse(balance.text) ?? 0;
    if (save != true || value.isEmpty) return;
    if (account == null) {
      await controller.addAccount(value, opening);
    } else {
      await controller.updateAccount(account.id, value);
    }
  }
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

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.onTap,
    required this.onArchive,
    this.archived = false,
  });
  final LedgerAccount account;
  final VoidCallback onTap;
  final VoidCallback onArchive;
  final bool archived;

  @override
  Widget build(BuildContext context) => Dismissible(
    key: ValueKey('account-${account.id}-$archived'),
    direction: DismissDirection.endToStart,
    confirmDismiss: (_) async => true,
    onDismissed: (_) => onArchive(),
    background: Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 22),
      color: archived ? AppTheme.green : AppTheme.expense,
      child: Text(
        archived ? '恢复' : '归档',
        style: const TextStyle(color: Colors.white),
      ),
    ),
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        onTap: onTap,
        leading: const CircleAvatar(
          child: Icon(Icons.account_balance_wallet_outlined),
        ),
        title: Text(account.name),
        subtitle: archived ? const Text('已归档') : null,
        trailing: Text(
          '¥${account.balance.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: account.balance < 0 ? AppTheme.expense : null,
          ),
        ),
      ),
    ),
  );
}
