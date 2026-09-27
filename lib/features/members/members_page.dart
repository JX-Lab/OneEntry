import 'package:flutter/material.dart';

import '../../data/ledger_controller.dart';
import '../../models/ledger_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/swipe_action_tile.dart';

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
      return Scaffold(
        appBar: AppBar(
          title: _searching
              ? TextField(
                  controller: _search,
                  autofocus: true,
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
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    '成员概况',
                    style: TextStyle(color: Color(0xFF8A9099), fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${active.length} 人',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _MemberCount(
                          label: '总人数',
                          value: widget.controller.members.length,
                        ),
                      ),
                      Expanded(
                        child: _MemberCount(
                          label: '当前成员',
                          value: active.length,
                        ),
                      ),
                      Expanded(
                        child: _MemberCount(
                          label: '已归档',
                          value: archived.length,
                        ),
                      ),
                    ],
                  ),
                ],
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
    final int count = widget.controller.entries
        .where((entry) => entry.memberIds.contains(member.id))
        .length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SwipeActionTile(
        key: ValueKey('member-${member.id}-${member.archived}'),
        actionLabel: member.archived ? '恢复' : '归档',
        actionColor: member.archived ? AppTheme.green : AppTheme.expense,
        onAction: () =>
            widget.controller.setMemberArchived(member.id, !member.archived),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _MemberDetailPage(
              controller: widget.controller,
              memberId: member.id,
              onEdit: () => _edit(context, member),
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
              member.archived ? '已归档 · $count 笔' : '参与 $count 笔账目',
            ),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
      ),
    );
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
                            autofocus: true,
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

class _MemberCount extends StatelessWidget {
  const _MemberCount({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(label, style: const TextStyle(color: Color(0xFF8A9099))),
      const SizedBox(height: 3),
      Text('$value', style: const TextStyle(fontWeight: FontWeight.w700)),
    ],
  );
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
      final List<LedgerEntry> entries = controller.entries
          .where((entry) => entry.memberIds.contains(memberId))
          .toList();
      final double income = entries
          .where((entry) => entry.type == EntryType.income)
          .fold(0, (sum, entry) => sum + entry.amount);
      final double expense = entries
          .where((entry) => entry.type == EntryType.expense)
          .fold(0, (sum, entry) => sum + entry.amount);
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
                } else {
                  controller.setMemberArchived(member.id, !member.archived);
                }
              },
              itemBuilder: (_) => <PopupMenuEntry<String>>[
                const PopupMenuItem(value: 'edit', child: Text('编辑')),
                PopupMenuItem(
                  value: 'archive',
                  child: Text(member.archived ? '取消归档' : '归档成员'),
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
                          '${member.name}${member.archived ? ' · 已归档' : ''}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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
                            color: AppTheme.income,
                          ),
                        ),
                        Expanded(
                          child: _MemberMetric(
                            label: '支出',
                            value: expense,
                            color: AppTheme.expense,
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
              ...months.entries.map(
                (month) => Card(
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    initiallyExpanded: month.key == months.keys.first,
                    title: Text(
                      month.key,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text('${month.value.length} 笔'),
                    children: month.value
                        .map(
                          (entry) => ListTile(
                            title: Text(entry.category),
                            subtitle: entry.note.isEmpty
                                ? null
                                : Text(entry.note),
                            trailing: Text(
                              '${entry.type == EntryType.expense
                                  ? '-'
                                  : entry.type == EntryType.income
                                  ? '+'
                                  : ''}¥${entry.amount.toStringAsFixed(2)}',
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
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
