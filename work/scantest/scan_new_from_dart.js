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
