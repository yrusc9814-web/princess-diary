import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../services/images.dart';
import '../services/settings.dart';
import '../services/tryon.dart';
import '../widgets/common.dart';
import 'outfit_form_page.dart';
import 'select_pages.dart';
import 'settings_page.dart';

/// AI 试衣（阿里云百炼，自行设计页面）
class TryOnPage extends StatefulWidget {
  final List<int> initialClothes;
  const TryOnPage({super.key, this.initialClothes = const []});
  @override
  State<TryOnPage> createState() => _TryOnPageState();
}

class _TryOnPageState extends State<TryOnPage> {
  String? model = Settings.p.getString('tryon_model_image');
  Clothes? top, bottom;
  bool running = false;
  String step = '';
  String? result;
  List<TryOnRecord> records = [];
  Map<int, Clothes> cm = {};

  bool _isTop(Clothes c) => const ['上装', '外套', '连衣裙', '连体装'].contains(c.cat1);
  bool _isBottom(Clothes c) => c.cat1 == '下装';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    cm = await AppDb.I.clothesMap();
    records = await AppDb.I.tryOnRecords();
    for (final id in widget.initialClothes) {
      final c = cm[id];
      if (c == null) continue;
      if (_isBottom(c)) {
        bottom ??= c;
      } else if (_isTop(c)) {
        top ??= c;
      } else {
        top ??= c;
      }
    }
    if (model != null && !File(ImageStore.abs(model!)).existsSync()) model = null;
    if (mounted) setState(() {});
  }

  Future<void> _pickModel(ImageSource src) async {
    final x = await ImagePicker().pickImage(source: src, maxWidth: 2000, maxHeight: 2000);
    if (x == null) return;
    final rel = await ImageStore.saveOriginal(x.path);
    Settings.p.setString('tryon_model_image', rel);
    setState(() => model = rel);
  }

  Future<void> _pick(bool isTop) async {
    final r = await push<List<int>>(
        context, SelectClothesPage(single: true, title: isTop ? '选择上装/连衣裙' : '选择下装', where: (c) => c.status != '丢弃' && (isTop ? _isTop(c) || c.cat1 == null : _isBottom(c) || c.cat1 == null)));
    if (r == null || r.isEmpty) return;
    setState(() => isTop ? top = cm[r.first] : bottom = cm[r.first]);
  }

  Future<File> _flatten(String rel) async {
    final bytes = await File(ImageStore.abs(rel)).readAsBytes();
    final jpg = await compute(_toWhiteJpg, bytes);
    return File('${Directory.systemTemp.path}/tryon_${DateTime.now().microsecondsSinceEpoch}.jpg')..writeAsBytesSync(jpg);
  }

  Future<void> _run() async {
    if (Settings.dashscopeKey.isEmpty) {
      final go = await confirm(context, '需要 API Key', 'AI 试衣使用阿里云百炼接口，请先在设置里填写 API Key。', ok: '去设置');
      if (go && mounted) await push(context, const SettingsPage());
      setState(() {});
      return;
    }
    if (model == null) {
      toast(null, '请先上传模特照片');
      return;
    }
    if (top == null && bottom == null) {
      toast(null, '请至少选择一件衣物');
      return;
    }
    setState(() {
      running = true;
      result = null;
      step = '准备图片';
    });
    try {
      final person = File(ImageStore.abs(model!));
      final t = top?.mainImage == null ? null : await _flatten(top!.mainImage!);
      final b = bottom?.mainImage == null ? null : await _flatten(bottom!.mainImage!);
      final bytes = await TryOn.run(person: person, top: t, bottom: b, onStep: (s) => mounted ? setState(() => step = s) : null);
      final rel = await ImageStore.saveBytes(bytes, 'tryon', 'jpg');
      await AppDb.I.addTryOn(TryOnRecord(modelImage: model!, result: rel, clothesIds: [if (top != null) top!.id!, if (bottom != null) bottom!.id!]));
      records = await AppDb.I.tryOnRecords();
      if (mounted) setState(() => result = rel);
    } catch (e) {
      toast(null, '$e'.replaceAll('Exception: ', '').replaceAll('HttpException: ', '').replaceAll('Bad state: ', ''), style: 'dark');
    }
    if (mounted) setState(() => running = false);
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: appBar('AI 试衣', actions: [
        IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => push(context, const SettingsPage()).then((_) => setState(() {}))),
      ]),
      body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        if (Settings.dashscopeKey.isEmpty)
          AppCard(
            color: kRoseBg,
            onTap: () => push(context, const SettingsPage()).then((_) => setState(() {})),
            child: const Row(children: [
              Icon(Icons.key_outlined, color: kRose),
              SizedBox(width: 10),
              Expanded(child: Text('使用前请在「设置 > AI 试衣」中填写阿里云百炼 API Key', style: TextStyle(color: kRose))),
              Icon(Icons.chevron_right, color: kRose),
            ]),
          ),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('模特照片', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('正面全身照、站立、光线均匀、单人，效果最好', style: TextStyle(color: kGrayText, fontSize: 12)),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GestureDetector(
                onTap: () => _pickModel(ImageSource.gallery),
                child: Container(
                  width: w * 0.36,
                  height: w * 0.48,
                  decoration: BoxDecoration(color: kCellBg, borderRadius: BorderRadius.circular(18), border: Border.all(color: kPinkBorder)),
                  clipBehavior: Clip.antiAlias,
                  child: model == null
                      ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Image.asset(Illus.tryon, width: w * 0.26, fit: BoxFit.contain),
                          const SizedBox(height: 6),
                          const Text('上传模特照', style: TextStyle(color: kRose, fontSize: 12, fontWeight: FontWeight.w600)),
                        ])
                      : AppImage(model, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(children: [
                  OutlinedButton.icon(onPressed: () => _pickModel(ImageSource.gallery), icon: const Icon(Icons.photo_outlined, size: 18), label: const Text('从相册选择')),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(onPressed: () => _pickModel(ImageSource.camera), icon: const Icon(Icons.photo_camera_outlined, size: 18), label: const Text('拍照')),
                ]),
              ),
            ]),
          ]),
        ),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('选择衣物', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('上装（或连衣裙）+ 下装，可只选其一', style: TextStyle(color: kGrayText, fontSize: 12)),
            const SizedBox(height: 12),
            Row(children: [
              _slot('上装 / 连衣裙', top, () => _pick(true), () => setState(() => top = null)),
              const SizedBox(width: 12),
              _slot('下装', bottom, () => _pick(false), () => setState(() => bottom = null)),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: kRose, shape: const StadiumBorder()),
              onPressed: running ? null : _run,
              icon: running ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.auto_awesome),
              label: Text(running ? step : '开始试衣', style: const TextStyle(fontSize: 16)),
            ),
          ),
        ),
        if (result != null) ...[
          const SectionTitle('试衣结果'),
          _resultCard(result!, [if (top != null) top!.id!, if (bottom != null) bottom!.id!]),
        ],
        if (records.isNotEmpty) ...[
          const SectionTitle('AI试衣记录'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.72,
              children: [
                for (final r in records)
                  GestureDetector(
                    onTap: () => showDialog(
                      context: context,
                      builder: (c) => Dialog(child: Padding(padding: const EdgeInsets.all(12), child: _resultCard(r.result, r.clothesIds, record: r, dialog: c))),
                    ),
                    child: ClipRRect(borderRadius: BorderRadius.circular(12), child: AppImage(r.result, fit: BoxFit.cover)),
                  ),
              ],
            ),
          ),
        ],
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Text('结果图由 AI 生成，仅供参考。生成需上传模特照和衣物图到阿里云百炼，按张计费。', style: TextStyle(fontSize: 11.5, color: kGrayText, height: 1.5)),
        ),
      ]),
    );
  }

  Widget _slot(String label, Clothes? c, VoidCallback onTap, VoidCallback onClear) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AspectRatio(
            aspectRatio: 0.85,
            child: Container(
              decoration: BoxDecoration(color: kCellBg, borderRadius: BorderRadius.circular(18), border: Border.all(color: c == null ? kPinkBorder : kRose, width: c == null ? 1.2 : 1.6)),
              clipBehavior: Clip.antiAlias,
              child: c == null
                  ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [const IconTile(Icons.add_rounded, size: 40, iconSize: 24), const SizedBox(height: 6), Text(label, style: const TextStyle(color: kGrayText, fontSize: 12))])
                  : Stack(children: [
                      Positioned.fill(child: Padding(padding: const EdgeInsets.all(8), child: AppImage(c.mainImage, placeholder: Colors.transparent))),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: GestureDetector(onTap: onClear, child: const CircleAvatar(radius: 11, backgroundColor: Color(0x66000000), child: Icon(Icons.close, size: 14, color: Colors.white))),
                      ),
                      Positioned(left: 6, bottom: 6, child: Text(label, style: const TextStyle(fontSize: 11, color: kGrayText))),
                    ]),
            ),
          ),
        ),
      );

  Widget _resultCard(String rel, List<int> ids, {TryOnRecord? record, BuildContext? dialog}) => Column(mainAxisSize: MainAxisSize.min, children: [
        ClipRRect(borderRadius: BorderRadius.circular(14), child: AppImage(rel, fit: BoxFit.contain)),
        const SizedBox(height: 8),
        const Text('AI 生成', style: TextStyle(fontSize: 11, color: kGrayText)),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          TextButton.icon(onPressed: () => Share.shareXFiles([XFile(ImageStore.abs(rel))]), icon: const Icon(Icons.share_outlined, size: 18), label: const Text('分享')),
          TextButton.icon(
            onPressed: () {
              if (dialog != null) Navigator.pop(dialog);
              push(context, OutfitFormPage(outfit: Outfit(type: 'photo', cover: rel, clothesIds: ids, name: 'AI 试衣'), isNew: true));
            },
            icon: const Icon(Icons.bookmark_add_outlined, size: 18),
            label: const Text('存为搭配'),
          ),
          if (record != null)
            TextButton.icon(
              onPressed: () async {
                await AppDb.I.deleteTryOn(record.id!);
                records = await AppDb.I.tryOnRecords();
                if (dialog != null && dialog.mounted) Navigator.pop(dialog);
                setState(() {});
              },
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('删除'),
            ),
        ]),
      ]);
}

Uint8List _toWhiteJpg(Uint8List b) {
  final im = img.decodeImage(b)!;
  final bg = img.Image(width: im.width, height: im.height)..clear(img.ColorRgb8(255, 255, 255));
  img.compositeImage(bg, im);
  return Uint8List.fromList(img.encodeJpg(bg, quality: 92));
}
