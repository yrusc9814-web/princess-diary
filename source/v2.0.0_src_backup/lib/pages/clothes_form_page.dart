import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../data/taxonomy.dart';
import '../services/images.dart';
import '../services/settings.dart';
import '../services/tagger.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';
import 'clothes_detail_page.dart';
import 'image_edit_page.dart';

/// 添加单品 / 编辑单品。所有字段选填。
class ClothesFormPage extends StatefulWidget {
  final EditedImage? newImage;
  final Clothes? edit;
  final Clothes? preset; // 批量/网页导入时预填
  const ClothesFormPage({super.key, this.newImage, this.edit, this.preset});
  @override
  State<ClothesFormPage> createState() => _ClothesFormPageState();
}

class _ClothesFormPageState extends State<ClothesFormPage> {
  late Clothes c;
  List<CustomCat> cats = [];
  List<DictItem> storages = [], tags = [];
  bool saving = false;
  bool recognizing = false;
  final priceCtl = TextEditingController();
  final extraCtl = TextEditingController();
  final noteCtl = TextEditingController();
  final nameCtl = TextEditingController();

  bool get isNew => widget.edit == null;

  @override
  void initState() {
    super.initState();
    c = widget.edit?.copy() ?? widget.preset?.copy() ?? Clothes();
    if (widget.newImage != null) {
      c.image = widget.newImage!.image;
      c.originalImage = widget.newImage!.original;
      c.thumb = widget.newImage!.thumb;
      c.source = 'camera';
    }
    priceCtl.text = c.price == null ? '' : _num(c.price!);
    extraCtl.text = c.extraWear == 0 ? '' : '${c.extraWear}';
    noteCtl.text = c.note;
    nameCtl.text = c.name;
    _loadDicts();
    if (isNew && widget.preset == null && Settings.autoRecognize && c.mainImage != null) _recognize();
  }

  String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(1) : '$v';

  Future<void> _loadDicts() async {
    final a = await AppDb.I.customCats();
    final s = await AppDb.I.dicts('storage');
    final t = await AppDb.I.dicts('tag');
    if (mounted) {
      setState(() {
        cats = a;
        storages = s;
        tags = t;
      });
    }
  }

  Future<void> _recognize() async {
    setState(() => recognizing = true);
    try {
      final r = await Tagger.analyze(File(ImageStore.abs(c.mainImage!)));
      if (!mounted) return;
      setState(() {
        c.cat1 ??= r.cat1;
        if (c.cat2 == null && c.cat1 == r.cat1) c.cat2 = r.cat2;
        if (c.colors.isEmpty) c.colors = r.colors;
        if (c.seasons.isEmpty) c.seasons = r.seasons;
        c.material ??= r.material;
        c.style ??= r.style;
        c.warmth ??= r.warmth;
        c.silhouette ??= r.silhouette;
        c.length ??= r.length;
        c.layer ??= r.layer;
      });
      if (r.cat1 != null && Settings.remindNewCategory) toast(context, '已识别为 ${r.cat2 ?? r.cat1}，可随时修改', style: 'dark');
    } catch (_) {}
    if (mounted) setState(() => recognizing = false);
  }

  String? get customCatText {
    final cat = cats.where((e) => e.id == c.customCatId).firstOrNull;
    if (cat == null) return null;
    final p = cats.where((e) => e.id == cat.parentId).firstOrNull;
    return p == null ? cat.name : '${p.name} / ${cat.name}';
  }

  Future<void> _save() async {
    setState(() => saving = true);
    c.name = nameCtl.text.trim();
    c.price = double.tryParse(priceCtl.text.trim());
    c.extraWear = int.tryParse(extraCtl.text.trim()) ?? 0;
    c.note = noteCtl.text.trim();
    final id = await AppDb.I.saveClothes(c);
    if (!mounted) return;
    if (isNew) {
      toast(context, '衣物保存成功', style: 'success');
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ClothesDetailPage(id: id)));
    } else {
      toast(context, '衣物更新成功', style: 'success');
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: appBar(isNew ? '添加单品' : '编辑单品'),
      body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        Center(
          child: Container(
            width: w * 0.62,
            height: w * 0.62 * 1.05,
            margin: const EdgeInsets.fromLTRB(0, 4, 0, 16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: Stack(children: [
              Positioned.fill(child: Padding(padding: const EdgeInsets.all(12), child: AppImage(c.mainImage, placeholder: Colors.white))),
              Positioned(
                left: 10,
                top: 10,
                child: GestureDetector(
                  onTap: () async {
                    final r = await pickColors(context, c.colors, recognize: c.mainImage == null
                        ? null
                        : () async => (await Tagger.analyze(File(ImageStore.abs(c.mainImage!)), colorsOnly: true)).colors);
                    if (r != null) setState(() => c.colors = r);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0x55000000), borderRadius: BorderRadius.circular(14)),
                    child: c.colors.isEmpty
                        ? const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.palette_outlined, color: Colors.white, size: 16),
                            SizedBox(width: 3),
                            Text('颜色', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ])
                        : ColorDots(c.colors, size: 14),
                  ),
                ),
              ),
              Positioned(
                right: 10,
                top: 10,
                child: GestureDetector(
                  onTap: c.mainImage == null && c.originalImage == null
                      ? null
                      : () async {
                          final r = await push<EditedImage>(context, ImageEditPage(path: ImageStore.abs(c.originalImage ?? c.mainImage!)));
                          if (r != null) {
                            setState(() {
                              c.image = r.image;
                              c.thumb = r.thumb;
                            });
                          }
                        },
                  child: const CircleAvatar(radius: 16, backgroundColor: Color(0x55000000), child: Icon(Icons.edit, color: Colors.white, size: 17)),
                ),
              ),
              if (recognizing)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 8,
                  child: Center(
                    child: Chip(
                      avatar: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                      label: Text('识别中…', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ),
            ]),
          ),
        ),
        FormGroup([
          FormRow('名称',
              valueWidget: TextField(
                controller: nameCtl,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: '未命名', hintStyle: TextStyle(color: kGrayText)),
              )),
          FormRow('衣物品类', value: c.catText, onTap: () async {
            final r = await pickSysCategory(context, c.cat1, c.cat2);
            if (r != null) {
              setState(() {
                c.cat1 = r.value?.first;
                c.cat2 = (r.value?.length ?? 0) > 1 ? r.value![1] : null;
              });
            }
          }),
          FormRow('自定义分类', value: customCatText, onTap: () async {
            final r = await pickCustomCat(context, c.customCatId);
            if (r != null) setState(() => c.customCatId = r.value);
            _loadDicts();
          }),
          FormRow('状态', value: c.status, onTap: () async {
            final r = await pickStatus(context, c.status);
            if (r != null) setState(() => c.status = r);
          }),
          FormRow('季节', value: c.seasons.map((e) => seasonShort[e]).join('、'), onTap: () async {
            final r = await pickSeasons(context, c.seasons);
            if (r != null) setState(() => c.seasons = r);
          }),
          FormRow('收纳位置', value: storages.where((e) => e.id == c.storageId).firstOrNull?.name, placeholder: '未设置', onTap: () async {
            final r = await pickStorage(context, c.storageId);
            await _loadDicts();
            if (r != null) setState(() => c.storageId = r.value);
          }),
        ]),
        FormGroup([
          FormRow('品牌', value: c.brand, placeholder: '选择品牌', onTap: () async {
            final r = await pickBrand(context, c.brand);
            if (r != null) setState(() => c.brand = r.value);
          }),
          FormRow('价格',
              valueWidget: TextField(
                controller: priceCtl,
                textAlign: TextAlign.right,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: '请输入价格', hintStyle: TextStyle(color: kGrayText)),
              )),
          FormRow('补充穿着次数',
              sub: '日历穿着次数：${c.calWear}',
              valueWidget: TextField(
                controller: extraCtl,
                textAlign: TextAlign.right,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: '请输入补充次数', hintStyle: TextStyle(color: kGrayText)),
              )),
          FormRow('购买日期', value: c.purchaseDate, placeholder: '选择日期', onTap: () async {
            final d = await pickDate(context, c.purchaseDate == null ? DateTime.now() : DateTime.tryParse(c.purchaseDate!), title: '选择购买日期');
            if (d != null) setState(() => c.purchaseDate = fmtDate(d));
          }),
        ]),
        FormGroup([
          FormRow('标签', value: tags.where((e) => c.tagIds.contains(e.id)).map((e) => e.name).join('、'), placeholder: '选择标签', onTap: () async {
            final r = await pickDictMulti(context, 'tag', c.tagIds);
            await _loadDicts();
            if (r != null) setState(() => c.tagIds = r);
          }),
        ]),
        FormGroup([
          _opt('风格', styleOptions, c.style, (v) => c.style = v),
          _opt('材质', materialOptions, c.material, (v) => c.material = v),
          _opt('保暖度', warmthOptions, c.warmth, (v) => c.warmth = v),
          _opt('轮廓', silhouetteOptions, c.silhouette, (v) => c.silhouette = v),
          _opt('长度', lengthOptions, c.length, (v) => c.length = v),
          _opt('叠穿角色', layerOptions, c.layer, (v) => c.layer = v),
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
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: SizedBox(
            height: 50,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kPurple, shape: const StadiumBorder()),
              onPressed: saving ? null : _save,
              child: saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('保存', style: TextStyle(fontSize: 16)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _opt(String label, List<String> opts, String? cur, void Function(String?) set) => FormRow(label, value: cur, placeholder: '未设置', onTap: () async {
        final r = await pickOption(context, '选择$label', opts, cur);
        if (r != null) setState(() => set(r.value));
      });
}
