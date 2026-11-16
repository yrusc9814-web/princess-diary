import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../services/images.dart';
import '../widgets/common.dart';
import 'image_edit_page.dart';
import 'outfit_form_page.dart';
import 'select_pages.dart';

/// 把「旋转后局部坐标系」里的位移换算回屏幕坐标系的位移。
///
/// GestureDetector 在 Transform.rotate 内部，[ScaleUpdateDetails.focalPointDelta] 是
/// 旋转之后局部坐标下的位移，直接加到 e.x/e.y 上会导致：旋转 180° 时上下左右全反，
/// 旋转 90° 时左右变上下。这里按 [rot] 正向旋转回去，得到屏幕上真实的拖动方向。
Offset rotateDelta(Offset d, double rot) {
  final c = math.cos(rot);
  final s = math.sin(rot);
  return Offset(d.dx * c - d.dy * s, d.dx * s + d.dy * c);
}

class CollageResult {
  final String cover, canvas;
  final List<int> clothesIds;
  CollageResult(this.cover, this.canvas, this.clothesIds);
}

class _El {
  String kind; // clothes / photo / text
  String? image;
  int? clothesId;
  String text;
  int color;
  double x, y, scale, rot;

  /// 照片被裁剪前的完整原图（相对路径）。第一次裁剪时记下，之后每次裁剪都从它重新开始，
  /// 这样反复裁剪不会越裁越小。旧数据没有这个字段时为 null，表示 image 就是原图。
  String? original;
  _El({required this.kind, this.image, this.clothesId, this.text = '', this.color = 0xFF000000, this.x = 0.5, this.y = 0.5, this.scale = 1, this.rot = 0, this.original});
  Map<String, dynamic> toJson() => {'k': kind, 'i': image, 'c': clothesId, 't': text, 'col': color, 'x': x, 'y': y, 's': scale, 'r': rot, 'o': original};
  factory _El.fromJson(Map<String, dynamic> j) => _El(
      kind: j['k'], image: j['i'], clothesId: j['c'], text: j['t'] ?? '', color: j['col'] ?? 0xFF000000,
      x: (j['x'] as num).toDouble(), y: (j['y'] as num).toDouble(), scale: (j['s'] as num).toDouble(), rot: (j['r'] as num).toDouble(),
      original: j['o'] as String?);
}

/// 仅供测试：把画布 JSON 解析后再序列化，用来验证 _El 的字段（包括 'o'）往返不丢。
@visibleForTesting
String collageJsonRoundTrip(String canvasJson) {
  final m = jsonDecode(canvasJson) as Map<String, dynamic>;
  final list = (m['els'] as List).map((e) => _El.fromJson(Map<String, dynamic>.from(e as Map)));
  return jsonEncode({'els': list.map((e) => e.toJson()).toList(), 'bg': m['bg'], 'bgImage': m['bgImage']});
}

/// 内置背景：纯色与渐变
const collageBgs = <List<int>>[
  [0xFFFFFFFF], [0xFFF5F5F7], [0xFFFFF4E6], [0xFFFDECEF], [0xFFEAF4FF], [0xFFEAF7EE], [0xFFF1ECFA], [0xFF2B2B2E],
  [0xFFFDEBEB, 0xFFEDE7FB], [0xFFE0F2FE, 0xFFF3E8FF], [0xFFFFF1D6, 0xFFFFD9E0], [0xFFDFF7EC, 0xFFDDEBFF], [0xFFF6F1E9, 0xFFE9DFD0], [0xFFFFE5EC, 0xFFFFF8E1],
];

class CollagePage extends StatefulWidget {
  final String? canvasJson;
  final bool returnResult;
  final int? occasionId;
  const CollagePage({super.key, this.canvasJson, this.returnResult = false, this.occasionId});
  @override
  State<CollagePage> createState() => _CollagePageState();
}

class _CollagePageState extends State<CollagePage> {
  final els = <_El>[];
  List<int> bg = const [0xFFFFFFFF];
  String? bgImage;
  int? sel;
  final history = <String>[];
  int hIndex = -1;
  final boundary = GlobalKey();
  final canvasKey = GlobalKey();
  bool dragging = false;
  bool overTrash = false;
  bool saving = false;
  // 手势
  double _startScale = 1, _startRot = 0;

  /// 当前选中的照片元素（没选中或选中的是单品/文字时为 null）。
  _El? get _selectedPhoto {
    final i = sel;
    if (i == null || i < 0 || i >= els.length) return null;
    final e = els[i];
    return e.kind == 'photo' ? e : null;
  }

  @override
  void initState() {
    super.initState();
    if (widget.canvasJson != null && widget.canvasJson!.isNotEmpty) {
      try {
        final j = jsonDecode(widget.canvasJson!) as Map<String, dynamic>;
        els.addAll((j['els'] as List).map((e) => _El.fromJson(Map<String, dynamic>.from(e))));
        bg = List<int>.from(j['bg'] ?? [0xFFFFFFFF]);
        bgImage = j['bgImage'];
      } catch (_) {}
    }
    _snap();
  }

  String _json() => jsonEncode({'els': els.map((e) => e.toJson()).toList(), 'bg': bg, 'bgImage': bgImage});

  void _snap() {
    final j = _json();
    if (hIndex >= 0 && history[hIndex] == j) return;
    history.removeRange(hIndex + 1, history.length);
    history.add(j);
    hIndex = history.length - 1;
  }

  void _restore(String j) {
    final m = jsonDecode(j) as Map<String, dynamic>;
    els
      ..clear()
      ..addAll((m['els'] as List).map((e) => _El.fromJson(Map<String, dynamic>.from(e))));
    bg = List<int>.from(m['bg']);
    bgImage = m['bgImage'];
    sel = null;
  }

  Future<void> _addClothes() async {
    final r = await push<List<int>>(context, SelectClothesPage(where: (c) => c.status != '丢弃'));
    if (r == null || r.isEmpty) return;
    final m = await AppDb.I.clothesMap();
    setState(() {
      var i = 0;
      for (final id in r) {
        final c = m[id];
        if (c == null) continue;
        els.add(_El(kind: 'clothes', image: c.mainImage, clothesId: id, x: 0.3 + (i % 2) * 0.4, y: 0.25 + (i ~/ 2) * 0.3, scale: 1));
        i++;
      }
      sel = els.length - 1;
      _snap();
    });
  }

  Future<void> _addPhoto() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600);
    if (x == null) return;
    final rel = await ImageStore.saveOriginal(x.path);
    setState(() {
      els.add(_El(kind: 'photo', image: rel));
      sel = els.length - 1;
      _snap();
    });
  }

  /// 只给照片元素用：点「裁剪」才进裁剪页，选完照片不会自动进来。
  ///
  /// 每次都从 original（第一次裁剪前记下的完整原图）打开，所以反复裁剪不会越裁越小。
  /// 确认后只替换 image，位置/缩放/旋转保持不变，再压入撤销栈；取消则什么都不改。
  Future<void> _cropPhoto() async {
    final e = _selectedPhoto;
    if (e == null) return;
    final src = e.original ?? e.image;
    if (src == null || src.isEmpty) return;
    final r = await push<EditedImage>(context, ImageEditPage(path: ImageStore.abs(src), cropOnly: true));
    if (!mounted || r == null) return;
    setState(() {
      e.original ??= e.image;
      e.image = r.image;
      _snap();
    });
  }

  Future<void> _editText([_El? e]) async {
    final r = await Navigator.of(context).push<(String, int)>(PageRouteBuilder(
      opaque: false,
      pageBuilder: (_, __, ___) => _TextEditor(text: e?.text ?? '', color: e?.color ?? 0xFF000000),
    ));
    if (r == null) return;
    setState(() {
      if (r.$1.trim().isEmpty) {
        if (e != null) els.remove(e);
      } else if (e != null) {
        e.text = r.$1;
        e.color = r.$2;
      } else {
        els.add(_El(kind: 'text', text: r.$1, color: r.$2));
        sel = els.length - 1;
      }
      _snap();
    });
  }

  void _background() {
    showSheet(
      context,
      (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SheetHandle(),
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('选择背景', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
            Row(children: [
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    bg = const [0xFFFFFFFF];
                    bgImage = null;
                    _snap();
                  });
                  Navigator.pop(c);
                },
                icon: const Icon(Icons.close, size: 18),
                label: const Text('清空'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(c);
                  final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600);
                  if (x == null) return;
                  final rel = await ImageStore.saveOriginal(x.path);
                  setState(() {
                    bgImage = rel;
                    _snap();
                  });
                },
                icon: const Icon(Icons.photo_outlined, size: 18),
                label: const Text('选择照片'),
              ),
            ]),
            const SizedBox(height: 14),
            const Text('纯色与渐变', style: TextStyle(color: kGrayText, fontSize: 13)),
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final b in collageBgs)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      bg = b;
                      bgImage = null;
                      _snap();
                    });
                    Navigator.pop(c);
                  },
                  child: Container(
                    width: 48,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: bg.toString() == b.toString() && bgImage == null ? kRose : Colors.black12, width: 2),
                      color: b.length == 1 ? Color(b[0]) : null,
                      gradient: b.length > 1 ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: b.map((e) => Color(e)).toList()) : null,
                    ),
                  ),
                ),
            ]),
          ]),
        ),
      ),
      scroll: false,
    );
  }

  void _more() {
    showSheet(
      context,
      (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SheetHandle(),
          if (sel != null) ...[
            ListTile(leading: const Icon(Icons.flip_to_front), title: const Text('置于顶层'), onTap: () {
              Navigator.pop(c);
              setState(() {
                final e = els.removeAt(sel!);
                els.add(e);
                sel = els.length - 1;
                _snap();
              });
            }),
            ListTile(leading: const Icon(Icons.flip_to_back), title: const Text('置于底层'), onTap: () {
              Navigator.pop(c);
              setState(() {
                final e = els.removeAt(sel!);
                els.insert(0, e);
                sel = 0;
                _snap();
              });
            }),
            ListTile(leading: const Icon(Icons.copy), title: const Text('复制'), onTap: () {
              Navigator.pop(c);
              setState(() {
                final e = _El.fromJson(els[sel!].toJson());
                e.x += 0.05;
                e.y += 0.05;
                els.add(e);
                sel = els.length - 1;
                _snap();
              });
            }),
          ],
          ListTile(leading: const Icon(Icons.delete_sweep_outlined), title: const Text('清空画布'), onTap: () {
            Navigator.pop(c);
            setState(() {
              els.clear();
              sel = null;
              _snap();
            });
          }),
          const SizedBox(height: 8),
        ]),
      ),
      scroll: false,
    );
  }

  Future<void> _done() async {
    if (els.isEmpty) {
      toast(context, '画布是空的，先添加单品吧');
      return;
    }
    setState(() {
      sel = null;
      saving = true;
    });
    await Future.delayed(const Duration(milliseconds: 60));
    await WidgetsBinding.instance.endOfFrame;
    final ro = boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await ro.toImage(pixelRatio: 2.5);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    final cover = await ImageStore.savePng(bytes, 'collage');
    final ids = els.where((e) => e.clothesId != null).map((e) => e.clothesId!).toSet().toList();
    if (!mounted) return;
    setState(() => saving = false);
    if (widget.returnResult) {
      Navigator.pop(context, CollageResult(cover, _json(), ids));
    } else {
      push(context, OutfitFormPage(
        outfit: Outfit(type: 'collage', cover: cover, canvas: _json(), clothesIds: ids, occasionIds: widget.occasionId == null ? [] : [widget.occasionId!]),
        isNew: true,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('穿搭拼图'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: hIndex > 0
                ? () => setState(() {
                      hIndex--;
                      _restore(history[hIndex]);
                    })
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: hIndex < history.length - 1
                ? () => setState(() {
                      hIndex++;
                      _restore(history[hIndex]);
                    })
                : null,
          ),
          IconButton(icon: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check), onPressed: saving ? null : _done),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: LayoutBuilder(builder: (c, cons) {
            var w = cons.maxWidth - 24;
            var h = w * 4 / 3;
            if (h > cons.maxHeight - 24) {
              h = cons.maxHeight - 24;
              w = h * 3 / 4;
            }
            return Stack(children: [
              Center(
                child: GestureDetector(
                  onTap: () => setState(() => sel = null),
                  child: RepaintBoundary(
                    key: boundary,
                    child: Container(
                      key: canvasKey,
                      width: w,
                      height: h,
                      decoration: BoxDecoration(
                        color: bg.length == 1 ? Color(bg[0]) : null,
                        gradient: bg.length > 1 ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: bg.map((e) => Color(e)).toList()) : null,
                        boxShadow: kSoftShadow,
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: Stack(clipBehavior: Clip.none, children: [
                        if (bgImage != null) Positioned.fill(child: AppImage(bgImage, fit: BoxFit.cover)),
                        for (var i = 0; i < els.length; i++) _element(i, Size(w, h)),
                      ]),
                    ),
                  ),
                ),
              ),
              if (dragging)
                Positioned(
                  left: 12,
                  top: 12,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: overTrash ? 64 : 52,
                    height: overTrash ? 64 : 52,
                    decoration: BoxDecoration(color: overTrash ? const Color(0xFFE53950) : const Color(0xCC3A2A31), shape: BoxShape.circle),
                    child: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                ),
            ]);
          }),
        ),
        SafeArea(
          top: false,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              _tool(Icons.checkroom, '单品', _addClothes),
              _tool(Icons.photo_outlined, '照片', _addPhoto),
              _tool(Icons.text_fields, '文字', () => _editText()),
              _tool(Icons.wallpaper, '背景', _background),
              // 只有选中照片时才出现「裁剪」，单品/文字/未选中都没有。
              if (_selectedPhoto != null) _tool(Icons.crop, '裁剪', _cropPhoto),
              _tool(Icons.more_horiz, '更多', _more),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _tool(IconData i, String t, VoidCallback f) => Expanded(
        child: InkWell(
          onTap: f,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: [Icon(i), const SizedBox(height: 3), Text(t, style: const TextStyle(fontSize: 12))]),
          ),
        ),
      );

  Widget _element(int i, Size size) {
    final e = els[i];
    final base = size.width * 0.42;
    final isText = e.kind == 'text';
    final selected = sel == i;
    final child = isText
        ? Padding(
            padding: const EdgeInsets.all(6),
            child: Text(e.text, style: TextStyle(color: Color(e.color), fontSize: 22 * e.scale, fontWeight: FontWeight.w600)),
          )
        : SizedBox(width: base * e.scale, height: base * e.scale, child: AppImage(e.image, placeholder: Colors.transparent));
    return Positioned(
      left: e.x * size.width,
      top: e.y * size.height,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: Transform.rotate(
          angle: e.rot,
          child: GestureDetector(
            onTap: () => setState(() => sel = i),
            onDoubleTap: isText ? () => _editText(e) : null,
            onScaleStart: (d) {
              setState(() {
                sel = i;
                dragging = true;
              });
              _startScale = e.scale;
              _startRot = e.rot;
            },
            onScaleUpdate: (d) {
              setState(() {
                // 先用本次更新前的 e.rot 把局部位移换回屏幕坐标（双指旋转会在同一次回调里改 e.rot）。
                final delta = rotateDelta(d.focalPointDelta, e.rot);
                e.x = (e.x + delta.dx / size.width).clamp(0.0, 1.0);
                e.y = (e.y + delta.dy / size.height).clamp(0.0, 1.0);
                if (d.pointerCount > 1) {
                  e.scale = (_startScale * d.scale).clamp(0.2, 5.0);
                  e.rot = _startRot + d.rotation;
                }
                final box = canvasKey.currentContext?.findRenderObject() as RenderBox?;
                final page = context.findRenderObject() as RenderBox?;
                if (box != null && page != null) {
                  final local = page.globalToLocal(d.focalPoint);
                  overTrash = local.dx < 90 && local.dy < 160;
                }
              });
            },
            onScaleEnd: (_) {
              setState(() {
                if (overTrash) {
                  els.removeAt(i);
                  sel = null;
                }
                dragging = false;
                overTrash = false;
                _snap();
              });
            },
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
                decoration: BoxDecoration(border: Border.all(color: selected ? kRose : Colors.transparent, width: 1.5)),
                child: child,
              ),
              if (selected) ...[
                Positioned(
                  left: -12,
                  top: -12,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      els.removeAt(i);
                      sel = null;
                      _snap();
                    }),
                    child: const CircleAvatar(radius: 12, backgroundColor: kRose, child: Icon(Icons.close, size: 14, color: Colors.white)),
                  ),
                ),
                Positioned(
                  right: -12,
                  bottom: -12,
                  child: GestureDetector(
                    onPanStart: (_) {
                      _startScale = e.scale;
                    },
                    onPanUpdate: (d) {
                      final box = canvasKey.currentContext?.findRenderObject() as RenderBox?;
                      if (box == null) return;
                      final center = box.localToGlobal(Offset(e.x * size.width, e.y * size.height));
                      final v = d.globalPosition - center;
                      final baseLen = (isText ? 40.0 : base / 2) * math.sqrt2;
                      setState(() {
                        e.scale = (v.distance / baseLen).clamp(0.2, 5.0);
                        e.rot = math.atan2(v.dy, v.dx) - math.pi / 4;
                      });
                    },
                    onPanEnd: (_) => setState(_snap),
                    child: const CircleAvatar(radius: 12, backgroundColor: kRose, child: Icon(Icons.open_in_full, size: 13, color: Colors.white)),
                  ),
                ),
                if (isText)
                  Positioned(
                    right: -12,
                    top: -12,
                    child: GestureDetector(
                      onTap: () => _editText(e),
                      child: const CircleAvatar(radius: 12, backgroundColor: kRose, child: Icon(Icons.edit, size: 13, color: Colors.white)),
                    ),
                  ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// 文字编辑：全屏暗底 + 右侧色条
class _TextEditor extends StatefulWidget {
  final String text;
  final int color;
  const _TextEditor({required this.text, required this.color});
  @override
  State<_TextEditor> createState() => _TextEditorState();
}

class _TextEditorState extends State<_TextEditor> {
  late final ctl = TextEditingController(text: widget.text);
  late int color = widget.color;
  static const colors = [0xFF000000, 0xFFFFFFFF, 0xFFE53935, 0xFFFB8C00, 0xFFFDD835, 0xFF43A047, 0xFF1E88E5, 0xFF8E24AA, 0xFFF48FB1, 0xFF795548];
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xCC000000),
        body: SafeArea(
          child: Stack(children: [
            Positioned(
              top: 4,
              left: 4,
              right: 4,
              child: Row(children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消', style: TextStyle(color: Colors.white, fontSize: 16))),
                const Spacer(),
                TextButton(onPressed: () => Navigator.pop(context, (ctl.text, color)), child: const Text('完成', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))),
              ]),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(left: 24, right: 64),
                child: TextField(
                  controller: ctl,
                  autofocus: true,
                  maxLines: null,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(color), fontSize: 30, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(border: InputBorder.none, hintText: '输入文字', hintStyle: TextStyle(color: Colors.white54)),
                ),
              ),
            ),
            Positioned(
              right: 12,
              top: 80,
              bottom: 80,
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  for (final c in colors)
                    GestureDetector(
                      onTap: () => setState(() => color = c),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: color == c ? 3 : 1.5)),
                      ),
                    ),
                ]),
              ),
            ),
          ]),
        ),
      );
}
