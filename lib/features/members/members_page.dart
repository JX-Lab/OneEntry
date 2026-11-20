import 'package:flutter/material.dart';

import '../../data/ledger_controller.dart';
import '../../models/ledger_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/swipe_action_tile.dart';
import '../entry/entry_sheet.dart';
import '../entry/entry_detail_sheet.dart';

class MembersPage extends StatefulWidget {
  const MembersPage({required this.controller, super.key});
  final LedgerController controller;

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  static const List<int> colors = <int>[
    0xFF2E7CF6,
    0xFFF5A623,
    0xFFEB4E6B,
    0xFF18B681,
    0xFF8E6BE0,
    0xFF00B0D6,
    0xFFE8652B,
    0xFF5B6B7A,
  ];
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
      final List<LedgerMember> active = widget.controller.members
          .where(
            (item) => !item.archived && item.name.toLowerCase().contains(query),
          )
          .toList();
      final List<LedgerMember> archived = widget.controller.members
          .where(
            (item) => item.archived && item.name.toLowerCase().contains(query),
          )
          .toList();
      final List<_DebtSummary> debts = _debtSummaries();
      return Scaffold(
        appBar: AppBar(
          title: _searching
              ? TextField(
                  controller: _search,
                  autofocus: false,
                  decoration: const InputDecoration(
                    hintText: '搜索成员',
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => setState(() {}),
                )
              : const Text('成员'),
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
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                minTileHeight: 88,
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: const Icon(Icons.account_balance_wallet_outlined),
                ),
                title: const Text(
                  '荷包与往来',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '公共 ¥${widget.controller.commonFund.toStringAsFixed(2)}'
                  '${debts.isEmpty ? ' · 暂无待结算' : ' · ${debts.length} 笔待结算'}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _WalletsAndDebtsPage(
                      controller: widget.controller,
                      onEditWallets: _editWallets,
                      onSettleDebt: _settleDebt,
                    ),
                  ),
                ),
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
                      key: ValueKey('reorder-member-${active[index].id}'),
                      index: index,
                      child: _tile(context, active[index]),
                    ),
                onReorder: (int oldIndex, int newIndex) {
                  if (newIndex > oldIndex) newIndex--;
                  final LedgerMember item = active.removeAt(oldIndex);
                  active.insert(newIndex, item);
                  widget.controller.reorderMembers(
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
                  '已归档成员',
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

  Widget _tile(BuildContext context, LedgerMember member) {
    final int count = widget.controller.visibleEntries
        .where((entry) => entry.memberIds.contains(member.id))
        .length;
    final double funds = widget.controller.memberWallets[member.id] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SwipeActionTile(
        key: ValueKey('member-${member.id}-${member.archived}'),
        actionLabel: member.archived ? '恢复' : '归档',
        actionColor: member.archived
            ? AppTheme.accentOf(context).action
            : AppTheme.expense,
        onAction: () =>
            widget.controller.setMemberArchived(member.id, !member.archived),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _MemberDetailPage(
              controller: widget.controller,
              memberId: member.id,
              onEdit: () => _edit(
                context,
                widget.controller.members.firstWhere(
                  (item) => item.id == member.id,
                ),
              ),
            ),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Color(member.colorValue),
              child: Text(
                member.name.substring(0, 1),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(member.name),
            subtitle: Text(
              member.archived
                  ? '已归档（$count 笔）'
                  : '资金 ¥${funds.toStringAsFixed(2)} · 参与 $count 笔账目',
            ),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
      ),
    );
  }

  List<_DebtSummary> _debtSummaries() =>
      _calculateDebtSummaries(widget.controller);

  Future<void> _settleDebt(BuildContext context, _DebtSummary debt) async {
    final _DebtSettlementResult? result =
        await showModalBottomSheet<_DebtSettlementResult>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (BuildContext context) => _DebtSettlementSheet(debt: debt),
        );
    if (result == null) return;
    await widget.controller.settleMemberDebt(
      creditorMemberId: debt.creditorMemberId,
      debtorMemberId: debt.debtorMemberId,
      amount: result.amount,
      note: result.note,
    );
  }

  Future<void> _editWallets(BuildContext context) async {
    final _WalletAllocationResult? result =
        await showModalBottomSheet<_WalletAllocationResult>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (BuildContext context) => _GlobalWalletAllocationSheet(
            commonFund: widget.controller.commonFund,
            members: widget.controller.members
                .where(
                  (LedgerMember member) =>
                      !member.archived ||
                      (widget.controller.memberWallets[member.id] ?? 0) != 0,
                )
                .toList(),
            balances: widget.controller.memberWallets,
          ),
        );
    if (result == null) return;
    try {
      await widget.controller.setWalletBalances(
        commonFund: result.commonFund,
        memberBalances: result.memberBalances,
      );
    } on StateError catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${error.message}')));
    }
  }

  Future<void> _edit(BuildContext context, [LedgerMember? member]) async {
    final TextEditingController name = TextEditingController(
      text: member?.name ?? '',
    );
    int colorValue = member?.colorValue ?? colors.first;
    final TextEditingController hex = TextEditingController(
      text: _hex(colorValue),
    );
    final bool? save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter update) {
          void setColor(int value) {
            update(() => colorValue = value);
            hex.text = _hex(value);
          }

          final Color color = Color(colorValue);
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
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
                              member == null ? '新增成员' : '编辑成员',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('保存'),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                      child: Column(
                        children: <Widget>[
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: color,
                            child: Text(
                              name.text.trim().isEmpty
                                  ? '名'
                                  : name.text.trim().substring(0, 1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: name,
                            autofocus: false,
                            decoration: const InputDecoration(labelText: '名称'),
                            onChanged: (_) => update(() {}),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: colors
                                .map(
                                  (int value) => InkWell(
                                    onTap: () => setColor(value),
                                    borderRadius: BorderRadius.circular(99),
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: Color(value),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: colorValue == value
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.onSurface
                                              : Colors.transparent,
                                          width: 2.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 14),
                          _ColorSlider(
                            label: 'R',
                            value: color.r,
                            color: Colors.red,
                            onChanged: (value) => setColor(
                              Color.from(
                                alpha: 1,
                                red: value,
                                green: color.g,
                                blue: color.b,
                              ).toARGB32(),
                            ),
                          ),
                          _ColorSlider(
                            label: 'G',
                            value: color.g,
                            color: Colors.green,
                            onChanged: (value) => setColor(
                              Color.from(
                                alpha: 1,
                                red: color.r,
                                green: value,
                                blue: color.b,
                              ).toARGB32(),
                            ),
                          ),
                          _ColorSlider(
                            label: 'B',
                            value: color.b,
                            color: Colors.blue,
                            onChanged: (value) => setColor(
                              Color.from(
                                alpha: 1,
                                red: color.r,
                                green: color.g,
                                blue: value,
                              ).toARGB32(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: hex,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'RGB / HEX',
                              hintText: '#2E7CF6',
                            ),
                            onChanged: (String value) {
                              final String normalized = value
                                  .replaceAll('#', '')
                                  .trim();
                              final int? parsed = int.tryParse(
                                'FF$normalized',
                                radix: 16,
                              );
                              if (normalized.length == 6 && parsed != null) {
                                update(() => colorValue = parsed);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    final String value = name.text.trim();
    if (save != true || value.isEmpty) return;
    if (member == null) {
      await widget.controller.addMember(value, colorValue);
    } else {
      await widget.controller.updateMember(member.id, value, colorValue);
    }
  }

  static String _hex(int value) =>
      '#${(value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

class _WalletsAndDebtsPage extends StatelessWidget {
  const _WalletsAndDebtsPage({
    required this.controller,
    required this.onEditWallets,
    required this.onSettleDebt,
  });

  final LedgerController controller;
  final Future<void> Function(BuildContext context) onEditWallets;
  final Future<void> Function(BuildContext context, _DebtSummary debt)
  onSettleDebt;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (BuildContext context, Widget? child) {
      final List<_DebtSummary> debts = _calculateDebtSummaries(controller);
      final List<LedgerMember> members = controller.members
          .where(
            (LedgerMember member) =>
                !member.archived ||
                (controller.memberWallets[member.id] ?? 0) > 0,
          )
          .toList();
      return Scaffold(
        appBar: AppBar(
          title: const Text('荷包与往来'),
          actions: <Widget>[
            TextButton(
              onPressed: () => onEditWallets(context),
              child: const Text('分配'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 4, 4, 8),
              child: Text(
                '荷包',
                style: TextStyle(fontSize: 12, color: Color(0xFF8A9099)),
              ),
            ),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: <Widget>[
                  ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.groups_outlined),
                    ),
                    title: const Text('公共资金'),
                    subtitle: const Text('未分配给成员的资金，不产生借款'),
                    trailing: Text(
                      '¥${controller.commonFund.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onTap: () => onEditWallets(context),
                  ),
                  ...members.map(
                    (LedgerMember member) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Color(member.colorValue),
                        child: Text(
                          member.name.substring(0, 1),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text('${member.name}的荷包'),
                      subtitle: member.archived ? const Text('已归档成员') : null,
                      trailing: Text(
                        '¥${(controller.memberWallets[member.id] ?? 0).toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onTap: () => onEditWallets(context),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 16, 4, 8),
              child: Text(
                '待结算往来',
                style: TextStyle(fontSize: 12, color: Color(0xFF8A9099)),
              ),
            ),
            if (debts.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(22),
                  child: Center(child: Text('暂无成员借款')),
                ),
              )
            else
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: debts
                      .map(
                        (_DebtSummary debt) => ListTile(
                          leading: const Icon(Icons.handshake_outlined),
                          title: Text('${debt.debtor} 欠 ${debt.creditor}'),
                          subtitle: const Text('点击记录结算'),
                          trailing: Text(
                            '¥${debt.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: AppTheme.ledgerOf(context).expense,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onTap: () => onSettleDebt(context, debt),
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _DebtSettlementResult {
  const _DebtSettlementResult({required this.amount, required this.note});
  final double amount;
  final String note;
}

class _DebtSettlementSheet extends StatefulWidget {
  const _DebtSettlementSheet({required this.debt});
  final _DebtSummary debt;

  @override
  State<_DebtSettlementSheet> createState() => _DebtSettlementSheetState();
}

class _DebtSettlementSheetState extends State<_DebtSettlementSheet> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.debt.amount.toStringAsFixed(2),
  );
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double value = double.tryParse(_amount.text) ?? 0;
    final bool valid = value > 0 && value - widget.debt.amount <= .004;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            height: 54,
            child: Row(
              children: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                Expanded(
                  child: Text(
                    '${widget.debt.debtor} 向 ${widget.debt.creditor} 结算',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: valid
                      ? () => Navigator.pop(
                          context,
                          _DebtSettlementResult(
                            amount: value,
                            note: _note.text.trim(),
                          ),
                        )
                      : null,
                  child: const Text('保存'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            child: Column(
              children: <Widget>[
                TextField(
                  controller: _amount,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText:
                        '结算金额（最多 ¥${widget.debt.amount.toStringAsFixed(2)}）',
                    prefixText: '¥ ',
                    errorText: value - widget.debt.amount > .004
                        ? '不能超过待结算金额'
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _note,
                  decoration: const InputDecoration(
                    labelText: '备注',
                    hintText: '如：现金归还、已另行转账',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletAllocationResult {
  const _WalletAllocationResult({
    required this.commonFund,
    required this.memberBalances,
  });
  final double commonFund;
  final Map<int, double> memberBalances;
}

class _GlobalWalletAllocationSheet extends StatefulWidget {
  const _GlobalWalletAllocationSheet({
    required this.commonFund,
    required this.members,
    required this.balances,
  });
  final double commonFund;
  final List<LedgerMember> members;
  final Map<int, double> balances;

  @override
  State<_GlobalWalletAllocationSheet> createState() =>
      _GlobalWalletAllocationSheetState();
}

class _GlobalWalletAllocationSheetState
    extends State<_GlobalWalletAllocationSheet> {
  final Map<int, TextEditingController> _memberInputs =
      <int, TextEditingController>{};

  double get _expected =>
      widget.commonFund +
      widget.balances.values.fold<double>(
        0,
        (double sum, double value) => sum + value,
      );

  @override
  void initState() {
    super.initState();
    for (final LedgerMember member in widget.members) {
      _memberInputs[member.id] = TextEditingController(
        text: (widget.balances[member.id] ?? 0).toStringAsFixed(2),
      );
    }
  }

  @override
  void dispose() {
    for (final TextEditingController input in _memberInputs.values) {
      input.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<double> values = _memberInputs.values
        .map((TextEditingController input) => double.tryParse(input.text) ?? 0)
        .toList();
    final double memberTotal = values.fold<double>(
      0,
      (sum, value) => sum + value,
    );
    final double commonFund = _expected - memberTotal;
    final bool valid =
        values.every((double value) => value >= 0) && commonFund >= -.004;
    return FractionallySizedBox(
      heightFactor: .86,
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 56,
            child: Row(
              children: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                const Expanded(
                  child: Text(
                    '分配成员荷包',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: valid
                      ? () => Navigator.pop(
                          context,
                          _WalletAllocationResult(
                            commonFund: commonFund < 0 ? 0 : commonFund,
                            memberBalances: <int, double>{
                              for (final MapEntry<int, TextEditingController>
                                  item
                                  in _memberInputs.entries)
                                item.key: double.tryParse(item.value.text) ?? 0,
                            },
                          ),
                        )
                      : null,
                  child: const Text('保存'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              valid
                  ? '未分配的 ¥${commonFund.toStringAsFixed(2)} 将保留为公共资金'
                  : '成员荷包已超出总资金 ¥${_expected.toStringAsFixed(2)}',
              style: TextStyle(
                color: valid ? null : AppTheme.ledgerOf(context).expense,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              children: <Widget>[
                ...widget.members.map(
                  (LedgerMember member) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: _memberInputs[member.id],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: '${member.name}的荷包',
                        prefixText: '¥ ',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DebtSummary {
  const _DebtSummary({
    required this.creditorMemberId,
    required this.debtorMemberId,
    required this.creditor,
    required this.debtor,
    required this.amount,
  });

  final int creditorMemberId;
  final int debtorMemberId;
  final String creditor;
  final String debtor;
  final double amount;
}

List<_DebtSummary> _calculateDebtSummaries(LedgerController controller) {
  final Map<(int, int), double> directional = <(int, int), double>{};
  for (final MemberDebt debt in controller.memberDebts) {
    final (int, int) key = (debt.creditorMemberId, debt.debtorMemberId);
    directional.update(
      key,
      (double value) => value + debt.amount,
      ifAbsent: () => debt.amount,
    );
  }
  for (final MemberDebtSettlement settlement in controller.debtSettlements) {
    final (int, int) key = (
      settlement.creditorMemberId,
      settlement.debtorMemberId,
    );
    directional.update(
      key,
      (double value) => value - settlement.amount,
      ifAbsent: () => -settlement.amount,
    );
  }
  final Set<(int, int)> visited = <(int, int)>{};
  final List<_DebtSummary> result = <_DebtSummary>[];
  for (final MapEntry<(int, int), double> item in directional.entries) {
    final int creditorId = item.key.$1;
    final int debtorId = item.key.$2;
    final (int, int) canonical = creditorId < debtorId
        ? (creditorId, debtorId)
        : (debtorId, creditorId);
    if (!visited.add(canonical)) continue;
    final double net =
        (directional[(creditorId, debtorId)] ?? 0) -
        (directional[(debtorId, creditorId)] ?? 0);
    if (net.abs() < .005) continue;
    final int finalCreditor = net > 0 ? creditorId : debtorId;
    final int finalDebtor = net > 0 ? debtorId : creditorId;
    String name(int id) =>
        controller.members
            .where((LedgerMember member) => member.id == id)
            .map((LedgerMember member) => member.name)
            .firstOrNull ??
        '已删除成员';
    result.add(
      _DebtSummary(
        creditorMemberId: finalCreditor,
        debtorMemberId: finalDebtor,
        creditor: name(finalCreditor),
        debtor: name(finalDebtor),
        amount: net.abs(),
      ),
    );
  }
  return result;
}

class _ColorSlider extends StatelessWidget {
  const _ColorSlider({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });
  final String label;
  final double value;
  final Color color;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      SizedBox(width: 20, child: Text(label)),
      Expanded(
        child: Slider(
          value: value,
          activeColor: color,
          min: 0,
          max: 1,
          onChanged: onChanged,
        ),
      ),
      SizedBox(width: 34, child: Text('${(value * 255).round()}')),
    ],
  );
}

class _MemberDetailPage extends StatelessWidget {
  const _MemberDetailPage({
    required this.controller,
    required this.memberId,
    required this.onEdit,
  });
  final LedgerController controller;
  final int memberId;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (BuildContext context, Widget? child) {
      final LedgerMember member = controller.members.firstWhere(
        (item) => item.id == memberId,
      );
      final List<LedgerEntry> entries = controller.visibleEntries
          .where((entry) => entry.memberIds.contains(memberId))
          .toList();
      final double income = entries
          .where((entry) => entry.type == EntryType.income)
          .fold(0, (sum, entry) => sum + _memberAmount(entry));
      final double expense = entries
          .where((entry) => entry.type == EntryType.expense)
          .fold(0, (sum, entry) => sum + _memberAmount(entry));
      final Map<String, List<LedgerEntry>> months =
          <String, List<LedgerEntry>>{};
      for (final LedgerEntry entry in entries) {
        final String key =
            '${entry.occurredAt.year}年${entry.occurredAt.month}月';
        months.putIfAbsent(key, () => <LedgerEntry>[]).add(entry);
      }
      return Scaffold(
        appBar: AppBar(
          title: Text(member.name),
          actions: <Widget>[
            PopupMenuButton<String>(
              onSelected: (String value) {
                if (value == 'edit') {
                  onEdit();
                } else if (value == 'archive') {
                  controller.setMemberArchived(member.id, !member.archived);
                } else {
                  _deleteMember(context, member);
                }
              },
              itemBuilder: (_) => <PopupMenuEntry<String>>[
                const PopupMenuItem(value: 'edit', child: Text('编辑')),
                PopupMenuItem(
                  value: 'archive',
                  child: Text(member.archived ? '取消归档' : '归档成员'),
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
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Color(member.colorValue),
                          child: Text(
                            member.name.substring(0, 1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${member.name}${member.archived ? '（已归档）' : ''}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '合计 ¥${expense.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _MemberMetric(
                            label: '收入',
                            value: income,
                            color: AppTheme.ledgerOf(context).income,
                          ),
                        ),
                        Expanded(
                          child: _MemberMetric(
                            label: '支出',
                            value: expense,
                            color: AppTheme.ledgerOf(context).expense,
                          ),
                        ),
                        Expanded(
                          child: _MemberMetric(
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
                    .fold(0, (sum, entry) => sum + _memberAmount(entry));
                final double monthExpense = month.value
                    .where((entry) => entry.type == EntryType.expense)
                    .fold(0, (sum, entry) => sum + _memberAmount(entry));
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
                                _memberDetailCategoryIcon(entry.category),
                                size: 20,
                              ),
                            ),
                            title: Text(entry.category),
                            subtitle: entry.note.isEmpty
                                ? null
                                : Text(entry.note),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: <Widget>[
                                Text(
                                  '${entry.type == EntryType.expense
                                      ? '-'
                                      : entry.type == EntryType.income
                                      ? '+'
                                      : ''}¥${entry.amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: entry.type == EntryType.expense
                                        ? AppTheme.ledgerOf(context).expense
                                        : entry.type == EntryType.income
                                        ? AppTheme.ledgerOf(context).income
                                        : AppTheme.ledgerOf(context).transfer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${entry.occurredAt.month}月${entry.occurredAt.day}日',
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

  double _memberAmount(LedgerEntry entry) {
    if (entry.memberShares.isNotEmpty) {
      return entry.memberShares
          .where((MemberShare share) => share.memberId == memberId)
          .map((MemberShare share) => share.amount)
          .fold(0, (double sum, double value) => sum + value);
    }
    return entry.memberIds.isEmpty ? 0 : entry.amount / entry.memberIds.length;
  }

  Future<void> _deleteMember(BuildContext context, LedgerMember member) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('永久删除「${member.name}」？'),
        content: const Text('成员会从历史账目的参与成员中移除，账目本身仍会保留。'),
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
    await controller.deleteMember(member.id);
    if (context.mounted) Navigator.pop(context);
  }
}

class _MemberMetric extends StatelessWidget {
  const _MemberMetric({required this.label, this.value, this.text, this.color});
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

IconData _memberDetailCategoryIcon(String category) => switch (category) {
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
