import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../main.dart';
import '../services/recommend.dart';
import '../services/settings.dart';
import '../services/weather.dart';
import '../widgets/common.dart';
import '../widgets/outfit_preview.dart';
import 'calendar_page.dart';
import 'flip_page.dart';
import 'smart_outfit_page.dart';
import 'stats_page.dart';
import 'trips_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with DataReload {
  List<Clothes> clothes = [];
  List<Outfit> outfits = [];
  Map<String, List<CalRecord>> days = {};
  int monthCount = 0;
  Suggestion? rec;
  String? recHint;
  int seed = Settings.recommendSeed;
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    listenData(dataVersion);
    WeatherService.current.addListener(_onWeather);
    reload();
    WeatherService.load();
  }

  void _onWeather() {
    if (mounted) _recommend();
  }

  @override
  void dispose() {
    unlistenData(dataVersion);
    WeatherService.current.removeListener(_onWeather);
    super.dispose();
  }

  @override
  Future<void> reload() async {
    final cs = await AppDb.I.allClothes();
    final os = await AppDb.I.outfits();
    final now = DateTime.now();
    final from = fmtDate(now.subtract(const Duration(days: 2)));
    final to = fmtDate(now.add(const Duration(days: 2)));
    final recs = await AppDb.I.calendarRange(from, to);
    final month = await AppDb.I.calendarRange(fmtDate(DateTime(now.year, now.month, 1)), fmtDate(DateTime(now.year, now.month + 1, 0)));
    if (!mounted) return;
    setState(() {
      clothes = cs;
      outfits = os;
      days = {};
      for (final r in recs) {
        days.putIfAbsent(r.date, () => []).add(r);
      }
      monthCount = month.map((e) => e.date).toSet().length;
      loaded = true;
    });
    _recommend();
  }

  void _recommend() {
    final w = WeatherService.current.value;
    final ctx = ctxFromWeather(max: w?.max, min: w?.min, temp: w?.temp, wind: w?.wind ?? 0, wet: w?.wet ?? false);
    final r = Recommender(clothes, ctx);
    final list = r.generate(count: 1, seed: seed);
    setState(() {
      rec = list.firstOrNull;
      recHint = rec == null ? (r.missingHint() ?? '可能被「自动搭配过滤设置」或季节过滤掉了') : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final active = clothes.where((c) => c.status != '丢弃').toList();
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await WeatherService.load(force: true);
            await reload();
          },
          child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 16),
              child: Row(children: [
                const Text('我的衣橱', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                const Spacer(),
                const _WeatherPill(),
              ]),
            ),
            // 衣橱概览
            AppCard(
              onTap: () => push(context, const StatsPage()),
              child: Column(children: [
                const _CardHeader('衣橱概览'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: const Color(0xFFF8F8FA), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFEFEFF2))),
                  child: Row(children: [
                    _stat('${active.length}', '衣物', const Color(0xFF6C5CE7)),
                    _stat('${outfits.length}', '搭配', const Color(0xFF3D8BFD)),
                    _stat('$monthCount', '本月', const Color(0xFF2EB67D)),
                    _stat('${active.where((c) => c.wearCount == 0).length}', '未穿', const Color(0xFFF0643C)),
                  ]),
                ),
              ]),
            ),
            // 穿搭日历
            AppCard(
              onTap: () => Shell.tab.value = 3,
              child: Column(children: [
                const _CardHeader('穿搭日历'),
                const SizedBox(height: 12),
                Row(children: [for (var i = -2; i <= 2; i++) Expanded(child: _dayCell(i))]),
              ]),
            ),
            // 今日推荐
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Text('今日推荐', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.black87),
                    onPressed: () {
                      seed++;
                      Settings.recommendSeed = seed;
                      _recommend();
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('换一换'),
                  ),
                ]),
                if (!loaded)
                  const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
                else if (rec == null)
                  _emptyRec()
                else ...[
                  GestureDetector(
                    onTap: () => push(context, SuggestionDetailPage(rec!)),
                    child: OutfitPreview(rec!.items, height: 320),
                  ),
                  const SizedBox(height: 10),
                  Text(rec!.reasons.isEmpty ? '根据当前天气推荐' : rec!.reasons.join(' · '), style: const TextStyle(color: kGrayText, fontSize: 13)),
                  const SizedBox(height: 12),
                  _recordButton(),
                ],
              ]),
            ),
            // 快捷入口
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('快捷入口', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Row(children: [
                  _quick(Icons.style_outlined, const Color(0xFFF0643C), '翻牌', '自由搭配', () => push(context, const FlipPage())),
                  const SizedBox(width: 10),
                  _quick(Icons.auto_awesome, const Color(0xFF6C5CE7), '智能搭配', '智能推荐', () => push(context, const SmartOutfitPage())),
                  const SizedBox(width: 10),
                  _quick(Icons.work_outline, const Color(0xFF8D5B3E), '行程', '出行清单', () => push(context, const TripsPage())),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _recordButton() {
    final done = Settings.recordedToday == '${todayStr()}|${rec!.key}';
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          side: BorderSide(color: done ? const Color(0xFFDDDDE2) : kPurple.withValues(alpha: 0.5)),
          backgroundColor: done ? const Color(0xFFF0F0F2) : kPurpleBg,
          foregroundColor: done ? kGrayText : kPurple,
        ),
        onPressed: done
            ? null
            : () async {
                for (final c in rec!.items) {
                  await AppDb.I.addCal(CalRecord(date: todayStr(), clothesId: c.id));
                }
                Settings.recordedToday = '${todayStr()}|${rec!.key}';
                toast(context, '已记录到今天', style: 'dark');
                setState(() {});
              },
        icon: Icon(done ? Icons.check : Icons.calendar_today_outlined, size: 17),
        label: Text(done ? '已记录' : '记录'),
      ),
    );
  }

  Widget _emptyRec() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Column(children: [
            const Icon(Icons.auto_awesome, color: Color(0xFFBDB4DD), size: 40),
            const SizedBox(height: 10),
            const Text('暂无合适推荐', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(active.isEmpty ? '衣橱里还没有可搭配的单品，先去添加几件吧' : '今天适穿的单品还凑不齐完整搭配${recHint == null ? '' : '（$recHint）'}',
                textAlign: TextAlign.center, style: const TextStyle(color: kGrayText, fontSize: 13)),
          ]),
        ),
      );

  List<Clothes> get active => clothes.where((c) => c.status == '拥有').toList();

  Widget _stat(String n, String label, Color dot) => Expanded(
        child: Column(children: [
          Text(n, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 5, height: 5, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: kGrayText)),
          ]),
        ]),
      );

  Widget _dayCell(int offset) {
    final d = DateTime.now().add(Duration(days: offset));
    final ds = fmtDate(d);
    final recs = days[ds] ?? [];
    final label = const {-2: '前天', -1: '昨天', 0: '今天', 1: '明天', 2: '后天'}[offset]!;
    String? img;
    if (recs.isNotEmpty) {
      final r = recs.first;
      if (r.outfitId != null) {
        final o = outfits.where((e) => e.id == r.outfitId).firstOrNull;
        img = o?.cover ?? (o?.photos.isEmpty ?? true ? null : o!.photos.first);
      } else {
        img = clothes.where((e) => e.id == r.clothesId).firstOrNull?.listImage;
      }
    }
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: offset == 0 ? kPurpleLight : null, borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(fontSize: 13, color: offset == 0 ? kPurple : Colors.black54, fontWeight: offset == 0 ? FontWeight.w600 : null)),
      ),
      const SizedBox(height: 4),
      Text('${d.month}/${d.day}', style: const TextStyle(fontSize: 12, color: kGrayText)),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: () => recs.isEmpty ? showAddRecordSheet(context, ds) : openCalendarAt(d),
        child: Container(
          width: 52,
          height: 66,
          decoration: BoxDecoration(color: const Color(0xFFF2F2F5), borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: recs.isEmpty
              ? const Icon(Icons.add, color: Color(0xFF9E9EA6))
              : Stack(children: [
                  Positioned.fill(child: AppImage(img, placeholder: Colors.transparent)),
                  if (recs.length > 1)
                    Positioned(
                      right: 3,
                      top: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(color: kPurple, borderRadius: BorderRadius.circular(6)),
                        child: Text('${recs.length}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                    ),
                ]),
        ),
      ),
    ]);
  }

  Widget _quick(IconData icon, Color color, String title, String sub, VoidCallback onTap) => Expanded(
        child: Material(
          color: const Color(0xFFF6F6F8),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(children: [
                Icon(icon, color: color, size: 26),
                const SizedBox(height: 6),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(sub, style: const TextStyle(fontSize: 11.5, color: kGrayText)),
              ]),
            ),
          ),
        ),
      );
}

class _CardHeader extends StatelessWidget {
  final String title;
  const _CardHeader(this.title);
  @override
  Widget build(BuildContext context) => Row(children: [
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const Spacer(),
        const Icon(Icons.chevron_right, color: kGrayText),
      ]);
}

class _WeatherPill extends StatelessWidget {
  const _WeatherPill();
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Weather?>(
        valueListenable: WeatherService.current,
        builder: (c, w, _) => GestureDetector(
          onTap: () => showWeatherSheet(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(w?.icon ?? Icons.wb_sunny_outlined, color: const Color(0xFFF5A623), size: 20),
              const SizedBox(width: 6),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(w == null ? '--°' : '${w.min.round()}°~${w.max.round()}°', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(w == null ? '定位中' : (w.city.isEmpty ? '当前位置' : w.city), style: const TextStyle(fontSize: 10.5, color: kGrayText)),
              ]),
            ]),
          ),
        ),
      );
}

void showWeatherSheet(BuildContext context) {
  var loading = false;
  showSheet(
    context,
    (c) => StatefulBuilder(
      builder: (c, set) => ValueListenableBuilder<Weather?>(
        valueListenable: WeatherService.current,
        builder: (c, w, _) {
          String two(int v) => v.toString().padLeft(2, '0');
          final up = w == null ? null : DateTime.fromMillisecondsSinceEpoch(w.updatedAt);
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.of(c).padding.bottom),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SheetHandle(),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.location_on, color: kPurple, size: 18),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () async {
                    final city = await inputDialog(c, '手动设置城市', initial: Settings.cityName, hint: '定位失败时使用，如：厦门');
                    if (city == null || city.isEmpty) return;
                    final g = await WeatherService.geocode(city);
                    if (g == null) {
                      toast(c, '未找到该城市');
                      return;
                    }
                    await Settings.setCity(g.name, g.lat, g.lng);
                    set(() => loading = true);
                    await WeatherService.load(force: true);
                    set(() => loading = false);
                  },
                  child: Text(w?.city.isNotEmpty == true ? w!.city : (Settings.cityName.isEmpty ? '点击设置城市' : Settings.cityName),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 26),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFBEADB), Color(0xFFFDF5EE)]),
                ),
                child: w == null
                    ? const Center(child: Text('暂无天气数据，请检查定位权限或手动设置城市', style: TextStyle(color: kGrayText)))
                    : Column(children: [
                        Icon(w.icon, size: 64, color: const Color(0xFFF5A623)),
                        const SizedBox(height: 8),
                        Text('${w.temp.round()}°', style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800)),
                        Text(w.text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text('今日 ${w.min.round()}°~${w.max.round()}° / 体感 ${w.feels.round()}°', style: const TextStyle(color: Colors.black54)),
                      ]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                _miniCard(Icons.water_drop, '降水概率', w == null ? '--' : '${w.precip}%'),
                const SizedBox(width: 12),
                _miniCard(Icons.air, '风力', w?.windText ?? '--'),
              ]),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(up == null ? '尚未更新' : '更新于 ${two(up.hour)}:${two(up.minute)}${w!.stale ? '（可能不准）' : ''}',
                    style: const TextStyle(color: kGrayText, fontSize: 13)),
                const Text('  |  ', style: TextStyle(color: Color(0xFFD0D0D5))),
                GestureDetector(
                  onTap: () async {
                    set(() => loading = true);
                    await WeatherService.load(force: true);
                    set(() => loading = false);
                  },
                  child: Row(children: [
                    loading
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh, size: 16, color: Colors.black54),
                    const SizedBox(width: 4),
                    const Text('刷新', style: TextStyle(color: Colors.black54, fontSize: 13)),
                  ]),
                ),
              ]),
            ]),
          );
        },
      ),
    ),
  );
}

Widget _miniCard(IconData icon, String label, String value) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFF6F6F8), borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          CircleAvatar(radius: 18, backgroundColor: kPurpleLight, child: Icon(icon, color: kPurple, size: 18)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 12, color: kGrayText)),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
    );
