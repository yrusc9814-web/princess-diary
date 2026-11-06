import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../data/taxonomy.dart';
import 'common.dart';
import 'pickers.dart';

class ClothesFilter {
  String name = '';
  Set<int> customCats = {};
  Set<String> cats = {};
  String status = '全部'; // 全部（不含丢弃）
  Set<String> seasons = {};
  Set<String> colors = {};
  Set<int> storages = {};
  Set<String> brands = {};
  double? priceMin, priceMax;
  DateTime? dateFrom, dateTo;
  Set<int> tags = {};
  Set<String> styles = {}, materials = {}, warmths = {}, silhouettes = {}, lengths = {}, layers = {};

  ClothesFilter copy() => ClothesFilter()
    ..name = name
    ..customCats = {...customCats}
    ..cats = {...cats}
    ..status = status
    ..seasons = {...seasons}
    ..colors = {...colors}
    ..storages = {...storages}
    ..brands = {...brands}
    ..priceMin = priceMin
    ..priceMax = priceMax
    ..dateFrom = dateFrom
    ..dateTo = dateTo
    ..tags = {...tags}
    ..styles = {...styles}
    ..materials = {...materials}
    ..warmths = {...warmths}
    ..silhouettes = {...silhouettes}
    ..lengths = {...lengths}
    ..layers = {...layers};

  int get activeCount {
    var n = 0;
    if (name.isNotEmpty) n++;
    if (status != '全部') n++;
    for (final s in [customCats, cats, seasons, colors, storages, brands, tags, styles, materials, warmths, silhouettes, lengths, layers]) {
      if (s.isNotEmpty) n++;
    }
    if (priceMin != null || priceMax != null) n++;
    if (dateFrom != null || dateTo != null) n++;
    return n;
  }

  List<Clothes> apply(List<Clothes> all, List<CustomCat> allCats) {
    // 选了一级自定义分类时包含其二级
    final cc = <int>{...customCats};
    for (final c in allCats) {
      if (c.parentId != null && customCats.contains(c.parentId)) cc.add(c.id!);
    }
    return all.where((c) {
      if (status == '全部' ? c.status == '丢弃' : c.status != status) return false;
      if (name.isNotEmpty && !c.displayName.contains(name) && !c.note.contains(name)) return false;
      if (cc.isNotEmpty && !cc.contains(c.customCatId)) return false;
      if (cats.isNotEmpty && !cats.contains(c.cat1OrUnknown)) return false;
      if (seasons.isNotEmpty && !c.seasons.any(seasons.contains)) return false;
      if (colors.isNotEmpty && !c.colors.any(colors.contains)) return false;
      if (storages.isNotEmpty && !storages.contains(c.storageId)) return false;
      if (brands.isNotEmpty && !brands.contains(c.brand)) return false;
      if (priceMin != null && (c.price ?? -1) < priceMin!) return false;
      if (priceMax != null && (c.price == null || c.price! > priceMax!)) return false;
      if (dateFrom != null && (c.purchaseDate == null || c.purchaseDate!.compareTo(fmtDate(dateFrom!)) < 0)) return false;
      if (dateTo != null && (c.purchaseDate == null || c.purchaseDate!.compareTo(fmtDate(dateTo!)) > 0)) return false;
      if (tags.isNotEmpty && !c.tagIds.any(tags.contains)) return false;
      bool one(Set<String> s, String? v) => s.isEmpty || s.contains(v);
      if (!one(styles, c.style) || !one(materials, c.material) || !one(warmths, c.warmth)) return false;
      if (!one(silhouettes, c.silhouette) || !one(lengths, c.length) || !one(layers, c.layer)) return false;
      return true;
    }).toList();
  }
}

/// 筛选条件底部弹窗
Future<ClothesFilter?> showClothesFilter(BuildContext context, ClothesFilter current, List<Clothes> all) async {
  final f = current.copy();
  final cats = await AppDb.I.customCats();
  final storages = await AppDb.I.dicts('storage');
  final tags = await AppDb.I.dicts('tag');
  final brands = all.map((e) => e.brand).whereType<String>().toSet().toList()..sort();
  final nameCtl = TextEditingController(text: f.name);
  final minCtl = TextEditingController(text: f.priceMin?.toString() ?? '');
  final maxCtl = TextEditingController(text: f.priceMax?.toString() ?? '');
  if (!context.mounted) return null;
  return showSheet<ClothesFilter>(
    context,
    (c) => StatefulBuilder(builder: (c, set) {
      Widget title(String t) => Padding(padding: const EdgeInsets.fromLTRB(0, 18, 0, 10), child: Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)));
      Widget chips<T>(Set<T> sel, List<T> opts, String Function(T) label, {Widget? Function(T)? icon}) => opts.isEmpty
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E2E6)), borderRadius: BorderRadius.circular(12)),
              child: const Text('暂无可选项', textAlign: TextAlign.center, style: TextStyle(color: kGrayText)),
            )
          : Wrap(spacing: 8, runSpacing: 8, children: [
              for (final o in opts)
                Pill(label(o), selected: sel.contains(o), icon: icon?.call(o), onTap: () => set(() => sel.contains(o) ? sel.remove(o) : sel.add(o))),
            ]);
      InputDecoration deco(String h) => InputDecoration(
            hintText: h,
            isDense: true,
            filled: true,
            fillColor: kCellBg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          );
      return SizedBox(
        height: MediaQuery.of(c).size.height * 0.88,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
            child: Row(children: [
              const Text('筛选条件', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton(
                onPressed: () => set(() {
                  final n = ClothesFilter();
                  nameCtl.clear();
                  minCtl.clear();
                  maxCtl.clear();
                  f
                    ..name = n.name
                    ..customCats.clear()
                    ..cats.clear()
                    ..status = '全部'
                    ..seasons.clear()
                    ..colors.clear()
                    ..storages.clear()
                    ..brands.clear()
                    ..priceMin = null
                    ..priceMax = null
                    ..dateFrom = null
                    ..dateTo = null
                    ..tags.clear()
                    ..styles.clear()
                    ..materials.clear()
                    ..warmths.clear()
                    ..silhouettes.clear()
                    ..lengths.clear()
                    ..layers.clear();
                }),
                child: const Text('重置', style: TextStyle(color: kGrayText)),
              ),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(c).viewInsets.bottom + 16), children: [
              title('名称'),
              TextField(controller: nameCtl, decoration: deco('输入名称关键词'), onChanged: (v) => f.name = v.trim()),
              title('自定义分类'),
              chips<int>(f.customCats, cats.map((e) => e.id!).toList(), (id) {
                final cat = cats.firstWhere((e) => e.id == id);
                final p = cats.where((e) => e.id == cat.parentId).firstOrNull;
                return p == null ? cat.name : '${p.name}/${cat.name}';
              }),
              title('衣物品类'),
              chips<String>(f.cats, [...sysCategories.keys, unrecognized], (s) => s),
              title('状态'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final s in ['全部', ...statusOptions])
                  Pill(s == '全部' ? '全部（不含丢弃）' : s, selected: f.status == s, onTap: () => set(() => f.status = s)),
              ]),
              title('季节'),
              chips<String>(f.seasons, seasonOptions, (s) => seasonShort[s]!),
              title('颜色'),
              chips<String>(f.colors, colorOptions.map((e) => e.name).toList(), (s) => s,
                  icon: (s) => Container(width: 12, height: 12, decoration: BoxDecoration(color: colorOf(s), shape: BoxShape.circle, border: Border.all(color: Colors.black26)))),
              title('收纳位置'),
              chips<int>(f.storages, storages.map((e) => e.id!).toList(), (id) => storages.firstWhere((e) => e.id == id).name),
              title('品牌'),
              chips<String>(f.brands, brands, (s) => s),
              title('价格范围'),
              Row(children: [
                Expanded(child: TextField(controller: minCtl, keyboardType: TextInputType.number, decoration: deco('最小'), onChanged: (v) => f.priceMin = double.tryParse(v))),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('-')),
                Expanded(child: TextField(controller: maxCtl, keyboardType: TextInputType.number, decoration: deco('最大'), onChanged: (v) => f.priceMax = double.tryParse(v))),
              ]),
              title('购买日期'),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final d = await pickDate(c, f.dateFrom, title: '开始日期');
                      if (d != null) set(() => f.dateFrom = d);
                    },
                    child: Text(f.dateFrom == null ? '开始日期' : fmtDate(f.dateFrom!)),
                  ),
                ),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('-')),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final d = await pickDate(c, f.dateTo, title: '结束日期');
                      if (d != null) set(() => f.dateTo = d);
                    },
                    child: Text(f.dateTo == null ? '结束日期' : fmtDate(f.dateTo!)),
                  ),
                ),
              ]),
              title('标签'),
              chips<int>(f.tags, tags.map((e) => e.id!).toList(), (id) => tags.firstWhere((e) => e.id == id).name),
              title('风格'),
              chips<String>(f.styles, styleOptions, (s) => s),
              title('材质'),
              chips<String>(f.materials, materialOptions, (s) => s),
              title('保暖度'),
              chips<String>(f.warmths, warmthOptions, (s) => s),
              title('轮廓'),
              chips<String>(f.silhouettes, silhouetteOptions, (s) => s),
              title('长度'),
              chips<String>(f.lengths, lengthOptions, (s) => s),
              title('叠穿角色'),
              chips<String>(f.layers, layerOptions, (s) => s),
            ]),
          ),
          BottomButtons(onCancel: () => Navigator.pop(c), onOk: () => Navigator.pop(c, f)),
        ]),
      );
    }),
  );
}

/// 分组
List<({String title, Color? dot, List<Clothes> items})> groupClothes(List<Clothes> list, String mode, List<CustomCat> cats) {
  final map = <String, List<Clothes>>{};
  final order = <String>[];
  void add(String k, Clothes c) {
    if (!map.containsKey(k)) order.add(k);
    map.putIfAbsent(k, () => []).add(c);
  }

  for (final c in list) {
    switch (mode) {
      case 'category':
        add(c.cat1OrUnknown, c);
      case 'color':
        add(c.colors.isEmpty ? '未设置颜色' : c.colors.first, c);
      default:
        final cat = cats.where((e) => e.id == c.customCatId).firstOrNull;
        final top = cat == null ? null : (cat.parentId == null ? cat : cats.where((e) => e.id == cat.parentId).firstOrNull ?? cat);
        add(top?.name ?? '未设置自定义分类', c);
    }
  }
  List<String> sortedKeys;
  switch (mode) {
    case 'category':
      final ref = [unrecognized, ...sysCategories.keys];
      sortedKeys = order..sort((a, b) => ref.indexOf(a).compareTo(ref.indexOf(b)));
    case 'color':
      final ref = [...colorOptions.map((e) => e.name), '未设置颜色'];
      sortedKeys = order..sort((a, b) => ref.indexOf(a).compareTo(ref.indexOf(b)));
    default:
      final ref = [...cats.where((e) => e.parentId == null).map((e) => e.name), '未设置自定义分类'];
      sortedKeys = order..sort((a, b) => ref.indexOf(a).compareTo(ref.indexOf(b)));
  }
  return [
    for (final k in sortedKeys) (title: k, dot: mode == 'color' && k != '未设置颜色' ? colorOf(k) : null, items: map[k]!),
  ];
}
