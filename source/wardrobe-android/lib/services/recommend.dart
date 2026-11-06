import 'dart:math' as math;

import '../data/models.dart';
import '../data/taxonomy.dart';
import 'settings.dart';

/// 本地智能搭配：天气/温差 → 温度带 → 骨架（上装+下装 或 连衣裙/连体装）→ 叠穿（内搭层、外搭）→ 鞋/包/配饰
/// → 打分（温度适配、季节、颜色、风格统一、穿着轮换）→ 去重与多样性。遵守「自动搭配过滤设置」。
class Suggestion {
  final List<Clothes> items;
  final double score;
  final List<String> reasons;
  Suggestion(this.items, this.score, this.reasons);
  String get key => (items.map((e) => e.id!).toList()..sort()).join(',');
  int get scorePct => score.round().clamp(0, 100);
}

class Ctx {
  final double? temp; // 有效温度，null = 不考虑天气（全衣橱灵感）
  final double diff; // 温差
  final bool wet;
  final String season;
  final DateTime today;
  Ctx({this.temp, this.diff = 0, this.wet = false, required this.season, required this.today});
}

String seasonOf(DateTime d) {
  final m = d.month;
  if (m >= 3 && m <= 5) return '春季';
  if (m >= 6 && m <= 8) return '夏季';
  if (m >= 9 && m <= 11) return '秋季';
  return '冬季';
}

const _warmV = {'薄': 1, '适中': 2, '保暖': 3, '很保暖': 4};

/// 温度带：上装保暖度范围、外套需求（0 不要 1 可选 2 需要）、外套保暖度
({int need, List<int> top, List<int> outer, String label}) bandOf(double t) {
  if (t >= 26) return (need: 0, top: [1, 1], outer: [1, 1], label: '炎热');
  if (t >= 20) return (need: 1, top: [1, 2], outer: [1, 2], label: '温暖');
  if (t >= 14) return (need: 1, top: [1, 3], outer: [1, 3], label: '舒适偏凉');
  if (t >= 8) return (need: 2, top: [1, 3], outer: [2, 3], label: '微凉');
  return (need: 2, top: [2, 4], outer: [3, 4], label: '寒冷');
}

bool isDisabledByCat(Clothes c, List<String> disabled) {
  if (c.cat1 == null) return false;
  return disabled.contains(c.cat1) || (c.cat2 != null && disabled.contains('${c.cat1}/${c.cat2}'));
}

bool _isOuterLikeTop(Clothes c) =>
    c.cat1 == '上装' && (c.layer == '外层' || c.layer == '中间层' || const ['衬衫', '卫衣', '毛衣/针织衫'].contains(c.cat2));

class Recommender {
  final List<Clothes> pool;
  final Ctx ctx;
  final int? anchorId;
  final List<String> disabledCats;
  final List<String> disabledSlots;
  Recommender(List<Clothes> all, this.ctx, {this.anchorId, bool ownedOnly = true, List<String>? disabledCats, List<String>? disabledSlots})
      : disabledCats = disabledCats ?? Settings.disabledCats,
        disabledSlots = disabledSlots ?? Settings.disabledSlots,
        pool = all.where((c) {
          if (c.status == '丢弃') return false;
          if (ownedOnly && c.status != '拥有' && c.id != anchorId) return false;
          if (c.cat1 == null || c.cat1!.isEmpty || c.cat1 == '其他' || c.cat1 == '内衣/家居服') return false;
          return true;
        }).toList() {
    pool.removeWhere((c) => c.id != anchorId && isDisabledByCat(c, this.disabledCats));
    if (ctx.temp != null) {
      // 今天可穿：季节匹配（未设季节视为四季）
      pool.removeWhere((c) => c.id != anchorId && c.seasons.isNotEmpty && !c.seasons.contains(ctx.season));
    }
  }

  List<Clothes> _by(bool Function(Clothes) f) => pool.where(f).toList();

  double _tempFit(Clothes c, List<int> range) {
    final w = _warmV[c.warmth];
    if (w == null) return 0.65;
    if (w >= range[0] && w <= range[1]) return 1;
    return math.max(0, 1 - 0.4 * math.min((w - range[0]).abs(), (w - range[1]).abs()));
  }

  ({double s, String? why}) _color(List<Clothes> items) {
    final cs = items.map((e) => e.colors.isEmpty ? null : e.colors.first).whereType<String>().toList();
    if (cs.isEmpty) return (s: 0.6, why: null);
    final vivid = cs.where((c) => !isNeutralColor(c) && c != '多色').toSet().toList();
    final multi = cs.where((c) => c == '多色').length;
    if (multi > 1) return (s: 0.3, why: null);
    if (vivid.isEmpty) return (s: 0.85, why: '中性色组合，干净耐看');
    if (vivid.length == 1) return (s: 1, why: '中性色搭配一个亮点色');
    if (vivid.length == 2) {
      final d = ((colorHue[vivid[0]] ?? 0) - (colorHue[vivid[1]] ?? 0)).abs() % 360;
      final diff = math.min(d, 360 - d);
      if (diff <= 40) return (s: 0.9, why: '同色系搭配');
      if (diff >= 150) return (s: 0.65, why: '撞色搭配');
      return (s: 0.45, why: null);
    }
    return (s: 0.2, why: null);
  }

  double _fresh(Clothes c) {
    if (c.lastWear == null) return 1;
    final d = ctx.today.difference(DateTime.parse(c.lastWear!)).inDays;
    return d < 2 ? 0 : d < 5 ? 0.35 : math.min(1.0, 0.4 + d / 30);
  }

  Suggestion _score(List<Clothes> items, {bool layered = false}) {
    final reasons = <String>[];
    final t = ctx.temp;
    double sTemp = 0.7;
    if (t != null) {
      final b = bandOf(t);
      final core = items.where((c) => const ['上装', '下装', '连衣裙', '连体装', '外套'].contains(c.cat1)).toList();
      if (core.isNotEmpty) {
        sTemp = core.map((c) => _tempFit(c, c.cat1 == '外套' ? b.outer : b.top)).reduce((a, b) => a + b) / core.length;
      }
      if (sTemp >= 0.8) reasons.add('适合当前${t.round()}°C');
      if (layered && ctx.diff >= 8) reasons.add('今日温差${ctx.diff.round()}°C，叠穿方便增减');
    }
    final sSeason = items.where((e) => e.seasons.isEmpty || e.seasons.contains(ctx.season)).length / items.length;
    if (sSeason == 1 && items.any((e) => e.seasons.isNotEmpty)) reasons.add('${ctx.season}适穿');
    final col = _color(items);
    if (col.why != null) reasons.add(col.why!);
    final styles = items.map((e) => e.style).whereType<String>().toList();
    var sStyle = 0.6;
    if (styles.length >= 2) {
      final top = styles.fold<Map<String, int>>({}, (m, s) => m..[s] = (m[s] ?? 0) + 1).values.reduce(math.max);
      sStyle = top / styles.length;
      if (sStyle >= 0.99) reasons.add('风格统一：${styles.first}');
    }
    final fr = items.map(_fresh).toList();
    final sFresh = fr.reduce((a, b) => a + b) / fr.length;
    if (items.any((e) => e.wearCount == 0)) {
      reasons.add('有从未穿过的单品');
    } else if (sFresh > 0.8) {
      reasons.add('最近较少穿');
    }
    var total = 32 * sTemp + 14 * sSeason + 22 * col.s + 14 * sStyle + 18 * sFresh;
    if (ctx.wet && items.any((e) => e.cat2 == '凉鞋/拖鞋' || e.material == '麂皮')) total -= 8;
    return Suggestion(items, total, reasons.take(3).toList());
  }

  /// 生成若干套搭配
  List<Suggestion> generate({int count = 6, int seed = 0, Set<String> exclude = const {}}) {
    final rnd = math.Random(seed);
    final t = ctx.temp;
    final b = t == null ? null : bandOf(t);
    final noInner = disabledSlots.contains('内搭层');
    final noTopOuter = disabledSlots.contains('上装外搭来源');
    final noSysOuter = disabledSlots.contains('系统外套来源');
    final noBag = disabledSlots.contains('包袋');
    final noAcc = disabledSlots.contains('配饰');

    final tops = _by((c) => c.cat1 == '上装');
    final bottoms = _by((c) => c.cat1 == '下装');
    final ones = _by((c) => c.cat1 == '连衣裙' || c.cat1 == '连体装');
    final outers = <Clothes>[
      if (!noSysOuter) ..._by((c) => c.cat1 == '外套'),
      if (!noTopOuter) ...tops.where(_isOuterLikeTop),
    ];
    var shoes = _by((c) => c.cat1 == '鞋履');
    var bags = noBag ? <Clothes>[] : _by((c) => c.cat1 == '包袋');
    var accs = noAcc ? <Clothes>[] : _by((c) => c.cat1 == '配饰');
    // 详情页主单品是鞋/包/配饰时，固定放进对应位置
    final anchorC = anchorId == null ? null : pool.where((e) => e.id == anchorId).firstOrNull;
    var forceBag = false, forceAcc = false;
    if (anchorC != null) {
      if (anchorC.cat1 == '鞋履') shoes = [anchorC];
      if (anchorC.cat1 == '包袋') {
        bags = [anchorC];
        forceBag = true;
      }
      if (anchorC.cat1 == '配饰') {
        accs = [anchorC];
        forceAcc = true;
      }
    }

    final bases = <List<Clothes>>[
      for (final tp in tops) for (final bt in bottoms) [tp, bt],
      for (final o in ones) [o],
    ]..shuffle(rnd);

    final cands = <Suggestion>[];
    for (final base in bases.take(400)) {
      final List<Clothes?> outerOpts;
      if (b == null) {
        outerOpts = [null, ...outers];
      } else if (b.need == 0) {
        outerOpts = [null];
      } else if (b.need == 1) {
        outerOpts = [null, ...outers];
      } else {
        outerOpts = outers.isEmpty ? [null] : outers.cast<Clothes?>();
      }
      final anchorOuter = anchorId == null ? null : outers.where((e) => e.id == anchorId && e.cat1 == '外套').firstOrNull;
      final shuffledOuters = anchorOuter != null ? <Clothes?>[anchorOuter] : ([...outerOpts]..shuffle(rnd));
      for (final o in shuffledOuters.take(6)) {
        if (o != null && base.contains(o)) continue;
        final items = [...base, if (o != null) o];
        var layered = o != null;
        // 内搭层：外搭是上装（衬衫/毛衣等）时，给它配一件打底
        if (!noInner && o != null && o.cat1 == '上装' && base.first.cat1 == '上装' && base.first.layer == '中间层') {
          final inner = tops.where((x) => !items.contains(x) && (x.layer == '打底' || x.cat2 == 'T恤' || x.cat2 == '打底衫')).toList();
          if (inner.isNotEmpty) items.insert(0, inner[rnd.nextInt(inner.length)]);
        }
        if (shoes.isNotEmpty) items.add(shoes[rnd.nextInt(shoes.length)]);
        if (bags.isNotEmpty && (forceBag || rnd.nextDouble() < 0.6)) items.add(bags[rnd.nextInt(bags.length)]);
        if (accs.isNotEmpty) {
          final cold = t != null && t < 10;
          final ok = forceAcc ? accs : accs.where((a) => t == null || cold || !const ['围巾', '手套'].contains(a.cat2)).toList();
          if (ok.isNotEmpty && (forceAcc || rnd.nextDouble() < (cold ? 0.7 : 0.35))) items.add(ok[rnd.nextInt(ok.length)]);
        }
        if (anchorId != null && !items.any((e) => e.id == anchorId)) {
          // 详情页：把主单品放进对应位置
          continue;
        }
        if (t != null && t >= 26 && items.any((e) => e.cat2 == '羽绒服' || e.cat2 == '大衣' || e.warmth == '很保暖')) continue;
        cands.add(_score(items, layered: layered));
        layered = false;
      }
    }
    if (anchorId != null && cands.isEmpty) {
      // 主单品可能是鞋包配饰：在普通结果上替换同位
      final anchor = pool.where((e) => e.id == anchorId).firstOrNull;
      if (anchor != null && const ['鞋履', '包袋', '配饰'].contains(anchor.cat1)) {
        final base = Recommender(pool, ctx, ownedOnly: false, disabledCats: disabledCats, disabledSlots: disabledSlots)
            .generate(count: count * 2, seed: seed);
        for (final s in base) {
          final items = s.items.where((e) => e.cat1 != anchor.cat1).toList()..add(anchor);
          cands.add(_score(items));
        }
      }
    }
    cands.sort((a, b) => b.score.compareTo(a.score));
    final seen = {...exclude};
    final usage = <int, int>{};
    final out = <Suggestion>[];
    for (final c in cands) {
      if (seen.contains(c.key)) continue;
      if (c.items.any((e) => e.id != anchorId && (usage[e.id!] ?? 0) >= 2)) continue;
      seen.add(c.key);
      for (final e in c.items) {
        usage[e.id!] = (usage[e.id!] ?? 0) + 1;
      }
      out.add(c);
      if (out.length >= count) break;
    }
    return out;
  }

  /// 凑不齐时的提示
  String? missingHint() {
    final hasTop = pool.any((c) => c.cat1 == '上装');
    final hasBottom = pool.any((c) => c.cat1 == '下装');
    final hasOne = pool.any((c) => c.cat1 == '连衣裙' || c.cat1 == '连体装');
    if (hasOne || (hasTop && hasBottom)) return null;
    if (!hasTop && !hasBottom) return '缺少上装和下装（或连衣裙/连体装）';
    return hasTop ? '缺少下装' : '缺少上装';
  }
}

Ctx ctxFromWeather({double? max, double? min, double? temp, double wind = 0, bool wet = false, DateTime? day}) {
  final now = day ?? DateTime.now();
  double? t;
  if (max != null && min != null) {
    t = (max + min) / 2;
  } else {
    t = temp;
  }
  if (t != null) {
    if (wind > 29) t -= 1;
    if (wet) t -= 1.5;
  }
  return Ctx(temp: t ?? 20, diff: (max != null && min != null) ? (max - min) : 0, wet: wet, season: seasonOf(now), today: now);
}
