import 'package:flutter/material.dart';

import '../../data/ledger_controller.dart';
import '../../models/ledger_models.dart';
import '../../theme/app_theme.dart';

class MembersPage extends StatelessWidget {
  const MembersPage({required this.controller, super.key});
  final LedgerController controller;
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

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (BuildContext context, Widget? child) {
      final List<LedgerMember> active = controller.members
          .where((item) => !item.archived)
          .toList();
      final List<LedgerMember> archived = controller.members
          .where((item) => item.archived)
          .toList();
      return Scaffold(
        appBar: AppBar(
          title: const Text('成员'),
          centerTitle: true,
          actions: <Widget>[
            IconButton(
              onPressed: () => _edit(context),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                '点卡片编辑；归档后不出现在新账目的成员选择中',
                style: TextStyle(fontSize: 12, color: Color(0xFF8A9099)),
              ),
            ),
            ...active.map(
              (item) => _MemberTile(
                member: item,
                onTap: () => _edit(context, item),
                onArchive: () => controller.setMemberArchived(item.id, true),
              ),
            ),
            if (archived.isNotEmpty) ...<Widget>[
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 16, 4, 8),
                child: Text(
                  '已归档成员',
                  style: TextStyle(fontSize: 12, color: Color(0xFF8A9099)),
                ),
              ),
              ...archived.map(
                (item) => _MemberTile(
                  member: item,
                  archived: true,
                  onTap: () => _edit(context, item),
                  onArchive: () => controller.setMemberArchived(item.id, false),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );

  Future<void> _edit(BuildContext context, [LedgerMember? member]) async {
    final TextEditingController name = TextEditingController(
      text: member?.name ?? '',
    );
    int color = member?.colorValue ?? colors.first;
    final bool? save = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) =>
            AlertDialog(
              title: Text(member == null ? '新增成员' : '编辑成员'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: name,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: '名称'),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: colors
                        .map(
                          (value) => InkWell(
                            onTap: () => setDialogState(() => color = value),
                            borderRadius: BorderRadius.circular(99),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Color(value),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: color == value
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('保存'),
                ),
              ],
            ),
      ),
    );
    final String value = name.text.trim();
    name.dispose();
    if (save != true || value.isEmpty) return;
    if (member == null) {
      await controller.addMember(value, color);
    } else {
      await controller.updateMember(member.id, value, color);
    }
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.onTap,
    required this.onArchive,
    this.archived = false,
  });
  final LedgerMember member;
  final VoidCallback onTap;
  final VoidCallback onArchive;
  final bool archived;

  @override
  Widget build(BuildContext context) => Dismissible(
    key: ValueKey('member-${member.id}-$archived'),
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
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Color(member.colorValue),
          child: Text(
            member.name.substring(0, 1),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(member.name),
        subtitle: Text(archived ? '已归档' : '本月参与账目'),
        trailing: const Icon(Icons.chevron_right),
      ),
    ),
  );
}
