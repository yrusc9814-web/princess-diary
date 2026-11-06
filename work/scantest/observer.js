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
