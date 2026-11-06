import 'package:url_launcher/url_launcher.dart';

import '../data/models.dart';

/// 去淘宝搜同款：关键词 = 品类 + 颜色；优先打开淘宝 App，未安装时打开网页
class Taobao {
  static String keywordOf(Clothes c) {
    final cat = (c.cat2 != null && c.cat2!.isNotEmpty && c.cat2 != '其他') ? c.cat2! : (c.cat1 ?? '');
    final color = c.colors.isEmpty ? '' : c.colors.first.replaceAll('多色', '');
    final kw = '$color${cat.replaceAll('/', ' ')}'.trim();
    return kw.isEmpty ? (c.name.isEmpty ? '衣服' : c.name) : kw;
  }

  static Future<bool> search(String keyword) async {
    final q = Uri.encodeComponent(keyword);
    final app = Uri.parse('taobao://s.taobao.com/search?q=$q');
    try {
      if (await launchUrl(app, mode: LaunchMode.externalNonBrowserApplication)) return true;
    } catch (_) {}
    final web = Uri.parse('https://s.taobao.com/search?q=$q');
    return launchUrl(web, mode: LaunchMode.externalApplication);
  }
}
