import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path_provider/path_provider.dart';

/// 端侧零样本打标：开源 SigLIP2 base（google/siglip2-base-patch16-224，Apache-2.0）。
/// 原理：图片 → 768 维向量，与 tag_embeddings.json 里预先算好的标签向量做余弦相似度，每组取最高分。
/// - 模型：assets/models/siglip2_vision.onnx（fp32 计算、fp16 存权重，约 186MB，ORT 1.15 可加载）
/// - 标签向量：assets/models/tag_embeddings.json（用 SigLIP2 文字模型离线生成，见 tools/gen_tag_embeddings.py）
/// - 预处理：铺白底 → 224×224 双三次 → (x/255-0.5)/0.5 → NCHW；输出取 pooler_output 并 L2 归一化。
class ClipTagger {
  ClipTagger._();
  static final ClipTagger I = ClipTagger._();

  static const modelAsset = 'assets/models/siglip2_vision.onnx';
  static const embAsset = 'assets/models/tag_embeddings.json';
  static const size = 224;

  OrtSession? _session;
  Map<String, List<(String, Float32List)>> _groups = {};
  bool unavailable = false;

  Future<bool> _ensure() async {
    if (_session != null) return true;
    if (unavailable) return false;
    try {
      OrtEnv.instance.init();
      // 186MB 不整块读进内存：首次启动拷到私有目录，再从文件加载
      final dir = await getApplicationSupportDirectory();
      final f = File('${dir.path}/siglip2_vision.onnx');
      if (!await f.exists()) {
        final raw = await rootBundle.load(modelAsset);
        await f.writeAsBytes(raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes), flush: true);
      }
      _session = OrtSession.fromFile(f, OrtSessionOptions()..setIntraOpNumThreads(4));
      final j = jsonDecode(await rootBundle.loadString(embAsset)) as Map<String, dynamic>;
      _groups = (j['groups'] as Map<String, dynamic>).map((g, list) => MapEntry(
          g,
          (list as List)
              .map((e) => ('${e['key']}', Float32List.fromList((e['vec'] as List).map((x) => (x as num).toDouble()).toList())))
              .toList()));
      return true;
    } catch (e) {
      debugPrint('打标模型加载失败：$e');
      unavailable = true;
      return false;
    }
  }

  /// 返回每组按分数降序的 (key, score)；失败返回 null
  Future<Map<String, List<(String, double)>>?> rank(File image) async {
    if (!await _ensure()) return null;
    final tensor = await compute(_prep, await image.readAsBytes());
    final input = OrtValueTensor.createTensorWithDataList(tensor, [1, 3, size, size]);
    final opts = OrtRunOptions();
    List<OrtValue?>? outs;
    try {
      final names = _session!.outputNames;
      final pooled = names.contains('pooler_output') ? 'pooler_output' : names.last;
      outs = _session!.run(opts, {_session!.inputNames.first: input}, [pooled]);
      final v = Float32List.fromList(((outs.first!.value as List)[0] as List).map((x) => (x as num).toDouble()).toList());
      var n = 0.0;
      for (final x in v) n += x * x;
      n = math.sqrt(n);
      final res = <String, List<(String, double)>>{};
      _groups.forEach((g, list) {
        final s = list.map((e) {
          var d = 0.0;
          for (var i = 0; i < v.length; i++) d += v[i] * e.$2[i];
          return (e.$1, d / n);
        }).toList()
          ..sort((a, b) => b.$2.compareTo(a.$2));
        res[g] = s;
      });
      return res;
    } catch (e) {
      debugPrint('打标失败：$e');
      return null;
    } finally {
      input.release();
      opts.release();
      outs?.forEach((o) => o?.release());
    }
  }
}

Float32List _prep(Uint8List bytes) {
  var im = img.bakeOrientation(img.decodeImage(bytes)!);
  final bg = img.Image(width: im.width, height: im.height)..clear(img.ColorRgb8(255, 255, 255));
  img.compositeImage(bg, im);
  final s = img.copyResize(bg, width: ClipTagger.size, height: ClipTagger.size, interpolation: img.Interpolation.cubic);
  const n = ClipTagger.size * ClipTagger.size;
  final t = Float32List(3 * n);
  for (final px in s) {
    final i = px.y * ClipTagger.size + px.x;
    t[i] = (px.r / 255 - 0.5) / 0.5;
    t[n + i] = (px.g / 255 - 0.5) / 0.5;
    t[2 * n + i] = (px.b / 255 - 0.5) / 0.5;
  }
  return t;
}
