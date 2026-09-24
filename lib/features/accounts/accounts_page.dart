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
      final active = controller.accounts
          .where((account) => !account.archived)
          .toList();
      final archived = controller.accounts
          .where((account) => account.archived)
          .toList();
      final total = active.fold<double>(
        0,
        (sum, account) => sum + account.balance,
      );
      return Scaffold(
        appBar: AppBar(
          title: const Text('账户'),
          centerTitle: true,
          actions: <Widget>[
            IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
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
                '左滑归档会保留历史账目',
                style: TextStyle(fontSize: 12, color: Color(0xFF8A9099)),
              ),
            ),
            ...active.map(
              (account) => _AccountTile(
                account: account,
                onArchive: () =>
                    controller.setAccountArchived(account.id, true),
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
                (account) => _AccountTile(
                  account: account,
                  archived: true,
                  onArchive: () =>
                      controller.setAccountArchived(account.id, false),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.onArchive,
    this.archived = false,
  });
  final LedgerAccount account;
  final VoidCallback onArchive;
  final bool archived;

  @override
  Widget build(BuildContext context) => Dismissible(
    key: ValueKey('account-${account.id}-$archived'),
    direction: DismissDirection.endToStart,
    confirmDismiss: (_) async {
      onArchive();
      return false;
    },
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
