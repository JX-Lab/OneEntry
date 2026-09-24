import 'package:flutter/material.dart';

import '../../data/ledger_controller.dart';
import '../../models/ledger_models.dart';

class EntrySheet extends StatefulWidget {
  const EntrySheet({required this.controller, super.key});

  final LedgerController controller;

  @override
  State<EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<EntrySheet> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  EntryType _type = EntryType.expense;
  String _category = '餐饮';
  int _accountId = 1;
  int? _toAccountId = 2;
  final Set<int> _members = <int>{1};
  bool _recurring = false;
  String _frequency = 'month';

  @override
  void initState() {
    super.initState();
    final activeAccounts = widget.controller.accounts
        .where((account) => !account.archived)
        .toList();
    if (activeAccounts.isNotEmpty) _accountId = activeAccounts.first.id;
    if (activeAccounts.length > 1) _toAccountId = activeAccounts[1].id;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    final double? amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入金额')));
      return;
    }
    if (_type == EntryType.transfer &&
        (_toAccountId == null || _toAccountId == _accountId)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请选择两个不同的账户')));
      return;
    }
    Navigator.of(context).pop(
      LedgerEntry(
        id: 0,
        type: _type,
        amount: amount,
        category: _type == EntryType.transfer ? '转账' : _category,
        occurredAt: DateTime.now(),
        note: _noteController.text.trim(),
        accountId: _accountId,
        toAccountId: _type == EntryType.transfer ? _toAccountId : null,
        memberIds: _members.toList(),
        recurring: _type != EntryType.transfer && _recurring,
        recurringFrequency: _frequency,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<LedgerAccount> accounts = widget.controller.accounts
        .where((account) => !account.archived)
        .toList();
    final List<LedgerMember> members = widget.controller.members
        .where((member) => !member.archived)
        .toList();
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('记一笔'),
        actions: <Widget>[
          TextButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: 8),
                SegmentedButton<EntryType>(
                  segments: const <ButtonSegment<EntryType>>[
                    ButtonSegment(value: EntryType.expense, label: Text('支出')),
                    ButtonSegment(value: EntryType.income, label: Text('收入')),
                    ButtonSegment(value: EntryType.transfer, label: Text('转账')),
                  ],
                  selected: <EntryType>{_type},
                  onSelectionChanged: (Set<EntryType> value) => setState(() {
                    _type = value.first;
                    if (_type == EntryType.transfer) _recurring = false;
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    prefixText: '¥ ',
                    labelText: '金额',
                  ),
                ),
                const SizedBox(height: 12),
                if (_type != EntryType.transfer)
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: '分类'),
                    items:
                        const <String>[
                              '餐饮',
                              '交通',
                              '购物',
                              '居住',
                              '娱乐',
                              '医疗',
                              '学习',
                              '旅行',
                              '工资',
                            ]
                            .map(
                              (String value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                    onChanged: (String? value) =>
                        setState(() => _category = value ?? _category),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _accountId,
                  decoration: InputDecoration(
                    labelText: _type == EntryType.transfer ? '转出账户' : '账户',
                  ),
                  items: accounts
                      .map(
                        (LedgerAccount account) => DropdownMenuItem<int>(
                          value: account.id,
                          child: Text(account.name),
                        ),
                      )
                      .toList(),
                  onChanged: (int? value) =>
                      setState(() => _accountId = value ?? _accountId),
                ),
                if (_type == EntryType.transfer) ...<Widget>[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _toAccountId,
                    decoration: const InputDecoration(labelText: '转入账户'),
                    items: accounts
                        .map(
                          (LedgerAccount account) => DropdownMenuItem<int>(
                            value: account.id,
                            child: Text(account.name),
                          ),
                        )
                        .toList(),
                    onChanged: (int? value) =>
                        setState(() => _toAccountId = value),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  _type == EntryType.transfer ? '操作者' : '成员',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: members.map((LedgerMember member) {
                    return FilterChip(
                      label: Text(member.name),
                      selected: _members.contains(member.id),
                      onSelected: (bool selected) => setState(
                        () => selected
                            ? _members.add(member.id)
                            : _members.remove(member.id),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: '备注',
                    hintText: '写点什么…',
                  ),
                ),
                if (_type != EntryType.transfer) ...<Widget>[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('设为周期账目'),
                    subtitle: const Text('到期时提醒手动确认记账'),
                    value: _recurring,
                    onChanged: (bool value) =>
                        setState(() => _recurring = value),
                  ),
                  if (_recurring)
                    DropdownButtonFormField<String>(
                      initialValue: _frequency,
                      decoration: const InputDecoration(labelText: '重复周期'),
                      items:
                          const <MapEntry<String, String>>[
                                MapEntry('year', '每年'),
                                MapEntry('month', '每月'),
                                MapEntry('week', '每周'),
                                MapEntry('day', '每天'),
                              ]
                              .map(
                                (entry) => DropdownMenuItem<String>(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ),
                              )
                              .toList(),
                      onChanged: (String? value) =>
                          setState(() => _frequency = value ?? _frequency),
                    ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
