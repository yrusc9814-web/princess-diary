import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'settings.dart';

/// 可选：阿里云百炼 AI 试衣（aitryon 0.2 元/张，aitryon-plus 0.5 元/张，各有 400 张免费额度）。
/// 必须用华北 2（北京）地域的 API Key。流程：本地图片 → 百炼临时存储(oss://) → 提交异步任务 → 轮询 → 下载结果。
/// 接口细节以百炼官方文档《AI试衣 API 参考》为准，接入时请核对一遍。
class TryOn {
  static const _base = 'https://dashscope.aliyuncs.com/api/v1';


  /// 上传到百炼临时存储，返回 oss:// 地址（有效期 48 小时）
  static Future<String> _upload(File f, String key, String model) async {
    final pr = await http.get(Uri.parse('$_base/uploads?action=getPolicy&model=$model'), headers: {'Authorization': 'Bearer $key'});
    if (pr.statusCode != 200) throw HttpException('获取上传凭证失败 ${pr.statusCode}');
    final d = jsonDecode(pr.body)['data'];
    final name = '${DateTime.now().millisecondsSinceEpoch}_${f.uri.pathSegments.last}';
    final objectKey = '${d['upload_dir']}/$name';
    final req = http.MultipartRequest('POST', Uri.parse(d['upload_host']))
      ..fields.addAll({
        'OSSAccessKeyId': d['oss_access_key_id'], 'Signature': d['signature'], 'policy': d['policy'],
        'x-oss-object-acl': d['x_oss_object_acl'], 'x-oss-forbid-overwrite': d['x_oss_forbid_overwrite'],
        'key': objectKey, 'success_action_status': '200',
      })
      ..files.add(await http.MultipartFile.fromPath('file', f.path));
    final up = await req.send();
    if (up.statusCode != 200) throw HttpException('图片上传失败 ${up.statusCode}');
    return 'oss://$objectKey';
  }

  /// person: 本人正面全身照；top/bottom: 衣物图（连衣裙放 top，bottom 传 null）。返回结果图字节。
  static Future<Uint8List> run({required File person, File? top, File? bottom, void Function(String)? onStep}) async {
    final key = Settings.dashscopeKey;
    if (key.isEmpty) throw StateError('请先在「设置 > AI 试衣」里填写阿里云百炼 API Key');
    final m = Settings.tryOnModel;
    onStep?.call('上传图片');
    final personUrl = await _upload(person, key, m);
    final topUrl = top == null ? null : await _upload(top, key, m);
    final bottomUrl = bottom == null ? null : await _upload(bottom, key, m);
    onStep?.call('提交任务');
    final sub = await http.post(Uri.parse('$_base/services/aigc/image2image/image-synthesis'),
        headers: {
          'Authorization': 'Bearer $key', 'Content-Type': 'application/json',
          'X-DashScope-Async': 'enable', 'X-DashScope-OssResourceResolve': 'enable',
        },
        body: jsonEncode({
          'model': m,
          'input': {'person_image_url': personUrl, if (topUrl != null) 'top_garment_url': topUrl, if (bottomUrl != null) 'bottom_garment_url': bottomUrl},
          'parameters': {'resolution': -1, 'restore_face': true},
        }));
    final sj = jsonDecode(utf8.decode(sub.bodyBytes));
    final taskId = sj['output']?['task_id'];
    if (taskId == null) throw HttpException('提交失败：${sj['message'] ?? sub.statusCode}');
    onStep?.call(m == 'aitryon-plus' ? '生成中（约 90 秒）' : '生成中（约 30 秒）');
    for (var i = 0; i < 80; i++) {
      await Future.delayed(const Duration(seconds: 4));
      final q = await http.get(Uri.parse('$_base/tasks/$taskId'), headers: {'Authorization': 'Bearer $key'});
      final out = jsonDecode(utf8.decode(q.bodyBytes))['output'];
      final st = out['task_status'];
      if (st == 'SUCCEEDED') {
        final img = await http.get(Uri.parse(out['image_url'])); // 链接 24 小时有效，立即下载
        return img.bodyBytes;
      }
      if (st == 'FAILED' || st == 'CANCELED') throw HttpException('生成失败：${out['message'] ?? st}');
    }
    throw const HttpException('生成超时，请稍后在百炼控制台查看');
  }
}
