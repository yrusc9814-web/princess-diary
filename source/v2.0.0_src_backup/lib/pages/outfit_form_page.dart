import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../data/taxonomy.dart';
import '../services/images.dart';
import '../services/taobao.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';
import 'clothes_detail_page.dart';
import 'collage_page.dart';
import 'select_pages.dart';
import 'tryon_page.dart';

/// 添加搭配 / 编辑搭配
class OutfitFormPage extends StatefulWidget {
  final Outfit outfit;
  final bool isNew;
  const OutfitFormPage({super.key, required this.outfit, this.isNew = false});
  @override
  State<OutfitFormPage> createState() => _OutfitFormPageState();
}

class _OutfitFormPageState extends State<OutfitFormPage> {
  late Outfit o;
  int tab = 0;
  Map<int, Clothes> cm = {};
  List<DictItem> occ = [], tags = [];
  final nameCtl = TextEditingController();
  final noteCtl = TextEditingController();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    o = Outfit.fromMap(widget.outfit.toMap());
    nameCtl.text = o.name;
    noteCtl.text = o.note;
    _load();
  }

  Future<void> _load() async {
    final m = await AppDb.I.clothesMap();
    final a = await AppDb.I.dicts('occasion');
    final t = await AppDb.I.dicts('outfit_tag');
    if (!mounted) return;
    setState(() {
      cm = m;
      occ = a;
      tags = t;
      if (widget.isNew && o.seasons.isEmpty) {
        // 由单品季节推断
        final items = o.clothesIds.map((e) => m[e]).whereType<Clothes>().where((c) => c.seasons.isNotEmpty).toList();
        if (items.isNotEmpty) {
          o.seasons = seasonOptions.where((s) => items.every((c) => c.seasons.contains(s))).toList();
        }
      }
    });
  }

  List<Clothes> get items => o.clothesIds.map((e) => cm[e]).whereType<Clothes>().toList();

  Future<void> _save() async {
    setState(() => saving = true);
    o.name = nameCtl.text.trim();
    o.note = noteCtl.text.trim();
    await AppDb.I.saveOutfit(o);
    if (!mounted) return;
    if (widget.isNew) {
      toast(null, '穿搭创建成功', style: 'dark');
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      toast(null, '保存成功');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final img = o.cover ?? (o.photos.isEmpty ? null : o.photos.first);
    return Scaffold(
      appBar: appBar(widget.isNew ? '添加搭配' : '编辑搭配', actions: [
        if (!widget.isNew)
          IconButton(
            tooltip: '记录到今天',
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: () async {
              await AppDb.I.addCal(CalRecord(date: todayStr(), outfitId: o.id));
              toast(null, '已记录到今天', style: 'dark');
            },
          ),
        PopupMenuButton<String>(
          onSelected: (v) async {
            switch (v) {
              case 'taobao':
                _taobao();
              case 'tryon':
                push(context, TryOnPage(initialClothes: o.clothesIds));
              case 'share':
                if (img != null) await Share.shareXFiles([XFile(ImageStore.abs(img))]);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'taobao', child: Row(children: [Icon(Icons.shopping_bag_outlined, size: 20), SizedBox(width: 10), Text('去淘宝搜同款')])),
            PopupMenuItem(value: 'tryon', child: Row(children: [Icon(Icons.auto_awesome, size: 20), SizedBox(width: 10), Text('AI 试衣')])),
            PopupMenuItem(value: 'share', child: Row(children: [Icon(Icons.share_outlined, size: 20), SizedBox(width: 10), Text('分享图片')])),
          ],
        ),
      ]),
      body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        Center(
          child: Container(
            width: w * 0.8,
            height: w * 0.8 * 1.15,
            margin: const EdgeInsets.only(top: 4, bottom: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: Stack(children: [
              Positioned.fill(child: AppImage(img, fit: o.type == 'photo' ? BoxFit.cover : BoxFit.contain, placeholder: Colors.white)),
              if (o.type == 'collage' && o.canvas.isNotEmpty)
                Positioned(
                  right: 10,
                  top: 10,
                  child: GestureDetector(
                    onTap: () async {
                      final r = await push<CollageResult>(context, CollagePage(canvasJson: o.canvas, returnResult: true));
                      if (r != null) {
                        setState(() {
                          o.cover = r.cover;
                          o.canvas = r.canvas;
                          o.clothesIds = r.clothesIds;
                        });
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
            _tab(1, '单品(${items.length})'),
            _tab(2, '穿搭照(${o.photos.length})'),
          ]),
        ),
        const SizedBox(height: 8),
        if (tab == 0) _basic(),
        if (tab == 1) _items(),
        if (tab == 2) _photos(),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Row(children: [
            if (!widget.isNew) ...[
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: const StadiumBorder(), foregroundColor: Colors.red),
                  onPressed: () async {
                    if (await confirm(context, '删除搭配', '确定删除这套搭配？日历和行程里的记录也会移除。', danger: true, ok: '删除')) {
                      await AppDb.I.deleteOutfit(o.id!);
                      if (context.mounted) Navigator.pop(context);
                      toast(null, '已删除');
                    }
                  },
                  child: const Text('删除'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: const StadiumBorder(), backgroundColor: kPurple),
                onPressed: saving ? null : _save,
                child: const Text('保存', style: TextStyle(fontSize: 16)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _taobao() {
    if (items.isEmpty) {
      toast(null, '这套搭配没有关联单品');
      return;
    }
    showSheet(
      context,
      (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SheetHandle(),
          const Padding(padding: EdgeInsets.all(8), child: Text('选择要搜同款的单品', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          for (final x in items)
            ListTile(
              leading: SizedBox(width: 44, height: 44, child: AppImage(x.listImage)),
              title: Text(Taobao.keywordOf(x)),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () async {
                Navigator.pop(c);
                if (!await Taobao.search(Taobao.keywordOf(x))) toast(null, '无法打开淘宝');
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
      scroll: false,
    );
  }

  Widget _tab(int i, String t) => GestureDetector(
        onTap: () => setState(() => tab = i),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Text(t, style: TextStyle(fontSize: 15.5, fontWeight: tab == i ? FontWeight.w700 : FontWeight.w400, color: tab == i ? Colors.black : kGrayText)),
        ),
      );

  Widget _basic() => Column(children: [
        FormGroup([
          FormRow('名称',
              valueWidget: TextField(
                controller: nameCtl,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: '未命名', hintStyle: TextStyle(color: kGrayText)),
              )),
          FormRow('场合', value: occ.where((e) => o.occasionIds.contains(e.id)).map((e) => e.name).join('、'), placeholder: '未设置', onTap: () async {
            final r = await pickDictMulti(context, 'occasion', o.occasionIds);
            if (r != null) setState(() => o.occasionIds = r);
            _load();
          }),
          FormRow('季节', value: o.seasons.join('、'), placeholder: '未设置', onTap: () async {
            final r = await pickSeasons(context, o.seasons);
            if (r != null) setState(() => o.seasons = r);
          }),
          FormRow('标签', value: tags.where((e) => o.tagIds.contains(e.id)).map((e) => e.name).join('、'), placeholder: '选择标签', onTap: () async {
            final r = await pickDictMulti(context, 'outfit_tag', o.tagIds);
            if (r != null) setState(() => o.tagIds = r);
            _load();
          }),
        ]),
        FormGroup([
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(padding: EdgeInsets.only(top: 10), child: Text('备注', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: noteCtl,
                  maxLines: 3,
                  minLines: 1,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(border: InputBorder.none, hintText: '请输入备注', hintStyle: TextStyle(color: kGrayText)),
                ),
              ),
            ]),
          ),
        ]),
      ]);

  Widget _items() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.78,
          children: [
            for (final c in items)
              Stack(children: [
                Positioned.fill(child: ClothesTile(c, showName: true, onTap: () => push(context, ClothesDetailPage(id: c.id!)))),
                Positioned(
                  right: 2,
                  top: 2,
                  child: GestureDetector(
                    onTap: () => setState(() => o.clothesIds.remove(c.id)),
                    child: const CircleAvatar(radius: 11, backgroundColor: Color(0x66000000), child: Icon(Icons.close, size: 14, color: Colors.white)),
                  ),
                ),
              ]),
            GestureDetector(
              onTap: () async {
                final r = await push<List<int>>(context, SelectClothesPage(initial: o.clothesIds));
                if (r != null) setState(() => o.clothesIds = r);
              },
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E2E6))),
                child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add, color: kGrayText), Text('添加单品', style: TextStyle(color: kGrayText, fontSize: 12))]),
              ),
            ),
          ],
        ),
      );

  Widget _photos() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.75,
          children: [
            for (final p in o.photos)
              Stack(children: [
                Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(12), child: AppImage(p, fit: BoxFit.cover))),
                Positioned(
                  right: 2,
                  top: 2,
                  child: GestureDetector(
                    onTap: () => setState(() => o.photos.remove(p)),
                    child: const CircleAvatar(radius: 11, backgroundColor: Color(0x66000000), child: Icon(Icons.close, size: 14, color: Colors.white)),
                  ),
                ),
              ]),
            GestureDetector(
              onTap: () async {
                final xs = await ImagePicker().pickMultiImage(maxWidth: 2000, maxHeight: 2000);
                for (final x in xs) {
                  final rel = await ImageStore.saveOriginal(x.path);
                  setState(() => o.photos.add(rel));
                }
              },
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E2E6))),
                child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo_outlined, color: kGrayText), SizedBox(height: 4), Text('添加穿搭照', style: TextStyle(color: kGrayText, fontSize: 12))]),
              ),
            ),
          ],
        ),
      );
}
