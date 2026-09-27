import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/ledger_controller.dart';
import '../../models/ledger_models.dart';
import '../../theme/app_theme.dart';
import '../home/period_picker_sheet.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({required this.controller, super.key});
  final LedgerController controller;

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  String _mode = 'month';
  DateTime _anchor = DateTime.now();
  bool _showIncome = true;
  bool _showExpense = true;
  EntryType _breakdown = EntryType.expense;
  String? _pointLabel;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (BuildContext context, Widget? child) {
      final ({DateTime start, DateTime end}) range = _range(_anchor);
      final List<LedgerEntry> entries = _entries(range);
      final ({DateTime start, DateTime end}) previous = _previousRange(range);
      final List<LedgerEntry> previousEntries = _entries(previous);
      final double income = _sum(entries, EntryType.income);
      final double expense = _sum(entries, EntryType.expense);
      final double previousIncome = _sum(previousEntries, EntryType.income);
      final double previousExpense = _sum(previousEntries, EntryType.expense);
      final List<_Slice> categorySlices = _categorySlices(entries);
      final List<_Slice> memberSlices = _memberSlices(entries);
      return Scaffold(
        appBar: AppBar(title: const Text('统计')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 100),
          children: <Widget>[
            _ModeTabs(
              value: _mode,
              onChanged: (String value) => setState(() {
                _mode = value;
                _anchor = DateTime.now();
                _pointLabel = null;
              }),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                IconButton(
                  onPressed: () => _shift(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _pickPeriod,
                  child: SizedBox(
                    width: 180,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        _periodLabel(range),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _canNext() ? () => _shift(1) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Text(
                          '收支统计',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        _TogglePill(
                          label: '收入',
                          selected: _showIncome,
                          onTap: () =>
                              setState(() => _showIncome = !_showIncome),
                        ),
                        const SizedBox(width: 6),
                        _TogglePill(
                          label: '支出',
                          selected: _showExpense,
                          onTap: () =>
                              setState(() => _showExpense = !_showExpense),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Text('收入 ¥${income.toStringAsFixed(2)}'),
                        const SizedBox(width: 14),
                        Text('支出 ¥${expense.toStringAsFixed(2)}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _InteractiveLineChart(
                      entries: entries,
                      range: range,
                      showIncome: _showIncome,
                      showExpense: _showExpense,
                      onPoint: (String value) =>
                          setState(() => _pointLabel = value),
                    ),
                    SizedBox(
                      height: 26,
                      child: Center(
                        child: Text(
                          _pointLabel ?? '点击折线上的圆点查看日期与金额',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8A9099),
                          ),
                        ),
                      ),
                    ),
                    if (_showIncome)
                      _ComparisonRow(
                        label: '收入',
                        amount: income,
                        previous: previousIncome,
                      ),
                    if (_showIncome && _showExpense) const SizedBox(height: 6),
                    if (_showExpense)
                      _ComparisonRow(
                        label: '支出',
                        amount: expense,
                        previous: previousExpense,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _BreakdownCard(
              title: '标签构成',
              slices: categorySlices,
              type: _breakdown,
              onTypeChanged: (EntryType value) =>
                  setState(() => _breakdown = value),
            ),
            ..._sliceCards(categorySlices),
            if (widget.controller.multiEnabled) ...<Widget>[
              const SizedBox(height: 12),
              _BreakdownCard(
                title: '成员构成',
                slices: memberSlices,
                type: _breakdown,
                onTypeChanged: (EntryType value) =>
                    setState(() => _breakdown = value),
              ),
              ..._sliceCards(memberSlices),
            ],
          ],
        ),
      );
    },
  );

  List<Widget> _sliceCards(List<_Slice> slices) {
    final double total = slices.fold(0, (sum, item) => sum + item.value);
    if (slices.isEmpty) {
      return <Widget>[const Card(child: ListTile(title: Text('该时间段暂无数据')))];
    }
    return slices
        .map(
          (item) => Card(
            child: ListTile(
              leading: CircleAvatar(radius: 6, backgroundColor: item.color),
              title: Text(item.name),
              subtitle: Text(
                '${total == 0 ? 0 : item.value / total * 100 ~/ 1}%',
              ),
              trailing: Text('¥${item.value.toStringAsFixed(2)}'),
            ),
          ),
        )
        .toList();
  }

  List<LedgerEntry> _entries(({DateTime start, DateTime end}) range) => widget
      .controller
      .entries
      .where(
        (entry) =>
            entry.occurredAt.compareTo(range.start) >= 0 &&
            entry.occurredAt.compareTo(range.end) <= 0 &&
            entry.type != EntryType.transfer &&
            entry.type != EntryType.adjustment,
      )
      .toList();

  double _sum(List<LedgerEntry> entries, EntryType type) => entries
      .where((entry) => entry.type == type)
      .fold(0, (sum, entry) => sum + entry.amount);

  List<_Slice> _categorySlices(List<LedgerEntry> entries) {
    final Map<String, double> values = <String, double>{};
    for (final LedgerEntry entry in entries.where(
      (item) => item.type == _breakdown,
    )) {
      values.update(
        entry.category,
        (value) => value + entry.amount,
        ifAbsent: () => entry.amount,
      );
    }
    int index = 0;
    return values.entries.map((item) {
      final _Slice result = _Slice(
        item.key,
        item.value,
        _palette[index % _palette.length],
      );
      index++;
      return result;
    }).toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  List<_Slice> _memberSlices(List<LedgerEntry> entries) {
    final Map<int, double> values = <int, double>{};
    for (final LedgerEntry entry in entries.where(
      (item) => item.type == _breakdown,
    )) {
      if (entry.memberIds.isEmpty) continue;
      final double share = widget.controller.splitMode == 'full'
          ? entry.amount
          : entry.amount / entry.memberIds.length;
      for (final int id in entry.memberIds) {
        values.update(id, (value) => value + share, ifAbsent: () => share);
      }
    }
    return values.entries.map((item) {
      final LedgerMember member = widget.controller.members.firstWhere(
        (member) => member.id == item.key,
      );
      return _Slice(member.name, item.value, Color(member.colorValue));
    }).toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  ({DateTime start, DateTime end}) _range(DateTime anchor) {
    if (_mode == 'year') {
      return (
        start: DateTime(anchor.year),
        end: DateTime(anchor.year, 12, 31, 23, 59, 59, 999),
      );
    }
    if (_mode == 'week') {
      final DateTime start = DateTime(
        anchor.year,
        anchor.month,
        anchor.day - anchor.weekday + 1,
      );
      return (
        start: start,
        end: start
            .add(const Duration(days: 7))
            .subtract(const Duration(milliseconds: 1)),
      );
    }
    return (
      start: DateTime(anchor.year, anchor.month),
      end: DateTime(
        anchor.year,
        anchor.month + 1,
      ).subtract(const Duration(milliseconds: 1)),
    );
  }

  ({DateTime start, DateTime end}) _previousRange(
    ({DateTime start, DateTime end}) current,
  ) {
    final Duration duration = current.end.difference(current.start);
    final DateTime end = current.start.subtract(
      const Duration(milliseconds: 1),
    );
    return (start: end.subtract(duration), end: end);
  }

  String _periodLabel(({DateTime start, DateTime end}) range) {
    if (_mode == 'year') return '${_anchor.year}年';
    if (_mode == 'month') return '${_anchor.year}年${_anchor.month}月';
    return '${range.start.month}月${range.start.day}日—${range.end.month}月${range.end.day}日';
  }

  void _shift(int direction) => setState(() {
    _anchor = _mode == 'year'
        ? DateTime(_anchor.year + direction, 1, 1)
        : _mode == 'month'
        ? DateTime(_anchor.year, _anchor.month + direction, 1)
        : _anchor.add(Duration(days: 7 * direction));
    _pointLabel = null;
  });

  bool _canNext() {
    final DateTime next = _mode == 'year'
        ? DateTime(_anchor.year + 1)
        : _mode == 'month'
        ? DateTime(_anchor.year, _anchor.month + 1)
        : _anchor.add(const Duration(days: 7));
    return _range(next).start.isBefore(DateTime.now());
  }

  Future<void> _pickPeriod() async {
    final PeriodSelection? selected =
        await showModalBottomSheet<PeriodSelection>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => PeriodPickerSheet(
            initial: (
              year: _anchor.year,
              month: _mode == 'year' ? null : _anchor.month,
              day: _mode == 'week' ? _anchor.day : null,
            ),
          ),
        );
    if (selected == null) return;
    setState(() {
      _anchor = DateTime(selected.year, selected.month ?? 1, selected.day ?? 1);
      _pointLabel = null;
    });
  }
}

class _ModeTabs extends StatelessWidget {
  const _ModeTabs({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Center(
    child: SegmentedButton<String>(
      segments: const <ButtonSegment<String>>[
        ButtonSegment(value: 'year', label: Text('年')),
        ButtonSegment(value: 'month', label: Text('月')),
        ButtonSegment(value: 'week', label: Text('周')),
      ],
      selected: <String>{value},
      onSelectionChanged: (values) => onChanged(values.first),
      showSelectedIcon: false,
    ),
  );
}

class _TogglePill extends StatelessWidget {
  const _TogglePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontWeight: selected ? FontWeight.w700 : null),
      ),
    ),
  );
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.label,
    required this.amount,
    required this.previous,
  });
  final String label;
  final double amount;
  final double previous;

  @override
  Widget build(BuildContext context) {
    final double percent = previous == 0
        ? (amount == 0 ? 0 : 100)
        : (amount - previous) / previous * 100;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(width: 36, child: Text(label)),
          Icon(
            percent > 0
                ? Icons.arrow_upward
                : percent < 0
                ? Icons.arrow_downward
                : Icons.remove,
            size: 17,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '¥${amount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text('${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(1)}%'),
        ],
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({
    required this.title,
    required this.slices,
    required this.type,
    required this.onTypeChanged,
  });
  final String title;
  final List<_Slice> slices;
  final EntryType type;
  final ValueChanged<EntryType> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    final double total = slices.fold(0, (sum, item) => sum + item.value);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                _TogglePill(
                  label: '收入',
                  selected: type == EntryType.income,
                  onTap: () => onTypeChanged(EntryType.income),
                ),
                const SizedBox(width: 6),
                _TogglePill(
                  label: '支出',
                  selected: type == EntryType.expense,
                  onTap: () => onTypeChanged(EntryType.expense),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                SizedBox(
                  width: 166,
                  height: 166,
                  child: CustomPaint(
                    painter: _PiePainter(slices),
                    child: Center(
                      child: Text(
                        '合计\n${total.toStringAsFixed(2)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: slices.take(6).map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: <Widget>[
                            CircleAvatar(
                              radius: 5,
                              backgroundColor: item.color,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                item.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${total == 0 ? 0 : (item.value / total * 100).round()}%',
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InteractiveLineChart extends StatelessWidget {
  const _InteractiveLineChart({
    required this.entries,
    required this.range,
    required this.showIncome,
    required this.showExpense,
    required this.onPoint,
  });
  final List<LedgerEntry> entries;
  final ({DateTime start, DateTime end}) range;
  final bool showIncome;
  final bool showExpense;
  final ValueChanged<String> onPoint;

  @override
  Widget build(BuildContext context) {
    final int days = math.max(1, range.end.difference(range.start).inDays + 1);
    final int buckets = math.min(days, 31);
    final List<double> income = List<double>.filled(buckets, 0);
    final List<double> expense = List<double>.filled(buckets, 0);
    for (final LedgerEntry entry in entries) {
      final int day = entry.occurredAt.difference(range.start).inDays;
      final int index = math.min(buckets - 1, day * buckets ~/ days);
      if (entry.type == EntryType.income) income[index] += entry.amount;
      if (entry.type == EntryType.expense) expense[index] += entry.amount;
    }
    return SizedBox(
      height: 160,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) =>
            GestureDetector(
              onTapDown: (TapDownDetails details) {
                final double step =
                    constraints.maxWidth / math.max(1, buckets - 1);
                final int index = (details.localPosition.dx / step)
                    .round()
                    .clamp(0, buckets - 1);
                final DateTime date = range.start.add(
                  Duration(days: index * days ~/ buckets),
                );
                onPoint(
                  '${date.month}月${date.day}日 · 收入 ¥${income[index].toStringAsFixed(2)} · 支出 ¥${expense[index].toStringAsFixed(2)}',
                );
              },
              child: CustomPaint(
                size: Size(constraints.maxWidth, 160),
                painter: _LinePainter(
                  income: income,
                  expense: expense,
                  showIncome: showIncome,
                  showExpense: showExpense,
                ),
              ),
            ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.income,
    required this.expense,
    required this.showIncome,
    required this.showExpense,
  });
  final List<double> income;
  final List<double> expense;
  final bool showIncome;
  final bool showExpense;

  @override
  void paint(Canvas canvas, Size size) {
    final double maxValue = math.max(
      1,
      <double>[
        if (showIncome) ...income,
        if (showExpense) ...expense,
      ].fold(0, math.max),
    );
    void draw(List<double> values, Color color) {
      final Path path = Path();
      final Paint line = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2;
      final Paint point = Paint()..color = color;
      for (int index = 0; index < values.length; index++) {
        final double x = values.length == 1
            ? size.width / 2
            : size.width * index / (values.length - 1);
        final double y =
            12 + (size.height - 28) * (1 - values[index] / maxValue);
        if (index == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
        canvas.drawCircle(Offset(x, y), 3, point);
      }
      canvas.drawPath(path, line);
    }

    if (showIncome) draw(income, AppTheme.income);
    if (showExpense) draw(expense, AppTheme.expense);
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) => true;
}

class _PiePainter extends CustomPainter {
  const _PiePainter(this.slices);
  final List<_Slice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final double total = slices.fold(0, (sum, item) => sum + item.value);
    final Rect rect = Offset.zero & size;
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24;
    if (total == 0) {
      paint.color = const Color(0xFFE0E4E9);
      canvas.drawCircle(size.center(Offset.zero), size.width / 2 - 18, paint);
      return;
    }
    double start = -math.pi / 2;
    for (final _Slice slice in slices) {
      final double sweep = math.pi * 2 * slice.value / total;
      paint.color = slice.color;
      canvas.drawArc(rect.deflate(18), start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PiePainter oldDelegate) => true;
}

class _Slice {
  const _Slice(this.name, this.value, this.color);
  final String name;
  final double value;
  final Color color;
}

const List<Color> _palette = <Color>[
  Color(0xFF0EB078),
  Color(0xFF2E7CF6),
  Color(0xFFF5A623),
  Color(0xFFEB4E6B),
  Color(0xFF8E6BE0),
  Color(0xFF00B0D6),
];
