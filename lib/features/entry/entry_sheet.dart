import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../data/ledger_controller.dart';
import '../../models/ledger_models.dart';
import '../../theme/app_theme.dart';

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
  bool _accountOpen = false;
  bool _membersOpen = false;
  bool _fromAccountOpen = false;
  bool _toAccountOpen = false;
  bool _recurring = false;
  String _frequency = 'month';
  DateTime _occurredAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    final List<LedgerAccount> activeAccounts = widget.controller.accounts
        .where((LedgerAccount account) => !account.archived)
        .toList();
    if (activeAccounts.isNotEmpty) _accountId = activeAccounts.first.id;
    if (activeAccounts.length > 1) _toAccountId = activeAccounts[1].id;
    final List<LedgerMember> activeMembers = widget.controller.members
        .where((LedgerMember member) => !member.archived)
        .toList();
    _members
      ..clear()
      ..addAll(activeMembers.take(1).map((LedgerMember member) => member.id));
    if (widget.controller.categories.isNotEmpty) {
      _category = widget.controller.categories.first;
    }
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
        occurredAt: _occurredAt,
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
        .where((LedgerAccount account) => !account.archived)
        .toList();
    final List<LedgerMember> members = widget.controller.members
        .where((LedgerMember member) => !member.archived)
        .toList();
    final LedgerAccount? account = _findAccount(accounts, _accountId);
    final LedgerAccount? toAccount = _findAccount(accounts, _toAccountId);
    final Color surface = Theme.of(context).colorScheme.surface;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('记一笔'),
        actions: <Widget>[
          TextButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 14,
            right: 14,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 22,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 10),
              _TypeTabs(
                selected: _type,
                onSelected: (EntryType value) => setState(() {
                  _type = value;
                  if (_type == EntryType.transfer) _recurring = false;
                }),
              ),
              const SizedBox(height: 14),
              _AmountBox(
                controller: _amountController,
                category: _type == EntryType.transfer ? '转账' : _category,
                icon: _type == EntryType.transfer
                    ? Icons.swap_horiz
                    : _categoryIcon(_category),
              ),
              if (_type != EntryType.transfer) ...<Widget>[
                _CategoryGrid(
                  categories: widget.controller.categories,
                  selected: _category,
                  onSelected: (String value) =>
                      setState(() => _category = value),
                ),
                _SelectorCard(
                  title: '账户',
                  value: account?.name ?? '请选择',
                  open: _accountOpen,
                  onHeaderTap: () =>
                      setState(() => _accountOpen = !_accountOpen),
                  children: accounts
                      .map(
                        (LedgerAccount item) => _SelectorRow(
                          icon: Icons.account_balance_wallet_outlined,
                          title: item.name,
                          selected: item.id == _accountId,
                          onTap: () => setState(() {
                            _accountId = item.id;
                            _accountOpen = false;
                          }),
                        ),
                      )
                      .toList(),
                ),
              ] else ...<Widget>[
                _SelectorCard(
                  title: '转出账户',
                  value: account?.name ?? '请选择',
                  open: _fromAccountOpen,
                  onHeaderTap: () =>
                      setState(() => _fromAccountOpen = !_fromAccountOpen),
                  children: accounts
                      .map(
                        (LedgerAccount item) => _SelectorRow(
                          icon: Icons.call_made,
                          title: item.name,
                          selected: item.id == _accountId,
                          onTap: () => setState(() {
                            _accountId = item.id;
                            _fromAccountOpen = false;
                          }),
                        ),
                      )
                      .toList(),
                ),
                _SelectorCard(
                  title: '转入账户',
                  value: toAccount?.name ?? '请选择',
                  open: _toAccountOpen,
                  onHeaderTap: () =>
                      setState(() => _toAccountOpen = !_toAccountOpen),
                  children: accounts
                      .map(
                        (LedgerAccount item) => _SelectorRow(
                          icon: Icons.call_received,
                          title: item.name,
                          selected: item.id == _toAccountId,
                          onTap: () => setState(() {
                            _toAccountId = item.id;
                            _toAccountOpen = false;
                          }),
                        ),
                      )
                      .toList(),
                ),
              ],
              _SelectorCard(
                title: _type == EntryType.transfer ? '操作者 · 可多选' : '成员 · 可多选',
                value: _memberSummary(members),
                open: _membersOpen,
                onHeaderTap: () => setState(() => _membersOpen = !_membersOpen),
                footer: _membersOpen
                    ? Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: () => setState(() => _membersOpen = false),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(74, 34),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: const Text('完成'),
                        ),
                      )
                    : null,
                children: <Widget>[
                  _SelectorRow(
                    icon: Icons.people_outline,
                    title: '全体成员',
                    selected:
                        members.isNotEmpty && _members.length == members.length,
                    onTap: () => setState(() {
                      if (_members.length == members.length) {
                        _members.clear();
                      } else {
                        _members
                          ..clear()
                          ..addAll(
                            members.map((LedgerMember member) => member.id),
                          );
                      }
                    }),
                  ),
                  ...members.map(
                    (LedgerMember member) => _SelectorRow(
                      color: Color(member.colorValue),
                      title: member.name,
                      selected: _members.contains(member.id),
                      onTap: () => setState(() {
                        if (!_members.add(member.id))
                          _members.remove(member.id);
                      }),
                    ),
                  ),
                ],
              ),
              Container(
                margin: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: <Widget>[
                    ListTile(
                      title: const Text('时间'),
                      trailing: Text(_formatDateTime(_occurredAt)),
                      onTap: _pickDateTime,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _noteController,
                        decoration: const InputDecoration(
                          labelText: '备注',
                          hintText: '写点什么…',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_type != EntryType.transfer)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: <Widget>[
                      SwitchListTile(
                        title: const Text('设为周期账目'),
                        subtitle: const Text('到期时提醒手动确认记账'),
                        value: _recurring,
                        onChanged: (bool value) =>
                            setState(() => _recurring = value),
                      ),
                      if (_recurring) ...<Widget>[
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        ListTile(
                          title: const Text('重复周期'),
                          trailing: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _frequency,
                              items: const <DropdownMenuItem<String>>[
                                DropdownMenuItem(
                                  value: 'year',
                                  child: Text('每年'),
                                ),
                                DropdownMenuItem(
                                  value: 'month',
                                  child: Text('每月'),
                                ),
                                DropdownMenuItem(
                                  value: 'week',
                                  child: Text('每周'),
                                ),
                                DropdownMenuItem(
                                  value: 'day',
                                  child: Text('每天'),
                                ),
                              ],
                              onChanged: (String? value) => setState(
                                () => _frequency = value ?? _frequency,
                              ),
                            ),
                          ),
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
  }

  LedgerAccount? _findAccount(List<LedgerAccount> accounts, int? id) {
    for (final LedgerAccount account in accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  String _memberSummary(List<LedgerMember> members) {
    final List<String> selected = members
        .where((LedgerMember member) => _members.contains(member.id))
        .map((LedgerMember member) => member.name)
        .toList();
    if (selected.isEmpty) return '未选择';
    if (selected.length == members.length) return '全体成员';
    if (selected.length <= 2) return selected.join('、');
    return '${selected.take(2).join('、')}等${selected.length}人';
  }

  Future<void> _pickDateTime() async {
    DateTime selected = _occurredAt;
    final DateTime? result = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: SafeArea(
          top: false,
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
                    const Expanded(
                      child: Center(
                        child: Text(
                          '选择时间',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, selected),
                      child: const Text('确定'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              SizedBox(
                height: 230,
                child: CupertinoDatePicker(
                  initialDateTime: _occurredAt,
                  maximumDate: DateTime.now(),
                  use24hFormat: true,
                  mode: CupertinoDatePickerMode.dateAndTime,
                  onDateTimeChanged: (DateTime value) => selected = value,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null && mounted) setState(() => _occurredAt = result);
  }
}

class _TypeTabs extends StatelessWidget {
  const _TypeTabs({required this.selected, required this.onSelected});
  final EntryType selected;
  final ValueChanged<EntryType> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    width: 300,
    margin: const EdgeInsets.symmetric(horizontal: 26),
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: EntryType.values
          .map(
            (EntryType value) => Expanded(
              child: InkWell(
                onTap: () => onSelected(value),
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: selected == value
                        ? Theme.of(context).colorScheme.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: selected == value
                        ? const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x16000000),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    switch (value) {
                      EntryType.expense => '支出',
                      EntryType.income => '收入',
                      EntryType.transfer => '转账',
                    },
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: selected == value
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    ),
  );
}

class _AmountBox extends StatelessWidget {
  const _AmountBox({
    required this.controller,
    required this.category,
    required this.icon,
  });
  final TextEditingController controller;
  final String category;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20),
        ),
        const SizedBox(width: 8),
        Text(category, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        const Spacer(),
        const Text(
          '¥',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 150,
          child: TextField(
            controller: controller,
            autofocus: true,
            textAlign: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              hintText: '0.00',
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
      ],
    ),
  );
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(2, 15, 2, 8),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 4,
      mainAxisExtent: 70,
      crossAxisSpacing: 5,
      mainAxisSpacing: 6,
    ),
    itemCount: categories.length,
    itemBuilder: (BuildContext context, int index) {
      final String category = categories[index];
      final bool active = category == selected;
      return InkWell(
        onTap: () => onSelected(category),
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: active
                    ? AppTheme.green.withValues(alpha: .10)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active ? AppTheme.green : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Icon(_categoryIcon(category), size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _SelectorCard extends StatelessWidget {
  const _SelectorCard({
    required this.title,
    required this.value,
    required this.open,
    required this.onHeaderTap,
    required this.children,
    this.footer,
  });
  final String title;
  final String value;
  final bool open;
  final VoidCallback onHeaderTap;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: <Widget>[
        InkWell(
          onTap: onHeaderTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF8A9099)),
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedRotation(
                  turns: open ? .5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(Icons.arrow_drop_down, size: 20),
                ),
              ],
            ),
          ),
        ),
        if (open) ...<Widget>[
          const Divider(height: 1),
          ...children,
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: footer,
            ),
        ],
      ],
    ),
  );
}

class _SelectorRow extends StatelessWidget {
  const _SelectorRow({
    required this.title,
    required this.selected,
    required this.onTap,
    this.icon,
    this.color,
  });
  final String title;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    onTap: onTap,
    leading: color == null
        ? Icon(icon, size: 20)
        : Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
    title: Text(
      title,
      style: TextStyle(fontWeight: selected ? FontWeight.w600 : null),
    ),
    trailing: selected
        ? const Icon(Icons.check, color: AppTheme.green, size: 20)
        : const SizedBox(width: 20),
  );
}

String _formatDateTime(DateTime value) =>
    '${value.year}年${value.month.toString().padLeft(2, '0')}月${value.day.toString().padLeft(2, '0')}日 '
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

IconData _categoryIcon(String category) => switch (category) {
  '交通' => Icons.directions_car_outlined,
  '购物' => Icons.shopping_bag_outlined,
  '居住' => Icons.home_outlined,
  '娱乐' => Icons.sports_esports_outlined,
  '医疗' => Icons.medical_services_outlined,
  '学习' => Icons.menu_book_outlined,
  '旅行' => Icons.flight_outlined,
  '红包' => Icons.card_giftcard_outlined,
  '理财' => Icons.show_chart,
  '工资' => Icons.payments_outlined,
  _ => Icons.restaurant_outlined,
};
