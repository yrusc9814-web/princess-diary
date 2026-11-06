import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';

/// 端侧抠图：开源 U²-Net（u2netp.onnx，Apache-2.0），全程离线。
/// 模型放在 assets/models/u2netp.onnx（见该目录 README）。
class Cutout {
  Cutout._();
  static final Cutout I = Cutout._();

  static const modelAsset = 'assets/models/u2netp.onnx';
  static const inputSize = 320;
  static const mean = [0.485, 0.456, 0.406];
  static const std = [0.229, 0.224, 0.225];

  OrtSession? _session;
  bool unavailable = false;

  Future<bool> _ensure() async {
    if (_session != null) return true;
    if (unavailable) return false;
    try {
      OrtEnv.instance.init();
      final raw = await rootBundle.load(modelAsset);
      _session = OrtSession.fromBuffer(raw.buffer.asUint8List(), OrtSessionOptions()..setIntraOpNumThreads(2));
      return true;
    } catch (e) {
      debugPrint('抠图模型加载失败：$e');
      unavailable = true;
      return false;
    }
  }

  /// 输入原图文件，输出裁掉透明边的 PNG；模型不可用或失败时返回 null（调用方保留原图）
  Future<Uint8List?> run(File src) async {
    if (!await _ensure()) return null;
    final bytes = await src.readAsBytes();
    final prep = await compute(_preprocess, bytes);
    final input = OrtValueTensor.createTensorWithDataList(prep.tensor, [1, 3, inputSize, inputSize]);
    final runOpts = OrtRunOptions();
    List<OrtValue?>? outputs;
    try {
      outputs = _session!.run(runOpts, {_session!.inputNames.first: input});
      // 第一个输出是融合后的显著性图 [1,1,320,320]
      final out = outputs.first!.value as List;
      final mask = Float32List(inputSize * inputSize);
      final plane = (out[0] as List)[0] as List;
      for (var y = 0; y < inputSize; y++) {
        final row = plane[y] as List;
        for (var x = 0; x < inputSize; x++) {
          mask[y * inputSize + x] = (row[x] as num).toDouble();
        }
      }
      return await compute(_compose, (prep.image, mask));
    } catch (e) {
      debugPrint('抠图失败：$e');
      return null;
    } finally {
      input.release();
      runOpts.release();
      outputs?.forEach((o) => o?.release());
    }
  }
}

class _Prep {
  final Float32List tensor;
  final Uint8List image; // 已缩放到长边 1024 的 PNG，用于合成
  _Prep(this.tensor, this.image);
}

_Prep _preprocess(Uint8List bytes) {
  var im = img.bakeOrientation(img.decodeImage(bytes)!);
  if (im.width > 1024 || im.height > 1024) {
    im = im.width >= im.height ? img.copyResize(im, width: 1024) : img.copyResize(im, height: 1024);
  }
  final small = img.copyResize(im, width: Cutout.inputSize, height: Cutout.inputSize, interpolation: img.Interpolation.linear);
  const n = Cutout.inputSize * Cutout.inputSize;
  final t = Float32List(3 * n);
  // 与 U²-Net 训练一致：先除以最大值，再按 ImageNet 均值方差归一化
  var maxV = 1.0;
  for (final px in small) {
    maxV = math.max(maxV, math.max(px.r.toDouble(), math.max(px.g.toDouble(), px.b.toDouble())));
  }
  for (final px in small) {
    final i = px.y * Cutout.inputSize + px.x;
    t[i] = (px.r / maxV - Cutout.mean[0]) / Cutout.std[0];
    t[n + i] = (px.g / maxV - Cutout.mean[1]) / Cutout.std[1];
    t[2 * n + i] = (px.b / maxV - Cutout.mean[2]) / Cutout.std[2];
  }
  return _Prep(t, Uint8List.fromList(img.encodePng(im)));
}

Uint8List _compose((Uint8List, Float32List) a) {
  final im = img.decodePng(a.$1)!.convert(numChannels: 4);
  final m = a.$2;
  // 归一化到 0-1
  var lo = double.infinity, hi = -double.infinity;
  for (final v in m) {
    lo = math.min(lo, v);
    hi = math.max(hi, v);
  }
  final range = (hi - lo).abs() < 1e-6 ? 1.0 : hi - lo;
  final maskIm = img.Image(width: Cutout.inputSize, height: Cutout.inputSize, numChannels: 1);
  for (var i = 0; i < m.length; i++) {
    final v = ((m[i] - lo) / range * 255).clamp(0, 255).toInt();
    maskIm.setPixelR(i % Cutout.inputSize, i ~/ Cutout.inputSize, v);
  }
  final big = img.copyResize(maskIm, width: im.width, height: im.height, interpolation: img.Interpolation.linear);
  var minX = im.width, minY = im.height, maxX = 0, maxY = 0;
  for (final px in im) {
    var alpha = big.getPixel(px.x, px.y).r.toInt();
    alpha = alpha < 20 ? 0 : (alpha > 235 ? 255 : alpha); // 去掉背景噪点，边缘保留过渡
    px.a = alpha;
    if (alpha > 0) {
      if (px.x < minX) minX = px.x;
      if (px.y < minY) minY = px.y;
      if (px.x > maxX) maxX = px.x;
      if (px.y > maxY) maxY = px.y;
    }
  }
  if (maxX <= minX || maxY <= minY) return Uint8List.fromList(img.encodePng(im));
  final cropped = img.copyCrop(im, x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1);
  return Uint8List.fromList(img.encodePng(cropped));
}
