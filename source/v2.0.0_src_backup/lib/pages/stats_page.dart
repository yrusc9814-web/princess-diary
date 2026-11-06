import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../data/taxonomy.dart';
import '../widgets/common.dart';
import 'clothes_detail_page.dart';

const _palette = [
  Color(0xFF7C6FD8), Color(0xFF4FA3F7), Color(0xFFF6A04D), Color(0xFF5CC98B), Color(0xFFEF6F8E), Color(0xFF9AA0AE),
  Color(0xFF3FC1C9), Color(0xFFB57EDC), Color(0xFFF2C94C), Color(0xFF8D6E63),
];

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});
  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  List<Clothes> list = [];
  int outfits = 0;
  List<CustomCat> cats = [];
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = (await AppDb.I.allClothes()).where((c) => c.status != '丢弃').toList();
    final o = (await AppDb.I.outfits()).length;
    final c = await AppDb.I.customCats();
    if (!mounted) return;
    setState(() {
      list = a;
      outfits = o;
      cats = c;
      loaded = true;
    });
  }

  double? _cpw(Clothes c) => (c.price == null || c.price == 0) ? null : c.price! / math.max(1, c.wearCount);

  @override
  Widget build(BuildContext context) {
    if (!loaded) return Scaffold(appBar: appBar('数据统计'), body: const Center(child: CircularProgressIndicator()));
    final value = list.fold<double>(0, (s, c) => s + (c.price ?? 0));
    // 性价比
    final costs = list.map(_cpw).whereType<double>().toList()..sort();
    final median = costs.isEmpty ? 0.0 : (costs.length.isOdd ? costs[costs.length ~/ 2] : (costs[costs.length ~/ 2 - 1] + costs[costs.length ~/ 2]) / 2);
    final remind = list.where((c) => c.wearCount == 0 || ((_cpw(c) ?? 0) > 2 * median && median > 0)).toList()
      ..sort((a, b) {
        if (a.wearCount == 0 && b.wearCount != 0) return -1;
        if (b.wearCount == 0 && a.wearCount != 0) return 1;
        return (_cpw(b) ?? 0).compareTo(_cpw(a) ?? 0);
      });
    final top = list.where((c) => c.wearCount > 0).toList()..sort((a, b) => b.wearCount.compareTo(a.wearCount));
    final cold = [...list]
      ..sort((a, b) {
        if (a.lastWear == null && b.lastWear != null) return -1;
        if (b.lastWear == null && a.lastWear != null) return 1;
        if (a.lastWear == null) return a.wearCount.compareTo(b.wearCount);
        return a.lastWear!.compareTo(b.lastWear!);
      });
    String remindSub(Clothes c) => c.wearCount == 0 ? '从未穿过 · 价格¥${(c.price ?? 0).toStringAsFixed(0)}' : '单次成本 ¥${_cpw(c)!.toStringAsFixed(2)} · 共${c.wearCount}次';
    String wearSub(Clothes c) => c.lastWear == null ? (c.wearCount == 0 ? '从未穿过 · 共0次' : '共${c.wearCount}次') : '上次: ${c.lastWear} · 共${c.wearCount}次';

    Map<String, int> count(Iterable<String?> xs, {String empty = '未设置'}) {
      final m = <String, int>{};
      for (final x in xs) {
        final k = (x == null || x.isEmpty) ? empty : x;
        m[k] = (m[k] ?? 0) + 1;
      }
      return Map.fromEntries(m.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
    }

    String topCustom(Clothes c) {
      final cat = cats.where((e) => e.id == c.customCatId).firstOrNull;
      if (cat == null) return '未设置自定义分类';
      return cat.parentId == null ? cat.name : (cats.where((e) => e.id == cat.parentId).firstOrNull?.name ?? cat.name);
    }

    final seasonCount = {for (final s in seasonOptions) s: list.where((c) => c.seasons.contains(s)).length};
    final warmCount = {for (final s in warmthOptions) s: list.where((c) => c.warmth == s).length};

    return Scaffold(
      appBar: appBar('数据统计'),
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(children: [
            _top('衣物', '${list.length}', '件', Icons.checkroom, const Color(0xFF7C6FD8)),
            const SizedBox(width: 10),
            _top('搭配', '$outfits', '套', Icons.style, const Color(0xFF4FA3F7)),
            const SizedBox(width: 10),
            _top('估值', value.toStringAsFixed(0), '元', Icons.payments_outlined, const Color(0xFFEF6F6F)),
          ]),
        ),
        const SectionTitle('性价比分析'),
        _rankCard('未穿与成本提醒', Icons.warning_amber_rounded, const Color(0xFFF6A04D), remind, remindSub,
            desc: '规则: 从未穿过、或 单次成本 > 2×中位数；单次成本中位数 ¥${median.toStringAsFixed(2)}'),
        const SectionTitle('穿着分析'),
        _rankCard('劳模榜', Icons.local_fire_department, const Color(0xFFEF5350), top, wearSub, desc: '按穿着次数从高到低'),
        _rankCard('冷宫榜', Icons.ac_unit, const Color(0xFF42A5F5), cold, wearSub, desc: '从未穿过或很久没穿'),
        const SectionTitle('风格画像'),
        _donutCard('衣物品类占比', count(list.map((c) => c.cat1), empty: '未设置衣物品类')),
        _donutCard('主色占比', count(list.map((c) => c.colors.isEmpty ? null : c.colors.first), empty: '未知'), useColorNames: true),
        _donutCard('自定义分类占比', count(list.map(topCustom))),
        _cardTitle('季节分布'),
        _grid4(seasonCount, const {
          '春季': (Color(0xFFE8F6EC), Color(0xFF3FAE6A), Icons.local_florist_outlined),
          '夏季': (Color(0xFFFDECEC), Color(0xFFE55353), Icons.wb_sunny_outlined),
          '秋季': (Color(0xFFFFF1E3), Color(0xFFE88A3C), Icons.eco_outlined),
          '冬季': (Color(0xFFE8F1FD), Color(0xFF3D8BFD), Icons.ac_unit),
        }),
        _pillCard('品牌分布', count(list.map((c) => c.brand))),
        _pillCard('风格分布', count(list.map((c) => c.style))),
        _pillCard('材质分布', count(list.map((c) => c.material))),
        _cardTitle('保暖度分布'),
        _grid4(warmCount, const {
          '薄': (Color(0xFFE8F6F9), Color(0xFF26A6C9), Icons.air),
          '适中': (Color(0xFFE8F6EC), Color(0xFF3FAE6A), Icons.thermostat),
          '保暖': (Color(0xFFFFF1E3), Color(0xFFE88A3C), Icons.local_fire_department_outlined),
          '很保暖': (Color(0xFFFDECEC), Color(0xFFE55353), Icons.whatshot),
        }),
        _pillCard('轮廓分布', count(list.map((c) => c.silhouette))),
        _pillCard('长度分布', count(list.map((c) => c.length))),
        _pillCard('叠穿角色分布', count(list.map((c) => c.layer))),
      ]),
    );
  }

  Widget _top(String label, String n, String unit, IconData icon, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(label, style: const TextStyle(color: kGrayText, fontSize: 13)),
              const Spacer(),
              Icon(icon, size: 18, color: color),
            ]),
            const SizedBox(height: 8),
            Text.rich(TextSpan(children: [
              TextSpan(text: n, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              TextSpan(text: ' $unit', style: const TextStyle(fontSize: 12, color: kGrayText)),
            ])),
          ]),
        ),
      );

  Widget _row(Clothes c, String sub) => InkWell(
        onTap: () => push(context, ClothesDetailPage(id: c.id!)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 46, height: 46, child: AppImage(c.listImage))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(sub, style: const TextStyle(color: kGrayText, fontSize: 12)),
              ]),
            ),
          ]),
        ),
      );

  Widget _rankCard(String title, IconData icon, Color color, List<Clothes> items, String Function(Clothes) sub, {String? desc}) => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            Icon(icon, color: color),
          ]),
          if (desc != null) Padding(padding: const EdgeInsets.only(top: 4, bottom: 4), child: Text(desc, style: const TextStyle(color: kGrayText, fontSize: 12))),
          if (items.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('暂无数据', style: TextStyle(color: kGrayText))),
          for (final c in items.take(3)) _row(c, sub(c)),
          if (items.length > 3)
            Center(
              child: TextButton(
                onPressed: () => showSheet(
                  context,
                  (s) => SizedBox(
                    height: MediaQuery.of(s).size.height * 0.75,
                    child: Column(children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                        child: Row(children: [
                          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                          const Spacer(),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(s)),
                        ]),
                      ),
                      Expanded(child: ListView(padding: const EdgeInsets.symmetric(horizontal: 20), children: [for (final c in items) _row(c, sub(c))])),
                    ]),
                  ),
                ),
                child: const Text('查看全部'),
              ),
            ),
        ]),
      );

  Widget _cardTitle(String t) => Padding(padding: const EdgeInsets.fromLTRB(20, 6, 16, 10), child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)));

  Widget _donutCard(String title, Map<String, int> data, {bool useColorNames = false}) {
    final total = data.values.fold<int>(0, (a, b) => a + b);
    final entries = data.entries.toList();
    Color colorAt(int i, String k) => useColorNames && k != '未知' ? colorOf(k) : _palette[i % _palette.length];
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        if (total == 0)
          const Text('暂无数据', style: TextStyle(color: kGrayText))
        else
          Row(children: [
            SizedBox(
              width: 120,
              height: 120,
              child: CustomPaint(painter: _Donut([for (var i = 0; i < entries.length; i++) (entries[i].value / total, colorAt(i, entries[i].key))])),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (var i = 0; i < entries.length && i < 8; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: colorAt(i, entries[i].key), shape: BoxShape.circle, border: Border.all(color: Colors.black12))),
                      const SizedBox(width: 6),
                      Expanded(child: Text(entries[i].key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                      Text('${(entries[i].value * 100 / total).round()}%', style: const TextStyle(fontSize: 12, color: kGrayText)),
                    ]),
                  ),
              ]),
            ),
          ]),
      ]),
    );
  }

  Widget _grid4(Map<String, int> data, Map<String, (Color, Color, IconData)> style) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.3,
          children: [
            for (final e in data.entries)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: style[e.key]!.$1, borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  Icon(style[e.key]!.$3, color: style[e.key]!.$2),
                  const SizedBox(width: 8),
                  Text(e.key, style: TextStyle(color: style[e.key]!.$2, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('${e.value}', style: TextStyle(color: style[e.key]!.$2, fontSize: 22, fontWeight: FontWeight.w800)),
                ]),
              ),
          ],
        ),
      );

  Widget _pillCard(String title, Map<String, int> data) => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (data.isEmpty)
            const Text('暂无数据', style: TextStyle(color: kGrayText))
          else
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in data.entries)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xFFF4F2FA), borderRadius: BorderRadius.circular(14)),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: e.key, style: const TextStyle(fontSize: 13)),
                    TextSpan(text: '  ${e.value}', style: const TextStyle(fontSize: 13, color: kPurple, fontWeight: FontWeight.w700)),
                  ])),
                ),
            ]),
        ]),
      );
}

class _Donut extends CustomPainter {
  final List<(double, Color)> parts;
  _Donut(this.parts);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.width * 0.2;
    final r = rect.deflate(stroke / 2);
    var start = -math.pi / 2;
    for (final p in parts) {
      final sweep = p.$1 * math.pi * 2;
      canvas.drawArc(r, start, sweep, false, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = p.$2);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
