import 'package:flutter/material.dart';

import '../../data/ledger_controller.dart';
import '../../models/ledger_models.dart';
import '../../theme/app_theme.dart';

class EntrySheet extends StatefulWidget {
  const EntrySheet({required this.controller, this.initial, super.key});

  final LedgerController controller;
  final LedgerEntry? initial;

  @override
  State<EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<EntrySheet> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _memberSearchController = TextEditingController();
  EntryType _type = EntryType.expense;
  String _category = '餐饮';
  int _accountId = 1;
  int? _toAccountId = 2;
  final Set<int> _members = <int>{};
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
    _members.clear();
    if (widget.controller.categories.isNotEmpty) {
      final List<LedgerCategory> expense = widget.controller.categoriesFor(
        EntryType.expense,
      );
      if (expense.isNotEmpty) _category = expense.first.name;
    }
    final LedgerEntry? initial = widget.initial;
    if (initial != null) {
      _type = initial.type;
      _category = initial.category;
      _accountId = initial.accountId;
      _toAccountId = initial.toAccountId;
      _members
        ..clear()
        ..addAll(initial.memberIds);
      _recurring = initial.recurring;
      _frequency = initial.recurringFrequency;
      _occurredAt = initial.occurredAt;
      _amountController.text = initial.amount.toStringAsFixed(2);
      _noteController.text = initial.note;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _memberSearchController.dispose();
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
        id: widget.initial?.id ?? 0,
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
    final String memberQuery = _memberSearchController.text
        .trim()
        .toLowerCase();
    final List<LedgerMember> filteredMembers = members
        .where(
          (member) =>
              memberQuery.isEmpty ||
              member.name.toLowerCase().contains(memberQuery),
        )
        .toList();
    final LedgerAccount? account = _findAccount(accounts, _accountId);
    final LedgerAccount? toAccount = _findAccount(accounts, _toAccountId);
    final Color surface = Theme.of(context).colorScheme.surface;
    final List<LedgerCategory> categories = widget.controller.categoriesFor(
      _type,
    );

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(widget.initial == null ? '记一笔' : '编辑账目'),
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
              _TypeTabs(selected: _type, onSelected: _changeType),
              const SizedBox(height: 14),
              _AmountBox(
                controller: _amountController,
                category: _type == EntryType.transfer ? '转账' : _category,
                icon: _type == EntryType.transfer
                    ? Icons.swap_horiz
                    : _categoryIconFor(categories),
              ),
              if (_type != EntryType.transfer) ...<Widget>[
                _CategoryGrid(
                  categories: categories,
                  selected: _category,
                  onSelected: (String value) =>
                      setState(() => _category = value),
                  onAdd: _addCategory,
                  onLongPress: (LedgerCategory category) =>
                      _addCategory(category),
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
              if (widget.controller.multiEnabled)
                _SelectorCard(
                  title: _type == EntryType.transfer ? '操作者 · 可多选' : '成员 · 可多选',
                  value: _memberSummary(members),
                  open: _membersOpen,
                  onHeaderTap: () =>
                      setState(() => _membersOpen = !_membersOpen),
                  footer: _membersOpen
                      ? Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            onPressed: () =>
                                setState(() => _membersOpen = false),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(74, 34),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                            ),
                            child: const Text('完成'),
                          ),
                        )
                      : null,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                      child: TextField(
                        controller: _memberSearchController,
                        autofocus: false,
                        decoration: InputDecoration(
                          hintText: '搜索成员',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _memberSearchController.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () =>
                                      setState(_memberSearchController.clear),
                                  icon: const Icon(Icons.close, size: 18),
                                ),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    _SelectorRow(
                      icon: Icons.block_outlined,
                      title: '无选择',
                      selected: _members.isEmpty,
                      onTap: () => setState(_members.clear),
                    ),
                    _SelectorRow(
                      icon: Icons.people_outline,
                      title: '全体成员',
                      selected:
                          members.isNotEmpty &&
                          _members.length == members.length,
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
                    ...filteredMembers.map(
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

  IconData _categoryIconFor(List<LedgerCategory> categories) {
    for (final LedgerCategory category in categories) {
      if (category.name == _category) {
        return _categoryIcon(category.icon, category.name);
      }
    }
    return Icons.sell_outlined;
  }

  void _changeType(EntryType value) {
    setState(() {
      _type = value;
      if (_type == EntryType.transfer) {
        _recurring = false;
      } else {
        final List<LedgerCategory> available = widget.controller.categoriesFor(
          _type,
        );
        if (!available.any((item) => item.name == _category) &&
            available.isNotEmpty) {
          _category = available.first.name;
        }
      }
    });
  }

  Future<void> _addCategory([LedgerCategory? existing]) async {
    final TextEditingController name = TextEditingController(
      text: existing?.name ?? '',
    );
    String group = _iconGroups.keys.first;
    for (final MapEntry<String, List<String>> item in _iconGroups.entries) {
      if (item.value.contains(existing?.icon)) {
        group = item.key;
        break;
      }
    }
    String icon = existing?.icon ?? _iconGroups[group]!.first;
    final bool? save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter update) =>
            FractionallySizedBox(
              heightFactor: .88,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
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
                              existing == null ? '自定义标签' : '编辑标签',
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
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                      child: TextField(
                        controller: name,
                        autofocus: false,
                        decoration: const InputDecoration(
                          labelText: '名称',
                          hintText: '如：宠物',
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 46,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: _iconGroups.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (BuildContext context, int index) {
                          final String item = _iconGroups.keys.elementAt(index);
                          final bool selected = item == group;
                          return ChoiceChip(
                            label: Text(item),
                            selected: selected,
                            showCheckmark: false,
                            onSelected: (_) => update(() {
                              group = item;
                              final List<String> icons = _iconGroups[group]!;
                              if (!icons.contains(icon)) icon = icons.first;
                            }),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 6,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                            ),
                        itemCount: _iconGroups[group]!.length,
                        itemBuilder: (BuildContext context, int index) {
                          final String item = _iconGroups[group]![index];
                          final bool selected = icon == item;
                          return InkWell(
                            onTap: () => update(() => icon = item),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppTheme.green.withValues(alpha: .12)
                                    : Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected
                                      ? AppTheme.green
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Icon(_iconFromKey(item), size: 22),
                            ),
                          );
                        },
                      ),
                    ),
                    if (existing != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () async {
                              if (await _deleteCategory(existing)) {
                                if (context.mounted) Navigator.pop(context);
                              }
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.expense,
                            ),
                            child: const Text('删除标签'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
      ),
    );
    final String value = name.text.trim();
    if (save != true || value.isEmpty) return;
    if (widget.controller.categories.any(
      (item) => item.name == value && item.name != existing?.name,
    )) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('标签已存在')));
      }
      return;
    }
    if (existing == null) {
      await widget.controller.addCategory(value, _type, icon);
    } else {
      await widget.controller.updateCategory(existing.name, value, icon);
    }
    if (mounted) setState(() => _category = value);
  }

  Future<bool> _deleteCategory(LedgerCategory category) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('删除标签「${category.name}」？'),
        content: const Text('已有账目仍会保留标签名称。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
    await widget.controller.archiveCategory(category.name);
    final List<LedgerCategory> remaining = widget.controller.categoriesFor(
      _type,
    );
    if (mounted && remaining.isNotEmpty) {
      setState(() => _category = remaining.first.name);
    }
    return true;
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
    final DateTime now = DateTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime(
        _occurredAt.year,
        _occurredAt.month,
        _occurredAt.day,
      ),
      firstDate: DateTime(1970),
      lastDate: DateTime(now.year, now.month, now.day),
      initialEntryMode: DatePickerEntryMode.calendar,
    );
    if (date == null || !mounted) return;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
      initialEntryMode: TimePickerEntryMode.dial,
      helpText: '选择时分',
    );
    if (time == null || !mounted) return;
    DateTime selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (selected.isAfter(now)) {
      selected = now;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('时间不能超过当前时间，已设为现在')));
    }
    setState(() => _occurredAt = selected);
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
      children:
          const <EntryType>[
                EntryType.expense,
                EntryType.income,
                EntryType.transfer,
              ]
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
                          EntryType.adjustment => '调整',
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
            autofocus: false,
            textAlign: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              hintText: '0.00',
              border: InputBorder.none,
              isDense: true,
              filled: false,
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
    required this.onAdd,
    required this.onLongPress,
  });
  final List<LedgerCategory> categories;
  final String selected;
  final ValueChanged<String> onSelected;
  final VoidCallback onAdd;
  final ValueChanged<LedgerCategory> onLongPress;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxHeight: 286),
    child: GridView.builder(
      key: ValueKey<int>(categories.length),
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(2, 15, 2, 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisExtent: 70,
        crossAxisSpacing: 5,
        mainAxisSpacing: 6,
      ),
      itemCount: categories.length + 1,
      itemBuilder: (BuildContext context, int index) {
        if (index == categories.length) {
          return InkWell(
            onTap: onAdd,
            borderRadius: BorderRadius.circular(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.add, size: 22),
                ),
                const SizedBox(height: 4),
                const Text('自定义', style: TextStyle(fontSize: 12)),
              ],
            ),
          );
        }
        final LedgerCategory category = categories[index];
        final bool active = category.name == selected;
        return InkWell(
          onTap: () => onSelected(category.name),
          onLongPress: () => onLongPress(category),
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
                child: Icon(
                  _categoryIcon(category.icon, category.name),
                  size: 22,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                category.name,
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
    ),
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
                Expanded(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
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

const Map<String, List<String>> _iconGroups = <String, List<String>>{
  '娱乐': <String>[
    'game',
    'movie',
    'music',
    'theater',
    'karaoke',
    'camera',
    'sports',
    'dice',
    'tv',
    'palette',
    'soccer',
  ],
  '饮食': <String>[
    'restaurant',
    'coffee',
    'cake',
    'bottle',
    'fastfood',
    'icecream',
    'breakfast',
    'wine',
    'grocery',
    'bakery',
    'fruit',
  ],
  '医疗': <String>[
    'medical',
    'medicine',
    'hospital',
    'pharmacy',
    'dental',
    'healing',
    'psychology',
    'spa',
    'vaccine',
    'glasses',
  ],
  '学习': <String>[
    'book',
    'school',
    'language',
    'calculate',
    'science',
    'edit',
    'library',
    'computer',
    'code',
    'graduation',
  ],
  '交通': <String>[
    'car',
    'bus',
    'train',
    'subway',
    'bicycle',
    'flight',
    'ship',
    'taxi',
    'motorcycle',
    'parking',
  ],
  '购物': <String>[
    'shopping',
    'cart',
    'bag',
    'store',
    'gift',
    'clothes',
    'beauty',
    'receipt',
    'electronics',
    'furniture',
  ],
  '生活': <String>[
    'home',
    'rent',
    'phone',
    'tools',
    'repair',
    'plant',
    'pet',
    'bolt',
    'laundry',
    'water',
  ],
  '个人': <String>[
    'fitness',
    'heart',
    'star',
    'child',
    'person',
    'beauty',
    'watch',
    'haircut',
    'meditation',
    'skincare',
  ],
  '家庭': <String>[
    'family',
    'baby',
    'elderly',
    'home',
    'pet',
    'child',
    'toy',
    'kitchen',
    'daycare',
    'family_meal',
  ],
  '办公': <String>[
    'work',
    'briefcase',
    'computer',
    'print',
    'email',
    'folder',
    'meeting',
    'calendar',
    'document',
    'analytics',
  ],
  '金融': <String>[
    'wallet',
    'bank',
    'card',
    'savings',
    'coin',
    'chart',
    'insurance',
    'receipt',
    'red_packet',
    'salary',
    'tip',
    'reimbursement',
    'part_time',
    'currency',
    'percent',
  ],
  '其他': <String>[
    'tag',
    'more',
    'key',
    'globe',
    'cloud',
    'repeat',
    'link',
    'flag',
    'lock',
    'bell',
  ],
};

IconData _categoryIcon(String? key, String category) =>
    key == null ? _categoryIconByName(category) : _iconFromKey(key);

IconData _categoryIconByName(String category) => switch (category) {
  '餐饮' => Icons.restaurant_outlined,
  '交通' => Icons.directions_car_outlined,
  '购物' => Icons.shopping_bag_outlined,
  '住房' => Icons.home_outlined,
  '居住' => Icons.home_outlined,
  '娱乐' => Icons.sports_esports_outlined,
  '医疗' => Icons.medical_services_outlined,
  '学习' => Icons.menu_book_outlined,
  '旅行' => Icons.flight_outlined,
  '红包' => Icons.card_giftcard_outlined,
  '理财' => Icons.show_chart,
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

IconData _iconFromKey(String key) => switch (key) {
  'restaurant' => Icons.restaurant_outlined,
  'car' => Icons.directions_car_outlined,
  'shopping' => Icons.shopping_bag_outlined,
  'home' => Icons.home_outlined,
  'game' => Icons.sports_esports_outlined,
  'medical' => Icons.medical_services_outlined,
  'book' => Icons.menu_book_outlined,
  'flight' => Icons.flight_outlined,
  'gift' => Icons.card_giftcard_outlined,
  'salary' => Icons.payments_outlined,
  'chart' => Icons.show_chart,
  'red_packet' => Icons.wallet_giftcard_outlined,
  'tip' => Icons.volunteer_activism_outlined,
  'reimbursement' => Icons.receipt_long_outlined,
  'part_time' => Icons.work_history_outlined,
  'more' => Icons.more_horiz,
  'pet' => Icons.pets_outlined,
  'coffee' => Icons.coffee_outlined,
  'phone' => Icons.phone_android_outlined,
  'fitness' => Icons.fitness_center_outlined,
  'child' => Icons.child_care_outlined,
  'beauty' => Icons.brush_outlined,
  'tools' => Icons.handyman_outlined,
  'plant' => Icons.local_florist_outlined,
  'cake' => Icons.cake_outlined,
  'insurance' => Icons.health_and_safety_outlined,
  'rent' => Icons.key_outlined,
  'heart' => Icons.favorite_border,
  'star' => Icons.star_border,
  'key' => Icons.vpn_key_outlined,
  'bus' => Icons.directions_bus_outlined,
  'train' => Icons.train_outlined,
  'bicycle' => Icons.pedal_bike_outlined,
  'clothes' => Icons.checkroom_outlined,
  'bottle' => Icons.local_drink_outlined,
  'bolt' => Icons.bolt_outlined,
  'music' => Icons.music_note_outlined,
  'movie' => Icons.movie_outlined,
  'hotel' => Icons.hotel_outlined,
  'work' => Icons.work_outline,
  'school' => Icons.school_outlined,
  'baby' => Icons.child_friendly_outlined,
  'repair' => Icons.build_outlined,
  'theater' => Icons.theater_comedy_outlined,
  'karaoke' => Icons.mic_external_on_outlined,
  'camera' => Icons.camera_alt_outlined,
  'sports' => Icons.sports_basketball_outlined,
  'dice' => Icons.casino_outlined,
  'tv' => Icons.tv_outlined,
  'palette' => Icons.palette_outlined,
  'soccer' => Icons.sports_soccer_outlined,
  'fastfood' => Icons.fastfood_outlined,
  'icecream' => Icons.icecream_outlined,
  'breakfast' => Icons.breakfast_dining_outlined,
  'wine' => Icons.wine_bar_outlined,
  'grocery' => Icons.local_grocery_store_outlined,
  'bakery' => Icons.bakery_dining_outlined,
  'fruit' => Icons.eco_outlined,
  'medicine' => Icons.medication_outlined,
  'hospital' => Icons.local_hospital_outlined,
  'pharmacy' => Icons.local_pharmacy_outlined,
  'dental' => Icons.medical_information_outlined,
  'healing' => Icons.healing_outlined,
  'psychology' => Icons.psychology_outlined,
  'spa' => Icons.spa_outlined,
  'vaccine' => Icons.vaccines_outlined,
  'glasses' => Icons.visibility_outlined,
  'language' => Icons.language_outlined,
  'calculate' => Icons.calculate_outlined,
  'science' => Icons.science_outlined,
  'edit' => Icons.edit_outlined,
  'library' => Icons.local_library_outlined,
  'computer' => Icons.computer_outlined,
  'code' => Icons.code,
  'graduation' => Icons.workspace_premium_outlined,
  'subway' => Icons.subway_outlined,
  'ship' => Icons.directions_boat_outlined,
  'taxi' => Icons.local_taxi_outlined,
  'motorcycle' => Icons.two_wheeler_outlined,
  'parking' => Icons.local_parking,
  'cart' => Icons.shopping_cart_outlined,
  'bag' => Icons.shopping_bag_outlined,
  'store' => Icons.storefront_outlined,
  'receipt' => Icons.receipt_long_outlined,
  'electronics' => Icons.devices_other_outlined,
  'furniture' => Icons.chair_outlined,
  'person' => Icons.person_outline,
  'watch' => Icons.watch_outlined,
  'haircut' => Icons.content_cut,
  'meditation' => Icons.self_improvement,
  'skincare' => Icons.face_retouching_natural,
  'family' => Icons.family_restroom_outlined,
  'elderly' => Icons.elderly_outlined,
  'toy' => Icons.toys_outlined,
  'kitchen' => Icons.kitchen_outlined,
  'daycare' => Icons.escalator_warning_outlined,
  'family_meal' => Icons.dining_outlined,
  'briefcase' => Icons.business_center_outlined,
  'print' => Icons.print_outlined,
  'email' => Icons.email_outlined,
  'folder' => Icons.folder_outlined,
  'meeting' => Icons.groups_outlined,
  'calendar' => Icons.calendar_month_outlined,
  'document' => Icons.description_outlined,
  'analytics' => Icons.analytics_outlined,
  'wallet' => Icons.account_balance_wallet_outlined,
  'bank' => Icons.account_balance_outlined,
  'card' => Icons.credit_card_outlined,
  'savings' => Icons.savings_outlined,
  'coin' => Icons.monetization_on_outlined,
  'currency' => Icons.currency_exchange,
  'percent' => Icons.percent,
  'globe' => Icons.public_outlined,
  'cloud' => Icons.cloud_outlined,
  'repeat' => Icons.repeat,
  'link' => Icons.link,
  'flag' => Icons.flag_outlined,
  'lock' => Icons.lock_outline,
  'bell' => Icons.notifications_none,
  'tag' => Icons.label_outline,
  _ => Icons.sell_outlined,
};
