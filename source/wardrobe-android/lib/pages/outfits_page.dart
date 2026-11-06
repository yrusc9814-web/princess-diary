import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../data/taxonomy.dart';
import '../services/images.dart';
import '../widgets/common.dart';
import 'collage_page.dart';
import 'flip_page.dart';
import 'manage_pages.dart';
import 'outfit_form_page.dart';
import 'smart_outfit_page.dart';

class OutfitFilter {
  String keyword = '';
  String status = '全部';
  Set<int> occasions = {};
  Set<String> seasons = {};
  Set<int> tags = {};
  OutfitFilter copy() => OutfitFilter()
    ..keyword = keyword
    ..status = status
    ..occasions = {...occasions}
    ..seasons = {...seasons}
    ..tags = {...tags};
  int get count => (keyword.isEmpty ? 0 : 1) + (status == '全部' ? 0 : 1) + (occasions.isEmpty ? 0 : 1) + (seasons.isEmpty ? 0 : 1) + (tags.isEmpty ? 0 : 1);

  List<Outfit> apply(List<Outfit> list, Map<int, Clothes> cm) => list.where((o) {
        if (keyword.isNotEmpty && !o.name.contains(keyword)) return false;
        final sts = o.clothesIds.map((e) => cm[e]?.status).whereType<String>().toList();
        if (status == '全部') {
          if (sts.contains('丢弃')) return false;
        } else if (!sts.contains(status)) {
          return false;
        }
        if (occasions.isNotEmpty && !o.occasionIds.any(occasions.contains)) return false;
        if (seasons.isNotEmpty && !o.seasons.any(seasons.contains)) return false;
        if (tags.isNotEmpty && !o.tagIds.any(tags.contains)) return false;
        return true;
      }).toList();
}

class OutfitsPage extends StatefulWidget {
  const OutfitsPage({super.key});
  @override
  State<OutfitsPage> createState() => _OutfitsPageState();
}

class _OutfitsPageState extends State<OutfitsPage> with DataReload {
  List<Outfit> all = [];
  Map<int, Clothes> cm = {};
  List<DictItem> occasions = [];
  OutfitFilter filter = OutfitFilter();
  bool loaded = false;

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
    final a = await AppDb.I.outfits();
    final m = await AppDb.I.clothesMap();
    final occ = await AppDb.I.dicts('occasion');
    if (!mounted) return;
    setState(() {
      all = a;
      cm = m;
      occasions = occ;
      loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = filter.apply(all, cm);
    final groups = <({DictItem? occ, List<Outfit> items})>[];
    for (final o in occasions) {
      final items = list.where((e) => e.occasionIds.contains(o.id)).toList();
      if (items.isNotEmpty) groups.add((occ: o, items: items));
    }
    final none = list.where((e) => !e.occasionIds.any((id) => occasions.any((o) => o.id == id))).toList();
    if (none.isNotEmpty) groups.add((occ: null, items: none));
    final w = MediaQuery.of(context).size.width;
    final cardW = (w - 32) / 3.2;
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Row(children: [
          const Text('我的搭配', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => push(context, const SmartOutfitPage()),
            style: TextButton.styleFrom(foregroundColor: kRose, textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            icon: const Icon(Icons.auto_awesome, size: 19),
            label: const Text('智能搭配'),
          ),
        ]),
        actions: [
          IconButton(
            icon: Badge(isLabelVisible: filter.count > 0, label: Text('${filter.count}'), child: const Icon(Icons.filter_list)),
            onPressed: () async {
              final f = await showOutfitFilter(context, filter);
              if (f != null) setState(() => filter = f);
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) => v == 'occ'
                ? push(context, const DictManagePage(type: 'occasion', title: '场合管理'))
                : push(context, const DictManagePage(type: 'outfit_tag', title: '标签管理')),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'occ', child: Row(children: [Icon(Icons.event_outlined, size: 20), SizedBox(width: 10), Text('场合管理')])),
              PopupMenuItem(value: 'tag', child: Row(children: [Icon(Icons.sell_outlined, size: 20), SizedBox(width: 10), Text('标签管理')])),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddOutfitSheet(context),
        child: const Icon(Icons.add, size: 28),
      ),
      body: !loaded
          ? const Center(child: CircularProgressIndicator())
          : groups.isEmpty
              ? EmptyState(icon: Icons.style_outlined, image: all.isEmpty ? Illus.outfits : Illus.search, imageWidth: all.isEmpty ? 250 : 200, title: all.isEmpty ? '还没有搭配' : '没有符合条件的穿搭', sub: all.isEmpty ? '点击右下角 + 用拼图、翻牌或照片创建搭配' : null)
              : ListView(padding: const EdgeInsets.only(bottom: 90), children: [
                  for (final g in groups)
                    AppCard(
                      padding: const EdgeInsets.only(bottom: 14),
                      margin: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                      child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
                      child: Row(children: [
                        Expanded(
                          child: Row(children: [
                            Flexible(child: Text(g.occ?.name ?? '未分场合', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: kInk))),
                            const SizedBox(width: 8),
                            if (g.occ != null)
                              InkWell(
                                onTap: () => showAddOutfitSheet(context, occasionId: g.occ!.id),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(color: kRoseLight, borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.add, size: 16, color: kRose),
                                ),
                              ),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        Text('${g.items.length}个', style: const TextStyle(color: kGrayText)),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => push(context, OutfitGroupPage(title: g.occ?.name ?? '未分场合', ids: g.items.map((e) => e.id!).toList())),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(color: kRoseLight, borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.chevron_right, color: kRose),
                          ),
                        ),
                      ]),
                    ),
                    SizedBox(
                      height: cardW / 0.72,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        itemCount: g.items.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => SizedBox(width: cardW, child: OutfitTile(g.items[i], onTap: () => push(context, OutfitFormPage(outfit: g.items[i])))),
                      ),
                    ),
                      ]),
                    ),
                ]),
    );
  }
}

class OutfitGroupPage extends StatefulWidget {
  final String title;
  final List<int> ids;
  const OutfitGroupPage({super.key, required this.title, required this.ids});
  @override
  State<OutfitGroupPage> createState() => _OutfitGroupPageState();
}

class _OutfitGroupPageState extends State<OutfitGroupPage> with DataReload {
  List<Outfit> list = [];
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
    final a = await AppDb.I.outfits();
    if (mounted) setState(() => list = a.where((o) => widget.ids.contains(o.id)).toList());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: appBar('${widget.title}（${list.length}）'),
        body: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.75),
          itemCount: list.length,
          itemBuilder: (_, i) => OutfitTile(list[i], onTap: () => push(context, OutfitFormPage(outfit: list[i]))),
        ),
      );
}

/// 筛选穿搭
Future<OutfitFilter?> showOutfitFilter(BuildContext context, OutfitFilter cur) async {
  final f = cur.copy();
  final occ = await AppDb.I.dicts('occasion');
  final tags = await AppDb.I.dicts('outfit_tag');
  final ctl = TextEditingController(text: f.keyword);
  if (!context.mounted) return null;
  return showSheet<OutfitFilter>(
    context,
    (c) => StatefulBuilder(builder: (c, set) {
      Widget title(String t, {Widget? extra}) => Padding(
            padding: const EdgeInsets.fromLTRB(0, 18, 0, 10),
            child: Row(children: [Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)), if (extra != null) extra]),
          );
      const statusIcons = {'拥有': Icons.check_circle, '种草': Icons.favorite, '素材': Icons.inventory_2, '丢弃': Icons.delete};
      return SizedBox(
        height: MediaQuery.of(c).size.height * 0.82,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
            child: Row(children: [
              const Text('筛选穿搭', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton(
                onPressed: () => set(() {
                  ctl.clear();
                  f
                    ..keyword = ''
                    ..status = '全部'
                    ..occasions.clear()
                    ..seasons.clear()
                    ..tags.clear();
                }),
                child: const Text('重置', style: TextStyle(color: kGrayText)),
              ),
            ]),
          ),
          Expanded(
            child: ListView(padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(c).viewInsets.bottom + 16), children: [
              TextField(
                controller: ctl,
                onChanged: (v) => f.keyword = v.trim(),
                decoration: InputDecoration(
                  hintText: '输入穿搭名称关键词',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: const Color(0xFFF5D5DE))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: const Color(0xFFF5D5DE))),
                ),
              ),
              title('单品状态',
                  extra: IconButton(
                    icon: const Icon(Icons.info_outline, size: 16, color: kGrayText),
                    onPressed: () => toast(c, '按穿搭中包含的单品状态筛选'),
                  )),
              Wrap(spacing: 8, runSpacing: 8, children: [
                Pill('全部（不含丢弃）', selected: f.status == '全部', icon: const SizedBox.shrink(), onTap: () => set(() => f.status = '全部')),
                for (final s in statusOptions)
                  Pill(s, selected: f.status == s, icon: Icon(statusIcons[s], size: 16, color: f.status == s ? kRose : Colors.black54), onTap: () => set(() => f.status = s)),
              ]),
              title('适用场合'),
              occ.isEmpty
                  ? const Text('暂无场合', style: TextStyle(color: kGrayText))
                  : Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final o in occ)
                        Pill(o.name, selected: f.occasions.contains(o.id), onTap: () => set(() => f.occasions.contains(o.id) ? f.occasions.remove(o.id) : f.occasions.add(o.id!))),
                    ]),
              title('适用季节'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final s in const [('春季', Icons.local_florist_outlined), ('夏季', Icons.wb_sunny_outlined), ('秋季', Icons.eco_outlined), ('冬季', Icons.ac_unit)])
                  Pill(s.$1, selected: f.seasons.contains(s.$1), icon: Icon(s.$2, size: 16, color: f.seasons.contains(s.$1) ? kRose : Colors.black54),
                      onTap: () => set(() => f.seasons.contains(s.$1) ? f.seasons.remove(s.$1) : f.seasons.add(s.$1))),
              ]),
              title('穿搭标签'),
              tags.isEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 22),
                      decoration: BoxDecoration(border: Border.all(color: kPinkBorder), borderRadius: BorderRadius.circular(12)),
                      child: const Center(child: Text('暂无可用标签', style: TextStyle(color: kGrayText))),
                    )
                  : Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final t in tags)
                        Pill(t.name, selected: f.tags.contains(t.id), onTap: () => set(() => f.tags.contains(t.id) ? f.tags.remove(t.id) : f.tags.add(t.id!))),
                    ]),
            ]),
          ),
          BottomButtons(onCancel: () => Navigator.pop(c), onOk: () => Navigator.pop(c, f)),
        ]),
      );
    }),
  );
}

/// 添加搭配方式
void showAddOutfitSheet(BuildContext context, {int? occasionId}) {
  showSheet(
    context,
    (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SheetHandle(),
        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('添加搭配方式', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          leading: const IconTile(Icons.grid_view, size: 38, iconSize: 20),
          title: const Text('拼图'),
          subtitle: const Text('使用画布创建搭配拼图'),
          onTap: () {
            Navigator.pop(c);
            push(context, CollagePage(occasionId: occasionId));
          },
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          leading: const IconTile(Icons.style_outlined, size: 38, iconSize: 20),
          title: const Text('翻牌'),
          subtitle: const Text('翻动衣物，边选边看整套搭配'),
          onTap: () {
            Navigator.pop(c);
            push(context, FlipPage(occasionId: occasionId));
          },
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          leading: const IconTile(Icons.photo_outlined, size: 38, iconSize: 20),
          title: const Text('选择照片'),
          subtitle: const Text('从相册选择搭配照片'),
          onTap: () async {
            Navigator.pop(c);
            final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2000, maxHeight: 2000);
            if (x == null) return;
            final rel = await ImageStore.saveOriginal(x.path);
            if (context.mounted) {
              push(context, OutfitFormPage(outfit: Outfit(type: 'photo', cover: rel, occasionIds: occasionId == null ? [] : [occasionId]), isNew: true));
            }
          },
        ),
        const SizedBox(height: 8),
      ]),
    ),
    scroll: false,
  );
}
