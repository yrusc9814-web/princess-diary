import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';
import 'outfit_form_page.dart';
import 'select_pages.dart';

class TripsPage extends StatefulWidget {
  const TripsPage({super.key});
  @override
  State<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends State<TripsPage> with DataReload {
  List<Trip> trips = [];
  Map<int, (int, int)> progress = {};
  bool loaded = false;

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
    final t = await AppDb.I.trips();
    final p = <int, (int, int)>{};
    for (final x in t) {
      final items = await AppDb.I.tripItems(x.id!);
      p[x.id!] = (items.where((e) => e.packed).length, items.length);
    }
    if (!mounted) return;
    setState(() {
      trips = t;
      progress = p;
      loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: appBar('行程', actions: [if (trips.isNotEmpty) IconButton(icon: const Icon(Icons.add), onPressed: () => createTrip(context))]),
        body: !loaded
            ? const Center(child: CircularProgressIndicator())
            : trips.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: Column(children: [
                        Image.asset(Illus.trip, width: 190, fit: BoxFit.contain),
                        const SizedBox(height: 18),
                        const Text('开启你的下一次旅程', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kInk)),
                        const SizedBox(height: 18),
                        for (final t in const [
                          (Icons.checklist, '按搭配添加，自动生成清单'),
                          (Icons.auto_awesome, '智能推荐，补全出行装备'),
                          (Icons.task_alt, '装箱打钩，不再遗漏好物'),
                        ])
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(t.$1, size: 18, color: kRose),
                              const SizedBox(width: 8),
                              Text(t.$2, style: const TextStyle(color: Color(0xFF7A6E73))),
                            ]),
                          ),
                        const SizedBox(height: 26),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: kRose, shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14)),
                          onPressed: () => createTrip(context),
                          icon: const Icon(Icons.add),
                          label: const Text('创建新行程', style: TextStyle(fontSize: 16)),
                        ),
                      ]),
                    ),
                  )
                : ListView(padding: const EdgeInsets.only(top: 4, bottom: 24), children: [
                    for (final t in trips)
                      AppCard(
                        onTap: () => push(context, TripDetailPage(id: t.id!)),
                        child: Row(children: [
                          const IconTile(Icons.work_outline, size: 44, iconSize: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(t.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text('${t.startDate} ~ ${t.endDate}', style: const TextStyle(color: kGrayText, fontSize: 13)),
                            ]),
                          ),
                          if ((progress[t.id]?.$2 ?? 0) > 0)
                            Text('已装箱 ${progress[t.id]!.$1}/${progress[t.id]!.$2}', style: const TextStyle(color: kRose, fontSize: 13)),
                          const Icon(Icons.chevron_right, color: kRose),
                        ]),
                      ),
                  ]),
      );
}

/// 新建行程 / 编辑行程
Future<void> createTrip(BuildContext context, {Trip? edit}) async {
  final name = TextEditingController(text: edit?.name ?? '');
  var start = edit == null ? DateTime.now() : DateTime.parse(edit.startDate);
  var end = edit == null ? DateTime.now().add(const Duration(days: 2)) : DateTime.parse(edit.endDate);
  final r = await showSheet<Trip>(
    context,
    (c) => StatefulBuilder(
      builder: (c, set) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(c).viewInsets.bottom + 16 + MediaQuery.of(c).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SheetHandle(),
          Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(edit == null ? '新建行程' : '编辑行程', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
          const Text('行程名称', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: name,
            autofocus: edit == null,
            decoration: InputDecoration(hintText: '例如：厦门三日游', filled: true, fillColor: kCellBg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _dateBox(c, '开始日期', start, (d) => set(() {
                  start = d;
                  if (end.isBefore(start)) end = start;
                }))),
            const SizedBox(width: 12),
            Expanded(child: _dateBox(c, '结束日期', end, (d) => set(() => end = d))),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kRose, shape: const StadiumBorder()),
              onPressed: () async {
                if (name.text.trim().isEmpty) {
                  toast(c, '请输入行程名称');
                  return;
                }
                if (end.isBefore(start)) {
                  toast(c, '开始日期不能晚于结束日期');
                  return;
                }
                final t = edit ?? Trip(name: '', startDate: '', endDate: '');
                t
                  ..name = name.text.trim()
                  ..startDate = fmtDate(start)
                  ..endDate = fmtDate(end);
                await AppDb.I.saveTrip(t);
                if (c.mounted) Navigator.pop(c, t);
              },
              child: Text(edit == null ? '创建并开始准备' : '保存', style: const TextStyle(fontSize: 16)),
            ),
          ),
        ]),
      ),
    ),
  );
  if (r != null && edit == null && context.mounted) push(context, TripDetailPage(id: r.id!));
}

Widget _dateBox(BuildContext c, String label, DateTime d, ValueChanged<DateTime> on) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      InkWell(
        onTap: () async {
          final r = await pickDate(c, d, title: label);
          if (r != null) on(r);
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(color: kCellBg, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(Icons.calendar_today_outlined, size: 16, color: kGrayText),
            const SizedBox(width: 6),
            Text(fmtDate(d)),
          ]),
        ),
      ),
    ]);

class TripDetailPage extends StatefulWidget {
  final int id;
  const TripDetailPage({super.key, required this.id});
  @override
  State<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends State<TripDetailPage> with DataReload {
  Trip? t;
  List<TripItem> items = [];
  List<Outfit> outfits = [];
  Map<int, Clothes> cm = {};

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
    final x = await AppDb.I.tripById(widget.id);
    if (x == null) return;
    final it = await AppDb.I.tripItems(widget.id);
    final oids = await AppDb.I.tripOutfitIds(widget.id);
    final all = {for (final o in await AppDb.I.outfits()) o.id!: o};
    final m = await AppDb.I.clothesMap();
    if (!mounted) return;
    setState(() {
      t = x;
      items = it.where((e) => m.containsKey(e.clothesId)).toList();
      outfits = oids.map((e) => all[e]).whereType<Outfit>().toList();
      cm = m;
    });
  }

  Future<void> _pickOutfits() async {
    final r = await push<List<int>>(context, SelectOutfitsPage(multi: true, initial: outfits.map((e) => e.id!).toList()));
    if (r == null) return;
    final cur = outfits.map((e) => e.id!).toSet();
    final add = r.where((e) => !cur.contains(e)).toList();
    for (final id in cur.where((e) => !r.contains(e))) {
      await AppDb.I.removeTripOutfit(widget.id, id);
    }
    await AppDb.I.addTripOutfits(widget.id, add);
    final n = items.length;
    await reload();
    if (add.isNotEmpty) toast(null, '已添加 ${add.length} 套搭配，新增 ${items.length - n > 0 ? items.length - n : 0} 件携带衣物。清单已自动去重。', style: 'dark');
  }

  Future<void> _pickClothes() async {
    final r = await push<List<int>>(context, SelectClothesPage(where: (c) => c.status != '丢弃'));
    if (r == null || r.isEmpty) return;
    await AppDb.I.addTripClothes(widget.id, r);
    toast(null, '保存成功');
  }

  @override
  Widget build(BuildContext context) {
    final x = t;
    final w = MediaQuery.of(context).size.width;
    // 每件衣物来自几套搭配
    final from = <int, int>{};
    for (final o in outfits) {
      for (final id in o.clothesIds.toSet()) {
        from[id] = (from[id] ?? 0) + 1;
      }
    }
    // 品类汇总
    final sum = <String, Map<String, int>>{};
    for (final i in items) {
      final c = cm[i.clothesId]!;
      final k1 = c.cat1 ?? '未设置衣物品类';
      sum.putIfAbsent(k1, () => {});
      if (c.cat2 != null) sum[k1]![c.cat2!] = (sum[k1]![c.cat2!] ?? 0) + 1;
      sum[k1]!['__'] = (sum[k1]!['__'] ?? 0) + 1;
    }
    final sumText = sum.entries.map((e) {
      final subs = e.value.entries.where((s) => s.key != '__').map((s) => '${s.key} ${s.value}').join('，');
      return '${e.key} ${e.value['__']}${subs.isEmpty ? '' : ' ($subs)'}';
    }).join('   ');
    final packed = items.where((e) => e.packed).length;
    return Scaffold(
      appBar: appBar('行程详情', actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            if (await confirm(context, '删除行程', '确定删除这个行程？', danger: true, ok: '删除')) {
              await AppDb.I.deleteTrip(widget.id);
              if (context.mounted) Navigator.pop(context);
            }
          },
        ),
      ]),
      body: x == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.only(top: 4, bottom: 24), children: [
              AppCard(
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(x.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.calendar_today_outlined, size: 15, color: kGrayText),
                        const SizedBox(width: 6),
                        Text('${x.startDate} ~ ${x.endDate}', style: const TextStyle(color: kGrayText)),
                      ]),
                    ]),
                  ),
                  IconButton(icon: const Icon(Icons.edit_outlined, color: kGrayText), onPressed: () => createTrip(context, edit: x)),
                ]),
              ),
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('添加到行程', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(children: [
                    _bigBtn(Icons.style_outlined, kRose, '选搭配', '自动汇总衣物', _pickOutfits),
                    const SizedBox(width: 12),
                    _bigBtn(Icons.checkroom, kRose, '选单品', '直接挑选单品', _pickClothes),
                  ]),
                ]),
              ),
              if (items.isEmpty && outfits.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Column(children: [
                    Image(image: AssetImage(Illus.trip), width: 150),
                    SizedBox(height: 12),
                    Text('选择搭配后，会自动去重整理\n需要携带的衣物', textAlign: TextAlign.center, style: TextStyle(color: kGrayText, height: 1.6)),
                  ]),
                )
              else ...[
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Text('携带衣物', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.info_outline, size: 18),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('携带衣物'),
                            content: const Text('多套搭配里重复的单品只会出现一次；移除搭配时，没有其他来源的单品会自动移出清单。点击单品右上角的勾可标记是否已装箱。'),
                            actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('知道了'))],
                          ),
                        ),
                      ),
                      if (items.isNotEmpty) Text('已装箱 $packed/${items.length}', style: const TextStyle(color: kRose, fontSize: 12)),
                      const Spacer(),
                      TextButton.icon(onPressed: _pickClothes, icon: const Icon(Icons.add, size: 18), label: const Text('添加单品'), style: TextButton.styleFrom(foregroundColor: kRose)),
                    ]),
                    if (sumText.isNotEmpty) Text(sumText, style: const TextStyle(color: kGrayText, fontSize: 12)),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: w / 3.5 / 0.72,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) {
                          final it = items[i];
                          final c = cm[it.clothesId]!;
                          final n = from[it.clothesId] ?? 0;
                          return GestureDetector(
                            onLongPress: () async {
                              if (await confirm(context, '移出清单', '把这件单品移出携带清单？')) await AppDb.I.removeTripItem(widget.id, it.clothesId);
                            },
                            child: Container(
                              width: w / 3.5,
                              decoration: BoxDecoration(color: kCellBg, borderRadius: BorderRadius.circular(12)),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(children: [
                                Column(children: [
                                  Expanded(child: Padding(padding: const EdgeInsets.all(6), child: AppImage(c.listImage, placeholder: Colors.transparent))),
                                  Container(
                                    width: double.infinity,
                                    color: const Color(0xFFF5D5DE),
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Text(n > 0 ? '用于 $n 套搭配' : '单独添加', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                                  ),
                                ]),
                                Positioned(
                                  right: 4,
                                  top: 4,
                                  child: GestureDetector(
                                    onTap: () => AppDb.I.setPacked(it.id!, !it.packed),
                                    child: Icon(it.packed ? Icons.check_circle : Icons.radio_button_unchecked, color: it.packed ? kRose : kRoseSoft, size: 24),
                                  ),
                                ),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text('长按单品可移出清单', style: TextStyle(fontSize: 11, color: Color(0xFFB9AEB2))),
                  ]),
                ),
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Text('穿搭组合', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      TextButton.icon(onPressed: _pickOutfits, icon: const Icon(Icons.add, size: 18), label: const Text('添加搭配'), style: TextButton.styleFrom(foregroundColor: kRose)),
                    ]),
                    if (outfits.isEmpty)
                      const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('还没有添加搭配', style: TextStyle(color: kGrayText)))
                    else
                      SizedBox(
                        height: w * 0.37 / 0.72,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: outfits.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (_, i) => Stack(clipBehavior: Clip.none, children: [
                            SizedBox(width: w * 0.37, child: OutfitTile(outfits[i], showName: true, onTap: () => push(context, OutfitFormPage(outfit: outfits[i])))),
                            Positioned(
                              right: -4,
                              top: -4,
                              child: GestureDetector(
                                onTap: () async {
                                  if (await confirm(context, '移除搭配', '从行程中移除这套搭配？只属于这套搭配的单品也会移出携带清单。')) {
                                    await AppDb.I.removeTripOutfit(widget.id, outfits[i].id!);
                                  }
                                },
                                child: const CircleAvatar(radius: 11, backgroundColor: Color(0x88000000), child: Icon(Icons.close, size: 14, color: Colors.white)),
                              ),
                            ),
                          ]),
                        ),
                      ),
                  ]),
                ),
              ],
            ]),
    );
  }

  Widget _bigBtn(IconData icon, Color color, String t, String sub, VoidCallback onTap) => Expanded(
        child: Material(
          color: const Color(0xFFFFF0F4),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(children: [
                IconTile(icon, size: 44, iconSize: 24, color: color),
                const SizedBox(height: 6),
                Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(sub, style: const TextStyle(fontSize: 12, color: kGrayText)),
              ]),
            ),
          ),
        ),
      );
}
