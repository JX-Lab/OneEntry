import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

typedef PeriodSelection = ({int year, int? month, int? day});

class PeriodPickerSheet extends StatefulWidget {
  const PeriodPickerSheet({required this.initial, super.key});
  final PeriodSelection initial;

  @override
  State<PeriodPickerSheet> createState() => _PeriodPickerSheetState();
}

class _PeriodPickerSheetState extends State<PeriodPickerSheet> {
  late int year = widget.initial.year;
  late int? month = widget.initial.month;
  late int? day = widget.initial.day;
  late final FixedExtentScrollController yearController;
  late final FixedExtentScrollController monthController;
  late final FixedExtentScrollController dayController;
  late final List<int> years;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    years = List<int>.generate(21, (index) => now.year - 20 + index);
    yearController = FixedExtentScrollController(
      initialItem: years.indexOf(year),
    );
    monthController = FixedExtentScrollController(initialItem: month ?? 0);
    dayController = FixedExtentScrollController(initialItem: day ?? 0);
  }

  @override
  void dispose() {
    yearController.dispose();
    monthController.dispose();
    dayController.dispose();
    super.dispose();
  }

  List<int?> get months {
    final DateTime now = DateTime.now();
    final int max = year == now.year ? now.month : 12;
    return <int?>[null, ...List<int>.generate(max, (index) => index + 1)];
  }

  List<int?> get days {
    if (month == null) return const <int?>[null];
    final DateTime now = DateTime.now();
    final int max = year == now.year && month == now.month
        ? now.day
        : DateTime(year, month! + 1, 0).day;
    return <int?>[null, ...List<int>.generate(max, (index) => index + 1)];
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
    clipBehavior: Clip.antiAlias,
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
                      '请选择时间',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, (
                    year: year,
                    month: month,
                    day: month == null ? null : day,
                  )),
                  child: const Text('确定'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 220,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _picker<int>(
                    controller: yearController,
                    values: years,
                    label: (value) => '$value年',
                    onSelected: (value) {
                      setState(() {
                        year = value;
                        if (!months.contains(month)) month = null;
                        if (!days.contains(day)) day = null;
                      });
                      monthController.jumpToItem(month ?? 0);
                      dayController.jumpToItem(day ?? 0);
                    },
                  ),
                ),
                Expanded(
                  child: _picker<int?>(
                    controller: monthController,
                    values: months,
                    label: (value) => value == null
                        ? '不选'
                        : '${value.toString().padLeft(2, '0')}月',
                    onSelected: (value) {
                      setState(() {
                        month = value;
                        if (month == null || !days.contains(day)) day = null;
                      });
                      dayController.jumpToItem(day ?? 0);
                    },
                  ),
                ),
                Expanded(
                  child: _picker<int?>(
                    controller: dayController,
                    values: days,
                    label: (value) => value == null
                        ? '不选'
                        : '${value.toString().padLeft(2, '0')}日',
                    onSelected: (value) => setState(() => day = value),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _picker<T>({
    required FixedExtentScrollController controller,
    required List<T> values,
    required String Function(T value) label,
    required ValueChanged<T> onSelected,
  }) => CupertinoPicker.builder(
    scrollController: controller,
    itemExtent: 40,
    useMagnifier: true,
    magnification: 1.14,
    squeeze: 1.05,
    selectionOverlay: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0EB078).withValues(alpha: .10),
        borderRadius: BorderRadius.circular(9),
      ),
    ),
    childCount: values.length,
    onSelectedItemChanged: (index) => onSelected(values[index]),
    itemBuilder: (context, index) => Center(
      child: Text(label(values[index]), style: const TextStyle(fontSize: 16)),
    ),
  );
}
