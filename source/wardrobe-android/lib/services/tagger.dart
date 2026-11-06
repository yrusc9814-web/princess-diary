import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../data/taxonomy.dart';
import 'clip_tagger.dart';

class TagResult {
  String? cat1, cat2;
  List<String> colors = [];
  String? material, warmth, silhouette, length, layer, style;
  List<String> seasons = [];
}

/// 本地识别：SigLIP2 零样本打标（品类、颜色、材质、风格、季节、保暖度、轮廓、长度、叠穿）+ 像素取色。全程离线。
class Tagger {
  static Future<TagResult> analyze(File image, {bool colorsOnly = false}) async {
    final r = TagResult();
    final bytes = await image.readAsBytes();
    List<String> pixel = [];
    try {
      pixel = await compute(dominantColors, bytes);
    } catch (_) {}
    r.colors = pixel;
    final rk = await ClipTagger.I.rank(image);
    if (rk == null) return r;
    String top(String g) => (rk[g] == null || rk[g]!.isEmpty) ? '' : rk[g]!.first.$1;
    final col = taggerColorMap[top('colors')];
    if (col != null) r.colors = [col, ...pixel.where((c) => c != col)].take(3).toList();
    if (colorsOnly) return r;
    final cat = taggerCategoryMap[top('categoryL2')];
    if (cat != null) {
      r.cat1 = cat[0];
      r.cat2 = cat[1];
    }
    r.material = taggerMaterialMap[top('materials')];
    r.style = taggerStyleMap[top('styles')];
    final se = rk['seasons'];
    if (se != null && se.length >= 2) {
      r.seasons = [se[0].$1, se[1].$1].map((e) => taggerSeasonMap[e]).whereType<String>().toList();
      r.seasons.sort((a, b) => seasonOptions.indexOf(a).compareTo(seasonOptions.indexOf(b)));
    }
    final wear = !const ['鞋履', '包袋', '配饰'].contains(r.cat1);
    if (wear) {
      r.warmth = taggerWarmthMap[top('warmth')];
      r.silhouette = taggerFitMap[top('fit')];
      r.length = taggerLengthMap[top('length')];
      r.layer = r.cat1 == '外套' ? '外层' : (r.cat1 == '上装' ? (taggerLayerMap[top('layerRole')] ?? '打底') : null);
    }
    return r;
  }
}

/// 主色：不透明像素映射到基础色，按占比取前 3（占比 < 12% 的忽略）
List<String> dominantColors(Uint8List bytes) {
  var im = img.decodeImage(bytes)!;
  if (im.width > 160) im = img.copyResize(im, width: 160);
  final count = <String, int>{};
  var total = 0;
  for (final px in im) {
    if (im.numChannels == 4 && px.a < 128) continue;
    final c = _nearest(px.r.toInt(), px.g.toInt(), px.b.toInt());
    count[c] = (count[c] ?? 0) + 1;
    total++;
  }
  if (total == 0) return [];
  final sorted = count.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return sorted.where((e) => e.value / total >= 0.12).take(3).map((e) => e.key).toList();
}

String _nearest(int r, int g, int b) {
  final mx = math.max(r, math.max(g, b)) / 255, mn = math.min(r, math.min(g, b)) / 255;
  final v = mx, s = mx == 0 ? 0.0 : (mx - mn) / mx;
  if (v < 0.18) return '黑色';
  if (s < 0.12) return v > 0.85 ? '白色' : '灰色';
  double h;
  final d = mx - mn;
  final rf = r / 255, gf = g / 255, bf = b / 255;
  if (mx == rf) {
    h = 60 * (((gf - bf) / d) % 6);
  } else if (mx == gf) {
    h = 60 * ((bf - rf) / d + 2);
  } else {
    h = 60 * ((rf - gf) / d + 4);
  }
  if (h < 0) h += 360;
  if (s < 0.35 && v > 0.7 && h >= 20 && h <= 60) return '米色';
  if (s < 0.45 && v > 0.45 && v <= 0.75 && h >= 30 && h <= 60) return '卡其色';
  if (h < 15 || h >= 345) return v < 0.55 ? '棕色' : (s < 0.5 ? '粉色' : '红色');
  if (h < 40) return v < 0.6 ? '棕色' : '橙色';
  if (h < 70) return v < 0.5 ? '棕色' : '黄色';
  if (h < 165) return '绿色';
  if (h < 195) return '青色';
  if (h < 255) return v < 0.4 ? '藏青色' : '蓝色';
  if (h < 300) return '紫色';
  return '粉色';
}
