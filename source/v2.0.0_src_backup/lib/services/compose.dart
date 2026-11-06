import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../data/models.dart';
import 'images.dart';

int _order(Clothes c) => switch (c.cat1) {
      '外套' => 0,
      '上装' => 1,
      '连衣裙' || '连体装' => 1,
      '下装' => 2,
      '鞋履' => 3,
      '包袋' => 4,
      _ => 5,
    };

/// 把一组单品拼成一张封面图（左列主件，右列鞋包配饰），返回相对路径
Future<String> composeOutfitCover(List<Clothes> items) async {
  final sorted = [...items]..sort((a, b) => _order(a).compareTo(_order(b)));
  final main = <Uint8List>[], side = <Uint8List>[];
  for (final c in sorted) {
    final rel = c.mainImage;
    if (rel == null) continue;
    final f = File(ImageStore.abs(rel));
    if (!await f.exists()) continue;
    (_order(c) <= 2 ? main : side).add(await f.readAsBytes());
  }
  final png = await compute(_compose, (main, side));
  return ImageStore.savePng(png, 'cover');
}

Uint8List _compose((List<Uint8List>, List<Uint8List>) a) {
  const w = 900, h = 1100;
  final canvas = img.Image(width: w, height: h, numChannels: 4)..clear(img.ColorRgba8(255, 255, 255, 255));
  void place(Uint8List bytes, int x, int y, int bw, int bh) {
    final src = img.decodeImage(bytes);
    if (src == null) return;
    final s = (bw / src.width) < (bh / src.height) ? bw / src.width : bh / src.height;
    final r = img.copyResize(src, width: (src.width * s).round().clamp(1, bw), height: (src.height * s).round().clamp(1, bh));
    img.compositeImage(canvas, r, dstX: x + (bw - r.width) ~/ 2, dstY: y + (bh - r.height) ~/ 2);
  }

  final mainW = a.$2.isEmpty ? w - 40 : 540;
  if (a.$1.isNotEmpty) {
    final each = (h - 40) ~/ a.$1.length;
    for (var i = 0; i < a.$1.length; i++) {
      place(a.$1[i], 20, 20 + i * each, mainW, each - 10);
    }
  }
  if (a.$2.isNotEmpty) {
    final n = a.$2.length.clamp(1, 3);
    final each = (h - 40) ~/ n;
    for (var i = 0; i < n; i++) {
      place(a.$2[i], mainW + 40, 20 + i * each + 20, w - mainW - 60, each - 40);
    }
  }
  return Uint8List.fromList(img.encodePng(canvas));
}
