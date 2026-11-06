import asyncio, json
from playwright.async_api import async_playwright
UA='Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36'
JS='''(()=>{const o=[];document.querySelectorAll('img').forEach(i=>{const r=i.getBoundingClientRect();o.push(['IMG',Math.round(r.width)+'x'+Math.round(r.height),i.naturalWidth+'x'+i.naturalHeight,(i.currentSrc||i.src).slice(0,140)])});
document.querySelectorAll('*').forEach(e=>{const b=getComputedStyle(e).backgroundImage;if(b&&b!='none'){const r=e.getBoundingClientRect();o.push(['BG',e.tagName,Math.round(r.width)+'x'+Math.round(r.height),b.slice(0,140)])}});
o.push(['PERF',performance.getEntriesByType('resource').filter(e=>/alicdn/.test(e.name)&&/\\.(png|jpe?g|webp)/.test(e.name)).map(e=>e.initiatorType+' '+e.name.slice(0,120))]);return JSON.stringify(o)})()'''
async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch(executable_path='/usr/bin/chromium', args=['--no-sandbox'], proxy={'server':'http://127.0.0.1:3128'})
        ctx = await b.new_context(user_agent=UA, viewport={'width':412,'height':915}, device_scale_factor=2.625, is_mobile=True, has_touch=True, locale='zh-CN')
        pg = await ctx.new_page()
        await pg.goto("https://www.taobao.com/list/item/NXI1VCtmVlVuMHA3dG5BTkNMa1NRZz09.htm", wait_until='load', timeout=40000)
        await pg.wait_for_timeout(6000)
        for x in json.loads(await pg.evaluate(JS)): print(x)
        await b.close()
asyncio.run(main())
