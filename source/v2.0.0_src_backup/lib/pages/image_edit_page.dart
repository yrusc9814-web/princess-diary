import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../services/cutout.dart';
import '../services/images.dart';
import '../widgets/common.dart';
import 'clothes_form_page.dart';

class EditedImage {
  final String image, original, thumb;
  EditedImage(this.image, this.original, this.thumb);
}

/// 编辑图片：裁剪 / 擦除 / 抠图 → 下一步
class ImageEditPage extends StatefulWidget {
  final String path; // 源图（绝对路径）
  final bool newClothes; // true: 下一步进入添加单品；false: 返回 EditedImage
  final bool autoCutout;
  const ImageEditPage({super.key, required this.path, this.newClothes = false, this.autoCutout = false});
  @override
  State<ImageEditPage> createState() => _ImageEditPageState();
}

class _ImageEditPageState extends State<ImageEditPage> {
  Uint8List? cur;
  Size imgSize = Size.zero;
  final undoStack = <Uint8List>[];
  String mode = ''; // '' / crop / erase
  bool busy = false;
  String busyText = '';
  // 擦除
  final strokes = <List<Offset>>[]; // 图片坐标
  double brush = 28;
  // 裁剪（0~1 归一化）
  Rect crop = const Rect.fromLTRB(0.05, 0.05, 0.95, 0.95);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final b = await compute(_normalize, await File(widget.path).readAsBytes());
      await _setImage(b, push: false);
      if (widget.autoCutout) _cutout();
    } catch (_) {
      if (!mounted) return;
      toast(context, '无法读取这张图片，请换一张试试', style: 'dark');
      Navigator.pop(context);
    }
  }

  Future<void> _setImage(Uint8List b, {bool push = true}) async {
    final decoded = await decodeImageFromList(b);
    if (push && cur != null) undoStack.add(cur!);
    setState(() {
      cur = b;
      imgSize = Size(decoded.width.toDouble(), decoded.height.toDouble());
    });
  }

  Future<void> _cutout() async {
    if (cur == null) return;
    setState(() {
      busy = true;
      busyText = '';
    });
    final tmp = File('${Directory.systemTemp.path}/cut_${DateTime.now().microsecondsSinceEpoch}.png')..writeAsBytesSync(cur!);
    final out = await Cutout.I.run(tmp);
    if (!mounted) return;
    setState(() => busy = false);
    if (out == null) {
      toast(context, '抠图失败，已保留原图', style: 'dark');
      return;
    }
    await _setImage(out);
    toast(context, '抠图完成', style: 'dark');
  }

  Future<void> _applyErase() async {
    if (strokes.isEmpty) {
      setState(() => mode = '');
      return;
    }
    setState(() => busy = true);
    final out = await compute(_erase, (cur!, strokes.map((s) => s.map((o) => [o.dx, o.dy]).toList()).toList(), brush * _scaleToImage));
    strokes.clear();
    await _setImage(out);
    setState(() {
      busy = false;
      mode = '';
    });
    if (mounted) toast(context, '擦除效果已应用', style: 'dark');
  }

  Future<void> _applyCrop() async {
    setState(() => busy = true);
    final r = Rect.fromLTRB(crop.left * imgSize.width, crop.top * imgSize.height, crop.right * imgSize.width, crop.bottom * imgSize.height);
    final out = await compute(_crop, (cur!, [r.left, r.top, r.width, r.height]));
    await _setImage(out);
    setState(() {
      busy = false;
      mode = '';
      crop = const Rect.fromLTRB(0.05, 0.05, 0.95, 0.95);
    });
  }

  double _scaleToImage = 1;

  Future<void> _next() async {
    if (cur == null) return;
    setState(() {
      busy = true;
      busyText = '正在保存图片…';
    });
    final original = await ImageStore.saveOriginal(widget.path);
    final image = await ImageStore.savePng(await compute(_toPng, cur!), 'img');
    final thumb = await ImageStore.makeThumb(image);
    if (!mounted) return;
    final r = EditedImage(image, original, thumb);
    if (widget.newClothes) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ClothesFormPage(newImage: r)));
    } else {
      Navigator.pop(context, r);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(mode == 'erase' ? '擦除' : (mode == 'crop' ? '裁剪' : '编辑图片')),
        centerTitle: false,
        actions: [
          if (mode == '' && undoStack.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: '撤销',
              onPressed: () async {
                final b = undoStack.removeLast();
                await _setImage(b, push: false);
              },
            ),
        ],
      ),
      body: Column(children: [
        if (mode == 'erase')
          Container(
            width: double.infinity,
            color: kPurpleBg,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: const Text('拖动手指在图片上进行擦除', textAlign: TextAlign.center, style: TextStyle(color: kPurple)),
          ),
        Expanded(
          child: cur == null
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(builder: (c, cons) {
                  final box = Size(cons.maxWidth - 32, cons.maxHeight - 32);
                  final fitted = applyBoxFit(BoxFit.contain, imgSize, box).destination;
                  final rect = Rect.fromLTWH(16 + (box.width - fitted.width) / 2, 16 + (box.height - fitted.height) / 2, fitted.width, fitted.height);
                  _scaleToImage = imgSize.width / fitted.width;
                  return Stack(children: [
                    Positioned.fromRect(rect: rect, child: Checkerboard(child: Image.memory(cur!, fit: BoxFit.fill, gaplessPlayback: true))),
                    if (mode == 'erase')
                      Positioned.fromRect(
                        rect: rect,
                        child: GestureDetector(
                          onPanStart: (d) => setState(() => strokes.add([d.localPosition * _scaleToImage])),
                          onPanUpdate: (d) => setState(() => strokes.last.add(d.localPosition * _scaleToImage)),
                          child: CustomPaint(painter: _StrokePainter(strokes, brush, 1 / _scaleToImage)),
                        ),
                      ),
                    if (mode == 'crop') ..._cropOverlay(rect),
                    if (busy)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 16)]),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            const CircularProgressIndicator(),
                            if (busyText.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(busyText)),
                          ]),
                        ),
                      ),
                  ]);
                }),
        ),
        SafeArea(top: false, child: _bottom()),
      ]),
    );
  }

  Widget _bottom() {
    if (mode == 'erase') {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Text('画笔粗细', style: TextStyle(fontSize: 13)),
            Expanded(child: Slider(value: brush, min: 8, max: 80, onChanged: (v) => setState(() => brush = v))),
          ]),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() {
                  strokes.clear();
                  mode = '';
                })),
            const Text('擦除', style: TextStyle(fontWeight: FontWeight.w600)),
            IconButton(icon: const Icon(Icons.undo), onPressed: strokes.isEmpty ? null : () => setState(() => strokes.removeLast())),
            IconButton(icon: const Icon(Icons.check), onPressed: busy ? null : _applyErase),
          ]),
        ]),
      );
    }
    if (mode == 'crop') {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => mode = '')),
          TextButton(onPressed: () => setState(() => crop = const Rect.fromLTRB(0, 0, 1, 1)), child: const Text('全图')),
          const Text('裁剪', style: TextStyle(fontWeight: FontWeight.w600)),
          IconButton(icon: const Icon(Icons.check), onPressed: busy ? null : _applyCrop),
        ]),
      );
    }
    Widget tool(IconData i, String t, VoidCallback f) => Expanded(
          child: InkWell(
            onTap: busy || cur == null ? null : f,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(children: [Icon(i), const SizedBox(height: 4), Text(t, style: const TextStyle(fontSize: 12))]),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          tool(Icons.crop, '裁剪', () => setState(() => mode = 'crop')),
          tool(Icons.auto_fix_normal, '擦除', () {
            setState(() => mode = 'erase');
            toast(context, '擦除模式已开启，拖动手指在图片上进行擦除', style: 'dark');
          }),
          tool(Icons.content_cut, '抠图', _cutout),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kPurple, shape: const StadiumBorder()),
            onPressed: busy || cur == null ? null : _next,
            child: const Text('下一步', style: TextStyle(fontSize: 16)),
          ),
        ),
      ]),
    );
  }

  List<Widget> _cropOverlay(Rect r) {
    final cr = Rect.fromLTRB(r.left + crop.left * r.width, r.top + crop.top * r.height, r.left + crop.right * r.width, r.top + crop.bottom * r.height);
    void move(Offset d, {bool l = false, bool t = false, bool rr = false, bool b = false, bool all = false}) {
      final dx = d.dx / r.width, dy = d.dy / r.height;
      var c = crop;
      if (all) {
        final nx = (c.left + dx).clamp(0.0, 1 - c.width), ny = (c.top + dy).clamp(0.0, 1 - c.height);
        c = Rect.fromLTWH(nx, ny, c.width, c.height);
      } else {
        c = Rect.fromLTRB(
          l ? (c.left + dx).clamp(0.0, c.right - 0.08) : c.left,
          t ? (c.top + dy).clamp(0.0, c.bottom - 0.08) : c.top,
          rr ? (c.right + dx).clamp(c.left + 0.08, 1.0) : c.right,
          b ? (c.bottom + dy).clamp(c.top + 0.08, 1.0) : c.bottom,
        );
      }
      setState(() => crop = c);
    }

    Widget handle(Offset at, {bool l = false, bool t = false, bool rr = false, bool b = false}) => Positioned(
          left: at.dx - 18,
          top: at.dy - 18,
          child: GestureDetector(
            onPanUpdate: (d) => move(d.delta, l: l, t: t, rr: rr, b: b),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              child: Container(width: 18, height: 18, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: kPurple, width: 3))),
            ),
          ),
        );
    return [
      Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _CropShade(cr)))),
      Positioned.fromRect(rect: cr, child: GestureDetector(onPanUpdate: (d) => move(d.delta, all: true), child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2))))),
      handle(cr.topLeft, l: true, t: true),
      handle(cr.topRight, rr: true, t: true),
      handle(cr.bottomLeft, l: true, b: true),
      handle(cr.bottomRight, rr: true, b: true),
    ];
  }
}

class _StrokePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final double width;
  final double scale; // 图片坐标 → 显示坐标
  _StrokePainter(this.strokes, this.width, this.scale);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x993D7BFD)
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final s in strokes) {
      if (s.isEmpty) continue;
      final path = Path()..moveTo(s.first.dx * scale, s.first.dy * scale);
      for (final o in s.skip(1)) {
        path.lineTo(o.dx * scale, o.dy * scale);
      }
      if (s.length == 1) path.lineTo(s.first.dx * scale + 0.1, s.first.dy * scale);
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _CropShade extends CustomPainter {
  final Rect r;
  _CropShade(this.r);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..addRect(Offset.zero & size)
      ..addRect(r)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(p, Paint()..color = const Color(0x88000000));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ---------------------------------------------------------------- isolate 工具
Uint8List _normalize(Uint8List b) {
  var im = img.bakeOrientation(img.decodeImage(b)!);
  if (im.width > 1600 || im.height > 1600) {
    im = im.width >= im.height ? img.copyResize(im, width: 1600) : img.copyResize(im, height: 1600);
  }
  return im.hasAlpha ? Uint8List.fromList(img.encodePng(im)) : Uint8List.fromList(img.encodeJpg(im, quality: 92));
}

Uint8List _toPng(Uint8List b) {
  final im = img.decodeImage(b)!;
  return Uint8List.fromList(img.encodePng(im));
}

Uint8List _erase((Uint8List, List<List<List<double>>>, double) a) {
  final im = img.decodeImage(a.$1)!.convert(numChannels: 4);
  final r = a.$3 / 2;
  final r2 = r * r;
  void dot(double cx, double cy) {
    final x0 = math.max(0, (cx - r).floor()), x1 = math.min(im.width - 1, (cx + r).ceil());
    final y0 = math.max(0, (cy - r).floor()), y1 = math.min(im.height - 1, (cy + r).ceil());
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final dx = x - cx, dy = y - cy;
        if (dx * dx + dy * dy <= r2) im.getPixel(x, y).a = 0;
      }
    }
  }

  for (final s in a.$2) {
    for (var i = 0; i < s.length; i++) {
      if (i == 0) {
        dot(s[0][0], s[0][1]);
        continue;
      }
      final p0 = s[i - 1], p1 = s[i];
      final dist = math.sqrt(math.pow(p1[0] - p0[0], 2) + math.pow(p1[1] - p0[1], 2));
      final steps = math.max(1, (dist / math.max(1, r / 2)).ceil());
      for (var k = 1; k <= steps; k++) {
        dot(p0[0] + (p1[0] - p0[0]) * k / steps, p0[1] + (p1[1] - p0[1]) * k / steps);
      }
    }
  }
  return Uint8List.fromList(img.encodePng(im));
}

Uint8List _crop((Uint8List, List<double>) a) {
  final im = img.decodeImage(a.$1)!;
  final x = a.$2[0].round().clamp(0, im.width - 1), y = a.$2[1].round().clamp(0, im.height - 1);
  final w = a.$2[2].round().clamp(1, im.width - x), h = a.$2[3].round().clamp(1, im.height - y);
  return Uint8List.fromList(img.encodePng(img.copyCrop(im, x: x, y: y, width: w, height: h)));
}
