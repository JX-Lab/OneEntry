import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/ledger_controller.dart';
import '../../models/ledger_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/swipe_action_tile.dart';
import '../entry/entry_detail_sheet.dart';
import 'period_picker_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    required this.controller,
    required this.onAddEntry,
    required this.onEditEntry,
    required this.onDeleteEntry,
    required this.onOpenStatistics,
    required this.onOpenSettings,
    required this.onOpenAccounts,
    required this.onOpenMembers,
    required this.onOpenBudget,
    super.key,
  });

  final LedgerController controller;
  final VoidCallback onAddEntry;
  final ValueChanged<LedgerEntry> onEditEntry;
  final ValueChanged<LedgerEntry> onDeleteEntry;
  final VoidCallback onOpenStatistics;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenAccounts;
  final VoidCallback onOpenMembers;
  final VoidCallback onOpenBudget;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Set<int> _selectedEntryIds = <int>{};
  int? _year = DateTime.now().year;
  int? _month = DateTime.now().month;
  int? _day;
  bool _searching = false;
  bool _selecting = false;
  bool _showEdgeButton = false;
  bool _edgeToBottom = true;
  double _lastScrollOffset = 0;
  Timer? _edgeButtonTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _edgeButtonTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final String query = _searchController.text.trim().toLowerCase();
        final List<LedgerEntry> periodEntries = widget.controller.entries
            .where(
              (LedgerEntry entry) =>
                  (_year == null || entry.occurredAt.year == _year) &&
                  (_month == null || entry.occurredAt.month == _month) &&
                  (_day == null || entry.occurredAt.day == _day),
            )
            .toList();
        final List<LedgerEntry> entries = periodEntries.where((
          LedgerEntry entry,
        ) {
          if (query.isEmpty) return true;
          final String members = entry.memberIds
              .map(
                (int id) => widget.controller.members
                    .where((member) => member.id == id)
                    .map((member) => member.name)
                    .join(),
              )
              .join(' ');
          return '${entry.category} ${entry.note} $members ${entry.occurredAt.year}-${entry.occurredAt.month}-${entry.occurredAt.day}'
              .toLowerCase()
              .contains(query);
        }).toList();
        final double income = periodEntries
            .where((entry) => entry.type == EntryType.income)
            .fold(0.0, (sum, entry) => sum + entry.amount);
        final double expense = periodEntries
            .where((entry) => entry.type == EntryType.expense)
            .fold(0.0, (sum, entry) => sum + entry.amount);
        return Scaffold(
          appBar: AppBar(
            centerTitle: true,
            leading: _selecting
                ? IconButton(
                    onPressed: _exitSelection,
                    icon: const Icon(Icons.close),
                  )
                : null,
            title: _selecting
                ? Text('已选 ${_selectedEntryIds.length} 笔')
                : _searching
                ? TextField(
                    controller: _searchController,
                    autofocus: false,
                    decoration: const InputDecoration(
                      hintText: '搜索标签、成员、备注或日期',
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  )
                : InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _openPeriodPicker,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            _periodLabel(),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_drop_down, size: 18),
                        ],
                      ),
                    ),
                  ),
            actions: <Widget>[
              if (!_selecting) ...<Widget>[
                IconButton(
                  tooltip: _searching ? '关闭搜索' : '搜索',
                  onPressed: () => setState(() {
                    _searching = !_searching;
                    if (!_searching) _searchController.clear();
                  }),
                  icon: Icon(_searching ? Icons.close : Icons.search),
                ),
                IconButton(
                  tooltip: '设置',
                  onPressed: widget.onOpenSettings,
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ],
          ),
          body: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 92),
            children: <Widget>[
              _SummaryCard(
                income: income,
                expense: expense,
                spent: expense,
                budget: widget.controller.monthlyBudget,
                showBudget: _year != null && _month != null,
                onBudgetTap: widget.onOpenBudget,
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  if (widget.controller.multiEnabled) ...<Widget>[
                    Expanded(
                      child: _QuickButton(
                        icon: Icons.people_outline,
                        label: '成员',
                        onTap: widget.onOpenMembers,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: _QuickButton(
                      icon: Icons.account_balance_wallet_outlined,
                      label: '账户',
                      onTap: widget.onOpenAccounts,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickButton(
                      icon: Icons.insights_outlined,
                      label: '统计',
                      onTap: widget.onOpenStatistics,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 72),
                  child: Center(child: Text('当前时间范围还没有匹配的账目')),
                )
              else
                ..._groupedEntries(entries),
            ],
          ),
          bottomNavigationBar: _selecting
              ? _selectionBar(entries)
              : SafeArea(
                  minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(28),
                    onTap: widget.onAddEntry,
                    child: Ink(
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: <Color>[AppTheme.green, AppTheme.greenLight],
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x420EB078),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(Icons.edit_outlined, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            '记一笔',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          floatingActionButton: _showEdgeButton
              ? FloatingActionButton.small(
                  heroTag: 'home-edge-scroll',
                  onPressed: _jumpToEdge,
                  child: Icon(
                    _edgeToBottom
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                  ),
                )
              : null,
        );
      },
    );
  }

  Future<void> _openPeriodPicker() async {
    final PeriodSelection? selected =
        await showModalBottomSheet<PeriodSelection>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (BuildContext context) => PeriodPickerSheet(
            allowUnselectedYear: true,
            initial: (year: _year, month: _month, day: _day),
          ),
        );
    if (selected == null) return;
    setState(() {
      _year = selected.year;
      _month = selected.month;
      _day = selected.day;
    });
  }

  String _periodLabel() {
    final List<String> parts = <String>[
      if (_year != null) '${_year}年',
      if (_month != null) '${_month}月',
      if (_day != null) '${_day}日',
    ];
    return parts.isEmpty ? '全部' : parts.join();
  }

  List<Widget> _groupedEntries(List<LedgerEntry> entries) {
    final Map<String, List<LedgerEntry>> groups = <String, List<LedgerEntry>>{};
    for (final LedgerEntry entry in entries) {
      final String key =
          '${entry.occurredAt.year}-${entry.occurredAt.month}-${entry.occurredAt.day}';
      groups.putIfAbsent(key, () => <LedgerEntry>[]).add(entry);
    }
    return groups.entries
        .expand(
          (entry) => <Widget>[
            Builder(
              builder: (BuildContext context) {
                final List<LedgerEntry> values = entry.value;
                final DateTime date = values.first.occurredAt;
                final double income = values
                    .where((item) => item.type == EntryType.income)
                    .fold(0, (sum, item) => sum + item.amount);
                final double expense = values
                    .where((item) => item.type == EntryType.expense)
                    .fold(0, (sum, item) => sum + item.amount);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
                  child: Row(
                    children: <Widget>[
                      if (_selecting)
                        SizedBox(
                          width: 30,
                          height: 30,
                          child: Checkbox(
                            value: values.every(
                              (item) => _selectedEntryIds.contains(item.id),
                            ),
                            onChanged: (_) => _toggleEntries(values),
                          ),
                        ),
                      Text(
                        '${_year == null ? '${date.year}年' : ''}${date.month}月${date.day}日 ${_weekday(date.weekday)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8A9099),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      if (income > 0)
                        Text(
                          '收 ${income.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8A9099),
                          ),
                        ),
                      if (income > 0 && expense > 0) const SizedBox(width: 8),
                      if (expense > 0)
                        Text(
                          '支 ${expense.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8A9099),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            ...entry.value.map(
              (LedgerEntry item) => _EntryTile(
                entry: item,
                controller: widget.controller,
                onEdit: () => widget.onEditEntry(item),
                onDelete: () => widget.onDeleteEntry(item),
                selectionMode: _selecting,
                selected: _selectedEntryIds.contains(item.id),
                onToggleSelection: () => _toggleEntry(item),
                onEnterSelection: () => _enterSelection(item),
              ),
            ),
          ],
        )
        .toList();
  }

  Widget _selectionBar(List<LedgerEntry> periodEntries) {
    final bool allSelected =
        periodEntries.isNotEmpty &&
        periodEntries.every((entry) => _selectedEntryIds.contains(entry.id));
    final bool hasSelection = _selectedEntryIds.isNotEmpty;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 12,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        child: Row(
          children: <Widget>[
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _toggleAll(periodEntries),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Checkbox(
                      value: allSelected,
                      onChanged: (_) => _toggleAll(periodEntries),
                    ),
                    const Text('全选'),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: '筛选选择',
              onPressed: () => _showSelectionFilter(periodEntries),
              icon: const Icon(Icons.filter_alt_outlined),
            ),
            const Spacer(),
            FilledButton.tonal(
              onPressed: hasSelection ? _batchEdit : null,
              child: const Text('编辑'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: hasSelection ? _batchDelete : null,
              style: FilledButton.styleFrom(backgroundColor: AppTheme.expense),
              child: const Text('删除'),
            ),
          ],
        ),
      ),
    );
  }

  void _enterSelection(LedgerEntry entry) => setState(() {
    _selecting = true;
    _selectedEntryIds.add(entry.id);
  });

  void _exitSelection() => setState(() {
    _selecting = false;
    _selectedEntryIds.clear();
  });

  void _toggleEntry(LedgerEntry entry) => setState(() {
    if (!_selecting) _selecting = true;
    if (!_selectedEntryIds.add(entry.id)) _selectedEntryIds.remove(entry.id);
  });

  void _toggleEntries(List<LedgerEntry> entries) => setState(() {
    final bool all = entries.every(
      (entry) => _selectedEntryIds.contains(entry.id),
    );
    if (all) {
      _selectedEntryIds.removeAll(entries.map((entry) => entry.id));
    } else {
      _selectedEntryIds.addAll(entries.map((entry) => entry.id));
    }
  });

  void _toggleAll(List<LedgerEntry> entries) => setState(() {
    final bool all =
        entries.isNotEmpty &&
        entries.every((entry) => _selectedEntryIds.contains(entry.id));
    if (all) {
      _selectedEntryIds.removeAll(entries.map((entry) => entry.id));
    } else {
      _selectedEntryIds.addAll(entries.map((entry) => entry.id));
    }
  });

  List<LedgerEntry> get _selectedEntries => widget.controller.entries
      .where((entry) => _selectedEntryIds.contains(entry.id))
      .toList();

  Future<void> _showSelectionFilter(List<LedgerEntry> periodEntries) async {
    final TextEditingController startController = TextEditingController();
    final TextEditingController endController = TextEditingController();
    final Set<String> categories = <String>{};
    final Set<int> members = <int>{};
    final Set<int> accounts = <int>{};
    bool includeNoMember = false;
    bool includeNoNote = false;
    final List<String> categoryOptions =
        periodEntries.map((entry) => entry.category).toSet().toList()..sort();
    final bool? apply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter update) =>
            FractionallySizedBox(
              heightFactor: .86,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  children: <Widget>[
                    _SheetHeader(
                      title: '筛选账目',
                      onCancel: () => Navigator.pop(context, false),
                      onConfirm: () => Navigator.pop(context, true),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                        children: <Widget>[
                          const _FilterTitle('按时间'),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: _DateInput(
                                  label: '开始日期',
                                  controller: startController,
                                  onPick: () => _pickDateInto(startController),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _DateInput(
                                  label: '结束日期',
                                  controller: endController,
                                  onPick: () => _pickDateInto(endController),
                                ),
                              ),
                            ],
                          ),
                          const _FilterTitle('按标签分类 · 可多选'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: categoryOptions
                                .map(
                                  (category) => FilterChip(
                                    label: Text(category),
                                    selected: categories.contains(category),
                                    onSelected: (_) => update(() {
                                      if (!categories.add(category)) {
                                        categories.remove(category);
                                      }
                                    }),
                                  ),
                                )
                                .toList(),
                          ),
                          const _FilterTitle('按账户 · 可多选'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: widget.controller.accounts
                                .map(
                                  (account) => FilterChip(
                                    label: Text(account.name),
                                    selected: accounts.contains(account.id),
                                    onSelected: (_) => update(() {
                                      if (!accounts.add(account.id)) {
                                        accounts.remove(account.id);
                                      }
                                    }),
                                  ),
                                )
                                .toList(),
                          ),
                          const _FilterTitle('按成员 · 可多选'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: <Widget>[
                              FilterChip(
                                label: const Text('无指定'),
                                selected: includeNoMember,
                                onSelected: (_) => update(
                                  () => includeNoMember = !includeNoMember,
                                ),
                              ),
                              ...widget.controller.members
                                  .where((member) => !member.archived)
                                  .map(
                                    (member) => FilterChip(
                                      avatar: CircleAvatar(
                                        backgroundColor: Color(
                                          member.colorValue,
                                        ),
                                      ),
                                      label: Text(member.name),
                                      selected: members.contains(member.id),
                                      onSelected: (_) => update(() {
                                        if (!members.add(member.id)) {
                                          members.remove(member.id);
                                        }
                                      }),
                                    ),
                                  ),
                            ],
                          ),
                          const _FilterTitle('按备注'),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FilterChip(
                              label: const Text('无备注'),
                              selected: includeNoNote,
                              onSelected: (_) =>
                                  update(() => includeNoNote = !includeNoNote),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ),
    );
    if (apply != true) return;
    final DateTime? start = _parseDate(startController.text);
    final DateTime? end = _parseDate(endController.text);
    if ((startController.text.trim().isNotEmpty && start == null) ||
        (endController.text.trim().isNotEmpty && end == null)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('日期格式应为 YYYY-MM-DD')));
      }
      return;
    }
    final List<int> selected = periodEntries
        .where((entry) {
          final DateTime day = DateTime(
            entry.occurredAt.year,
            entry.occurredAt.month,
            entry.occurredAt.day,
          );
          if (start != null && day.isBefore(start)) return false;
          if (end != null && day.isAfter(end)) return false;
          if (categories.isNotEmpty && !categories.contains(entry.category)) {
            return false;
          }
          if (accounts.isNotEmpty && !accounts.contains(entry.accountId)) {
            return false;
          }
          if (members.isNotEmpty || includeNoMember) {
            final bool memberMatched = entry.memberIds.any(members.contains);
            final bool noMemberMatched =
                includeNoMember && entry.memberIds.isEmpty;
            if (!memberMatched && !noMemberMatched) return false;
          }
          if (includeNoNote && entry.note.trim().isNotEmpty) return false;
          return true;
        })
        .map((entry) => entry.id)
        .toList();
    setState(() {
      _selectedEntryIds
        ..clear()
        ..addAll(selected);
    });
  }

  Future<void> _pickDateInto(TextEditingController controller) async {
    final DateTime? value = await showDatePicker(
      context: context,
      firstDate: DateTime(1970),
      lastDate: DateTime.now(),
      initialDate: _parseDate(controller.text) ?? DateTime.now(),
    );
    if (value != null) controller.text = _dateKey(value);
  }

  Future<void> _batchEdit() async {
    final List<LedgerEntry> entries = _selectedEntries;
    if (entries.isEmpty) return;
    bool changeAccount = false;
    bool changeMembers = false;
    bool changeNote = false;
    final List<LedgerAccount> accounts = widget.controller.accounts
        .where((account) => !account.archived)
        .toList();
    final List<LedgerMember> activeMembers = widget.controller.members
        .where((member) => !member.archived)
        .toList();
    int? accountId = accounts.isEmpty ? null : accounts.first.id;
    final Set<int> memberIds = <int>{};
    final TextEditingController noteController = TextEditingController();
    final bool? save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter update) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _SheetHeader(
                  title: '批量编辑 ${entries.length} 笔',
                  onCancel: () => Navigator.pop(context, false),
                  onConfirm: () => Navigator.pop(context, true),
                ),
                CheckboxListTile(
                  title: const Text('统一账户'),
                  subtitle: const Text('所有选中收支账目都替换为下方账户'),
                  value: changeAccount,
                  onChanged: (value) =>
                      update(() => changeAccount = value ?? false),
                ),
                if (changeAccount && accounts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DropdownButtonFormField<int>(
                      initialValue: accountId,
                      decoration: const InputDecoration(labelText: '账户'),
                      items: accounts
                          .map(
                            (account) => DropdownMenuItem<int>(
                              value: account.id,
                              child: Text(account.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => accountId = value,
                    ),
                  ),
                CheckboxListTile(
                  title: const Text('统一成员'),
                  subtitle: const Text('所有选中账目都替换为下方成员'),
                  value: changeMembers,
                  onChanged: (value) =>
                      update(() => changeMembers = value ?? false),
                ),
                if (changeMembers)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      children: <Widget>[
                        FilterChip(
                          label: const Text('无指定'),
                          selected: memberIds.isEmpty,
                          onSelected: (_) => update(memberIds.clear),
                        ),
                        FilterChip(
                          label: const Text('全体成员'),
                          selected:
                              activeMembers.isNotEmpty &&
                              memberIds.length == activeMembers.length &&
                              activeMembers.every(
                                (member) => memberIds.contains(member.id),
                              ),
                          onSelected: (_) => update(() {
                            memberIds
                              ..clear()
                              ..addAll(
                                activeMembers.map((member) => member.id),
                              );
                          }),
                        ),
                        ...activeMembers.map(
                          (member) => FilterChip(
                            label: Text(member.name),
                            selected: memberIds.contains(member.id),
                            onSelected: (_) => update(() {
                              if (!memberIds.add(member.id)) {
                                memberIds.remove(member.id);
                              }
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                CheckboxListTile(
                  title: const Text('统一备注'),
                  subtitle: const Text('所有选中账目都替换为输入内容'),
                  value: changeNote,
                  onChanged: (value) =>
                      update(() => changeNote = value ?? false),
                ),
                if (changeNote)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        TextField(
                          controller: noteController,
                          decoration: const InputDecoration(
                            labelText: '统一备注',
                            hintText: '输入要替换成的备注',
                          ),
                        ),
                        TextButton.icon(
                          onPressed: noteController.clear,
                          icon: const Icon(Icons.clear, size: 17),
                          label: const Text('设为无备注'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (save != true) return;
    if (!changeAccount && !changeMembers && !changeNote) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请至少选择一项要修改的内容')));
      }
      return;
    }
    await widget.controller.batchUpdateEntries(
      entries,
      changeAccount: changeAccount,
      accountId: accountId,
      changeMembers: changeMembers,
      memberIds: memberIds.toList(),
      changeNote: changeNote,
      note: noteController.text.trim(),
    );
    if (mounted) {
      _exitSelection();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已修改 ${entries.length} 笔账目')));
    }
  }

  Future<void> _batchDelete() async {
    final List<LedgerEntry> entries = _selectedEntries;
    if (entries.isEmpty) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('删除 ${entries.length} 笔账目？'),
        content: const Text('账户余额会同步恢复，此操作无法撤销。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.expense),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.controller.deleteEntries(entries);
    if (mounted) {
      _exitSelection();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已删除 ${entries.length} 笔账目')));
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final double offset = _scrollController.offset;
    final double delta = offset - _lastScrollOffset;
    _lastScrollOffset = offset;
    if (delta.abs() < 4) return;
    final bool down = delta > 0;
    final bool available = down
        ? _scrollController.position.extentAfter > 24
        : _scrollController.position.extentBefore > 24;
    _edgeButtonTimer?.cancel();
    if (mounted) {
      setState(() {
        _edgeToBottom = down;
        _showEdgeButton = available;
      });
    }
    _edgeButtonTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _showEdgeButton = false);
    });
  }

  void _jumpToEdge() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _edgeToBottom ? _scrollController.position.maxScrollExtent : 0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
    setState(() => _showEdgeButton = false);
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.onCancel,
    required this.onConfirm,
  });

  final String title;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    child: Row(
      children: <Widget>[
        TextButton(onPressed: onCancel, child: const Text('取消')),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        TextButton(onPressed: onConfirm, child: const Text('确定')),
      ],
    ),
  );
}

class _FilterTitle extends StatelessWidget {
  const _FilterTitle(this.value);
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
    child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
  );
}

class _DateInput extends StatelessWidget {
  const _DateInput({
    required this.label,
    required this.controller,
    required this.onPick,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: TextInputType.datetime,
    decoration: InputDecoration(
      labelText: label,
      hintText: 'YYYY-MM-DD',
      suffixIcon: IconButton(
        onPressed: onPick,
        icon: const Icon(Icons.calendar_month_outlined),
      ),
    ),
  );
}

DateTime? _parseDate(String text) {
  final RegExpMatch? match = RegExp(
    r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$',
  ).firstMatch(text.trim());
  if (match == null) return null;
  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}

String _dateKey(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.income,
    required this.expense,
    required this.spent,
    required this.budget,
    required this.showBudget,
    required this.onBudgetTap,
  });
  final double income;
  final double expense;
  final double spent;
  final double budget;
  final bool showBudget;
  final VoidCallback onBudgetTap;

  @override
  Widget build(BuildContext context) {
    final bool over = spent > budget;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[AppTheme.green, AppTheme.greenLight],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x330EB078),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _SummaryValue(label: '↓ 收入', value: income),
                ),
                Container(width: .5, height: 54, color: Colors.white38),
                Expanded(
                  child: _SummaryValue(label: '↑ 支出', value: expense),
                ),
              ],
            ),
          ),
          if (showBudget)
            Material(
              color: Colors.black.withValues(alpha: .14),
              child: InkWell(
                onTap: onBudgetTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 9,
                  ),
                  child: Row(
                    children: <Widget>[
                      Text(
                        '本月预算 ¥${budget.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        over
                            ? '超支 ¥${(spent - budget).toStringAsFixed(2)}'
                            : '剩余 ¥${(budget - spent).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: over ? const Color(0xFFFFD5D5) : Colors.white,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.toStringAsFixed(2),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Column(
          children: <Widget>[
            Icon(icon, size: 21),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    ),
  );
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.controller,
    required this.onEdit,
    required this.onDelete,
    required this.selectionMode,
    required this.selected,
    required this.onToggleSelection,
    required this.onEnterSelection,
  });
  final LedgerEntry entry;
  final LedgerController controller;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onToggleSelection;
  final VoidCallback onEnterSelection;

  @override
  Widget build(BuildContext context) {
    final bool adjustment = entry.type == EntryType.adjustment;
    final bool expense =
        entry.type == EntryType.expense ||
        (adjustment && entry.adjustmentDelta < 0);
    final bool transfer = entry.type == EntryType.transfer;
    final List<LedgerAccount> matchingAccounts = controller.accounts
        .where((LedgerAccount item) => item.id == entry.accountId)
        .toList();
    final LedgerAccount? account = matchingAccounts.isEmpty
        ? null
        : matchingAccounts.first;
    final List<LedgerAccount> matchingToAccounts = controller.accounts
        .where((LedgerAccount item) => item.id == entry.toAccountId)
        .toList();
    final LedgerAccount? toAccount = matchingToAccounts.isEmpty
        ? null
        : matchingToAccounts.first;
    final List<LedgerMember> members = controller.members
        .where((LedgerMember member) => entry.memberIds.contains(member.id))
        .toList();
    final double shownAmount = adjustment
        ? entry.adjustmentDelta.abs()
        : entry.amount;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SwipeActionTile(
        actionLabel: '删除',
        onAction: () => _confirmDelete(context),
        leftSwipeEnabled: !selectionMode,
        onSwipeRight: selectionMode ? onToggleSelection : null,
        rightSwipeSelected: selected,
        onTap: selectionMode
            ? onToggleSelection
            : () => showEntryDetailSheet(
                context: context,
                controller: controller,
                entry: entry,
                onEdit: onEdit,
              ),
        onLongPress: selectionMode ? onToggleSelection : onEnterSelection,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 3,
            ),
            leading: SizedBox(
              width: selectionMode ? 72 : 44,
              height: 44,
              child: Row(
                children: <Widget>[
                  if (selectionMode)
                    SizedBox(
                      width: 28,
                      child: Icon(
                        selected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            transfer
                                ? Icons.swap_horiz
                                : adjustment
                                ? Icons.account_balance_wallet_outlined
                                : _entryCategoryIcon(
                                    controller,
                                    entry.category,
                                  ),
                            size: 21,
                          ),
                        ),
                        if (controller.multiEnabled)
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: _MemberBadge(members: members),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            title: Text(
              adjustment
                  ? '余额调整'
                  : transfer
                  ? '转账'
                  : entry.category,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            subtitle: entry.note.isEmpty
                ? null
                : Text(
                    entry.note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  '${expense
                      ? '-'
                      : transfer
                      ? ''
                      : '+'}${shownAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: expense
                        ? AppTheme.expense
                        : transfer
                        ? null
                        : AppTheme.income,
                  ),
                ),
                Text(
                  transfer
                      ? '${account?.name ?? ''} → ${toAccount?.name ?? ''}'
                      : account == null
                      ? ''
                      : account.name,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8A9099),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('删除这笔账目？'),
        content: Text(entry.note.isEmpty ? entry.category : entry.note),
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
    if (confirmed == true) onDelete();
  }
}

class _MemberBadge extends StatelessWidget {
  const _MemberBadge({required this.members});
  final List<LedgerMember> members;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return _badge(context, '?', Theme.of(context).colorScheme.outline);
    }
    if (members.length == 1) {
      return _badge(
        context,
        members.first.name.substring(0, 1),
        Color(members.first.colorValue),
      );
    }
    return _badge(
      context,
      '${members.length}',
      Color(members.first.colorValue),
    );
  }

  Widget _badge(BuildContext context, String text, Color color) => Container(
    width: 19,
    height: 19,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      shape: BoxShape.circle,
      border: Border.all(color: color, width: 1.5),
    ),
    alignment: Alignment.center,
    child: Text(
      text,
      textScaler: TextScaler.noScaling,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 9,
        height: 1,
        color: color,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

String _weekday(int day) =>
    const <String>['周一', '周二', '周三', '周四', '周五', '周六', '周日'][day - 1];

IconData _categoryIcon(String category) => switch (category) {
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

IconData _entryCategoryIcon(LedgerController controller, String categoryName) {
  final List<LedgerCategory> matching = controller.categories
      .where((item) => item.name == categoryName)
      .toList();
  if (matching.isEmpty) return _categoryIcon(categoryName);
  return switch (matching.first.icon) {
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
    _ => _categoryIcon(categoryName),
  };
}
