import 'package:flutter/material.dart';

import '../../data/ledger_controller.dart';
import '../../models/ledger_models.dart';
import '../../theme/app_theme.dart';

Future<void> showEntryDetailSheet({
  required BuildContext context,
  required LedgerController controller,
  required LedgerEntry entry,
  required VoidCallback onEdit,
  VoidCallback? onRepeat,
}) async {
  List<EntryHistory> history = const <EntryHistory>[];
  try {
    history = await controller.entryHistory(entry);
  } on Object {
    // Detail remains available if history storage is temporarily unavailable.
  }
  if (!context.mounted) return;
  final LedgerAccount? account = _account(controller, entry.accountId);
  final LedgerAccount? target = _account(controller, entry.toAccountId);
  final List<String> members = controller.members
      .where((member) => entry.memberIds.contains(member.id))
      .map((member) => member.name)
      .toList();
  final bool expense =
      entry.type == EntryType.expense ||
      (entry.type == EntryType.adjustment && entry.adjustmentDelta < 0);
  final double amount = entry.type == EntryType.adjustment
      ? entry.adjustmentDelta.abs()
      : entry.amount;
  final String sign = expense
      ? '-'
      : entry.type == EntryType.transfer
      ? ''
      : '+';
  final String accountText = entry.type == EntryType.transfer
      ? '${account?.name ?? '未知账户'} → ${target?.name ?? '未知账户'}'
      : _fundingText(controller, entry, account?.name ?? '未知账户');
  final bool editable = entry.type != EntryType.adjustment;
  final List<int> recorderIds = entry.recorderIds.isNotEmpty
      ? entry.recorderIds
      : <int>[?entry.recordedByMemberId];
  final String recorder = recorderIds.isEmpty
      ? '未记录'
      : recorderIds
            .map(
              (int id) =>
                  controller.members
                      .where((LedgerMember member) => member.id == id)
                      .map((LedgerMember member) => member.name)
                      .firstOrNull ??
                  '已删除成员',
            )
            .join('、');
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: 8),
          const Text(
            '账目详情',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          _DetailRow(label: '类别', value: _typeName(entry)),
          _DetailRow(
            label: '金额',
            value: '$sign¥${amount.toStringAsFixed(2)}',
            valueColor: expense
                ? AppTheme.ledgerOf(context).expense
                : entry.type == EntryType.income || entry.adjustmentDelta > 0
                ? AppTheme.ledgerOf(context).income
                : null,
          ),
          _DetailRow(label: '支付', value: accountText),
          if (entry.walletSources.isNotEmpty)
            _DetailRow(
              label: '荷包',
              value: _walletSourceText(controller, entry.walletSources),
            ),
          if (entry.type == EntryType.expense)
            _DetailRow(
              label: '预算',
              value: entry.outsideBudget ? '预算外花销' : '计入预算',
              valueColor: entry.outsideBudget
                  ? AppTheme.ledgerOf(context).expense
                  : null,
            ),
          _DetailRow(
            label: entry.type == EntryType.income ? '收入归属' : '付款成员',
            value: members.isEmpty ? '无' : members.join('、'),
          ),
          _DetailRow(label: '记录者', value: recorder),
          _DetailRow(label: '时间', value: _dateTime(entry.occurredAt)),
          _DetailRow(label: '备注', value: entry.note.isEmpty ? '无' : entry.note),
          if (history.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('修改历史'),
              children: history
                  .map(
                    (EntryHistory item) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.summary),
                      subtitle: Text(_dateTime(item.occurredAt)),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 14),
          if (editable)
            Row(
              children: <Widget>[
                if (onRepeat != null) ...<Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => onRepeat(),
                        );
                      },
                      icon: const Icon(Icons.replay_outlined),
                      label: const Text('再记一笔'),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => onEdit(),
                      );
                    },
                    child: const Text('编辑'),
                  ),
                ),
              ],
            )
          else
            const Text(
              '余额调整记录请到账户编辑中修改',
              style: TextStyle(fontSize: 12, color: Color(0xFF8A9099)),
            ),
        ],
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 54,
          child: Text(label, style: const TextStyle(color: Color(0xFF8A9099))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(fontWeight: FontWeight.w600, color: valueColor),
          ),
        ),
      ],
    ),
  );
}

LedgerAccount? _account(LedgerController controller, int? id) {
  for (final LedgerAccount account in controller.accounts) {
    if (account.id == id) return account;
  }
  return null;
}

String _fundingText(
  LedgerController controller,
  LedgerEntry entry,
  String fallback,
) {
  if (entry.fundings.isEmpty) return fallback;
  return entry.fundings
      .map((EntryFunding funding) {
        final String account =
            _account(controller, funding.accountId)?.name ?? '未知账户';
        final String owner = funding.memberId == null
            ? '共同资金'
            : controller.members
                      .where(
                        (LedgerMember member) => member.id == funding.memberId,
                      )
                      .map((LedgerMember member) => member.name)
                      .firstOrNull ??
                  '未知成员';
        return '$account·$owner ¥${funding.amount.toStringAsFixed(2)}';
      })
      .join(' + ');
}

String _walletSourceText(
  LedgerController controller,
  List<WalletSource> sources,
) => sources
    .map((WalletSource source) {
      final String owner = source.sourceMemberId == null
          ? '公共资金'
          : controller.members
                    .where(
                      (LedgerMember member) =>
                          member.id == source.sourceMemberId,
                    )
                    .map((LedgerMember member) => member.name)
                    .firstOrNull ??
                '已删除成员';
      final bool borrowed =
          source.sourceMemberId != null &&
          source.payerMemberId != null &&
          source.sourceMemberId != source.payerMemberId;
      return '$owner ¥${source.amount.toStringAsFixed(2)}${borrowed ? '（代付）' : ''}';
    })
    .join(' + ');

String _typeName(LedgerEntry entry) => switch (entry.type) {
  EntryType.transfer => '转账',
  EntryType.adjustment => '余额调整',
  _ => entry.category,
};

String _dateTime(DateTime value) =>
    '${value.year}年${value.month}月${value.day}日'
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';
