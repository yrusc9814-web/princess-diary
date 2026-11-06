import asyncio, sys
from playwright.async_api import async_playwright
UA='Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36'
async def main(u):
    async with async_playwright() as p:
        b = await p.chromium.launch(executable_path='/usr/bin/chromium', args=['--no-sandbox'], proxy={'server':'http://127.0.0.1:3128'})
        ctx = await b.new_context(user_agent=UA, viewport={'width':412,'height':915}, device_scale_factor=2.625, is_mobile=True, has_touch=True, locale='zh-CN')
        pg = await ctx.new_page()
        async def onresp(r):
            t=r.request.resource_type
            if t in('document','xhr','fetch','script') and ('mtop' in r.url or t=='document'):
                try: body=(await r.text())[:300]
                except: body='?'
                print('RESP',r.status,t,r.url[:160],'\n   ',body.replace('\n',' ')[:300])
            elif t=='image': print('IMG', r.url[:160])
        pg.on('response', onresp)
        pg.on('framenavigated', lambda f: print('NAV', f.url[:150]))
        try: await pg.goto(u, timeout=30000, wait_until='domcontentloaded')
        except Exception as e: print('ERR', str(e)[:100])
        await pg.wait_for_timeout(9000)
        print('frames', [f.url[:100] for f in pg.frames])
        await b.close()
asyncio.run(main(sys.argv[1]))
