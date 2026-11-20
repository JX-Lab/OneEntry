import 'package:flutter/material.dart';

import '../../data/ledger_controller.dart';
import '../../models/ledger_models.dart';
import '../../theme/app_theme.dart';
import '../../utils/amount_expression.dart';

class EntrySheet extends StatefulWidget {
  const EntrySheet({
    required this.controller,
    this.initial,
    this.draft,
    super.key,
  });

  final LedgerController controller;
  final LedgerEntry? initial;
  final LedgerEntry? draft;

  @override
  State<EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<EntrySheet> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode(debugLabel: 'entry-amount');
  EntryType _type = EntryType.expense;
  String _category = '餐饮';
  int _accountId = 1;
  int? _toAccountId = 2;
  final Set<int> _members = <int>{};
  int? _recordedByMemberId;
  final List<EntryFunding> _fundings = <EntryFunding>[];
  bool _recurring = false;
  bool _outsideBudget = false;
  String _frequency = 'month';
  DateTime _occurredAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    final List<LedgerAccount> activeAccounts = widget.controller.accounts
        .where((LedgerAccount account) => !account.archived)
        .toList();
    if (activeAccounts.isNotEmpty) {
      _accountId = _lastUsedAccountId(activeAccounts);
    }
    if (activeAccounts.length > 1) {
      _toAccountId = activeAccounts
          .firstWhere((account) => account.id != _accountId)
          .id;
    }
    _members.clear();
    final List<LedgerMember> activeMembers = widget.controller.members
        .where((LedgerMember member) => !member.archived)
        .toList();
    _recordedByMemberId = null;
    if (activeMembers.length == 1) _members.add(activeMembers.first.id);
    if (widget.controller.categories.isNotEmpty) {
      final List<LedgerCategory> expense = widget.controller.categoriesFor(
        EntryType.expense,
      );
      if (expense.isNotEmpty) _category = expense.first.name;
    }
    final LedgerEntry? source = widget.initial ?? widget.draft;
    if (source != null) {
      _type = source.type;
      _category = source.category;
      _accountId = source.accountId;
      _toAccountId = source.toAccountId;
      _members
        ..clear()
        ..addAll(source.memberIds);
      _fundings
        ..clear()
        ..addAll(source.fundings);
      _recordedByMemberId = source.recordedByMemberId;
      _recurring = source.recurring;
      _outsideBudget = source.outsideBudget;
      _frequency = source.recurringFrequency;
      _occurredAt = source.occurredAt;
      _amountController.text = source.amount.toStringAsFixed(2);
      _noteController.text = source.note;
    } else {
      final List<LedgerCategory> expense = widget.controller.categoriesFor(
        EntryType.expense,
      );
      _category = _lastUsedCategory(expense) ?? _category;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _amountController.selection = TextSelection.collapsed(
        offset: _amountController.text.length,
      );
      _amountFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  int _lastUsedAccountId(List<LedgerAccount> activeAccounts) {
    final Set<int> activeIds = activeAccounts
        .map((account) => account.id)
        .toSet();
    for (final LedgerEntry entry in widget.controller.visibleEntries) {
      if (entry.type == EntryType.expense || entry.type == EntryType.income) {
        return activeIds.contains(entry.accountId)
            ? entry.accountId
            : activeAccounts.first.id;
      }
    }
    return activeAccounts.first.id;
  }

  String? _lastUsedCategory(List<LedgerCategory> available) {
    final Set<String> names = available
        .map((LedgerCategory category) => category.name)
        .toSet();
    for (final LedgerEntry entry in widget.controller.visibleEntries) {
      if (entry.type == EntryType.expense && names.contains(entry.category)) {
        return entry.category;
      }
    }
    return null;
  }

  void _save() {
    final double? amount = evaluateAmountExpression(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入有效的金额或算式')));
      return;
    }
    if (_type == EntryType.transfer &&
        (_toAccountId == null || _toAccountId == _accountId)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请选择两个不同的账户')));
      return;
    }
    late final List<EntryFunding> fundings;
    try {
      fundings = _fundingsForSave(amount);
    } on StateError catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${error.message}')));
      return;
    }
    final String? fundingError = _validateLocalFundings(fundings);
    if (fundingError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(fundingError)));
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
        memberShares: _memberSharesForSave(amount),
        fundings: fundings,
        outsideBudget: _type == EntryType.expense && _outsideBudget,
        recordedByMemberId: _recordedByMemberId,
        visibility: EntryVisibility.all,
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
    final List<LedgerCategory> categories = widget.controller.categoriesFor(
      _type,
      memberId: _recordedByMemberId,
    );

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(widget.initial == null ? '记一笔' : '编辑账目'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.tonalIcon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('保存'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(80, 40),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
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
                focusNode: _amountFocusNode,
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
                if (widget.controller.multiEnabled)
                  _PickerField(
                    title: '承担成员（可多选）',
                    value: _memberSummary(members),
                    onTap: () => _pickMembers(members),
                  ),
                if (widget.controller.multiEnabled)
                  _PickerField(
                    title: '记录者（可不选）',
                    value: _memberName(members, _recordedByMemberId),
                    onTap: () => _pickRecorder(members),
                  ),
                _PickerField(
                  title: _type == EntryType.expense ? '支付来源' : '入账账户',
                  value: _fundingSummary(accounts, members, account),
                  onTap: () =>
                      _editFundings(accounts: accounts, members: members),
                ),
              ] else ...<Widget>[
                _PickerField(
                  title: '转出账户',
                  value: account?.name ?? '请选择',
                  onTap: () => _pickAccount(
                    title: '选择转出账户',
                    accounts: accounts,
                    selectedId: _accountId,
                    excludedId: _toAccountId,
                    onSelected: (int id) => setState(() => _accountId = id),
                  ),
                ),
                _PickerField(
                  title: '转入账户',
                  value: toAccount?.name ?? '请选择',
                  onTap: () => _pickAccount(
                    title: '选择转入账户',
                    accounts: accounts,
                    selectedId: _toAccountId,
                    excludedId: _accountId,
                    onSelected: (int id) => setState(() => _toAccountId = id),
                  ),
                ),
              ],
              if (widget.controller.multiEnabled && _type == EntryType.transfer)
                _PickerField(
                  title: '操作者（可多选）',
                  value: _memberSummary(members),
                  onTap: () => _pickMembers(members),
                ),
              if (widget.controller.multiEnabled && _type == EntryType.transfer)
                _PickerField(
                  title: '记录者（可不选）',
                  value: _memberName(members, _recordedByMemberId),
                  onTap: () => _pickRecorder(members),
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
                      if (_type == EntryType.expense) ...<Widget>[
                        SwitchListTile(
                          title: const Text('预算外花销'),
                          subtitle: const Text('计入本月总支出，但不占用预算额度'),
                          value: _outsideBudget,
                          onChanged: (bool value) =>
                              setState(() => _outsideBudget = value),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                      ],
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

  Future<void> _pickAccount({
    required String title,
    required List<LedgerAccount> accounts,
    required int? selectedId,
    required ValueChanged<int> onSelected,
    int? excludedId,
  }) async {
    _dismissKeyboard();
    final int? result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) => _AccountPickerSheet(
        title: title,
        accounts: accounts,
        selectedId: selectedId,
        excludedId: excludedId,
      ),
    );
    if (!mounted) return;
    _dismissKeyboard();
    if (result != null) onSelected(result);
  }

  Future<void> _pickMembers(List<LedgerMember> members) async {
    _dismissKeyboard();
    final Set<int>? result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) => _MemberPickerSheet(
        title: _type == EntryType.transfer ? '选择操作者' : '选择成员',
        members: members,
        selectedIds: _members,
      ),
    );
    if (!mounted) return;
    _dismissKeyboard();
    if (result == null) return;
    setState(() {
      _members
        ..clear()
        ..addAll(result);
    });
  }

  String _memberName(List<LedgerMember> members, int? memberId) =>
      members
          .where((LedgerMember member) => member.id == memberId)
          .map((LedgerMember member) => member.name)
          .firstOrNull ??
      '系统记录';

  Future<void> _pickRecorder(List<LedgerMember> members) async {
    _dismissKeyboard();
    final int? result = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      builder: (BuildContext context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 16),
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 12, 18, 6),
            child: Text(
              '选择记录身份',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.remove)),
            title: const Text('不记录'),
            trailing: _recordedByMemberId == null
                ? const Icon(Icons.check)
                : null,
            onTap: () => Navigator.pop(context, -1),
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
              title: Text(member.name),
              trailing: member.id == _recordedByMemberId
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(context, member.id),
            ),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _recordedByMemberId = result < 0 ? null : result;
      final List<LedgerCategory> available = widget.controller.categoriesFor(
        _type,
        memberId: _recordedByMemberId,
      );
      if (!available.any((LedgerCategory item) => item.name == _category) &&
          available.isNotEmpty) {
        _category = available.first.name;
      }
    });
  }

  List<EntryFunding> _fundingsForSave(double amount) {
    if (_type == EntryType.transfer) {
      return <EntryFunding>[
        EntryFunding(accountId: _accountId, amount: amount),
      ];
    }
    if (_fundings.isEmpty) {
      final List<EntryFunding> suggested = _suggestFundings(amount);
      final int allocated = suggested.fold<int>(
        0,
        (int sum, EntryFunding item) => sum + (item.amount * 100).round(),
      );
      if (allocated != (amount * 100).round()) {
        throw StateError('所有可用账户合计仍不足，请调整金额或使用信用账户');
      }
      return suggested;
    }
    if (_fundings.length == 1) {
      final EntryFunding only = _fundings.first;
      return <EntryFunding>[
        EntryFunding(
          accountId: only.accountId,
          memberId: only.memberId,
          amount: amount,
        ),
      ];
    }
    final int expected = (amount * 100).round();
    final int actual = _fundings.fold<int>(
      0,
      (int sum, EntryFunding item) => sum + (item.amount * 100).round(),
    );
    if (actual != expected) {
      throw StateError('组合付款合计必须等于账目金额');
    }
    return List<EntryFunding>.from(_fundings);
  }

  List<EntryFunding> _suggestFundings(double amount) {
    final List<LedgerAccount> active = widget.controller.accounts
        .where(
          (LedgerAccount account) =>
              !account.archived && account.kind != AccountKind.loan,
        )
        .toList();
    active.sort((LedgerAccount a, LedgerAccount b) {
      if (a.id == _accountId) return -1;
      if (b.id == _accountId) return 1;
      return widget.controller.accounts
          .indexOf(a)
          .compareTo(widget.controller.accounts.indexOf(b));
    });
    int remaining = (amount * 100).round();
    final List<EntryFunding> result = <EntryFunding>[];
    for (final LedgerAccount account in active) {
      final List<AccountFund> funds = account.funds.isEmpty
          ? <AccountFund>[
              AccountFund(accountId: account.id, balance: account.balance),
            ]
          : List<AccountFund>.from(account.funds);
      funds.sort((AccountFund a, AccountFund b) {
        int rank(AccountFund fund) => fund.memberId == null
            ? 0
            : _members.contains(fund.memberId)
            ? 1
            : 2;
        return rank(a).compareTo(rank(b));
      });
      int accountAllocated = 0;
      for (final AccountFund fund in funds) {
        if (fund.memberId != null && !_members.contains(fund.memberId)) {
          continue;
        }
        final int available = (fund.balance * 100).round().clamp(0, remaining);
        if (available <= 0) continue;
        result.add(
          EntryFunding(
            accountId: account.id,
            memberId: fund.memberId,
            amount: available / 100,
          ),
        );
        accountAllocated += available;
        remaining -= available;
        if (remaining == 0) return result;
      }
      if (account.kind == AccountKind.credit && remaining > 0) {
        final int creditAvailable =
            ((account.availableToSpend * 100).round() - accountAllocated).clamp(
              0,
              remaining,
            );
        if (creditAvailable > 0) {
          result.add(
            EntryFunding(accountId: account.id, amount: creditAvailable / 100),
          );
          remaining -= creditAvailable;
          if (remaining == 0) return result;
        }
      }
    }
    return result;
  }

  List<MemberShare> _memberSharesForSave(double amount) {
    if (widget.controller.splitMode != 'fund_ratio' || _members.isEmpty) {
      return const <MemberShare>[];
    }
    final Map<int, double> wealth = <int, double>{
      for (final int memberId in _members)
        memberId: widget.controller.accounts
            .where((LedgerAccount account) => !account.archived)
            .expand((LedgerAccount account) => account.funds)
            .where((AccountFund fund) => fund.memberId == memberId)
            .fold(
              0,
              (double sum, AccountFund fund) =>
                  sum + (fund.balance > 0 ? fund.balance : 0),
            ),
    };
    final double totalWealth = wealth.values.fold(
      0,
      (double sum, double value) => sum + value,
    );
    if (totalWealth <= 0) return const <MemberShare>[];
    final int totalMinor = (amount * 100).round();
    int assigned = 0;
    final List<int> ids = _members.toList();
    return ids.map((int memberId) {
      final int share = memberId == ids.last
          ? totalMinor - assigned
          : (totalMinor * (wealth[memberId] ?? 0) / totalWealth).floor();
      assigned += share;
      return MemberShare(memberId: memberId, amount: share / 100);
    }).toList();
  }

  String? _validateLocalFundings(List<EntryFunding> fundings) {
    if (_type == EntryType.income) return null;
    final Map<(int, int?), double> requested = <(int, int?), double>{};
    for (final EntryFunding funding in fundings) {
      final (int, int?) key = (funding.accountId, funding.memberId);
      requested.update(
        key,
        (double value) => value + funding.amount,
        ifAbsent: () => funding.amount,
      );
    }
    for (final MapEntry<(int, int?), double> item in requested.entries) {
      final LedgerAccount? account = widget.controller.accounts
          .where((LedgerAccount value) => value.id == item.key.$1)
          .firstOrNull;
      if (account == null || account.archived) return '所选账户不可用';
      if (account.kind == AccountKind.loan) return '贷款账户不能直接用于支付';
      final double available =
          account.kind == AccountKind.credit && item.key.$2 == null
          ? account.availableToSpend
          : account.funds
                    .where((AccountFund fund) => fund.memberId == item.key.$2)
                    .map((AccountFund fund) => fund.balance)
                    .firstOrNull ??
                (item.key.$2 == null && account.funds.isEmpty
                    ? account.balance
                    : 0);
      if (item.value - available > .004) {
        return '所选资金不足，请调整支付来源或使用组合付款';
      }
    }
    return null;
  }

  String _fundingSummary(
    List<LedgerAccount> accounts,
    List<LedgerMember> members,
    LedgerAccount? fallback,
  ) {
    if (_fundings.isEmpty) return fallback?.name ?? '请选择';
    String label(EntryFunding funding) {
      final String account =
          accounts
              .where((LedgerAccount item) => item.id == funding.accountId)
              .map((LedgerAccount item) => item.name)
              .firstOrNull ??
          '未知账户';
      final String owner = funding.memberId == null
          ? '共同资金'
          : members
                    .where((LedgerMember item) => item.id == funding.memberId)
                    .map((LedgerMember item) => item.name)
                    .firstOrNull ??
                '未知成员';
      return '$account·$owner ¥${funding.amount.toStringAsFixed(2)}';
    }

    if (_fundings.length == 1) return label(_fundings.first);
    return _fundings.map(label).join(' + ');
  }

  Future<void> _editFundings({
    required List<LedgerAccount> accounts,
    required List<LedgerMember> members,
  }) async {
    _dismissKeyboard();
    final double? amount = evaluateAmountExpression(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先输入账目金额')));
      return;
    }
    final List<EntryFunding>? result =
        await showModalBottomSheet<List<EntryFunding>>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (BuildContext context) => _FundingEditorSheet(
            total: amount,
            type: _type,
            accounts: accounts,
            members: members,
            selectedMemberIds: _members,
            initial: _fundings.isEmpty ? _suggestFundings(amount) : _fundings,
          ),
        );
    if (!mounted || result == null || result.isEmpty) return;
    setState(() {
      _fundings
        ..clear()
        ..addAll(result);
      _accountId = result.first.accountId;
    });
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
          memberId: _recordedByMemberId,
        );
        if (!available.any((item) => item.name == _category) &&
            available.isNotEmpty) {
          _category = available.first.name;
        }
      }
    });
  }

  Future<void> _addCategory([LedgerCategory? existing]) async {
    _dismissKeyboard();
    final TextEditingController name = TextEditingController(
      text: existing?.name ?? '',
    );
    String group = categoryIconGroups.keys.first;
    for (final MapEntry<String, List<String>> item
        in categoryIconGroups.entries) {
      if (item.value.contains(existing?.icon)) {
        group = item.key;
        break;
      }
    }
    String icon = existing?.icon ?? categoryIconGroups[group]!.first;
    int? categoryMemberId = existing?.memberId;
    final bool? save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter update) => FractionallySizedBox(
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
                          style: const TextStyle(fontWeight: FontWeight.w700),
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
                if (_recordedByMemberId != null)
                  SwitchListTile(
                    title: const Text('当前身份专属标签'),
                    subtitle: Text(
                      categoryMemberId == null
                          ? '所有成员都可以使用'
                          : '仅 ${_memberName(widget.controller.members, categoryMemberId)} 使用',
                    ),
                    value: categoryMemberId != null,
                    onChanged: (bool value) => update(
                      () =>
                          categoryMemberId = value ? _recordedByMemberId : null,
                    ),
                  ),
                SizedBox(
                  height: 46,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: categoryIconGroups.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (BuildContext context, int index) {
                      final String item = categoryIconGroups.keys.elementAt(
                        index,
                      );
                      final bool selected = item == group;
                      return ChoiceChip(
                        label: Text(item),
                        selected: selected,
                        showCheckmark: false,
                        onSelected: (_) => update(() {
                          group = item;
                          final List<String> icons = categoryIconGroups[group]!;
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
                    itemCount: categoryIconGroups[group]!.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String item = categoryIconGroups[group]![index];
                      final bool selected = icon == item;
                      return InkWell(
                        onTap: () => update(() => icon = item),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: selected
                                ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: .12)
                                : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Icon(categoryIconFromKey(item), size: 22),
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
    if (mounted) _dismissKeyboard();
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
      await widget.controller.addCategory(
        value,
        _type,
        icon,
        memberId: categoryMemberId,
      );
    } else {
      await widget.controller.updateCategory(
        existing.name,
        value,
        icon,
        memberId: categoryMemberId,
      );
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
    _dismissKeyboard();
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
    if (!mounted) return;
    _dismissKeyboard();
    if (date == null) return;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
      initialEntryMode: TimePickerEntryMode.dial,
      helpText: '选择时分',
    );
    if (!mounted) return;
    _dismissKeyboard();
    if (time == null) return;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _dismissKeyboard();
    });
  }

  void _dismissKeyboard() {
    _amountFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
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
    required this.focusNode,
    required this.category,
    required this.icon,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
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
            focusNode: focusNode,
            autofocus: false,
            autocorrect: false,
            enableSuggestions: false,
            textAlign: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
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
                      ? Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: .10)
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: active
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
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

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.title,
    required this.value,
    required this.onTap,
  });
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: <Widget>[
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    ),
  );
}

class _FundingSource {
  const _FundingSource({
    required this.account,
    required this.available,
    this.memberId,
    this.memberName,
  });

  final LedgerAccount account;
  final int? memberId;
  final String? memberName;
  final double available;

  String get label =>
      '${account.name} · ${memberId == null ? '共同资金' : memberName ?? '成员资金'}';
}

class _FundingDraft {
  _FundingDraft(this.source, double amount)
    : controller = TextEditingController(text: amount.toStringAsFixed(2));

  _FundingSource source;
  final TextEditingController controller;

  double get amount => double.tryParse(controller.text) ?? 0;
  void dispose() => controller.dispose();
}

class _FundingEditorSheet extends StatefulWidget {
  const _FundingEditorSheet({
    required this.total,
    required this.type,
    required this.accounts,
    required this.members,
    required this.selectedMemberIds,
    required this.initial,
  });

  final double total;
  final EntryType type;
  final List<LedgerAccount> accounts;
  final List<LedgerMember> members;
  final Set<int> selectedMemberIds;
  final List<EntryFunding> initial;

  @override
  State<_FundingEditorSheet> createState() => _FundingEditorSheetState();
}

class _FundingEditorSheetState extends State<_FundingEditorSheet> {
  final List<_FundingDraft> _rows = <_FundingDraft>[];

  @override
  void initState() {
    super.initState();
    final List<_FundingSource> sources = _sources();
    for (final EntryFunding item in widget.initial) {
      final _FundingSource? source = sources
          .where(
            (_FundingSource candidate) =>
                candidate.account.id == item.accountId &&
                candidate.memberId == item.memberId,
          )
          .firstOrNull;
      if (source != null) _rows.add(_FundingDraft(source, item.amount));
    }
    if (_rows.isEmpty && sources.isNotEmpty) {
      _rows.add(_FundingDraft(sources.first, widget.total));
    }
  }

  @override
  void dispose() {
    for (final _FundingDraft row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  List<_FundingSource> _sources() {
    final List<_FundingSource> result = <_FundingSource>[];
    for (final LedgerAccount account in widget.accounts) {
      if (widget.type == EntryType.expense &&
          account.kind == AccountKind.loan) {
        continue;
      }
      final Map<int?, double> balances = <int?, double>{
        for (final AccountFund fund in account.funds)
          fund.memberId: fund.balance,
      };
      balances.putIfAbsent(
        null,
        () => account.funds.isEmpty ? account.balance : 0,
      );
      if (widget.type == EntryType.income) {
        for (final LedgerMember member in widget.members) {
          balances.putIfAbsent(member.id, () => 0);
        }
      }
      for (final MapEntry<int?, double> fund in balances.entries) {
        if (widget.type == EntryType.expense &&
            fund.key != null &&
            widget.selectedMemberIds.isEmpty) {
          continue;
        }
        final LedgerMember? member = fund.key == null
            ? null
            : widget.members
                  .where((LedgerMember item) => item.id == fund.key)
                  .firstOrNull;
        final double available =
            account.kind == AccountKind.credit &&
                fund.key == null &&
                widget.type == EntryType.expense
            ? account.availableToSpend
            : fund.value;
        if (widget.type == EntryType.expense && available <= 0) continue;
        result.add(
          _FundingSource(
            account: account,
            memberId: fund.key,
            memberName: member?.name,
            available: available,
          ),
        );
      }
    }
    return result;
  }

  double get _allocated => _rows.fold<double>(
    0,
    (double sum, _FundingDraft row) => sum + row.amount,
  );

  double get _remaining => widget.total - _allocated;

  Future<void> _addOrReplace({int? index}) async {
    final _FundingSource? source = await showModalBottomSheet<_FundingSource>(
      context: context,
      useSafeArea: true,
      builder: (BuildContext context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 16),
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Text(
              '选择资金来源',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          ..._sources().map(
            (_FundingSource item) => ListTile(
              leading: CircleAvatar(
                child: Icon(_entryAccountIcon(item.account.icon)),
              ),
              title: Text(item.label),
              subtitle: widget.type == EntryType.expense
                  ? Text('可用 ¥${item.available.toStringAsFixed(2)}')
                  : const Text('收入将计入这部分资金'),
              onTap: () => Navigator.pop(context, item),
            ),
          ),
        ],
      ),
    );
    if (source == null || !mounted) return;
    setState(() {
      if (index == null) {
        final double suggested = widget.type == EntryType.expense
            ? _remaining.clamp(0, source.available).toDouble()
            : _remaining.clamp(0, widget.total).toDouble();
        _rows.add(_FundingDraft(source, suggested));
      } else {
        _rows[index].source = source;
      }
    });
  }

  void _autoFill() {
    for (final _FundingDraft row in _rows) {
      row.dispose();
    }
    _rows.clear();
    double remaining = widget.total;
    for (final _FundingSource source in _sources()) {
      if (source.memberId != null &&
          !widget.selectedMemberIds.contains(source.memberId)) {
        continue;
      }
      final double amount = remaining.clamp(0, source.available).toDouble();
      if (amount <= 0) continue;
      _rows.add(_FundingDraft(source, amount));
      remaining -= amount;
      if (remaining <= .004) break;
    }
    setState(() {});
  }

  List<EntryFunding> _result() {
    final Map<(int, int?), double> grouped = <(int, int?), double>{};
    for (final _FundingDraft row in _rows) {
      if (row.amount <= 0) continue;
      final (int, int?) key = (row.source.account.id, row.source.memberId);
      grouped.update(
        key,
        (double value) => value + row.amount,
        ifAbsent: () => row.amount,
      );
    }
    return grouped.entries
        .map(
          (MapEntry<(int, int?), double> item) => EntryFunding(
            accountId: item.key.$1,
            memberId: item.key.$2,
            amount: item.value,
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final bool withinAvailable =
        widget.type != EntryType.expense ||
        _rows.every(
          (_FundingDraft row) => row.amount - row.source.available <= .004,
        );
    final bool complete =
        _remaining.abs() < .005 && _rows.isNotEmpty && withinAvailable;
    return FractionallySizedBox(
      heightFactor: .9,
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
                Expanded(
                  child: Text(
                    widget.type == EntryType.expense ? '组合付款' : '收入归属',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: complete
                      ? () => Navigator.pop(context, _result())
                      : null,
                  child: const Text('完成'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _FundingMetric(label: '账目金额', value: widget.total),
                  ),
                  Expanded(
                    child: _FundingMetric(label: '已分配', value: _allocated),
                  ),
                  Expanded(
                    child: _FundingMetric(
                      label: '还需分配',
                      value: _remaining,
                      warning: !complete,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.type == EntryType.expense)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: _autoFill,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('按账户顺序自动补足'),
              ),
            ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: complete
                ? const SizedBox(height: 8, key: ValueKey<String>('complete'))
                : Padding(
                    key: const ValueKey<String>('remaining'),
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                    child: Text(
                      !withinAvailable
                          ? '有一项超过可用资金'
                          : _remaining > 0
                          ? '还差 ¥${_remaining.toStringAsFixed(2)}'
                          : '已多分配 ¥${(-_remaining).toStringAsFixed(2)}',
                      style: TextStyle(
                        color: AppTheme.ledgerOf(context).expense,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              itemCount: _rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (BuildContext context, int index) {
                final _FundingDraft row = _rows[index];
                return Material(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _addOrReplace(index: index),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    row.source.label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (widget.type == EntryType.expense)
                                    Text(
                                      '可用 ¥${row.source.available.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Color(0xFF8A9099),
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 104,
                          child: TextField(
                            controller: row.controller,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textAlign: TextAlign.end,
                            decoration: const InputDecoration(
                              prefixText: '¥ ',
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        IconButton(
                          tooltip: '移除',
                          onPressed: () => setState(() {
                            _rows.removeAt(index).dispose();
                          }),
                          icon: const Icon(Icons.close, size: 20),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: OutlinedButton.icon(
              onPressed: _remaining > .004 ? _addOrReplace : null,
              icon: const Icon(Icons.add),
              label: const Text('添加资金来源'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FundingMetric extends StatelessWidget {
  const _FundingMetric({
    required this.label,
    required this.value,
    this.warning = false,
  });

  final String label;
  final double value;
  final bool warning;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        label,
        style: const TextStyle(fontSize: 11, color: Color(0xFF8A9099)),
      ),
      const SizedBox(height: 3),
      Text(
        '¥${value.abs().toStringAsFixed(2)}',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: warning ? AppTheme.ledgerOf(context).expense : null,
        ),
      ),
    ],
  );
}

class _AccountPickerSheet extends StatefulWidget {
  const _AccountPickerSheet({
    required this.title,
    required this.accounts,
    required this.selectedId,
    this.excludedId,
  });

  final String title;
  final List<LedgerAccount> accounts;
  final int? selectedId;
  final int? excludedId;

  @override
  State<_AccountPickerSheet> createState() => _AccountPickerSheetState();
}

class _AccountPickerSheetState extends State<_AccountPickerSheet> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String query = _searchController.text.trim().toLowerCase();
    final List<LedgerAccount> filtered = widget.accounts
        .where((account) => account.name.toLowerCase().contains(query))
        .toList();
    final double height = (MediaQuery.sizeOf(context).height * .72)
        .clamp(360.0, 620.0)
        .toDouble();
    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: height,
        child: Column(
          children: <Widget>[
            _PickerSheetHeader(
              title: widget.title,
              onClose: () => Navigator.pop(context),
            ),
            _PickerSearchField(
              controller: _searchController,
              hintText: '搜索账户',
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: filtered.isEmpty
                  ? const _PickerEmpty(message: '没有匹配的账户')
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: filtered.length,
                      itemBuilder: (BuildContext context, int index) {
                        final LedgerAccount account = filtered[index];
                        final bool excluded = account.id == widget.excludedId;
                        return _SelectorRow(
                          icon: _entryAccountIcon(account.icon),
                          title: account.name,
                          subtitle: excluded
                              ? '已选为另一个转账账户'
                              : '余额 ¥${account.balance.toStringAsFixed(2)}',
                          selected: account.id == widget.selectedId,
                          enabled: !excluded,
                          onTap: () => Navigator.pop(context, account.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberPickerSheet extends StatefulWidget {
  const _MemberPickerSheet({
    required this.title,
    required this.members,
    required this.selectedIds,
  });

  final String title;
  final List<LedgerMember> members;
  final Set<int> selectedIds;

  @override
  State<_MemberPickerSheet> createState() => _MemberPickerSheetState();
}

class _MemberPickerSheetState extends State<_MemberPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  late final Set<int> _selectedIds;

  @override
  void initState() {
    super.initState();
    final Set<int> activeIds = widget.members
        .map((member) => member.id)
        .toSet();
    _selectedIds = widget.selectedIds.intersection(activeIds);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String query = _searchController.text.trim().toLowerCase();
    final List<LedgerMember> filtered = widget.members
        .where((member) => member.name.toLowerCase().contains(query))
        .toList();
    final bool allSelected =
        widget.members.isNotEmpty &&
        widget.members.every((member) => _selectedIds.contains(member.id));
    final double height = (MediaQuery.sizeOf(context).height * .78)
        .clamp(400.0, 680.0)
        .toDouble();
    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: height,
        child: Column(
          children: <Widget>[
            _PickerSheetHeader(
              title: widget.title,
              onClose: () => Navigator.pop(context),
              action: TextButton(
                onPressed: () => Navigator.pop(context, _selectedIds),
                child: Text(
                  _selectedIds.isEmpty ? '完成' : '完成 (${_selectedIds.length})',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            _PickerSearchField(
              controller: _searchController,
              hintText: '搜索成员',
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: <Widget>[
                  _SelectorRow(
                    icon: Icons.block_outlined,
                    title: '无选择',
                    selected: _selectedIds.isEmpty,
                    onTap: () => setState(_selectedIds.clear),
                  ),
                  _SelectorRow(
                    icon: Icons.people_outline,
                    title: '全体成员',
                    subtitle: widget.members.isEmpty
                        ? '暂无可用成员'
                        : '共 ${widget.members.length} 人',
                    selected: allSelected,
                    enabled: widget.members.isNotEmpty,
                    onTap: () => setState(() {
                      if (allSelected) {
                        _selectedIds.clear();
                      } else {
                        _selectedIds
                          ..clear()
                          ..addAll(widget.members.map((member) => member.id));
                      }
                    }),
                  ),
                  if (filtered.isEmpty && query.isNotEmpty)
                    const SizedBox(
                      height: 120,
                      child: _PickerEmpty(message: '没有匹配的成员'),
                    )
                  else
                    ...filtered.map(
                      (LedgerMember member) => _SelectorRow(
                        color: Color(member.colorValue),
                        title: member.name,
                        selected: _selectedIds.contains(member.id),
                        onTap: () => setState(() {
                          if (!_selectedIds.add(member.id)) {
                            _selectedIds.remove(member.id);
                          }
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerSheetHeader extends StatelessWidget {
  const _PickerSheetHeader({
    required this.title,
    required this.onClose,
    this.action,
  });

  final String title;
  final VoidCallback onClose;
  final Widget? action;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: Row(
      children: <Widget>[
        SizedBox(
          width: 64,
          child: Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: '关闭',
              onPressed: onClose,
              icon: const Icon(Icons.close),
            ),
          ),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(width: 64, child: action),
      ],
    ),
  );
}

class _PickerSearchField extends StatelessWidget {
  const _PickerSearchField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
    child: TextField(
      controller: controller,
      autofocus: false,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: '清空',
                onPressed: () {
                  controller.clear();
                  onChanged();
                },
                icon: const Icon(Icons.close, size: 18),
              ),
        isDense: true,
      ),
      onChanged: (_) => onChanged(),
    ),
  );
}

class _PickerEmpty extends StatelessWidget {
  const _PickerEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
    this.subtitle,
    this.enabled = true,
  });
  final String title;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? color;
  final String? subtitle;
  final bool enabled;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    enabled: enabled,
    onTap: enabled ? onTap : null,
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
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: selected
        ? Icon(
            Icons.check,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          )
        : const SizedBox(width: 20),
  );
}

IconData _entryAccountIcon(String value) => switch (value) {
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

String _formatDateTime(DateTime value) =>
    '${value.year}年${value.month.toString().padLeft(2, '0')}月${value.day.toString().padLeft(2, '0')}日 '
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

const Map<String, List<String>> categoryIconGroups = <String, List<String>>{
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
    'festival',
    'piano',
    'mic',
    'headphones',
    'puzzle',
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
    'tea',
    'lunch',
    'dinner',
    'ramen',
    'bar',
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
    'monitor_heart',
    'blood',
    'accessible',
    'clean_hands',
    'health',
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
    'history_edu',
    'quiz',
    'draw',
    'translate',
    'architecture',
    'backpack',
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
    'walk',
    'scooter',
    'gas_station',
    'toll',
    'traffic',
    'map',
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
    'diamond',
    'mall',
    'sell',
    'inventory',
    'redeem',
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
    'lightbulb',
    'wifi',
    'cleaning',
    'trash',
    'delivery',
    'bed',
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
    'shower',
    'dry_cleaning',
    'face',
    'hiking',
    'sleep',
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
    'pregnant',
    'crib',
    'stroller',
    'diversity',
    'home_health',
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
    'badge',
    'task',
    'event_note',
    'attachment',
    'cloud_upload',
    'support',
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
    'paid',
    'price_check',
    'request_quote',
    'discount',
    'atm',
    'donate',
  ],
  '旅行': <String>[
    'hotel',
    'luggage',
    'beach',
    'explore',
    'attractions',
    'museum',
    'travel_explore',
    'landscape',
    'camping',
    'tour',
  ],
  '数码': <String>[
    'smartphone',
    'laptop',
    'tablet',
    'headphones',
    'mouse',
    'keyboard',
    'smartwatch',
    'router',
    'memory',
    'cable',
  ],
  '社交': <String>[
    'chat',
    'groups',
    'contacts',
    'celebration',
    'handshake',
    'forum',
    'send',
    'call',
    'video_call',
    'mood',
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
    'help',
    'warning',
    'info',
    'bookmark',
    'place',
    'schedule',
    'qr_code',
  ],
};

IconData _categoryIcon(String? key, String category) =>
    key == null ? _categoryIconByName(category) : categoryIconFromKey(key);

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

IconData categoryIconFromKey(String key) => switch (key) {
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
  'laundry' => Icons.local_laundry_service_outlined,
  'water' => Icons.water_drop_outlined,
  'festival' => Icons.festival_outlined,
  'piano' => Icons.piano_outlined,
  'mic' => Icons.mic_none,
  'headphones' => Icons.headphones_outlined,
  'puzzle' => Icons.extension_outlined,
  'tea' => Icons.emoji_food_beverage_outlined,
  'lunch' => Icons.lunch_dining_outlined,
  'dinner' => Icons.dinner_dining_outlined,
  'ramen' => Icons.ramen_dining_outlined,
  'bar' => Icons.local_bar_outlined,
  'monitor_heart' => Icons.monitor_heart_outlined,
  'blood' => Icons.bloodtype_outlined,
  'accessible' => Icons.accessible_outlined,
  'clean_hands' => Icons.clean_hands_outlined,
  'health' => Icons.health_and_safety_outlined,
  'history_edu' => Icons.history_edu_outlined,
  'quiz' => Icons.quiz_outlined,
  'draw' => Icons.draw_outlined,
  'translate' => Icons.translate,
  'architecture' => Icons.architecture_outlined,
  'backpack' => Icons.backpack_outlined,
  'walk' => Icons.directions_walk_outlined,
  'scooter' => Icons.electric_scooter_outlined,
  'gas_station' => Icons.local_gas_station_outlined,
  'toll' => Icons.toll_outlined,
  'traffic' => Icons.traffic_outlined,
  'map' => Icons.map_outlined,
  'diamond' => Icons.diamond_outlined,
  'mall' => Icons.local_mall_outlined,
  'sell' => Icons.sell_outlined,
  'inventory' => Icons.inventory_2_outlined,
  'redeem' => Icons.redeem_outlined,
  'lightbulb' => Icons.lightbulb_outline,
  'wifi' => Icons.wifi,
  'cleaning' => Icons.cleaning_services_outlined,
  'trash' => Icons.delete_outline,
  'delivery' => Icons.local_shipping_outlined,
  'bed' => Icons.bed_outlined,
  'shower' => Icons.shower_outlined,
  'dry_cleaning' => Icons.dry_cleaning_outlined,
  'face' => Icons.face_outlined,
  'hiking' => Icons.hiking,
  'sleep' => Icons.bedtime_outlined,
  'pregnant' => Icons.pregnant_woman,
  'crib' => Icons.crib_outlined,
  'stroller' => Icons.stroller_outlined,
  'diversity' => Icons.diversity_1_outlined,
  'home_health' => Icons.medical_services_outlined,
  'badge' => Icons.badge_outlined,
  'task' => Icons.task_alt,
  'event_note' => Icons.event_note_outlined,
  'attachment' => Icons.attach_file,
  'cloud_upload' => Icons.cloud_upload_outlined,
  'support' => Icons.support_agent,
  'paid' => Icons.paid_outlined,
  'price_check' => Icons.price_check,
  'request_quote' => Icons.request_quote_outlined,
  'discount' => Icons.discount_outlined,
  'atm' => Icons.local_atm_outlined,
  'donate' => Icons.volunteer_activism_outlined,
  'luggage' => Icons.luggage_outlined,
  'beach' => Icons.beach_access_outlined,
  'explore' => Icons.explore_outlined,
  'attractions' => Icons.attractions_outlined,
  'museum' => Icons.museum_outlined,
  'travel_explore' => Icons.travel_explore,
  'landscape' => Icons.landscape_outlined,
  'camping' => Icons.forest_outlined,
  'tour' => Icons.tour_outlined,
  'smartphone' => Icons.smartphone,
  'laptop' => Icons.laptop_mac,
  'tablet' => Icons.tablet_mac,
  'mouse' => Icons.mouse_outlined,
  'keyboard' => Icons.keyboard_outlined,
  'smartwatch' => Icons.watch_outlined,
  'router' => Icons.router,
  'memory' => Icons.memory,
  'cable' => Icons.cable,
  'chat' => Icons.chat_bubble_outline,
  'groups' => Icons.groups_outlined,
  'contacts' => Icons.contacts_outlined,
  'celebration' => Icons.celebration_outlined,
  'handshake' => Icons.handshake_outlined,
  'forum' => Icons.forum_outlined,
  'send' => Icons.send_outlined,
  'call' => Icons.call_outlined,
  'video_call' => Icons.video_call_outlined,
  'mood' => Icons.mood_outlined,
  'help' => Icons.help_outline,
  'warning' => Icons.warning_amber,
  'info' => Icons.info_outline,
  'bookmark' => Icons.bookmark_border,
  'place' => Icons.place_outlined,
  'schedule' => Icons.schedule,
  'qr_code' => Icons.qr_code_2,
  'tag' => Icons.label_outline,
  _ => Icons.sell_outlined,
};
