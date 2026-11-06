import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../services/images.dart';
import '../services/recommend.dart';
import '../services/taobao.dart';
import '../widgets/common.dart';
import 'clothes_form_page.dart';
import 'filter_settings_page.dart';
import 'image_edit_page.dart';
import 'outfit_form_page.dart';
import 'smart_outfit_page.dart';
import 'tryon_page.dart';

class ClothesDetailPage extends StatefulWidget {
  final int id;
  const ClothesDetailPage({super.key, required this.id});
  @override
  State<ClothesDetailPage> createState() => _ClothesDetailPageState();
}

class _ClothesDetailPageState extends State<ClothesDetailPage> with DataReload {
  Clothes? c;
  List<Outfit> mine = [];
  List<Suggestion> smart = [];
  List<CustomCat> cats = [];
  List<DictItem> storages = [], tags = [];
  int tab = 0;
  bool missing = false;
  int seed = 0;

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
    final x = await AppDb.I.clothesById(widget.id);
    if (x == null) {
      if (mounted) setState(() => missing = true);
      return;
    }
    final os = (await AppDb.I.outfits()).where((o) => o.clothesIds.contains(widget.id)).toList();
    final all = await AppDb.I.allClothes();
    final ctx = Ctx(temp: null, season: seasonOf(DateTime.now()), today: DateTime.now());
    final sm = Recommender(all, ctx, anchorId: widget.id).generate(count: 6, seed: seed);
    cats = await AppDb.I.customCats();
    storages = await AppDb.I.dicts('storage');
    tags = await AppDb.I.dicts('tag');
    if (!mounted) return;
    setState(() {
      c = x;
      mine = os;
      smart = sm;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (missing) return Scaffold(appBar: appBar('单品详情'), body: const EmptyState(icon: Icons.delete_outline, title: '该单品已删除'));
    final x = c;
    final w = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: appBar('单品详情', actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: x == null
              ? null
              : () async {
                  if (await confirm(context, '删除单品', '确定删除这件单品？相关穿搭、日历和行程里的记录也会移除。', danger: true, ok: '删除')) {
                    await AppDb.I.deleteClothes(x.id!);
                    if (context.mounted) {
                      Navigator.pop(context);
                      toast(null, '已删除');
                    }
                  }
                },
        ),
        IconButton(icon: const Icon(Icons.edit_outlined), onPressed: x == null ? null : () => push(context, ClothesFormPage(edit: x))),
      ]),
      body: x == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.only(bottom: 32), children: [
              Center(
                child: Container(
                  width: w * 0.8,
                  height: w * 0.8 * 1.05,
                  margin: const EdgeInsets.only(top: 4, bottom: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(children: [
                    Positioned.fill(child: Padding(padding: const EdgeInsets.all(14), child: AppImage(x.mainImage, placeholder: Colors.white))),
                    if (x.colors.isNotEmpty)
                      Positioned(
                        left: 10,
                        top: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0x44000000), borderRadius: BorderRadius.circular(14)),
                          child: ColorDots(x.colors, size: 14),
                        ),
                      ),
                    Positioned(
                      right: 10,
                      top: 10,
                      child: GestureDetector(
                        onTap: () async {
                          final src = x.originalImage ?? x.mainImage;
                          if (src == null) return;
                          final r = await push<EditedImage>(context, ImageEditPage(path: ImageStore.abs(src)));
                          if (r != null) {
                            x.image = r.image;
                            x.thumb = r.thumb;
                            await AppDb.I.saveClothes(x);
                            toast(null, '衣物更新成功', style: 'success');
                          }
                        },
                        child: const CircleAvatar(radius: 16, backgroundColor: Color(0x44000000), child: Icon(Icons.edit, color: Colors.white, size: 17)),
                      ),
                    ),
                  ]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _tab(0, '基本信息'),
                  _tab(1, '智能搭配(${smart.length})'),
                  _tab(2, '我的搭配(${mine.length})'),
                ]),
              ),
              const SizedBox(height: 8),
              if (tab == 0) _basic(x),
              if (tab == 1) _smart(),
              if (tab == 2) _mine(),
            ]),
    );
  }

  Widget _tab(int i, String t) => GestureDetector(
        onTap: () => setState(() => tab = i),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Text(t, style: TextStyle(fontSize: 15.5, fontWeight: tab == i ? FontWeight.w700 : FontWeight.w400, color: tab == i ? Colors.black : kGrayText)),
        ),
      );

  Widget _basic(Clothes x) {
    final cat = cats.where((e) => e.id == x.customCatId).firstOrNull;
    final pcat = cat == null ? null : cats.where((e) => e.id == cat.parentId).firstOrNull;
    final cells = <(String, String, String?)>[
      ('状态', x.status, null),
      ('衣物品类', x.catText.isEmpty ? '未识别' : x.catText, null),
      ('穿着次数', '${x.wearCount} 次', '补充穿着次数：${x.extraWear} 次'),
      if (cat != null) ('自定义分类', pcat == null ? cat.name : '${pcat.name} / ${cat.name}', null),
      if (x.seasons.isNotEmpty) ('季节', x.seasons.join('、'), null),
      if (x.storageId != null) ('收纳位置', storages.where((e) => e.id == x.storageId).firstOrNull?.name ?? '-', null),
      if (x.brand != null) ('品牌', x.brand!, null),
      if (x.price != null) ('价格', '¥${x.price}', x.wearCount > 0 ? '单次成本：¥${(x.price! / x.wearCount).toStringAsFixed(2)}' : null),
      if (x.purchaseDate != null) ('购买日期', x.purchaseDate!, null),
      if (x.lastWear != null) ('上次穿着', x.lastWear!, null),
      if (x.tagIds.isNotEmpty) ('标签', tags.where((e) => x.tagIds.contains(e.id)).map((e) => e.name).join('、'), null),
      if (x.style != null) ('风格', x.style!, null),
      if (x.material != null) ('材质', x.material!, null),
      if (x.warmth != null) ('保暖度', x.warmth!, null),
      if (x.silhouette != null) ('轮廓', x.silhouette!, null),
      if (x.length != null) ('长度', x.length!, null),
      if (x.layer != null) ('叠穿角色', x.layer!, null),
      if (x.colors.isNotEmpty) ('颜色', x.colors.join('、'), null),
      if (x.note.isNotEmpty) ('备注', x.note, null),
    ];
    // 两列排布，长值占整行
    final rows = <Widget>[];
    final pending = <(String, String, String?)>[];
    Widget cell((String, String, String?) e) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: kCellBg, borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(TextSpan(children: [
              TextSpan(text: '${e.$1}：', style: const TextStyle(color: kGrayText)),
              TextSpan(text: e.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
            ])),
            if (e.$3 != null) Padding(padding: const EdgeInsets.only(top: 3), child: Text(e.$3!, style: const TextStyle(fontSize: 11.5, color: kGrayText))),
          ]),
        );
    void flush() {
      if (pending.isEmpty) return;
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: cell(pending[0])),
            const SizedBox(width: 8),
            Expanded(child: pending.length > 1 ? cell(pending[1]) : const SizedBox()),
          ]),
        ),
      ));
      pending.clear();
    }

    for (final e in cells) {
      if (e.$2.length + e.$1.length > 11) {
        flush();
        rows.add(Padding(padding: const EdgeInsets.only(bottom: 8), child: SizedBox(width: double.infinity, child: cell(e))));
      } else {
        pending.add(e);
        if (pending.length == 2) flush();
      }
    }
    flush();
    return Column(children: [
      AppCard(padding: const EdgeInsets.fromLTRB(14, 14, 14, 6), child: Column(children: rows)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(shape: const StadiumBorder(), minimumSize: const Size.fromHeight(44)),
              onPressed: () async {
                if (!await Taobao.search(Taobao.keywordOf(x))) toast(null, '无法打开淘宝');
              },
              icon: const Icon(Icons.shopping_bag_outlined, size: 18),
              label: const Text('去淘宝搜同款'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(shape: const StadiumBorder(), minimumSize: const Size.fromHeight(44)),
              onPressed: () => push(context, TryOnPage(initialClothes: [x.id!])),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('AI 试衣'),
            ),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: FilledButton.tonalIcon(
          style: FilledButton.styleFrom(shape: const StadiumBorder(), minimumSize: const Size.fromHeight(44)),
          onPressed: () async {
            await AppDb.I.addCal(CalRecord(date: todayStr(), clothesId: x.id));
            toast(null, '已记录到今天', style: 'dark');
          },
          icon: const Icon(Icons.calendar_today_outlined, size: 18),
          label: const Text('今天穿了'),
        ),
      ),
    ]);
  }

  Widget _smart() => Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            TextButton.icon(
              onPressed: () => push(context, const FilterSettingsPage()).then((_) => reload()),
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: const Text('过滤设置'),
            ),
            const Spacer(),
            IconButton(
              tooltip: '换一批',
              onPressed: () {
                seed++;
                reload();
              },
              icon: const Icon(Icons.refresh, size: 20),
            ),
            TextButton.icon(
              onPressed: () => showOutfitRules(context),
              icon: const Icon(Icons.info_outline, size: 18),
              label: const Text('搭配说明'),
            ),
          ]),
        ),
        if (smart.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            child: Text('本次未生成可用搭配，可尝试补充同搭配位单品', textAlign: TextAlign.center, style: TextStyle(color: kGrayText)),
          )
        else
          for (var i = 0; i < smart.length; i++) SuggestionCard(smart[i], index: i + 1),
      ]);

  Widget _mine() => mine.isEmpty
      ? const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Text('还没有包含这件单品的搭配', textAlign: TextAlign.center, style: TextStyle(color: kGrayText)),
        )
      : GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.66),
          itemCount: mine.length,
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => push(context, OutfitFormPage(outfit: mine[i])),
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.antiAlias,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: AppImage(mine[i].cover ?? (mine[i].photos.isEmpty ? null : mine[i].photos.first), width: double.infinity, fit: BoxFit.cover)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                  child: Text(mine[i].name.isEmpty ? '未命名' : mine[i].name, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
          ),
        );
}
