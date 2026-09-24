import 'package:flutter/material.dart';

import '../../data/ledger_controller.dart';
import '../../models/ledger_models.dart';
import '../../theme/app_theme.dart';

class MembersPage extends StatelessWidget {
  const MembersPage({required this.controller, super.key});
  final LedgerController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (BuildContext context, Widget? child) {
      final active = controller.members
          .where((member) => !member.archived)
          .toList();
      final archived = controller.members
          .where((member) => member.archived)
          .toList();
      return Scaffold(
        appBar: AppBar(
          title: const Text('成员'),
          centerTitle: true,
          actions: <Widget>[
            IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                '归档后不会出现在新账目的成员选择中',
                style: TextStyle(fontSize: 12, color: Color(0xFF8A9099)),
              ),
            ),
            ...active.map(
              (member) => _MemberTile(
                member: member,
                onArchive: () => controller.setMemberArchived(member.id, true),
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
                (member) => _MemberTile(
                  member: member,
                  archived: true,
                  onArchive: () =>
                      controller.setMemberArchived(member.id, false),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.onArchive,
    this.archived = false,
  });
  final LedgerMember member;
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
