import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../main.dart';
import '../widgets/common.dart';
import 'clothes_detail_page.dart';
import 'outfit_form_page.dart';
import 'select_pages.dart';

final ValueNotifier<DateTime> calendarSelected = ValueNotifier(DateTime.now());

void openCalendarAt(DateTime d) {
  calendarSelected.value = d;
  Shell.tab.value = 3;
}

/// 添加单品/穿搭到某天
void showAddRecordSheet(BuildContext context, String date) {
  showSheet(
    context,
    (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SheetHandle(),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          leading: const Icon(Icons.checkroom, color: kPurple),
          title: const Text('添加单品到当天'),
          onTap: () async {
            Navigator.pop(c);
            final r = await push<List<int>>(context, SelectClothesPage(where: (x) => x.status != '丢弃'));
            if (r == null || r.isEmpty) return;
            for (final id in r) {
              await AppDb.I.addCal(CalRecord(date: date, clothesId: id));
            }
            toast(null, '保存成功');
          },
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          leading: const Icon(Icons.style_outlined, color: kPurple),
          title: const Text('添加穿搭到当天'),
          onTap: () async {
            Navigator.pop(c);
            final r = await push<List<int>>(context, const SelectOutfitsPage());
            if (r == null || r.isEmpty) return;
            for (final id in r) {
              await AppDb.I.addCal(CalRecord(date: date, outfitId: id));
            }
            toast(null, '保存成功');
          },
        ),
        const SizedBox(height: 8),
      ]),
    ),
    scroll: false,
  );
}

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> with DataReload {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime selected = DateTime.now();
  Map<String, List<CalRecord>> recs = {};
  Map<String, String> notes = {};
  Map<int, Clothes> cm = {};
  Map<int, Outfit> om = {};

  @override
  void initState() {
    super.initState();
    listenData(dataVersion);
    calendarSelected.addListener(_onSel);
    reload();
  }

  void _onSel() {
    final d = calendarSelected.value;
    setState(() {
      selected = d;
      month = DateTime(d.year, d.month);
    });
    reload();
  }

  @override
  void dispose() {
    unlistenData(dataVersion);
    calendarSelected.removeListener(_onSel);
    super.dispose();
  }

  @override
  Future<void> reload() async {
    final from = fmtDate(DateTime(month.year, month.month, 1).subtract(const Duration(days: 7)));
    final to = fmtDate(DateTime(month.year, month.month + 1, 7));
    final r = await AppDb.I.calendarRange(from, to);
    final n = await AppDb.I.dayNotesRange(from, to);
    final c = await AppDb.I.clothesMap();
    final o = {for (final x in await AppDb.I.outfits()) x.id!: x};
    if (!mounted) return;
    setState(() {
      recs = {};
      for (final x in r) {
        recs.putIfAbsent(x.date, () => []).add(x);
      }
      notes = n;
      cm = c;
      om = o;
    });
  }

  String? _thumb(CalRecord r) {
    if (r.outfitId != null) {
      final o = om[r.outfitId];
      return o?.cover ?? (o == null || o.photos.isEmpty ? null : o.photos.first);
    }
    return cm[r.clothesId]?.listImage;
  }

  void _move(int d) {
    setState(() => month = DateTime(month.year, month.month + d));
    reload();
  }

  Future<void> _editNote() async {
    final ds = fmtDate(selected);
    final ctl = TextEditingController(text: notes[ds] ?? '');
    final r = await showSheet<String>(
      context,
      (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(c).viewInsets.bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SheetHandle(),
          const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('编辑当天备注', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
          TextField(
            controller: ctl,
            autofocus: true,
            maxLines: 4,
            decoration: InputDecoration(hintText: '备注', border: OutlineInputBorder(borderRadius: BorderRadius.circular(6))),
          ),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
            const SizedBox(width: 8),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: kPurple), onPressed: () => Navigator.pop(c, ctl.text), child: const Text('保存')),
          ]),
        ]),
      ),
    );
    if (r == null) return;
    await AppDb.I.setDayNote(ds, r.trim());
    toast(null, '保存成功');
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final first = DateTime(month.year, month.month, 1);
    final start = first.subtract(Duration(days: first.weekday % 7));
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final rows = ((first.weekday % 7) + daysInMonth + 6) ~/ 7;
    final ds = fmtDate(selected);
    final dayRecs = recs[ds] ?? [];
    final isCurMonth = month.year == now.year && month.month == now.month;
    return Scaffold(
      appBar: AppBar(
        title: const Text('穿搭日历', style: TextStyle(fontSize: 24)),
        centerTitle: false,
        actions: [
          IconButton(icon: const Icon(Icons.edit_note), tooltip: '编辑当天备注', onPressed: _editNote),
          IconButton(icon: const Icon(Icons.add), onPressed: () => showAddRecordSheet(context, ds)),
        ],
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0).abs() > 200) _move((d.primaryVelocity ?? 0) < 0 ? 1 : -1);
        },
        child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _move(-1)),
              Expanded(
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('${month.year}年${month.month}月', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  if (!isCurMonth || !DateUtils.isSameDay(selected, now)) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          month = DateTime(now.year, now.month);
                          selected = now;
                        });
                        reload();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: kPurpleLight, borderRadius: BorderRadius.circular(10)),
                        child: const Text('回到今天', style: TextStyle(color: kPurple, fontSize: 12)),
                      ),
                    ),
                  ],
                ]),
              ),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _move(1)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(children: [
              for (final (i, w) in const ['日', '一', '二', '三', '四', '五', '六'].indexed)
                Expanded(child: Center(child: Text(w, style: TextStyle(color: i == 0 || i == 6 ? Colors.red : Colors.black87, fontWeight: FontWeight.w600)))),
            ]),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(children: [
              for (var r = 0; r < rows; r++)
                Row(children: [
                  for (var c = 0; c < 7; c++) Expanded(child: _cell(start.add(Duration(days: r * 7 + c)), now)),
                ]),
            ]),
          ),
          const SizedBox(height: 16),
          if (notes[ds]?.isNotEmpty == true)
            AppCard(
              onTap: _editNote,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.sticky_note_2_outlined, size: 18, color: kPurple),
                const SizedBox(width: 8),
                Expanded(child: Text(notes[ds]!, style: const TextStyle(height: 1.5))),
              ]),
            ),
          if (dayRecs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(children: [
                const Text('暂无记录', style: TextStyle(fontSize: 17, color: kGrayText)),
                const SizedBox(height: 4),
                Text(ds, style: const TextStyle(color: Color(0xFFB0B0B5))),
                const SizedBox(height: 14),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(shape: const StadiumBorder()),
                  onPressed: () => showAddRecordSheet(context, ds),
                  icon: const Icon(Icons.add),
                  label: const Text('添加记录'),
                ),
              ]),
            )
          else
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$ds  ${dayRecs.length}条记录', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: dayRecs.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final r = dayRecs[i];
                      return GestureDetector(
                        onTap: () {
                          if (r.outfitId != null && om[r.outfitId] != null) {
                            push(context, OutfitFormPage(outfit: om[r.outfitId]!));
                          } else if (r.clothesId != null) {
                            push(context, ClothesDetailPage(id: r.clothesId!));
                          }
                        },
                        child: Stack(clipBehavior: Clip.none, children: [
                          Container(
                            width: 90,
                            height: 120,
                            decoration: BoxDecoration(color: const Color(0xFFF4F4F6), borderRadius: BorderRadius.circular(12)),
                            clipBehavior: Clip.antiAlias,
                            child: AppImage(_thumb(r), placeholder: Colors.transparent),
                          ),
                          if (r.outfitId != null)
                            Positioned(
                              left: 4,
                              bottom: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                                child: const Text('穿搭', style: TextStyle(fontSize: 10)),
                              ),
                            ),
                          Positioned(
                            right: -6,
                            top: -6,
                            child: GestureDetector(
                              onTap: () async {
                                if (await confirm(context, '删除记录', '确定删除这条穿搭记录？')) await AppDb.I.deleteCal(r.id!);
                              },
                              child: const CircleAvatar(radius: 11, backgroundColor: Color(0x88000000), child: Icon(Icons.close, size: 14, color: Colors.white)),
                            ),
                          ),
                        ]),
                      );
                    },
                  ),
                ),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _cell(DateTime d, DateTime now) {
    final inMonth = d.month == month.month;
    final ds = fmtDate(d);
    final list = recs[ds] ?? [];
    final isToday = DateUtils.isSameDay(d, now);
    final isSel = DateUtils.isSameDay(d, selected);
    return GestureDetector(
      onTap: () => setState(() => selected = d),
      child: Container(
        height: 78,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFFE4E2EA) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFEDEDF0)),
        ),
        child: Opacity(
          opacity: inMonth ? 1 : 0.35,
          child: Stack(children: [
            Positioned(
              left: 4,
              top: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: isToday ? kPurple : null, borderRadius: BorderRadius.circular(5)),
                child: Text('${d.day}', style: TextStyle(fontSize: 12, color: isToday ? Colors.white : Colors.black87, fontWeight: isToday ? FontWeight.w700 : null)),
              ),
            ),
            if (list.isNotEmpty)
              Positioned(
                right: 3,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(color: const Color(0xFF8E83B5), borderRadius: BorderRadius.circular(5)),
                  child: Text('${list.length}', style: const TextStyle(fontSize: 10, color: Colors.white)),
                ),
              ),
            if (list.isNotEmpty)
              Positioned(left: 3, right: 3, top: 22, bottom: 3, child: AppImage(_thumb(list.first), placeholder: Colors.transparent)),
          ]),
        ),
      ),
    );
  }
}
