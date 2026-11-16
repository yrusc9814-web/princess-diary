import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'settings.dart';

/// 阿里云百炼「千问-图像编辑」（qwen-image-3.0 / qwen-image-3.0-pro）同步接口。
///
/// 历史：原 aitryon / aitryon-plus（AI 试衣）已被阿里下架（2026-11），改为多模态图像编辑模型。
/// 价格：qwen-image-3.0 输入 0.02 元/张、输出 0.18 元/张（标准版一次约 0.2 元）；qwen-image-3.0-pro 更贵。
/// 必须用华北 2（北京）地域的 API Key。
///
/// 流程：本地图片直接转 Base64（data:{mime};base64,...）→ POST 同步接口 → 从
/// output.choices[0].message.content[] 里取第一个带 image 字段的 URL（24 小时有效）→ 立即下载成字节返回。
class TryOn {
  static const _endpoint = 'https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation';

  /// 可选模型：id → 中文名（设置页单选项）
  static const models = {
    'qwen-image-3.0': '标准版（较快、便宜）',
    'qwen-image-3.0-pro': '高清版（细节更好、较慢）',
  };

  static const _negativePrompt = '改变人脸，改变发型，改变姿势，改变背景，多余的手指，畸形，模糊，低质量';

  /// 按有几件衣服拼编辑指令。图1 固定是本人；上衣（连衣裙放上衣位）为图2；有下装则顺延。
  static String prompt({required bool hasTop, required bool hasBottom}) {
    final parts = <String>[];
    var n = 2;
    if (hasTop) {
      parts.add('图${n++}中的上衣（如果是连衣裙就整件穿上）');
    }
    if (hasBottom) {
      parts.add('图${n++}中的下装');
    }
    final head = parts.isEmpty ? '把图1人物的衣服换成参考图中的衣服' : '把图1人物的衣服换成${parts.join('和')}';
    return '$head，严格保持图1人物的脸、发型、体型、姿势、背景和光线完全不变，只替换对应部位的衣服；'
        '衣服的颜色、图案、材质、logo 和版型要和参考图一致，穿着自然贴身，真实照片质感。';
  }

  /// 读文件转 data URI；读不到就抛错。
  static Future<String> _dataUri(File f) async {
    final bytes = await f.readAsBytes();
    final name = f.path.toLowerCase();
    final mime = name.endsWith('.png') ? 'image/png' : (name.endsWith('.webp') ? 'image/webp' : 'image/jpeg');
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  /// 常见错误码翻成大白话
  static String friendlyError(String? code, String? message) {
    switch (code) {
      case 'InvalidApiKey':
        return 'API Key 不对（要用华北2 北京地域的 Key）';
      case 'Arrearage':
        return '账户欠费或额度已用完';
      case 'DataInspectionFailed':
        return '图片没过内容审核，换一张试试';
      case 'Throttling':
      case 'Throttling.RateQuota':
        return '请求太频繁，稍后再试';
      case 'AccessDenied':
      case 'Model.AccessDenied':
        return '这个 Key 没开通该模型';
    }
    final m = (message == null || message.trim().isEmpty) ? '未知错误' : message.trim();
    return '生成失败：$m';
  }

  /// person: 本人正面全身照；top/bottom: 衣物图（连衣裙放 top，bottom 传 null）。返回结果图字节。
  static Future<Uint8List> run({required File person, File? top, File? bottom, void Function(String)? onStep}) async {
    final key = Settings.dashscopeKey;
    if (key.isEmpty) throw StateError('请先在「设置 > AI 试衣」里填写阿里云百炼 API Key');
    final m = Settings.tryOnModel;
    onStep?.call('准备图片');
    final content = <Map<String, String>>[
      {'image': await _dataUri(person)},
      if (top != null) {'image': await _dataUri(top)},
      if (bottom != null) {'image': await _dataUri(bottom)},
      {'text': prompt(hasTop: top != null, hasBottom: bottom != null)},
    ];
    final body = jsonEncode({
      'model': m,
      'input': {
        'messages': [
          {'role': 'user', 'content': content},
        ],
      },
      'parameters': {'n': 1, 'watermark': false, 'prompt_extend': false, 'negative_prompt': _negativePrompt},
    });
    onStep?.call(m == 'qwen-image-3.0-pro' ? '生成中（约 1 分钟）' : '生成中（约 30 秒）');

    http.Response r;
    try {
      r = await http
          .post(Uri.parse(_endpoint),
              headers: {'Authorization': 'Bearer $key', 'Content-Type': 'application/json'},
              body: utf8.encode(body))
          .timeout(const Duration(minutes: 4));
    } on TimeoutException {
      throw const HttpException('生成超时，请检查网络后重试');
    }

    Map<String, dynamic> j = const {};
    try {
      j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      // 非 JSON 响应，下面按状态码处理
    }
    if (r.statusCode != 200) {
      throw HttpException(friendlyError(j['code'] as String?, j['message'] as String?));
    }

    final content2 = (j['output']?['choices']?[0]?['message']?['content']) as List?;
    String? url;
    for (final c in content2 ?? const []) {
      if (c is Map && c['image'] is String && (c['image'] as String).isNotEmpty) {
        url = c['image'] as String;
        break;
      }
    }
    if (url == null) throw HttpException(friendlyError(j['code'] as String?, j['message'] as String? ?? '返回里没有图片'));

    onStep?.call('下载结果');
    http.Response img;
    try {
      img = await http.get(Uri.parse(url)).timeout(const Duration(minutes: 1));
    } on TimeoutException {
      throw const HttpException('生成超时，请检查网络后重试');
    }
    if (img.statusCode != 200) throw HttpException('下载结果失败 ${img.statusCode}');
    return img.bodyBytes;
  }
}
