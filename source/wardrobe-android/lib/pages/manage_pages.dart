import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';

/// 自定义分类管理（两级，长按拖动排序）
class CustomCatManagePage extends StatefulWidget {
  const CustomCatManagePage({super.key});
  @override
  State<CustomCatManagePage> createState() => _CustomCatManagePageState();
}

class _CustomCatManagePageState extends State<CustomCatManagePage> with DataReload {
  List<CustomCat> cats = [];
  Map<int, int> usage = {};
  final expanded = <int>{};

  @override
  void initState() {
    super.initState();
    listenData(dataVersion);
    reload();
  }

  @override
  void dispose() {
    unlistenData(dataVersion);
    super.dispose();
  }

  @override
  Future<void> reload() async {
    final c = await AppDb.I.customCats();
    final u = <int, int>{};
    for (final x in await AppDb.I.allClothes()) {
      if (x.customCatId != null) u[x.customCatId!] = (u[x.customCatId!] ?? 0) + 1;
    }
    if (mounted) {
      setState(() {
        cats = c;
        usage = u;
      });
    }
  }

  Future<void> _menu(CustomCat c) async {
    final v = await showSheet<String>(
      context,
      (s) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SheetHandle(),
          if (c.parentId == null) ListTile(leading: const Icon(Icons.add), title: const Text('添加二级自定义分类'), onTap: () => Navigator.pop(s, 'sub')),
          ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('编辑'), onTap: () => Navigator.pop(s, 'edit')),
          ListTile(leading: const Icon(Icons.delete_outline, color: Colors.red), title: const Text('删除', style: TextStyle(color: Colors.red)), onTap: () => Navigator.pop(s, 'del')),
        ]),
      ),
      scroll: false,
    );
    if (!mounted) return;
    switch (v) {
      case 'sub':
        await addCustomCatDialog(context, parentId: c.id);
        expanded.add(c.id!);
      case 'edit':
        await addCustomCatDialog(context, edit: c);
      case 'del':
        final kids = cats.where((e) => e.parentId == c.id).length;
        final n = usage[c.id] ?? 0;
        if (await confirm(context, '删除自定义分类', '确定删除「${c.name}」${kids > 0 ? '及其 $kids 个二级自定义分类' : ''}？${n > 0 ? '可能影响已使用该分类的 $n 件衣物。' : ''}',
            danger: true, ok: '删除')) {
          await AppDb.I.deleteCustomCat(c.id!);
          toast(null, '已删除');
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tops = cats.where((e) => e.parentId == null).toList();
    return Scaffold(
      appBar: appBar('自定义分类管理', actions: [
        IconButton(icon: const Icon(Icons.add), onPressed: () => addCustomCatDialog(context)),
      ]),
      body: Column(children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: Text('点击可展开二级自定义分类；长按拖动可修改自定义分类排序', style: TextStyle(color: kRose, fontSize: 13)),
        ),
        Expanded(
          child: tops.isEmpty
              ? EmptyState(
                  icon: Icons.category_outlined,
                  title: '暂无自定义分类',
                  sub: '点击右上角“+”创建新分类',
                  action: FilledButton.icon(onPressed: () => addCustomCatDialog(context), icon: const Icon(Icons.add), label: const Text('添加自定义分类')))
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: tops.length,
                  onReorder: (a, b) async {
                    if (b > a) b--;
                    final ids = tops.map((e) => e.id!).toList();
                    final x = ids.removeAt(a);
                    ids.insert(b, x);
                    await AppDb.I.reorderCustomCats(ids);
                  },
                  itemBuilder: (_, i) {
                    final t = tops[i];
                    final kids = cats.where((e) => e.parentId == t.id).toList();
                    final open = expanded.contains(t.id);
                    return Container(
                      key: ValueKey(t.id),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(20), boxShadow: kCardShadow),
                      child: Column(children: [
                        ListTile(
                          leading: const IconTile(Icons.folder_outlined, size: 38, iconSize: 20),
                          title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${usage[t.id] ?? 0}件${kids.isEmpty ? '' : ' · ${kids.length}个二级分类'}${t.description.isEmpty ? '' : ' · ${t.description}'}'),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (kids.isNotEmpty) Icon(open ? Icons.expand_less : Icons.expand_more),
                            IconButton(icon: const Icon(Icons.more_horiz), onPressed: () => _menu(t)),
                          ]),
                          onTap: () => setState(() => open ? expanded.remove(t.id) : expanded.add(t.id!)),
                        ),
                        if (open)
                          for (final k in kids)
                            ListTile(
                              contentPadding: const EdgeInsets.only(left: 40, right: 8),
                              leading: const Icon(Icons.subdirectory_arrow_right, size: 18),
                              title: Text(k.name),
                              subtitle: Text('${usage[k.id] ?? 0}件'),
                              trailing: IconButton(icon: const Icon(Icons.more_horiz), onPressed: () => _menu(k)),
                            ),
                      ]),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

/// 标签管理 / 穿搭标签管理 / 场合管理
class DictManagePage extends StatefulWidget {
  final String type;
  final String title;
  const DictManagePage({super.key, required this.type, required this.title});
  @override
  State<DictManagePage> createState() => _DictManagePageState();
}

class _DictManagePageState extends State<DictManagePage> with DataReload {
  List<DictItem> items = [];
  String get noun => widget.type == 'occasion' ? '场合' : '标签';

  @override
  void initState() {
    super.initState();
    listenData(dataVersion);
    reload();
  }

  @override
  void dispose() {
    unlistenData(dataVersion);
    super.dispose();
  }

  @override
  Future<void> reload() async {
    final d = await AppDb.I.dicts(widget.type);
    if (mounted) setState(() => items = d);
  }

  Future<void> _add() async {
    final n = await inputDialog(context, '添加$noun', hint: '$noun名称');
    if (n == null || n.isEmpty) return;
    if (items.any((e) => e.name == n)) {
      toast(context, '$noun已存在');
      return;
    }
    await AppDb.I.addDict(widget.type, n);
    toast(null, '保存成功');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: appBar(widget.title, actions: [IconButton(icon: const Icon(Icons.add), onPressed: _add)]),
        body: items.isEmpty
            ? EmptyState(
                icon: Icons.sell_outlined,
                title: '暂无$noun',
                action: FilledButton.icon(onPressed: _add, icon: const Icon(Icons.add), label: Text('添加$noun')),
              )
            : ReorderableListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                onReorder: (a, b) async {
                  if (b > a) b--;
                  final ids = items.map((e) => e.id!).toList();
                  final x = ids.removeAt(a);
                  ids.insert(b, x);
                  await AppDb.I.reorderDicts(ids);
                },
                itemBuilder: (_, i) {
                  final d = items[i];
                  return Container(
                    key: ValueKey(d.id),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(18), boxShadow: kCardShadow),
                    child: ListTile(
                      leading: Icon(widget.type == 'occasion' ? Icons.event_outlined : Icons.sell_outlined, color: kRose),
                      title: Text(d.name),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () async {
                            final n = await inputDialog(context, '编辑$noun', initial: d.name);
                            if (n != null && n.isNotEmpty) {
                              d.name = n;
                              await AppDb.I.updateDict(d);
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () async {
                            if (await confirm(context, '删除$noun', '确定删除「${d.name}」？已使用的${widget.type == 'tag' ? '衣物' : '穿搭'}会移除该$noun。', danger: true, ok: '删除')) {
                              await AppDb.I.deleteDict(d);
                            }
                          },
                        ),
                      ]),
                    ),
                  );
                },
              ),
      );
}

/// 收纳位置管理（自行设计）
class StorageManagePage extends StatefulWidget {
  const StorageManagePage({super.key});
  @override
  State<StorageManagePage> createState() => _StorageManagePageState();
}

class _StorageManagePageState extends State<StorageManagePage> with DataReload {
  List<DictItem> items = [];
  Map<int, int> usage = {};

  @override
  void initState() {
    super.initState();
    listenData(dataVersion);
    reload();
  }

  @override
  void dispose() {
    unlistenData(dataVersion);
    super.dispose();
  }

  @override
  Future<void> reload() async {
    final d = await AppDb.I.dicts('storage');
    final u = <int, int>{};
    for (final c in await AppDb.I.allClothes()) {
      if (c.storageId != null) u[c.storageId!] = (u[c.storageId!] ?? 0) + 1;
    }
    if (mounted) {
      setState(() {
        items = d;
        usage = u;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: appBar('收纳位置管理', actions: [IconButton(icon: const Icon(Icons.add), onPressed: () => addStorageDialog(context))]),
        body: items.isEmpty
            ? EmptyState(
                icon: Icons.inventory_2_outlined,
                title: '暂无收纳位置',
                sub: '记录衣物放在哪个衣柜、抽屉或收纳箱，找起来更方便',
                action: FilledButton.icon(onPressed: () => addStorageDialog(context), icon: const Icon(Icons.add), label: const Text('添加收纳位置')),
              )
            : ReorderableListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                onReorder: (a, b) async {
                  if (b > a) b--;
                  final ids = items.map((e) => e.id!).toList();
                  final x = ids.removeAt(a);
                  ids.insert(b, x);
                  await AppDb.I.reorderDicts(ids);
                },
                itemBuilder: (_, i) {
                  final d = items[i];
                  return Container(
                    key: ValueKey(d.id),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(20), boxShadow: kCardShadow),
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
                      leading: CircleAvatar(backgroundColor: kRoseLight, child: const Icon(Icons.inventory_2_outlined, color: kRose, size: 20)),
                      title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${usage[d.id] ?? 0}件衣物${d.description.isEmpty ? '' : ' · ${d.description}'}'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => addStorageDialog(context, edit: d)),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () async {
                            final n = usage[d.id] ?? 0;
                            if (await confirm(context, '删除收纳位置', '确定删除「${d.name}」？${n > 0 ? '$n 件衣物的收纳位置将被清空。' : ''}', danger: true, ok: '删除')) {
                              await AppDb.I.deleteDict(d);
                            }
                          },
                        ),
                      ]),
                    ),
                  );
                },
              ),
      );
}
