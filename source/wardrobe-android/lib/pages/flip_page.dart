import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../data/taxonomy.dart';
import '../services/compose.dart';
import '../services/settings.dart';
import '../widgets/common.dart';
import 'outfit_form_page.dart';

/// 翻牌：上下装 / 连衣裙 / 自选品类槽位，可上锁、随机、撤销
class FlipPage extends StatefulWidget {
  final int? occasionId;
  const FlipPage({super.key, this.occasionId});
  @override
  State<FlipPage> createState() => _FlipPageState();
}

class _FlipPageState extends State<FlipPage> {
  String mode = 'tb';
  List<String> customSlots = Settings.p.getStringList('flip_custom') ?? ['外套', '上装', '下装', '鞋履'];
  Map<String, List<Clothes>> pool = {};
  Map<String, int> idx = {};
  Set<String> locked = {};
  final history = <Map<String, int>>[];
  final rnd = math.Random();
  bool saving = false;

  List<String> get slots => switch (mode) {
        'tb' => const ['外套', '上装', '鞋履', '下装'],
        'dress' => const ['外套', '连衣裙/连体装', '鞋履'],
        _ => customSlots,
      };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = (await AppDb.I.allClothes()).where((c) => c.status != '丢弃').toList();
    final p = <String, List<Clothes>>{};
    for (final c in all) {
      p.putIfAbsent(flipSlotOf(c.cat1, c.cat2), () => []).add(c);
    }
    if (!mounted) return;
    setState(() {
      pool = p;
      for (final s in flipSlots) {
        final n = p[s]?.length ?? 0;
        idx[s] = n == 0 ? 0 : rnd.nextInt(n);
      }
    });
  }

  Clothes? cur(String s) {
    final l = pool[s];
    if (l == null || l.isEmpty) return null;
    return l[(idx[s] ?? 0) % l.length];
  }

  void _push() {
    history.add({...idx});
    if (history.length > 50) history.removeAt(0);
  }

  void _step(String s, int d) {
    final n = pool[s]?.length ?? 0;
    if (n <= 1) return;
    _push();
    setState(() => idx[s] = ((idx[s] ?? 0) + d) % n < 0 ? n - 1 : ((idx[s] ?? 0) + d) % n);
  }

  void _random() {
    _push();
    setState(() {
      for (final s in slots) {
        if (locked.contains(s)) continue;
        final n = pool[s]?.length ?? 0;
        if (n > 1) {
          var v = rnd.nextInt(n);
          if (v == idx[s]) v = (v + 1) % n;
          idx[s] = v;
        }
      }
    });
  }

  List<Clothes> get chosen => slots.map(cur).whereType<Clothes>().toList();

  Future<void> _save() async {
    setState(() => saving = true);
    final items = chosen;
    final cover = await composeOutfitCover(items);
    if (!mounted) return;
    setState(() => saving = false);
    push(context, OutfitFormPage(
      outfit: Outfit(type: 'flip', cover: cover, clothesIds: items.map((e) => e.id!).toList(), occasionIds: widget.occasionId == null ? [] : [widget.occasionId!]),
      isNew: true,
    ));
  }

  Future<void> _customSheet() async {
    final sel = [...customSlots];
    final r = await showSheet<List<String>>(
      context,
      (c) => StatefulBuilder(
        builder: (c, set) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 8, 8),
              child: Row(children: [
                const Text('选择搭配品类', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(c)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(spacing: 10, runSpacing: 10, children: [
                for (final s in flipSlots)
                  Pill(s, selected: sel.contains(s), icon: const SizedBox.shrink(), onTap: () => set(() => sel.contains(s) ? sel.remove(s) : sel.add(s))),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Row(children: [
                TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: kRose, shape: const StadiumBorder(), minimumSize: const Size.fromHeight(48)),
                    onPressed: sel.isEmpty ? null : () => Navigator.pop(c, flipSlots.where(sel.contains).toList()),
                    child: Text('应用 · ${sel.length} 个槽位'),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
      scroll: false,
    );
    if (r != null) {
      Settings.p.setStringList('flip_custom', r);
      setState(() {
        customSlots = r;
        mode = 'custom';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget modeBtn(String m, IconData icon, VoidCallback onTap) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(color: mode == m ? kRoseLight : Colors.transparent, shape: BoxShape.circle),
          child: IconButton(icon: Icon(icon, color: mode == m ? kRose : kInk), onPressed: onTap),
        );
    final canSave = chosen.length >= 2 && !saving;
    return Container(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [kBg, kBgBottom, Color(0xFFFDEEF2)])),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('翻牌'),
          centerTitle: false,
          actions: [
            modeBtn('tb', Icons.checkroom, () => setState(() => mode = 'tb')),
            modeBtn('dress', Icons.woman, () => setState(() => mode = 'dress')),
            modeBtn('custom', Icons.tune, _customSheet),
            const SizedBox(width: 6),
          ],
        ),
        body: pool.isEmpty && idx.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : GridView.count(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                crossAxisCount: 2,
                mainAxisSpacing: 18,
                crossAxisSpacing: 22,
                childAspectRatio: 0.78,
                children: [for (final s in slots) _slot(s)],
              ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 6, 16, 12),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.undo),
                color: kGrayText,
                onPressed: history.isEmpty
                    ? null
                    : () => setState(() {
                          idx = history.removeLast();
                        }),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _random,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: const BoxDecoration(color: kRoseLight, shape: BoxShape.circle, boxShadow: kSoftShadow),
                  child: const Icon(Icons.casino_outlined, color: kRose, size: 32),
                ),
              ),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: kRose,
                  disabledBackgroundColor: const Color(0xFFF6D5DE),
                  disabledForegroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                ),
                onPressed: canSave ? _save : null,
                child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('去保存', style: TextStyle(fontSize: 16)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _slot(String s) {
    final c = cur(s);
    final n = pool[s]?.length ?? 0;
    final lock = locked.contains(s);
    return Column(children: [
      Expanded(
        child: c == null
            ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const IconTile(Icons.checkroom_outlined, size: 60, iconSize: 32, color: kRoseSoft),
                const SizedBox(height: 6),
                Text(s, style: const TextStyle(fontWeight: FontWeight.w600)),
                const Text('暂无单品', style: TextStyle(color: kGrayText, fontSize: 12)),
              ])
            : GestureDetector(
                onTap: () => _step(s, 1),
                onHorizontalDragEnd: (d) => _step(s, (d.primaryVelocity ?? 0) < 0 ? 1 : -1),
                child: Stack(clipBehavior: Clip.none, children: [
                  if (n > 1)
                    Positioned.fill(
                      child: Transform.rotate(
                        angle: 0.12,
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          decoration: BoxDecoration(color: const Color(0xFFFFF5F7), borderRadius: BorderRadius.circular(20), border: Border.all(color: kPinkLine)),
                        ),
                      ),
                    ),
                  Positioned.fill(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (w, a) => ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(a), child: FadeTransition(opacity: a, child: w)),
                      child: Container(
                        key: ValueKey(c.id),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: kPinkBorder, width: 1.6),
                          boxShadow: kSoftShadow,
                        ),
                        child: Stack(children: [
                          Positioned.fill(child: Padding(padding: const EdgeInsets.fromLTRB(10, 10, 10, 18), child: AppImage(c.mainImage, placeholder: Colors.white))),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 8,
                            child: Center(child: Container(width: 22, height: 3, decoration: BoxDecoration(color: kRose, borderRadius: BorderRadius.circular(2)))),
                          ),
                          if (n > 1)
                            Positioned(
                              right: 4,
                              top: 4,
                              child: IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.refresh_rounded, size: 18, color: kRoseSoft),
                                onPressed: () {
                                  _push();
                                  setState(() {
                                    var v = rnd.nextInt(n);
                                    if (v == idx[s]) v = (v + 1) % n;
                                    idx[s] = v;
                                  });
                                },
                              ),
                            ),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ),
      ),
      const SizedBox(height: 10),
      GestureDetector(
        onTap: () => setState(() => lock ? locked.remove(s) : locked.add(s)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: lock ? kRoseLight : const Color(0xCCFFFFFF), borderRadius: BorderRadius.circular(14), border: Border.all(color: lock ? kRose : kPinkLine)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(s, style: TextStyle(fontSize: 13, color: lock ? kRose : kInk)),
            const SizedBox(width: 4),
            Icon(lock ? Icons.lock : Icons.lock_open, size: 14, color: lock ? kRose : kGrayText),
          ]),
        ),
      ),
    ]);
  }
}
