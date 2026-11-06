import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/taxonomy.dart';
import '../services/images.dart';
import '../services/settings.dart';

// ---------------------------------------------------------------- 粉色甜美主题（2.1.0）
const kRose = Color(0xFFEC4A6E); // 主强调色：玫红
const kRoseDark = Color(0xFFD63B5F);
const kRoseLight = Color(0xFFFCE1E8); // 淡粉填充（今天胶囊、+ 格子、图标底、FAB、导航胶囊）
const kRoseBg = Color(0xFFFDEBF0); // 更淡的粉底
const kRoseSoft = Color(0xFFF7A9BC); // 柔和粉（次要图标/箭头）
const kPinkBorder = Color(0xFFF8C6D3); // 细粉描边（单品缩略图）
const kPinkLine = Color(0xFFF7E0E7); // 分隔线/浅描边
const kBg = Color(0xFFFDEEF2);
const kBgBottom = Color(0xFFFFF6F8);
const kInk = Color(0xFF221A1D); // 近黑标题
const kGrayText = Color(0xFF8E8689);
const kCellBg = Color(0xFFFFF1F4);
const kSheetBg = Color(0xFFFFFAFB);
const kCardColor = Color(0xE6FFFFFF); // 90% 白
const kPageGradient = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [kBg, kBgBottom]);
const kCardShadow = [BoxShadow(color: Color(0x14E8456B), blurRadius: 18, offset: Offset(0, 6))];
const kSoftShadow = [BoxShadow(color: Color(0x1FE8456B), blurRadius: 14, offset: Offset(0, 4))];

/// 整页淡粉渐变背景
class PinkBackground extends StatelessWidget {
  final Widget child;
  const PinkBackground({super.key, required this.child});
  @override
  Widget build(BuildContext context) => DecoratedBox(decoration: const BoxDecoration(gradient: kPageGradient), child: child);
}

/// 淡粉圆角方块里的玫红图标
class IconTile extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final Color color;
  final Color bg;
  const IconTile(this.icon, {super.key, this.size = 40, this.iconSize = 21, this.color = kRose, this.bg = kRoseLight});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * 0.3)),
        child: Icon(icon, size: iconSize, color: color),
      );
}

/// 插画资源
class Illus {
  static const recGift = 'assets/illustrations/rec_gift.png';
  static const outfits = 'assets/illustrations/empty_outfits.png';
  static const clothes = 'assets/illustrations/empty_clothes.png';
  static const trip = 'assets/illustrations/empty_trip.png';
  static const material = 'assets/illustrations/empty_material.png';
  static const calendar = 'assets/illustrations/empty_calendar.png';
  static const tryon = 'assets/illustrations/empty_tryon.png';
  static const search = 'assets/illustrations/empty_search.png';
}

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
  final bg = style == 'dark' ? const Color(0xFF3A2A31) : (style == 'success' ? kRose : Colors.white);
  final fg = style == 'light' ? kInk : Colors.white;
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
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16), boxShadow: kSoftShadow),
                  child: Text(msg, style: TextStyle(color: fg, fontSize: 14)),
                )
              : Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: kSoftShadow,
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
  const AppImage(this.rel, {super.key, this.fit = BoxFit.contain, this.width, this.height, this.placeholder = const Color(0xFFFCEFF3)});

  @override
  Widget build(BuildContext context) {
    Widget ph() => Container(
          width: width,
          height: height,
          color: placeholder,
          alignment: Alignment.center,
          child: const Icon(Icons.hide_image_outlined, color: Color(0xFFF2B8C6), size: 26),
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
    final b = Paint()..color = const Color(0xFFFBE4EA);
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
      this.onTap, this.color = kCardColor, this.radius = 22});
  @override
  Widget build(BuildContext context) => Padding(
        padding: margin,
        child: DecoratedBox(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius), boxShadow: kCardShadow),
          child: Material(
            color: color,
            borderRadius: BorderRadius.circular(radius),
            clipBehavior: Clip.antiAlias,
            child: InkWell(onTap: onTap, splashColor: kRoseLight, highlightColor: kRoseBg, child: Padding(padding: padding, child: child)),
          ),
        ),
      );
}

/// 左侧玫红竖条的分区标题
class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Row(children: [
          Container(width: 4, height: 16, decoration: BoxDecoration(color: kRose, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kInk)),
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
    final color = switch (status) { '素材' => const Color(0xFF4DB6A0), '种草' => const Color(0xFFF29A5B), '丢弃' => const Color(0xFFB9AEB2), _ => kRose };
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
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? kRose : kPinkBorder, width: selected ? 2.2 : 1.6),
          boxShadow: const [BoxShadow(color: Color(0x10E8456B), blurRadius: 8, offset: Offset(0, 3))],
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
              child: Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked, color: selected ? kRose : kRoseSoft, size: 22),
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
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? kRose : kPinkBorder, width: selected ? 2.2 : 1.6),
          boxShadow: const [BoxShadow(color: Color(0x10E8456B), blurRadius: 8, offset: Offset(0, 3))],
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
                decoration: BoxDecoration(color: const Color(0xEEFFFFFF), borderRadius: BorderRadius.circular(8)),
                child: Text(o.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
              ),
            ),
          if (selectable)
            Positioned(
              right: 5,
              top: 5,
              child: Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked, color: selected ? kRose : kRoseSoft, size: 22),
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
            color: selected ? kRoseLight : Colors.white,
            borderRadius: BorderRadius.circular(square ? 12 : 22),
            border: Border.all(color: selected ? kRose : const Color(0xFFF3D3DC)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (selected && icon == null) ...[const Icon(Icons.check, size: 15, color: kRose), const SizedBox(width: 4)],
            if (icon != null) ...[icon!, const SizedBox(width: 4)],
            Text(text, style: TextStyle(fontSize: 13.5, color: selected ? kRose : kInk, fontWeight: selected ? FontWeight.w600 : null)),
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
            Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kInk)),
            const SizedBox(width: 16),
            Expanded(
              child: valueWidget ??
                  Text(empty ? placeholder : value!, textAlign: TextAlign.right, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14.5, color: empty ? kGrayText : kInk)),
            ),
            if (onTap != null) const Icon(Icons.chevron_right, color: kRoseSoft, size: 20),
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
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), boxShadow: kCardShadow),
        child: Material(
          color: kCardColor,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const Divider(height: 1, indent: 16, endIndent: 16, color: kPinkLine),
          ],
        ]),
        ),
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
              child: Text(ok, style: TextStyle(color: danger ? const Color(0xFFE53950) : null))),
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

/// 底部弹窗容器（淡粉白底大圆角）
Future<T?> showSheet<T>(BuildContext context, Widget Function(BuildContext) builder, {bool scroll = true}) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: scroll,
      useSafeArea: true,
      backgroundColor: kSheetBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
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
            decoration: BoxDecoration(color: const Color(0xFFF3C9D4), borderRadius: BorderRadius.circular(2))),
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
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: const StadiumBorder(), side: const BorderSide(color: kPinkBorder), backgroundColor: Colors.white),
              onPressed: onCancel,
              child: Text(cancel, style: const TextStyle(color: kInk, fontSize: 16)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: const StadiumBorder(), backgroundColor: kRose),
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
  final String? image;
  final double imageWidth;
  const EmptyState({super.key, required this.icon, required this.title, this.sub, this.action, this.image, this.imageWidth = 200});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (image != null)
              Image.asset(image!, width: imageWidth, fit: BoxFit.contain, filterQuality: FilterQuality.medium)
            else
              Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(color: kRoseLight, shape: BoxShape.circle),
                child: Icon(icon, size: 42, color: kRoseSoft),
              ),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: Color(0xFF3A3034))),
            if (sub != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(sub!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: kGrayText))),
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
