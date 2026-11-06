import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/taxonomy.dart';
import '../services/images.dart';
import '../services/settings.dart';

const kPurple = Color(0xFF65558F);
const kPurpleLight = Color(0xFFE8DEF8);
const kPurpleBg = Color(0xFFF3EDF7);
const kBg = Color(0xFFF7F7FA);
const kGrayText = Color(0xFF8A8A8E);
const kCellBg = Color(0xFFF4F4F6);

final navKey = GlobalKey<NavigatorState>();

// ---------------------------------------------------------------- Toast
OverlayEntry? _toastEntry;
Timer? _toastTimer;

/// style: light（白色圆角，居中偏下）/ dark（黑色条）/ success（绿色）
void toast(BuildContext? context, String msg, {String style = 'light'}) {
  final overlay = navKey.currentState?.overlay;
  if (overlay == null) return;
  _toastTimer?.cancel();
  _toastEntry?.remove();
  final bg = style == 'dark' ? const Color(0xFF2B2B2E) : (style == 'success' ? const Color(0xFF34A853) : Colors.white);
  final fg = style == 'light' ? Colors.black87 : Colors.white;
  _toastEntry = OverlayEntry(
    builder: (c) => Positioned(
      left: style == 'dark' ? 16 : 0,
      right: style == 'dark' ? 16 : 0,
      bottom: MediaQuery.of(c).padding.bottom + (style == 'dark' ? 24 : 90),
      child: IgnorePointer(
        child: Material(
          color: Colors.transparent,
          child: style == 'dark'
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
                  child: Text(msg, style: TextStyle(color: fg, fontSize: 14)),
                )
              : Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 3))],
                    ),
                    child: Text(msg, style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.w500)),
                  ),
                ),
        ),
      ),
    ),
  );
  overlay.insert(_toastEntry!);
  _toastTimer = Timer(const Duration(milliseconds: 2000), () {
    _toastEntry?.remove();
    _toastEntry = null;
  });
}

// ---------------------------------------------------------------- 图片
class AppImage extends StatelessWidget {
  final String? rel;
  final BoxFit fit;
  final double? width, height;
  final Color placeholder;
  const AppImage(this.rel, {super.key, this.fit = BoxFit.contain, this.width, this.height, this.placeholder = const Color(0xFFEDEDF0)});

  @override
  Widget build(BuildContext context) {
    Widget ph() => Container(
          width: width,
          height: height,
          color: placeholder,
          alignment: Alignment.center,
          child: const Icon(Icons.hide_image_outlined, color: Color(0xFFB5B5BA), size: 26),
        );
    if (rel == null || rel!.isEmpty) return ph();
    final f = File(ImageStore.abs(rel!));
    return Image.file(f, fit: fit, width: width, height: height, gaplessPlayback: true, cacheWidth: width != null && width! < 300 ? 400 : null,
        errorBuilder: (_, __, ___) => ph());
  }
}

/// 透明底棋盘格
class Checkerboard extends StatelessWidget {
  final Widget child;
  const Checkerboard({super.key, required this.child});
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _CheckerPainter(), child: child);
}

class _CheckerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const s = 12.0;
    final a = Paint()..color = const Color(0xFFFFFFFF);
    final b = Paint()..color = const Color(0xFFE6E6E6);
    canvas.drawRect(Offset.zero & size, a);
    for (var y = 0; y * s < size.height; y++) {
      for (var x = 0; x * s < size.width; x++) {
        if ((x + y).isOdd) canvas.drawRect(Rect.fromLTWH(x * s, y * s, s, s), b);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------- 卡片
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color color;
  final double radius;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 12),
      this.onTap, this.color = Colors.white, this.radius = 20});
  @override
  Widget build(BuildContext context) => Padding(
        padding: margin,
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
        ),
      );
}

/// 左侧紫色竖条的分区标题
class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Row(children: [
          Container(width: 4, height: 16, decoration: BoxDecoration(color: kPurple, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const Spacer(),
          if (trailing != null) trailing!,
        ]),
      );
}

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final color = switch (status) { '素材' => const Color(0xFF3FA27A), '种草' => const Color(0xFFE88A3C), '丢弃' => Colors.grey, _ => kPurple };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 10, height: 1.4)),
    );
  }
}

/// 单品卡片
class ClothesTile extends StatelessWidget {
  final Clothes c;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final bool selectable;
  final bool? showName;
  final Color bg;
  const ClothesTile(this.c, {super.key, this.onTap, this.onLongPress, this.selected = false, this.selectable = false, this.showName,
      this.bg = Colors.white});
  @override
  Widget build(BuildContext context) {
    final name = showName ?? Settings.showClothesName;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? kPurple : const Color(0xFFE9E9EE), width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          Positioned.fill(
            child: Column(children: [
              Expanded(child: Padding(padding: const EdgeInsets.all(6), child: AppImage(c.listImage, width: double.infinity))),
              if (name)
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                  child: Text(c.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                ),
            ]),
          ),
          if (c.status == '素材' || c.status == '种草' || c.status == '丢弃') Positioned(left: 4, top: 4, child: StatusBadge(c.status)),
          if (selectable)
            Positioned(
              right: 5,
              top: 5,
              child: Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked, color: selected ? kPurple : Colors.black26, size: 22),
            ),
        ]),
      ),
    );
  }
}

/// 穿搭卡片
class OutfitTile extends StatelessWidget {
  final Outfit o;
  final VoidCallback? onTap;
  final bool selected;
  final bool selectable;
  final bool? showName;
  const OutfitTile(this.o, {super.key, this.onTap, this.selected = false, this.selectable = false, this.showName});
  @override
  Widget build(BuildContext context) {
    final name = (showName ?? Settings.showOutfitName) && o.name.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? kPurple : const Color(0xFFE9E9EE), width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          Positioned.fill(child: AppImage(o.cover ?? (o.photos.isEmpty ? null : o.photos.first), fit: o.type == 'photo' ? BoxFit.cover : BoxFit.contain)),
          if (name)
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 120),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                child: Text(o.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
              ),
            ),
          if (selectable)
            Positioned(
              right: 5,
              top: 5,
              child: Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked, color: selected ? kPurple : Colors.black26, size: 22),
            ),
        ]),
      ),
    );
  }
}

class ColorDots extends StatelessWidget {
  final List<String> colors;
  final double size;
  const ColorDots(this.colors, {super.key, this.size = 12});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (final c in colors)
          Container(
            width: size,
            height: size,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(color: colorOf(c), shape: BoxShape.circle, border: Border.all(color: Colors.black26, width: 0.6)),
          ),
      ]);
}

// ---------------------------------------------------------------- 胶囊
class Pill extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? icon;
  final bool square;
  const Pill(this.text, {super.key, this.selected = false, this.onTap, this.icon, this.square = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? kPurpleLight : Colors.white,
            borderRadius: BorderRadius.circular(square ? 10 : 22),
            border: Border.all(color: selected ? kPurple : const Color(0xFFDADADF)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (selected && icon == null) ...[const Icon(Icons.check, size: 15, color: kPurple), const SizedBox(width: 4)],
            if (icon != null) ...[icon!, const SizedBox(width: 4)],
            Text(text, style: TextStyle(fontSize: 13.5, color: selected ? kPurple : Colors.black87)),
          ]),
        ),
      );
}

// ---------------------------------------------------------------- 表单行
class FormRow extends StatelessWidget {
  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback? onTap;
  final Widget? valueWidget;
  final String? sub;
  const FormRow(this.label, {super.key, this.value, this.placeholder = '未选择', this.onTap, this.valueWidget, this.sub});
  @override
  Widget build(BuildContext context) {
    final empty = value == null || value!.isEmpty;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Row(children: [
            Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(width: 16),
            Expanded(
              child: valueWidget ??
                  Text(empty ? placeholder : value!, textAlign: TextAlign.right, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14.5, color: empty ? kGrayText : Colors.black87)),
            ),
            if (onTap != null) const Icon(Icons.chevron_right, color: kGrayText, size: 20),
          ]),
          if (sub != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(sub!, style: const TextStyle(fontSize: 12, color: kGrayText))),
        ]),
      ),
    );
  }
}

class FormGroup extends StatelessWidget {
  final List<Widget> children;
  const FormGroup(this.children, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF0F0F2)),
          ],
        ]),
      );
}

// ---------------------------------------------------------------- 对话框
Future<bool> confirm(BuildContext context, String title, String msg, {String ok = '确定', bool danger = false}) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(ok, style: TextStyle(color: danger ? Colors.red : null))),
        ],
      ),
    ) ??
    false;

Future<String?> inputDialog(BuildContext context, String title, {String initial = '', String hint = '', String ok = '保存', TextInputType? type}) {
  final ctl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(controller: ctl, autofocus: true, keyboardType: type, decoration: InputDecoration(hintText: hint)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
        TextButton(onPressed: () => Navigator.pop(c, ctl.text.trim()), child: Text(ok)),
      ],
    ),
  );
}

/// 底部弹窗容器（淡紫白底大圆角）
Future<T?> showSheet<T>(BuildContext context, Widget Function(BuildContext) builder, {bool scroll = true}) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: scroll,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: builder,
    );

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: const Color(0xFFCFCFD4), borderRadius: BorderRadius.circular(2))),
      );
}

/// 底部 取消 | 确定 两个胶囊按钮
class BottomButtons extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback? onOk;
  final String cancel, ok;
  const BottomButtons({super.key, required this.onCancel, required this.onOk, this.cancel = '取消', this.ok = '确定'});
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + MediaQuery.of(context).padding.bottom),
        child: Row(children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: const StadiumBorder()),
              onPressed: onCancel,
              child: Text(cancel, style: const TextStyle(color: Colors.black87, fontSize: 16)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: const StadiumBorder(), backgroundColor: kPurple),
              onPressed: onOk,
              child: Text(ok, style: const TextStyle(fontSize: 16)),
            ),
          ),
        ]),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? sub;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, this.sub, this.action});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: const Color(0xFFBDBDC4)),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: kGrayText)),
            if (sub != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(sub!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: Color(0xFFB0B0B5)))),
            if (action != null) Padding(padding: const EdgeInsets.only(top: 16), child: action!),
          ]),
        ),
      );
}

/// 监听数据版本，自动重新加载
mixin DataReload<T extends StatefulWidget> on State<T> {
  Future<void> reload();
  void _onData() {
    if (mounted) reload();
  }

  void listenData(ValueNotifier<int> n) => n.addListener(_onData);
  void unlistenData(ValueNotifier<int> n) => n.removeListener(_onData);
}

String fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String todayStr() => fmtDate(DateTime.now());

Future<T?> push<T>(BuildContext context, Widget page) => Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));

AppBar appBar(String title, {List<Widget>? actions, bool center = true, Widget? titleWidget}) => AppBar(
      title: titleWidget ?? Text(title),
      centerTitle: center,
      actions: actions,
    );
