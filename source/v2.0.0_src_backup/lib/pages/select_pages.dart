import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../data/taxonomy.dart';
import '../widgets/clothes_filter.dart';
import '../widgets/common.dart';
import 'outfits_page.dart';

/// 选择单品（多选，点完成返回 id 列表）
class SelectClothesPage extends StatefulWidget {
  final List<int> initial;
  final bool single;
  final String title;
  final bool Function(Clothes)? where;
  const SelectClothesPage({super.key, this.initial = const [], this.single = false, this.title = '选择单品', this.where});
  @override
  State<SelectClothesPage> createState() => _SelectClothesPageState();
}

class _SelectClothesPageState extends State<SelectClothesPage> {
  List<Clothes> all = [];
  List<CustomCat> cats = [];
  late List<int> sel = [...widget.initial];
  ClothesFilter filter = ClothesFilter();
  String catChip = '全部';
  String mode = 'category';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await AppDb.I.allClothes();
    final c = await AppDb.I.customCats();
    if (mounted) {
      setState(() {
        all = widget.where == null ? a : a.where(widget.where!).toList();
        cats = c;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var list = filter.apply(all, cats);
    if (catChip != '全部') list = list.where((c) => c.cat1OrUnknown == catChip).toList();
    final groups = groupClothes(list, mode, cats);
    final chips = ['全部', ...sysCategories.keys.where((k) => all.any((c) => c.cat1 == k)), if (all.any((c) => c.cat1 == null)) unrecognized];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Badge(isLabelVisible: filter.activeCount > 0, label: Text('${filter.activeCount}'), child: const Icon(Icons.filter_list)),
            onPressed: () async {
              final f = await showClothesFilter(context, filter, all);
              if (f != null) setState(() => filter = f);
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.checkroom),
            onSelected: (v) => setState(() => mode = v),
            itemBuilder: (_) => [
              for (final e in const [('category', '按衣物品类'), ('color', '按主色'), ('custom', '按自定义分类')])
                PopupMenuItem(value: e.$1, child: Row(children: [Expanded(child: Text(e.$2)), if (mode == e.$1) const Icon(Icons.check, color: kPurple, size: 18)])),
            ],
          ),
          if (!widget.single)
            TextButton(onPressed: () => Navigator.pop(context, sel), child: Text(sel.isEmpty ? '完成' : '完成(${sel.length})', style: const TextStyle(fontSize: 16))),
        ],
      ),
      body: Column(children: [
        SizedBox(
          height: 52,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), children: [
            const Center(child: Text('衣物品类', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
            const SizedBox(width: 10),
            for (final c in chips)
              Padding(padding: const EdgeInsets.only(right: 8), child: Pill(c, square: true, selected: catChip == c, onTap: () => setState(() => catChip = c))),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: groups.isEmpty
              ? const EmptyState(icon: Icons.checkroom_outlined, title: '没有可选的单品')
              : ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                  for (final g in groups) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(g.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.8),
                      itemCount: g.items.length,
                      itemBuilder: (_, i) {
                        final c = g.items[i];
                        return ClothesTile(
                          c,
                          bg: const Color(0xFFFBF9FF),
                          selectable: !widget.single,
                          selected: sel.contains(c.id),
                          onTap: () {
                            if (widget.single) {
                              Navigator.pop(context, [c.id!]);
                              return;
                            }
                            setState(() => sel.contains(c.id) ? sel.remove(c.id) : sel.add(c.id!));
                          },
                        );
                      },
                    ),
                  ],
                ]),
        ),
      ]),
    );
  }
}

/// 选择穿搭
class SelectOutfitsPage extends StatefulWidget {
  final bool multi;
  final List<int> initial;
  const SelectOutfitsPage({super.key, this.multi = false, this.initial = const []});
  @override
  State<SelectOutfitsPage> createState() => _SelectOutfitsPageState();
}

class _SelectOutfitsPageState extends State<SelectOutfitsPage> {
  List<Outfit> all = [];
  Map<int, Clothes> cm = {};
  OutfitFilter filter = OutfitFilter();
  late List<int> sel = [...widget.initial];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await AppDb.I.outfits();
    final m = await AppDb.I.clothesMap();
    if (mounted) {
      setState(() {
        all = a;
        cm = m;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = filter.apply(all, cm);
    return Scaffold(
      appBar: AppBar(
        title: const Text('选择穿搭'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Badge(isLabelVisible: filter.count > 0, label: Text('${filter.count}'), child: const Icon(Icons.filter_list)),
            onPressed: () async {
              final f = await showOutfitFilter(context, filter);
              if (f != null) setState(() => filter = f);
            },
          ),
          if (widget.multi)
            TextButton(onPressed: () => Navigator.pop(context, sel), child: Text(sel.isEmpty ? '完成' : '完成(${sel.length})', style: const TextStyle(fontSize: 16))),
        ],
      ),
      body: list.isEmpty
          ? const EmptyState(icon: Icons.style_outlined, title: '没有可选的穿搭', sub: '先去「搭配」页创建搭配吧')
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.75),
              itemCount: list.length,
              itemBuilder: (_, i) => OutfitTile(
                list[i],
                showName: true,
                selectable: widget.multi,
                selected: sel.contains(list[i].id),
                onTap: () {
                  if (!widget.multi) {
                    Navigator.pop(context, [list[i].id!]);
                    return;
                  }
                  setState(() => sel.contains(list[i].id) ? sel.remove(list[i].id) : sel.add(list[i].id!));
                },
              ),
            ),
    );
  }
}
