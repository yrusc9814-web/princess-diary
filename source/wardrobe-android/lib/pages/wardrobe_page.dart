import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../services/settings.dart';
import '../widgets/clothes_filter.dart';
import '../widgets/common.dart';
import 'batch_add_page.dart';
import 'clothes_detail_page.dart';
import 'image_edit_page.dart';
import 'manage_pages.dart';
import 'web_import_page.dart';

class WardrobePage extends StatefulWidget {
  const WardrobePage({super.key});
  @override
  State<WardrobePage> createState() => _WardrobePageState();
}

class _WardrobePageState extends State<WardrobePage> with DataReload {
  List<Clothes> all = [];
  List<CustomCat> cats = [];
  ClothesFilter filter = ClothesFilter();
  String mode = Settings.groupMode;
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
    final a = await AppDb.I.allClothes();
    final c = await AppDb.I.customCats();
    if (!mounted) return;
    setState(() {
      all = a;
      cats = c;
      loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = filter.apply(all, cats);
    final groups = groupClothes(list, mode, cats);
    final w = MediaQuery.of(context).size.width;
    final cardW = (w - 32) / 3.2;
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的单品', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
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
            icon: const Icon(Icons.category),
            tooltip: '分组方式',
            onSelected: (v) {
              Settings.groupMode = v;
              setState(() => mode = v);
            },
            itemBuilder: (_) => [
              for (final e in const [('category', '按衣物品类'), ('color', '按主色'), ('custom', '按自定义分类')])
                PopupMenuItem(
                  value: e.$1,
                  child: Row(children: [
                    Expanded(child: Text(e.$2)),
                    if (mode == e.$1) const Icon(Icons.check, color: kRose, size: 18),
                  ]),
                ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              switch (v) {
                case 'cat':
                  push(context, const CustomCatManagePage());
                case 'tag':
                  push(context, const DictManagePage(type: 'tag', title: '标签管理'));
                case 'storage':
                  push(context, const StorageManagePage());
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'cat', child: Row(children: [Icon(Icons.folder_outlined, size: 20), SizedBox(width: 10), Text('自定义分类管理')])),
              PopupMenuItem(value: 'tag', child: Row(children: [Icon(Icons.sell_outlined, size: 20), SizedBox(width: 10), Text('标签管理')])),
              PopupMenuItem(value: 'storage', child: Row(children: [Icon(Icons.inventory_2_outlined, size: 20), SizedBox(width: 10), Text('收纳位置管理')])),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddClothesSheet(context),
        child: const Icon(Icons.add, size: 28),
      ),
      body: !loaded
          ? const Center(child: CircularProgressIndicator())
          : groups.isEmpty
              ? EmptyState(
                  icon: Icons.checkroom_outlined,
                  image: all.isEmpty ? Illus.clothes : Illus.search,
                  title: all.isEmpty ? '开始建立你的衣橱' : '没有符合条件的单品',
                  sub: all.isEmpty ? '点击右下角 + 拍照、从相册或网页导入衣物' : null,
                )
              : ListView(padding: const EdgeInsets.only(bottom: 90), children: [
                  for (final g in groups)
                    AppCard(
                      padding: const EdgeInsets.only(bottom: 14),
                      margin: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                      child: Column(children: [
                    InkWell(
                      onTap: () => push(context, ClothesGroupPage(title: g.title, ids: g.items.map((e) => e.id!).toList())),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
                        child: Row(children: [
                          Expanded(
                            child: Row(children: [
                              Flexible(child: Text(g.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: kInk))),
                              if (g.dot != null) ...[
                                const SizedBox(width: 6),
                                Container(width: 12, height: 12, decoration: BoxDecoration(color: g.dot, shape: BoxShape.circle, border: Border.all(color: Colors.black26))),
                              ],
                            ]),
                          ),
                          const SizedBox(width: 8),
                          Text('${g.items.length}件', style: const TextStyle(color: kGrayText)),
                          const Icon(Icons.chevron_right, color: kRoseSoft),
                        ]),
                      ),
                    ),
                    SizedBox(
                      height: cardW / 0.78,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        itemCount: g.items.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => SizedBox(
                          width: cardW,
                          child: ClothesTile(g.items[i], onTap: () => push(context, ClothesDetailPage(id: g.items[i].id!))),
                        ),
                      ),
                    ),
                      ]),
                    ),
                ]),
    );
  }
}

/// 分组全部单品
class ClothesGroupPage extends StatefulWidget {
  final String title;
  final List<int> ids;
  const ClothesGroupPage({super.key, required this.title, required this.ids});
  @override
  State<ClothesGroupPage> createState() => _ClothesGroupPageState();
}

class _ClothesGroupPageState extends State<ClothesGroupPage> with DataReload {
  List<Clothes> list = [];
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
    final m = await AppDb.I.clothesMap();
    if (mounted) setState(() => list = widget.ids.map((e) => m[e]).whereType<Clothes>().toList());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: appBar('${widget.title}（${list.length}）'),
        body: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.78),
          itemCount: list.length,
          itemBuilder: (_, i) => ClothesTile(list[i], onTap: () => push(context, ClothesDetailPage(id: list[i].id!))),
        ),
      );
}

/// 添加单品方式
void showAddClothesSheet(BuildContext context) {
  showSheet(
    context,
    (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SheetHandle(),
        _addTile(c, Icons.photo_camera_outlined, '拍照', null, () async {
          Navigator.pop(c);
          final x = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 2400, maxHeight: 2400);
          if (x != null && context.mounted) push(context, ImageEditPage(path: x.path, newClothes: true));
        }),
        _addTile(c, Icons.photo_outlined, '从相册选择', null, () async {
          Navigator.pop(c);
          final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2400, maxHeight: 2400);
          if (x != null && context.mounted) push(context, ImageEditPage(path: x.path, newClothes: true));
        }),
        _addTile(c, Icons.photo_library_outlined, '从相册选择（批量添加）', '一次选择多张图片，单次最多30张', () async {
          Navigator.pop(c);
          final xs = await ImagePicker().pickMultiImage(maxWidth: 2400, maxHeight: 2400, limit: 30);
          if (xs.isEmpty || !context.mounted) return;
          if (xs.length > 30) toast(context, '单次最多30张，已取前30张');
          push(context, BatchAddPage(paths: xs.take(30).map((e) => e.path).toList()));
        }),
        _addTile(c, Icons.shopping_bag_outlined, '淘宝导入', '支持淘宝、京东、唯品会、拼多多', () {
          Navigator.pop(c);
          push(context, const WebImportPage());
        }),
        const SizedBox(height: 8),
      ]),
    ),
    scroll: false,
  );
}

Widget _addTile(BuildContext c, IconData icon, String title, String? sub, VoidCallback onTap) => ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      leading: IconTile(icon, size: 40),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      subtitle: sub == null ? null : Text(sub, style: const TextStyle(fontSize: 12.5, color: kGrayText)),
      onTap: onTap,
    );
