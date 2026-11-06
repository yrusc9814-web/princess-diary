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
