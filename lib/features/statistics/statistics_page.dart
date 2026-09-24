import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/ledger_controller.dart';
import '../../models/ledger_models.dart';
import '../../theme/app_theme.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({required this.controller, super.key});
  final LedgerController controller;

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  bool _showIncome = true;
  bool _showExpense = true;
  EntryType _breakdown = EntryType.expense;

  @override
  Widget build(BuildContext context) {
    final DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final List<LedgerEntry> entries = widget.controller.entriesForMonth(
          month,
        );
        final double income = widget.controller.incomeForMonth(month);
        final double expense = widget.controller.expenseForMonth(month);
        final Map<String, double> categories = <String, double>{};
        for (final LedgerEntry entry in entries.where(
          (LedgerEntry item) => item.type == _breakdown,
        )) {
          categories.update(
            entry.category,
            (double value) => value + entry.amount,
            ifAbsent: () => entry.amount,
          );
        }
        return CustomScrollView(
          slivers: <Widget>[
            const SliverAppBar(title: Text('统计'), floating: true),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
              sliver: SliverList.list(
                children: <Widget>[
                  Center(
                    child: Text(
                      '${month.year}年${month.month}月',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
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
                              FilterChip(
                                label: const Text('收入'),
                                selected: _showIncome,
                                onSelected: (bool value) =>
                                    setState(() => _showIncome = value),
                              ),
                              const SizedBox(width: 6),
                              FilterChip(
                                label: const Text('支出'),
                                selected: _showExpense,
                                onSelected: (bool value) =>
                                    setState(() => _showExpense = value),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 150,
                            width: double.infinity,
                            child: CustomPaint(
                              painter: _LinePainter(
                                entries: entries,
                                showIncome: _showIncome,
                                showExpense: _showExpense,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_showIncome)
                            _ComparisonRow(
                              label: '收入',
                              amount: income,
                              positive: true,
                              percent: 12.6,
                            ),
                          if (_showExpense) ...<Widget>[
                            if (_showIncome) const SizedBox(height: 6),
                            _ComparisonRow(
                              label: '支出',
                              amount: expense,
                              positive: false,
                              percent: -8.4,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              const Text(
                                '标签构成',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const Spacer(),
                              SegmentedButton<EntryType>(
                                segments: const <ButtonSegment<EntryType>>[
                                  ButtonSegment(
                                    value: EntryType.income,
                                    label: Text('收入'),
                                  ),
                                  ButtonSegment(
                                    value: EntryType.expense,
                                    label: Text('支出'),
                                  ),
                                ],
                                selected: <EntryType>{_breakdown},
                                onSelectionChanged: (Set<EntryType> value) =>
                                    setState(() => _breakdown = value.first),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 180,
                            child: categories.isEmpty
                                ? const Center(child: Text('该时间段暂无账目'))
                                : Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: CustomPaint(
                                          painter: _DonutPainter(
                                            values: categories.values.toList(),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: categories.entries
                                              .take(5)
                                              .map(
                                                (entry) => Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 4,
                                                      ),
                                                  child: Text(
                                                    '${entry.key}  ¥${entry.value.toStringAsFixed(2)}',
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.label,
    required this.amount,
    required this.positive,
    required this.percent,
  });
  final String label;
  final double amount;
  final bool positive;
  final double percent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      children: <Widget>[
        SizedBox(width: 36, child: Text(label)),
        Icon(positive ? Icons.arrow_upward : Icons.arrow_downward, size: 17),
        const SizedBox(width: 5),
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

class _LinePainter extends CustomPainter {
  const _LinePainter({
    required this.entries,
    required this.showIncome,
    required this.showExpense,
  });
  final List<LedgerEntry> entries;
  final bool showIncome;
  final bool showExpense;

  @override
  void paint(Canvas canvas, Size size) {
    final List<double> income = List<double>.filled(7, 0);
    final List<double> expense = List<double>.filled(7, 0);
    for (final LedgerEntry entry in entries) {
      final int index = (entry.occurredAt.day - 1).clamp(0, 6).toInt();
      if (entry.type == EntryType.income) income[index] += entry.amount;
      if (entry.type == EntryType.expense) expense[index] += entry.amount;
    }
    final double maxValue = math.max(
      1.0,
      <double>[...income, ...expense].reduce(math.max),
    );
    void drawSeries(List<double> values, Color color) {
      final Path path = Path();
      for (int index = 0; index < values.length; index++) {
        final double x = index * size.width / (values.length - 1);
        final double y =
            size.height - 16 - values[index] / maxValue * (size.height - 28);
        if (index == 0)
          path.moveTo(x, y);
        else
          path.lineTo(x, y);
        canvas.drawCircle(Offset(x, y), 3, Paint()..color = color);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );
    }

    if (showIncome) drawSeries(income, AppTheme.income);
    if (showExpense) drawSeries(expense, AppTheme.expense);
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) => true;
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.values});
  final List<double> values;

  static const List<Color> colors = <Color>[
    AppTheme.green,
    Color(0xFF2E7CF6),
    Color(0xFFF5A623),
    Color(0xFFEB4E6B),
    Color(0xFF8E6BE0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final double total = values.fold(
      0,
      (double sum, double value) => sum + value,
    );
    final Rect rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: math.min(size.width, size.height) * .32,
    );
    double start = -math.pi / 2;
    for (int index = 0; index < values.length; index++) {
      final double sweep = values[index] / total * math.pi * 2;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = colors[index % colors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 24,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => true;
}
