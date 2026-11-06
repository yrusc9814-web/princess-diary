import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../widgets/common.dart';
import 'batch_add_page.dart';
import 'image_edit_page.dart';

const _sites = [
  ('淘宝', 'https://main.m.taobao.com/'),
  ('京东', 'https://m.jd.com/'),
  ('唯品会', 'https://m.vip.com/'),
  ('拼多多', 'https://mobile.yangkeduo.com/'),
];

/// 扫描页面商品图（2.1.3 重写）：不依赖页面结构。
/// 来源：<img>/<source>/srcset/懒加载属性（按屏幕渲染尺寸判断）、所有元素的计算后 background-image、
/// 开放的 shadowRoot、同源 iframe、performance 资源记录（含 CSS 背景/canvas/懒加载）、页面 HTML 与内联脚本里的商品图 URL、
/// 服务端内联的 data:image 大图。过滤淘宝 UI 素材（-tps-WxH、!!6000000…、/tfs/、小尺寸后缀、logo/icon 等）。
/// 按“像商品图”程度排序后返回 JSON 字符串数组。
const _scanJs = r'''
(function(){
  var VW = window.innerWidth || document.documentElement.clientWidth || 400;
  var HOSTS = /(alicdn\.com|tbcdn\.cn|taobaocdn\.com|360buyimg\.com|jd\.com|vpimg\d*\.com|appsimg\.com|vipstatic\.com|vip\.com|pddpic\.com|yangkeduo\.com|pinduoduo\.com)/i;
  var EXT = /\.(jpe?g|png|webp|avif|heic)/i;
  var seen = {};
  function abs(u){
    if(!u || typeof u !== 'string') return '';
    u = u.trim().replace(/^url\(["']?/, '').replace(/["']?\)$/, '');
    if(u.indexOf('//') === 0) u = 'https:' + u;
    if(u.indexOf('http://') === 0 && HOSTS.test(u)) u = 'https://' + u.slice(7);
    if(u.indexOf('http') !== 0) return '';
    return u;
  }
  // 去缩略后缀作为去重键（与 Dart _normalize 一致），阿里不同图片域名视为同一张
  function key(u){
    var s = u.split('#')[0];
    if(/alicdn\.com/i.test(s)) s = s.split('?')[0].replace(/^https:\/\/[a-z0-9-]+\.alicdn\.com\/(img\/)?/i, 'https://img.alicdn.com/');
    s = s.replace(/(\.(jpe?g|png|webp))_[^\/]*$/i, '$1');
    s = s.replace(/\/s\d+x\d+_jfs\//, '/jfs/').replace(/\/n\d+\/(s\d+x\d+_)?jfs\//, '/n1/jfs/');
    s = s.replace(/\.avif$/i, '');
    return s;
  }
  function productish(u){
    if(/\/bao\/uploaded\//i.test(u) || /item_pic/i.test(u) || /\/jfs\//i.test(u)) return true;
    var m = u.match(/O1CN[0-9A-Za-z_]+!!(\d+)/);
    if(m && m[1].indexOf('6000000') !== 0) return true;
    if(/pddpic\.com\/(mms|goods|open)/i.test(u) || /yangkeduo\.com\/(mms|goods)/i.test(u)) return true;
    if(/(vpimg\d*|appsimg)\.com\/upload\/merchandise/i.test(u)) return true;
    return false;
  }
  function junk(u){
    if(/^data:|^blob:/i.test(u)) return true;
    if(/\.(gif|svg|ico)(\?|$|_)/i.test(u)) return true;
    if(/mmstat\.com|\/log\.|beacon|tracker|analytics|\.gif\?/i.test(u)) return true;
    if(/-tps-\d+-\d+\./i.test(u)) return true;                 // 阿里设计平台素材（淘 logo、横幅、按钮）
    if(/!!6000000\d+-/i.test(u)) return true;                   // 同上，设计平台账号
    if(/alicdn\.com\/tfs\//i.test(u)) return true;              // 旧 TFS UI 素材
    var sz = u.match(/-(\d{2,4})-(\d{2,4})\.(png|jpe?g|webp)/i);  // 显式尺寸后缀且偏小
    if(sz && (+sz[1] < 300 || +sz[2] < 300)) return true;
    if(/sprite|icon|logo|avatar|blank|placeholder|loading|qrcode|emoji|badge|default_?head/i.test(u.split('?')[0])) return true;
    if(!EXT.test(u) && !HOSTS.test(u)) return true;
    return false;
  }
  function add(raw, score, size){
    var u = abs(raw);
    if(!u || junk(u)) return;
    var p = productish(u);
    var s = score + (p ? 100 : 0) + Math.min(size || 0, VW) / VW * 60;
    var k = key(u);
    if(!seen[k] || seen[k].s < s) seen[k] = {u: k, s: s, p: p, src: seen[k] ? seen[k].src + 1 : 1};
    else seen[k].src++;
  }
  function bigSrc(set){
    if(!set) return '';
    var best = '', bw = -1;
    set.split(',').forEach(function(part){
      var a = part.trim().split(/\s+/); var w = parseFloat(a[1]) || 1;
      if(w > bw){ bw = w; best = a[0]; }
    });
    return best;
  }
  var LAZY = ['data-src','data-ks-lazyload','data-lazy-img','data-original','data-lazy','data-url','data-img','data-image','data-origin','data-lazyload-src'];
  var dataN = 0;
  // 服务端内联的大图（data:image）或 blob: 图片：屏幕上 >=200px 才收，转成 data URL 交给 App 解码
  function addInline(el, w, m){
    if(m < 200 || dataN >= 4) return;
    var u = el.currentSrc || el.src || '';
    if(/^data:image\/(jpe?g|jpg|png|webp)/i.test(u) && u.length > 15000 && u.length < 6000000){
      var k = 'data:' + u.length + ':' + u.slice(30, 120);
      if(!seen[k]){ seen[k] = {u: u, s: 140 + Math.min(w, VW) / VW * 60, p: true, src: 1}; dataN++; }
    } else if(/^blob:/i.test(u) && el.naturalWidth >= 200){
      try {
        var c = document.createElement('canvas'); c.width = el.naturalWidth; c.height = el.naturalHeight;
        c.getContext('2d').drawImage(el, 0, 0);
        var d = c.toDataURL('image/jpeg', 0.92);
        if(d.length > 15000){ seen['blob:' + u] = {u: d, s: 130 + Math.min(w, VW) / VW * 60, p: true, src: 1}; dataN++; }
      } catch(e){}
    }
  }
  var count = 0;
  function walk(root, win){
    var els; try { els = root.querySelectorAll('*'); } catch(e){ return; }
    for(var i=0;i<els.length && count < 12000;i++, count++){
      var el = els[i], tag = el.tagName;
      var r = el.getBoundingClientRect(), w = r.width, h = r.height, m = Math.min(w, h);
      if(tag === 'IMG' || tag === 'SOURCE'){
        var srcs = [el.currentSrc, el.src, bigSrc(el.getAttribute('srcset')), bigSrc(el.getAttribute('data-srcset'))];
        for(var a=0;a<LAZY.length;a++) srcs.push(el.getAttribute(LAZY[a]));
        if(tag === 'IMG') addInline(el, w, m);
        if(tag === 'SOURCE' && el.parentElement){ var pr = el.parentElement.getBoundingClientRect(); w = pr.width; h = pr.height; m = Math.min(w,h); }
        for(var b=0;b<srcs.length;b++){
          var u = abs(srcs[b]); if(!u) continue;
          if(m >= 100) add(u, 60, w);                       // 屏幕上真实渲染 >=100px
          else if(m === 0 && productish(u)) add(u, 20, 0);   // 隐藏/懒加载的轮播图
          else if(productish(u)) add(u, 10, 0);              // 小缩略图：只收商品路径，去重后与大图合并
        }
      } else if(tag === 'VIDEO'){
        if(m >= 100) add(el.getAttribute('poster'), 30, w);
      } else if(tag === 'IFRAME'){
        try { var d = el.contentDocument; if(d){ walk(d, el.contentWindow); perf(el.contentWindow, 10); } } catch(e){}
      }
      if(m >= 120 && tag !== 'IMG'){
        var bg = '';
        try { bg = (win || window).getComputedStyle(el).backgroundImage || ''; } catch(e){}
        if(bg && bg !== 'none'){
          var re = /url\(["']?([^"')]+)["']?\)/g, mm;
          while((mm = re.exec(bg))) add(mm[1], 50, w);
        }
      }
      if(el.shadowRoot) walk(el.shadowRoot, win);
    }
  }
  function perf(win, base){
    var list = [];
    try { list = win.performance.getEntriesByType('resource'); } catch(e){}
    try { if(win.__wdImgs) list = list.concat(win.__wdImgs.map(function(n){ return {name: n, initiatorType: 'img'}; })); } catch(e){}
    for(var i=0;i<list.length;i++){
      var e = list[i], n = e.name || '', t = e.initiatorType || '';
      var imgish = (t === 'img' || t === 'css' || t === 'other' || t === 'image') ? EXT.test(n) || HOSTS.test(n) : (HOSTS.test(n) && EXT.test(n));
      if(imgish) add(n, base, 0);
    }
  }
  function scanText(){
    var html = '';
    try { html = document.documentElement.outerHTML; } catch(e){}
    html = html.replace(/\\u002F/gi, '/').replace(/\\\//g, '/').replace(/&amp;/g, '&');
    var re = /(?:https?:)?\/\/[a-z0-9.-]+\.(?:alicdn|tbcdn|360buyimg|pddpic|yangkeduo|vpimg\d*|appsimg)\.(?:com|cn)\/[^\s"'<>()\\,]+?\.(?:jpe?g|png|webp|avif)/gi, m, n = 0;
    while((m = re.exec(html)) && n < 2000){ n++; if(productish(m[0])) add(m[0], 5, 0); }
  }
  walk(document, window);
  perf(window, 15);
  scanText();
  var arr = Object.keys(seen).map(function(k){ return seen[k]; });
  arr.sort(function(x, y){ return (y.s + Math.min(y.src, 3) * 3) - (x.s + Math.min(x.src, 3) * 3); });
  return JSON.stringify(arr.slice(0, 150).map(function(o){ return o.u; }));
})();
''';

/// 页面加载完成后注入：放大资源记录缓冲并用 PerformanceObserver 记录后续加载的图片
const _observerJs = r'''
(function(){
  try { performance.setResourceTimingBufferSize(5000); } catch(e){}
  if(window.__wdObs) return;
  window.__wdImgs = [];
  try {
    var o = new PerformanceObserver(function(l){
      l.getEntries().forEach(function(e){
        if(window.__wdImgs.length < 3000 && /^(img|css|other|image)$/.test(e.initiatorType)) window.__wdImgs.push(e.name);
      });
    });
    o.observe({type: 'resource', buffered: true});
    window.__wdObs = o;
  } catch(e){}
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
        onPageFinished: (_) => ctl.runJavaScript(_observerJs).catchError((_) {}),
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
    if (u.startsWith('data:')) return u;
    var s = u;
    if (s.contains('alicdn.com')) s = s.split('?').first;
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
        _noImages();
        return;
      }
      final referer = (await ctl.currentUrl()) ?? '';
      if (mounted) push(context, WebScanSelectPage(urls: list, referer: referer));
    } catch (e) {
      if (mounted) setState(() => scanning = false);
      toast(null, '扫描失败：$e', style: 'dark');
    }
  }

  /// 兜底：webview_flutter 在 Android 上没有截图 API（平台视图也无法被 RepaintBoundary 可靠截取），
  /// 所以引导用户用系统截图，再从相册选图进入「编辑图片」裁剪。
  void _noImages() => showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('没有找到商品图片'),
          content: const Text('这个页面的图片暂时无法直接读取。你可以：\n1. 用手机系统截图把商品图截下来\n2. 点下方「从相册选择」，选刚才的截图\n3. 在编辑图片里裁剪出商品',
              style: TextStyle(height: 1.7)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('知道了')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kRose, shape: const StadiumBorder()),
              onPressed: () async {
                Navigator.pop(c);
                final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2400, maxHeight: 2400);
                if (x != null && mounted) push(context, ImageEditPage(path: x.path, newClothes: true));
              },
              child: const Text('从相册选择'),
            ),
          ],
        ),
      );

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
              decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: const Color(0xFFF5D5DE)))),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.arrow_back), onPressed: () async => (await ctl.canGoBack()) ? ctl.goBack() : null),
                IconButton(icon: const Icon(Icons.arrow_forward), onPressed: () async => (await ctl.canGoForward()) ? ctl.goForward() : null),
                IconButton(icon: const Icon(Icons.refresh), onPressed: () => ctl.reload()),
                const Spacer(),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: kRose, shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
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
  final _streams = <ImageStream, ImageStreamListener>{};

  @override
  void initState() {
    super.initState();
    // 读取每张图的真实尺寸，隐藏过小的图（店铺头像、小图标等）
    for (final u in widget.urls) {
      final stream = _provider(u).resolve(ImageConfiguration.empty);
      late final ImageStreamListener l;
      l = ImageStreamListener((info, _) {
        final w = info.image.width, h = info.image.height;
        if (w < 160 && h < 160 && mounted) {
          setState(() {
            failed.add(u);
            sel.remove(u);
          });
        }
        stream.removeListener(l);
      }, onError: (_, __) => stream.removeListener(l));
      stream.addListener(l);
      _streams[stream] = l;
    }
  }

  @override
  void dispose() {
    _streams.forEach((s, l) => s.removeListener(l));
    super.dispose();
  }

  final _prov = <String, ImageProvider>{};

  /// 缩略显示用（最宽 300px，小图不放大，因此也能据此判断原图是否过小）；data: 内联图直接解码
  ImageProvider _provider(String u) => _prov.putIfAbsent(u, () {
        final ImageProvider base = u.startsWith('data:') ? MemoryImage(base64Decode(u.substring(u.indexOf(',') + 1))) : NetworkImage(u, headers: headers);
        return ResizeImage(base, width: 300, policy: ResizeImagePolicy.fit);
      });
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
        List<int>? bytes;
        if (u.startsWith('data:')) {
          bytes = base64Decode(u.substring(u.indexOf(',') + 1));
        } else {
          final r = await http.get(Uri.parse(u), headers: headers).timeout(const Duration(seconds: 20));
          if (r.statusCode == 200) bytes = r.bodyBytes;
        }
        if (bytes != null && bytes.length > 2000) {
          final f = File('${Directory.systemTemp.path}/web_${DateTime.now().microsecondsSinceEpoch}.img');
          await f.writeAsBytes(bytes);
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
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: s ? kRose : const Color(0xFFF5D5DE), width: s ? 2 : 1)),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(children: [
                    Positioned.fill(
                      child: Image(image: _provider(u), fit: BoxFit.cover, errorBuilder: (_, __, ___) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && !failed.contains(u)) setState(() {
                                failed.add(u);
                                sel.remove(u);
                              });
                        });
                        return const SizedBox();
                      }),
                    ),
                    Positioned(right: 4, top: 4, child: Icon(s ? Icons.check_circle : Icons.radio_button_unchecked, color: s ? kRose : Colors.white, shadows: const [Shadow(blurRadius: 4)])),
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
              style: FilledButton.styleFrom(backgroundColor: kRose, shape: const StadiumBorder()),
              onPressed: sel.isEmpty || downloading ? null : _import,
              child: Text(downloading ? '正在下载 $done/${sel.length.clamp(0, 30)}' : '导入所选(${sel.length})${sel.length > 30 ? '，单次最多30张' : ''}', style: const TextStyle(fontSize: 16)),
            ),
          ),
        ),
      ),
    );
  }
}
