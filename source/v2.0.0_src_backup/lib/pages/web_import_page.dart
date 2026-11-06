import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

import '../widgets/common.dart';
import 'batch_add_page.dart';

const _sites = [
  ('淘宝', 'https://main.m.taobao.com/'),
  ('京东', 'https://m.jd.com/'),
  ('唯品会', 'https://m.vip.com/'),
  ('拼多多', 'https://mobile.yangkeduo.com/'),
];

const _scanJs = r'''
(function(){
  var out = {};
  function add(u, w, h){
    if(!u || typeof u !== 'string') return;
    u = u.trim();
    if(u.indexOf('data:') === 0) return;
    if(u.indexOf('//') === 0) u = 'https:' + u;
    if(u.indexOf('http') !== 0) return;
    if(w && h && (w < 120 || h < 120)) return;
    if(/\.gif(\?|$)/i.test(u) || /sprite|icon|logo|avatar|blank/i.test(u)) return;
    out[u] = 1;
  }
  var imgs = document.querySelectorAll('img');
  for (var i=0;i<imgs.length;i++){
    var im = imgs[i];
    var w = im.naturalWidth || im.width, h = im.naturalHeight || im.height;
    add(im.currentSrc || im.src, w, h);
    add(im.getAttribute('data-src'), 0, 0);
    add(im.getAttribute('data-ks-lazyload'), 0, 0);
    add(im.getAttribute('data-lazy-img'), 0, 0);
    add(im.getAttribute('data-original'), 0, 0);
  }
  var els = document.querySelectorAll('[style*="background"]');
  for (var j=0;j<els.length;j++){
    var m = (els[j].getAttribute('style')||'').match(/url\(["']?([^"')]+)["']?\)/);
    if(m && els[j].offsetWidth >= 120 && els[j].offsetHeight >= 120) add(m[1], 0, 0);
  }
  return JSON.stringify(Object.keys(out).slice(0, 300));
})();
''';

/// 网页导入（淘宝/京东/唯品会/拼多多）：内嵌浏览器，用户自行登录，扫描页面商品图
class WebImportPage extends StatefulWidget {
  const WebImportPage({super.key});
  @override
  State<WebImportPage> createState() => _WebImportPageState();
}

class _WebImportPageState extends State<WebImportPage> {
  late final WebViewController ctl;
  String host = 'main.m.taobao.com';
  int progress = 0;
  bool scanning = false;

  @override
  void initState() {
    super.initState();
    ctl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36')
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => mounted ? setState(() => progress = p) : null,
        onUrlChange: (c) {
          final u = Uri.tryParse(c.url ?? '');
          if (u != null && u.host.isNotEmpty && mounted) setState(() => host = u.host);
        },
        onNavigationRequest: (r) {
          final u = r.url;
          if (u.startsWith('http://') || u.startsWith('https://') || u.startsWith('about:')) return NavigationDecision.navigate;
          return NavigationDecision.prevent; // 阻止唤起淘宝/京东 App 的跳转
        },
      ))
      ..loadRequest(Uri.parse(_sites.first.$2));
  }

  String _normalize(String u) {
    var s = u;
    // 阿里 CDN：去掉 _300x300.jpg / _.webp 等缩略后缀，取原图
    s = s.replaceAll(RegExp(r'(\.(jpg|jpeg|png|webp))_[^/]*$', caseSensitive: false), r'$1');
    s = s.replaceAllMapped(RegExp(r'(\.(jpg|jpeg|png))_\d+x\d+[^/]*$', caseSensitive: false), (m) => m.group(1)!);
    // 京东：/n7/ /s200x200_ 等缩略图路径
    s = s.replaceAll(RegExp(r'/s\d+x\d+_jfs/'), '/jfs/').replaceAll(RegExp(r'/n\d+/(s\d+x\d+_)?jfs/'), '/n1/jfs/');
    s = s.replaceAll(RegExp(r'\.avif$'), '');
    return s;
  }

  Future<void> _scan() async {
    setState(() => scanning = true);
    try {
      var r = await ctl.runJavaScriptReturningResult(_scanJs);
      dynamic v = r;
      for (var i = 0; i < 2 && v is String; i++) {
        try {
          v = jsonDecode(v);
        } catch (_) {
          break;
        }
      }
      final list = (v is List ? v.map((e) => _normalize('$e')).toSet().toList() : <String>[]);
      if (!mounted) return;
      setState(() => scanning = false);
      if (list.isEmpty) {
        toast(null, '当前页面没有找到商品图片，进入商品详情或订单列表后再试', style: 'dark');
        return;
      }
      final referer = (await ctl.currentUrl()) ?? '';
      if (mounted) push(context, WebScanSelectPage(urls: list, referer: referer));
    } catch (e) {
      if (mounted) setState(() => scanning = false);
      toast(null, '扫描失败：$e', style: 'dark');
    }
  }

  void _help() => showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('如何导入'),
          content: const Text('1. 在页面中登录你的购物账号（账号只保存在本机网页里）\n2. 打开「我的订单」或商品详情页\n3. 点击下方「扫描图片」\n4. 勾选要导入的商品图，点「导入所选」',
              style: TextStyle(height: 1.7)),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('知道了'))],
        ),
      );

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (did, _) async {
          if (did) return;
          if (await ctl.canGoBack()) {
            ctl.goBack();
          } else if (context.mounted) {
            Navigator.pop(context);
          }
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            title: Text(host, style: const TextStyle(fontSize: 15)),
            centerTitle: true,
            actions: [
              IconButton(icon: const Icon(Icons.help_outline), onPressed: _help),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'clear') {
                    await ctl.clearCache();
                    await ctl.clearLocalStorage();
                    await WebViewCookieManager().clearCookies();
                    toast(null, '已清除网页数据并退出购物账号');
                    ctl.reload();
                  } else {
                    ctl.loadRequest(Uri.parse(v));
                  }
                },
                itemBuilder: (_) => [
                  for (final s in _sites) PopupMenuItem(value: s.$2, child: Text('打开${s.$1}')),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'clear', child: Text('清除网页数据/退出购物账号')),
                ],
              ),
            ],
            bottom: progress < 100 ? PreferredSize(preferredSize: const Size.fromHeight(2), child: LinearProgressIndicator(value: progress / 100, minHeight: 2)) : null,
          ),
          body: WebViewWidget(controller: ctl),
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
              decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFEDEDF0)))),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.arrow_back), onPressed: () async => (await ctl.canGoBack()) ? ctl.goBack() : null),
                IconButton(icon: const Icon(Icons.arrow_forward), onPressed: () async => (await ctl.canGoForward()) ? ctl.goForward() : null),
                IconButton(icon: const Icon(Icons.refresh), onPressed: () => ctl.reload()),
                const Spacer(),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: kPurple, shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                  onPressed: scanning ? null : _scan,
                  icon: scanning ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.document_scanner_outlined, size: 18),
                  label: const Text('扫描图片'),
                ),
              ]),
            ),
          ),
        ),
      );
}

/// 扫描结果选图页（自行设计：网格多选 + 导入所选）
class WebScanSelectPage extends StatefulWidget {
  final List<String> urls;
  final String referer;
  const WebScanSelectPage({super.key, required this.urls, required this.referer});
  @override
  State<WebScanSelectPage> createState() => _WebScanSelectPageState();
}

class _WebScanSelectPageState extends State<WebScanSelectPage> {
  final sel = <String>{};
  final failed = <String>{};
  String status = '拥有';
  bool downloading = false;
  int done = 0;

  Map<String, String> get headers => {
        'Referer': widget.referer,
        'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36',
      };

  Future<void> _import() async {
    setState(() {
      downloading = true;
      done = 0;
    });
    final paths = <String>[];
    for (final u in sel.take(30)) {
      try {
        final r = await http.get(Uri.parse(u), headers: headers).timeout(const Duration(seconds: 20));
        if (r.statusCode == 200 && r.bodyBytes.length > 2000) {
          final f = File('${Directory.systemTemp.path}/web_${DateTime.now().microsecondsSinceEpoch}.img');
          await f.writeAsBytes(r.bodyBytes);
          paths.add(f.path);
        }
      } catch (_) {}
      if (mounted) setState(() => done++);
    }
    if (!mounted) return;
    setState(() => downloading = false);
    if (paths.isEmpty) {
      toast(null, '图片下载失败，请重试', style: 'dark');
      return;
    }
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => BatchAddPage(paths: paths, status: status, source: 'web')));
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls.where((u) => !failed.contains(u)).toList();
    return Scaffold(
      appBar: appBar('选择要导入的图片', actions: [
        TextButton(
          onPressed: () => setState(() => sel.length == urls.length ? sel.clear() : sel.addAll(urls)),
          child: Text(sel.length == urls.length && urls.isNotEmpty ? '取消全选' : '全选'),
        ),
      ]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(children: [
            Text('共 ${urls.length} 张，已选 ${sel.length} 张', style: const TextStyle(color: kGrayText, fontSize: 13)),
            const Spacer(),
            const Text('导入为 ', style: TextStyle(fontSize: 13)),
            DropdownButton<String>(
              value: status,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: '拥有', child: Text('拥有')),
                DropdownMenuItem(value: '种草', child: Text('种草')),
                DropdownMenuItem(value: '素材', child: Text('素材')),
              ],
              onChanged: (v) => setState(() => status = v!),
            ),
          ]),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8),
            itemCount: urls.length,
            itemBuilder: (_, i) {
              final u = urls[i];
              final s = sel.contains(u);
              return GestureDetector(
                onTap: () => setState(() => s ? sel.remove(u) : sel.add(u)),
                child: Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: s ? kPurple : const Color(0xFFE9E9EE), width: s ? 2 : 1)),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(children: [
                    Positioned.fill(
                      child: Image.network(u, headers: headers, fit: BoxFit.cover, cacheWidth: 300, errorBuilder: (_, __, ___) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && !failed.contains(u)) setState(() {
                                failed.add(u);
                                sel.remove(u);
                              });
                        });
                        return const SizedBox();
                      }),
                    ),
                    Positioned(right: 4, top: 4, child: Icon(s ? Icons.check_circle : Icons.radio_button_unchecked, color: s ? kPurple : Colors.white, shadows: const [Shadow(blurRadius: 4)])),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: SizedBox(
            height: 50,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kPurple, shape: const StadiumBorder()),
              onPressed: sel.isEmpty || downloading ? null : _import,
              child: Text(downloading ? '正在下载 $done/${sel.length.clamp(0, 30)}' : '导入所选(${sel.length})${sel.length > 30 ? '，单次最多30张' : ''}', style: const TextStyle(fontSize: 16)),
            ),
          ),
        ),
      ),
    );
  }
}
