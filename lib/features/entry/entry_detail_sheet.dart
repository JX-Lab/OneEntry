import 'package:flutter/material.dart';

import '../../data/ledger_controller.dart';
import '../../models/ledger_models.dart';
import '../../theme/app_theme.dart';

Future<void> showEntryDetailSheet({
  required BuildContext context,
  required LedgerController controller,
  required LedgerEntry entry,
  required VoidCallback onEdit,
}) async {
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
      : account?.name ?? '未知账户';
  final bool editable = entry.type != EntryType.adjustment;
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
                ? AppTheme.expense
                : entry.type == EntryType.income || entry.adjustmentDelta > 0
                ? AppTheme.income
                : null,
          ),
          _DetailRow(label: '账户', value: accountText),
          _DetailRow(
            label: '成员',
            value: members.isEmpty ? '无' : members.join('、'),
          ),
          _DetailRow(label: '时间', value: _dateTime(entry.occurredAt)),
          _DetailRow(label: '备注', value: entry.note.isEmpty ? '无' : entry.note),
          const SizedBox(height: 14),
          if (editable)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  WidgetsBinding.instance.addPostFrameCallback((_) => onEdit());
                },
                child: const Text('编辑'),
              ),
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

String _typeName(LedgerEntry entry) => switch (entry.type) {
  EntryType.transfer => '转账',
  EntryType.adjustment => '余额调整',
  _ => entry.category,
};

String _dateTime(DateTime value) =>
    '${value.year}年${value.month}月${value.day}日'
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';
