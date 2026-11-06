import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../main.dart';
import '../services/compose.dart';
import '../services/recommend.dart';
import '../services/weather.dart';
import '../widgets/common.dart';
import '../widgets/outfit_preview.dart';
import 'clothes_detail_page.dart';
import 'filter_settings_page.dart';
import 'outfit_form_page.dart';

const outfitRulesText = '1、智能搭配基于您的衣橱服装自动搭配，搭配效果和评分仅供参考。\n'
    '2、智能搭配基于衣物品类进行搭配，若衣物品类为空或选择“其他”，则不参与搭配。\n'
    '3、“今天可穿”会结合当前天气、今日温差、季节、保暖度、颜色、风格和最近穿着情况；“全衣橱灵感”不受天气和季节限制。\n'
    '4、可在「自动搭配过滤设置」中禁用部分衣物品类或搭配位。';

void showOutfitRules(BuildContext context) => showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('搭配说明'),
        content: const Text(outfitRulesText, style: TextStyle(height: 1.6)),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('我知道了'))],
      ),
    );

/// 把推荐保存成搭配：生成封面后进入「添加搭配」
Future<void> saveSuggestionAsOutfit(BuildContext context, Suggestion s) async {
  final cover = await composeOutfitCover(s.items);
  final o = Outfit(type: 'auto', cover: cover, clothesIds: s.items.map((e) => e.id!).toList(), seasons: []);
  if (context.mounted) await push(context, OutfitFormPage(outfit: o, isNew: true));
}

class SmartOutfitPage extends StatefulWidget {
  const SmartOutfitPage({super.key});
  @override
  State<SmartOutfitPage> createState() => _SmartOutfitPageState();
}

class _SmartOutfitPageState extends State<SmartOutfitPage> {
  int tab = 0; // 0 今天可穿 1 全衣橱灵感
  bool onlyUnsaved = false;
  bool loading = true;
  int seed = DateTime.now().millisecondsSinceEpoch % 100000;
  List<Suggestion> list = [];
  Set<String> savedKeys = {};
  String? hint;
  Weather? w;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() => loading = true);
    w = WeatherService.current.value ?? await WeatherService.load();
    final all = await AppDb.I.allClothes();
    savedKeys = (await AppDb.I.outfits()).map((o) => (o.clothesIds.toSet().toList()..sort()).join(',')).toSet();
    await Future.delayed(const Duration(milliseconds: 500));
    final Ctx ctx = tab == 0
        ? ctxFromWeather(max: w?.max, min: w?.min, temp: w?.temp, wind: w?.wind ?? 0, wet: w?.wet ?? false)
        : Ctx(temp: null, season: seasonOf(DateTime.now()), today: DateTime.now());
    final r = Recommender(all, ctx);
    final res = r.generate(count: 12, seed: seed);
    if (!mounted) return;
    setState(() {
      list = res;
      hint = r.missingHint();
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final shown = onlyUnsaved ? list.where((s) => !savedKeys.contains(s.key)).toList() : list;
    return Scaffold(
      appBar: appBar('智能搭配', center: false, actions: [
        IconButton(icon: const Icon(Icons.tune), onPressed: () async {
          await push(context, const FilterSettingsPage());
          _run();
        }),
        IconButton(icon: const Icon(Icons.refresh), onPressed: () {
          seed++;
          _run();
        }),
      ]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SegmentedButton<int>(
            segments: const [ButtonSegment(value: 0, label: Text('今天可穿')), ButtonSegment(value: 1, label: Text('全衣橱灵感'))],
            selected: {tab},
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(selectedBackgroundColor: kPurpleLight, selectedForegroundColor: kPurple),
            onSelectionChanged: (s) {
              setState(() => tab = s.first);
              _run();
            },
          ),
        ),
        if (tab == 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Row(children: [
              Icon(w?.icon ?? Icons.thermostat, size: 16, color: kGrayText),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  w == null ? '未获取到天气，按 20°C 推荐' : '根据当前${w!.temp.round()}°C、今日温差${(w!.max - w!.min).round()}°C推荐',
                  style: const TextStyle(color: kGrayText, fontSize: 13),
                ),
              ),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 8, 0),
          child: Row(children: [
            const Text('推荐搭配', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const Spacer(),
            Checkbox(value: onlyUnsaved, onChanged: (v) => setState(() => onlyUnsaved = v!)),
            const Text('仅看未保存'),
            IconButton(icon: const Icon(Icons.info_outline, size: 20), onPressed: () => showOutfitRules(context)),
          ]),
        ),
        Expanded(
          child: loading
              ? const Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 14),
                    Text('正在为你生成搭配…', style: TextStyle(color: kGrayText)),
                  ]),
                )
              : shown.isEmpty
                  ? EmptyState(
                      icon: Icons.checkroom_outlined,
                      title: tab == 0 ? '今天适穿的单品还凑不齐完整搭配' : '衣橱里的单品还凑不齐完整搭配',
                      sub: hint ?? (onlyUnsaved && list.isNotEmpty ? '推荐结果都已保存过' : '可能被「自动搭配过滤设置」过滤，或单品缺少衣物品类'),
                      action: Column(children: [
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: kPurple),
                          onPressed: () {
                            Navigator.popUntil(context, (r) => r.isFirst);
                            Shell.tab.value = 1;
                          },
                          child: const Text('检查衣橱'),
                        ),
                        if (tab == 0)
                          TextButton(
                            onPressed: () {
                              setState(() => tab = 1);
                              _run();
                            },
                            child: const Text('查看全衣橱灵感'),
                          ),
                      ]),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
                      itemCount: shown.length,
                      itemBuilder: (_, i) => SuggestionCard(shown[i], index: i + 1, saved: savedKeys.contains(shown[i].key), onSaved: _run),
                    ),
        ),
      ]),
    );
  }
}

/// 推荐结果卡片（自行设计：白色圆角卡、预览、评分、理由、保存）
class SuggestionCard extends StatelessWidget {
  final Suggestion s;
  final int index;
  final bool saved;
  final VoidCallback? onSaved;
  const SuggestionCard(this.s, {super.key, required this.index, this.saved = false, this.onSaved});
  @override
  Widget build(BuildContext context) => AppCard(
        onTap: () => push(context, SuggestionDetailPage(s)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('搭配 $index', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: kPurpleLight, borderRadius: BorderRadius.circular(10)),
              child: Text('${s.scorePct}分', style: const TextStyle(color: kPurple, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            const Spacer(),
            if (saved) const Text('已保存', style: TextStyle(color: kGrayText, fontSize: 12)),
          ]),
          const SizedBox(height: 8),
          OutfitPreview(s.items, height: 240),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final r in s.reasons)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFF4F4F6), borderRadius: BorderRadius.circular(8)),
                child: Text(r, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
                onPressed: () async {
                  for (final c in s.items) {
                    await AppDb.I.addCal(CalRecord(date: todayStr(), clothesId: c.id));
                  }
                  toast(null, '已记录到今天', style: 'dark');
                },
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: const Text('记录到今天'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: kPurple, shape: const StadiumBorder()),
                onPressed: saved
                    ? null
                    : () async {
                        await saveSuggestionAsOutfit(context, s);
                        onSaved?.call();
                      },
                icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                label: Text(saved ? '已保存' : '保存搭配'),
              ),
            ),
          ]),
        ]),
      );
}

/// 推荐详情：单品清单 + 理由 + 保存/记录
class SuggestionDetailPage extends StatelessWidget {
  final Suggestion s;
  const SuggestionDetailPage(this.s, {super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: appBar('搭配详情'),
        body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          AppCard(child: OutfitPreview(s.items, height: 380)),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('推荐理由', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('综合评分 ${s.scorePct}', style: const TextStyle(color: kPurple, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 8),
              for (final r in (s.reasons.isEmpty ? ['按衣物品类自动组合'] : s.reasons))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    const Icon(Icons.check_circle, size: 16, color: kPurple),
                    const SizedBox(width: 6),
                    Expanded(child: Text(r)),
                  ]),
                ),
            ]),
          ),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('包含单品（${s.items.length}）', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.78,
                children: [
                  for (final c in s.items) ClothesTile(c, showName: true, onTap: () => push(context, ClothesDetailPage(id: c.id!))),
                ],
              ),
            ]),
          ),
        ]),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: const StadiumBorder()),
                  onPressed: () async {
                    for (final c in s.items) {
                      await AppDb.I.addCal(CalRecord(date: todayStr(), clothesId: c.id));
                    }
                    toast(null, '已记录到今天', style: 'dark');
                  },
                  child: const Text('记录到今天'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: const StadiumBorder(), backgroundColor: kPurple),
                  onPressed: () => saveSuggestionAsOutfit(context, s),
                  child: const Text('保存为搭配'),
                ),
              ),
            ]),
          ),
        ),
      );
}
