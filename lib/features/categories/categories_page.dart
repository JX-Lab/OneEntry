import 'package:flutter/material.dart';

import '../../data/ledger_controller.dart';
import '../../models/ledger_models.dart';
import '../../theme/app_theme.dart';
import '../entry/entry_sheet.dart' show categoryIconFromKey, categoryIconGroups;

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({required this.controller, super.key});

  final LedgerController controller;

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  EntryType _type = EntryType.expense;
  bool _selecting = false;
  final Set<String> _selected = <String>{};

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (BuildContext context, Widget? child) {
      final List<LedgerCategory> categories = widget.controller
          .categoriesFor(_type)
          .toList();
      return Scaffold(
        appBar: AppBar(
          title: Text(_selecting ? '已选 ${_selected.length} 个' : '标签管理'),
          leading: _selecting
              ? IconButton(
                  onPressed: _exitSelection,
                  icon: const Icon(Icons.close),
                )
              : null,
          actions: <Widget>[
            TextButton(
              onPressed: () => setState(() {
                _selecting = !_selecting;
                if (!_selecting) _selected.clear();
              }),
              child: Text(_selecting ? '完成' : '多选'),
            ),
          ],
        ),
        body: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SegmentedButton<EntryType>(
                segments: const <ButtonSegment<EntryType>>[
                  ButtonSegment<EntryType>(
                    value: EntryType.expense,
                    label: Text('支出'),
                    icon: Icon(Icons.arrow_upward),
                  ),
                  ButtonSegment<EntryType>(
                    value: EntryType.income,
                    label: Text('收入'),
                    icon: Icon(Icons.arrow_downward),
                  ),
                ],
                selected: <EntryType>{_type},
                onSelectionChanged: (value) => setState(() {
                  _type = value.first;
                  _selected.clear();
                }),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '拖动右侧把手调整显示顺序；点按标签可修改名称和图标。',
                  style: TextStyle(fontSize: 12, color: Color(0xFF8A9099)),
                ),
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                buildDefaultDragHandles: false,
                itemCount: categories.length,
                onReorder: _selecting
                    ? (_, _) {}
                    : (oldIndex, newIndex) =>
                          _reorder(categories, oldIndex, newIndex),
                itemBuilder: (BuildContext context, int index) {
                  final LedgerCategory category = categories[index];
                  final bool selected = _selected.contains(category.name);
                  return Card(
                    key: ValueKey<String>(category.name),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: _selecting
                          ? Checkbox(
                              value: selected,
                              onChanged: (_) => _toggle(category.name),
                            )
                          : CircleAvatar(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              child: Icon(categoryIconFromKey(category.icon)),
                            ),
                      title: Text(
                        category.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(category.custom ? '自定义标签' : '默认标签'),
                      trailing: _selecting
                          ? null
                          : ReorderableDragStartListener(
                              index: index,
                              child: const Padding(
                                padding: EdgeInsets.all(10),
                                child: Icon(Icons.drag_handle),
                              ),
                            ),
                      onTap: _selecting
                          ? () => _toggle(category.name)
                          : () => _editCategory(category),
                      onLongPress: _selecting
                          ? null
                          : () {
                              setState(() {
                                _selecting = true;
                                _selected.add(category.name);
                              });
                            },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: _selecting
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _editCategory(null),
                icon: const Icon(Icons.add),
                label: const Text('新建标签'),
              ),
        bottomNavigationBar: _selecting
            ? SafeArea(
                top: false,
                child: Material(
                  elevation: 12,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                    child: Row(
                      children: <Widget>[
                        TextButton(
                          onPressed: () => setState(() {
                            if (_selected.length == categories.length) {
                              _selected.clear();
                            } else {
                              _selected
                                ..clear()
                                ..addAll(categories.map((item) => item.name));
                            }
                          }),
                          child: Text(
                            _selected.length == categories.length
                                ? '取消全选'
                                : '全选',
                          ),
                        ),
                        const Spacer(),
                        FilledButton.tonal(
                          onPressed: _selected.isEmpty ? null : _mergeSelected,
                          child: const Text('合并到'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _selected.isEmpty
                              ? null
                              : _archiveSelected,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.expense,
                          ),
                          child: const Text('移除'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : null,
      );
    },
  );

  void _toggle(String name) => setState(() {
    if (!_selected.add(name)) _selected.remove(name);
  });

  void _exitSelection() => setState(() {
    _selecting = false;
    _selected.clear();
  });

  Future<void> _reorder(
    List<LedgerCategory> categories,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex > oldIndex) newIndex--;
    final List<LedgerCategory> reordered = categories.toList();
    final LedgerCategory moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    await widget.controller.reorderCategories(
      reordered.map((item) => item.name).toList(),
    );
  }

  Future<void> _mergeSelected() async {
    if (_selected.contains('其他')) {
      _message('“其他”是导入和兜底标签，不能作为被合并标签');
      return;
    }
    final List<LedgerCategory> targets = widget.controller
        .categoriesFor(_type)
        .where((category) => !_selected.contains(category.name))
        .toList();
    if (targets.isEmpty) {
      _message('需要至少保留一个未选中的目标标签');
      return;
    }
    final String? target = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const ListTile(
              title: Text(
                '合并到哪个标签？',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '选中标签关联的账目、预算和周期账目会一起转移',
                textAlign: TextAlign.center,
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: targets
                    .map(
                      (category) => ListTile(
                        leading: Icon(categoryIconFromKey(category.icon)),
                        title: Text(category.name),
                        onTap: () => Navigator.pop(context, category.name),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
    if (target == null || !mounted) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('合并 ${_selected.length} 个标签？'),
        content: Text('这些标签会被合并到“$target”，原标签随后删除。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('合并'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.controller.mergeCategories(_selected.toList(), target);
    if (mounted) {
      _exitSelection();
      _message('标签已合并到“$target”');
    }
  }

  Future<void> _archiveSelected() async {
    final List<String> removable = _selected
        .where((name) => name != '其他')
        .toList();
    if (removable.isEmpty) {
      _message('“其他”是导入和兜底标签，不能移除');
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('移除 ${removable.length} 个标签？'),
        content: const Text('历史账目不会删除，但这些标签不再出现在记一笔的可选列表中。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.controller.archiveCategories(removable);
    if (mounted) _exitSelection();
  }

  Future<void> _editCategory(LedgerCategory? existing) async {
    final TextEditingController nameController = TextEditingController(
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
    final bool? save = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter update) => AlertDialog(
          title: Text(existing == null ? '新建标签' : '编辑标签'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: nameController,
                  autofocus: false,
                  decoration: const InputDecoration(labelText: '标签名称'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categoryIconGroups.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (BuildContext context, int index) {
                      final String item = categoryIconGroups.keys.elementAt(
                        index,
                      );
                      return ChoiceChip(
                        label: Text(item),
                        selected: item == group,
                        showCheckmark: false,
                        onSelected: (_) => update(() {
                          group = item;
                          if (!categoryIconGroups[group]!.contains(icon)) {
                            icon = categoryIconGroups[group]!.first;
                          }
                        }),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: categoryIconGroups[group]!.length,
                  itemBuilder: (BuildContext context, int index) {
                    final String key = categoryIconGroups[group]![index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => update(() => icon = key),
                      child: Container(
                        decoration: BoxDecoration(
                          color: icon == key
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(categoryIconFromKey(key), size: 20),
                      ),
                    );
                  },
                ),
              ],
            ),
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
    if (save != true) return;
    final String name = nameController.text.trim();
    if (name.isEmpty) {
      _message('请输入标签名称');
      return;
    }
    if (widget.controller.categories.any(
      (category) => category.name == name && category.name != existing?.name,
    )) {
      _message('已有同名标签；如需整理，请使用多选合并');
      return;
    }
    if (existing == null) {
      await widget.controller.addCategory(name, _type, icon);
    } else {
      await widget.controller.updateCategory(existing.name, name, icon);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
