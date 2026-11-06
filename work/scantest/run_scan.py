import asyncio, sys, json
from playwright.async_api import async_playwright
UA='Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36'
OLD=open('scan_old.js').read(); NEW=open('scan_new.js').read(); OBS=open('observer.js').read()
async def main(url, tag, wait=8000):
    async with async_playwright() as p:
        b = await p.chromium.launch(executable_path='/usr/bin/chromium', args=['--no-sandbox'], proxy={'server':'http://127.0.0.1:3128','bypass':'127.0.0.1,localhost'})
        ctx = await b.new_context(user_agent=UA, viewport={'width':412,'height':915}, device_scale_factor=2.625, is_mobile=True, has_touch=True, locale='zh-CN')
        pg = await ctx.new_page()
        try: await pg.goto(url, timeout=40000, wait_until='load')
        except Exception as e: print('goto:', str(e)[:120])
        await pg.evaluate(OBS)
        await pg.wait_for_timeout(wait)
        await pg.screenshot(path=f'shot_{tag}.png')
        await pg.screenshot(path=f'shot_{tag}_full.png', full_page=True)
        o = json.loads(await pg.evaluate(OLD)); n = json.loads(await pg.evaluate(NEW))
        res={'url':url,'final':pg.url,'old':o,'new':n}
        json.dump(res, open(f'result_{tag}.json','w'), ensure_ascii=False, indent=1)
        print('FINAL', pg.url[:120]); print('OLD', len(o)); [print('  ',x[:150]) for x in o]; print('NEW', len(n)); [print('  ',x[:150]+(' ...(%d chars)'%len(x) if len(x)>150 else '')) for x in n]
        await b.close()
asyncio.run(main(sys.argv[1], sys.argv[2], int(sys.argv[3]) if len(sys.argv)>3 else 8000))
