import 'package:flutter/material.dart';

import '../../data/ledger_controller.dart';
import '../../models/ledger_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/swipe_action_tile.dart';
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
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _yearOnly = false;
  int? _day;
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DateTime month = _month;
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final String query = _searchController.text.trim().toLowerCase();
        final List<LedgerEntry> periodEntries = widget.controller.entries
            .where(
              (LedgerEntry entry) =>
                  entry.occurredAt.year == month.year &&
                  (_yearOnly || entry.occurredAt.month == month.month) &&
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
            title: _searching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
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
                            _yearOnly
                                ? '${month.year}年'
                                : _day == null
                                ? '${month.year}年${month.month}月'
                                : '${month.year}年${month.month}月${_day}日',
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
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 92),
            children: <Widget>[
              _SummaryCard(
                income: income,
                expense: expense,
                spent: expense,
                budget: widget.controller.monthlyBudget,
                showBudget: !_yearOnly,
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
                  child: Center(child: Text('本月还没有匹配的账目')),
                )
              else
                ..._groupedEntries(entries),
            ],
          ),
          bottomNavigationBar: SafeArea(
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
            initial: (
              year: _month.year,
              month: _yearOnly ? null : _month.month,
              day: _day,
            ),
          ),
        );
    if (selected == null) return;
    setState(() {
      _month = DateTime(selected.year, selected.month ?? 1);
      _yearOnly = selected.month == null;
      _day = selected.month == null ? null : selected.day;
    });
  }

  List<Widget> _groupedEntries(List<LedgerEntry> entries) {
    final Map<String, List<LedgerEntry>> groups = <String, List<LedgerEntry>>{};
    for (final LedgerEntry entry in entries) {
      final String key = '${entry.occurredAt.month}月${entry.occurredAt.day}日';
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
                      Text(
                        '${entry.key} ${_weekday(date.weekday)}',
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
                onTap: () => widget.onEditEntry(item),
                onDelete: () => widget.onDeleteEntry(item),
              ),
            ),
          ],
        )
        .toList();
  }
}

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
    required this.onTap,
    required this.onDelete,
  });
  final LedgerEntry entry;
  final LedgerController controller;
  final VoidCallback onTap;
  final VoidCallback onDelete;

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
        onTap: onTap,
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
                          : _entryCategoryIcon(controller, entry.category),
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
                      : '余额 ¥${account.balance.toStringAsFixed(2)}',
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
      style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700),
    ),
  );
}

String _weekday(int day) =>
    const <String>['周一', '周二', '周三', '周四', '周五', '周六', '周日'][day - 1];

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
  '通讯' => Icons.phone_android_outlined,
  '健身' => Icons.fitness_center_outlined,
  '美妆' => Icons.brush_outlined,
  '服饰' => Icons.checkroom_outlined,
  '打赏' => Icons.volunteer_activism_outlined,
  '报销' => Icons.receipt_long_outlined,
  '礼物' => Icons.card_giftcard_outlined,
  '兼职' => Icons.work_history_outlined,
  '其他' => Icons.more_horiz,
  _ => Icons.restaurant_outlined,
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
    'fastfood' => Icons.fastfood_outlined,
    'icecream' => Icons.icecream_outlined,
    'breakfast' => Icons.breakfast_dining_outlined,
    'wine' => Icons.wine_bar_outlined,
    'medicine' => Icons.medication_outlined,
    'hospital' => Icons.local_hospital_outlined,
    'pharmacy' => Icons.local_pharmacy_outlined,
    'dental' => Icons.medical_information_outlined,
    'healing' => Icons.healing_outlined,
    'psychology' => Icons.psychology_outlined,
    'spa' => Icons.spa_outlined,
    'language' => Icons.language_outlined,
    'calculate' => Icons.calculate_outlined,
    'science' => Icons.science_outlined,
    'edit' => Icons.edit_outlined,
    'library' => Icons.local_library_outlined,
    'computer' => Icons.computer_outlined,
    'subway' => Icons.subway_outlined,
    'ship' => Icons.directions_boat_outlined,
    'taxi' => Icons.local_taxi_outlined,
    'cart' => Icons.shopping_cart_outlined,
    'bag' => Icons.shopping_bag_outlined,
    'store' => Icons.storefront_outlined,
    'receipt' => Icons.receipt_long_outlined,
    'person' => Icons.person_outline,
    'watch' => Icons.watch_outlined,
    'haircut' => Icons.content_cut,
    'family' => Icons.family_restroom_outlined,
    'elderly' => Icons.elderly_outlined,
    'toy' => Icons.toys_outlined,
    'kitchen' => Icons.kitchen_outlined,
    'briefcase' => Icons.business_center_outlined,
    'print' => Icons.print_outlined,
    'email' => Icons.email_outlined,
    'folder' => Icons.folder_outlined,
    'meeting' => Icons.groups_outlined,
    'calendar' => Icons.calendar_month_outlined,
    'wallet' => Icons.account_balance_wallet_outlined,
    'bank' => Icons.account_balance_outlined,
    'card' => Icons.credit_card_outlined,
    'savings' => Icons.savings_outlined,
    'coin' => Icons.monetization_on_outlined,
    'globe' => Icons.public_outlined,
    'cloud' => Icons.cloud_outlined,
    'repeat' => Icons.repeat,
    'link' => Icons.link,
    'flag' => Icons.flag_outlined,
    'tag' => Icons.sell_outlined,
    _ => _categoryIcon(categoryName),
  };
}
