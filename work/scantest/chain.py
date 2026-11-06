import asyncio, sys
from playwright.async_api import async_playwright
UA='Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36'
async def main(urls):
    async with async_playwright() as p:
        b = await p.chromium.launch(executable_path='/usr/bin/chromium', args=['--no-sandbox'], proxy={'server':'http://127.0.0.1:3128'})
        ctx = await b.new_context(user_agent=UA, viewport={'width':412,'height':915}, device_scale_factor=2.625, is_mobile=True, has_touch=True, locale='zh-CN', extra_http_headers={'Accept-Language':'zh-CN,zh;q=0.9'})
        for i,u in enumerate(urls):
            pg = await ctx.new_page()
            navs=[]
            pg.on('framenavigated', lambda f: navs.append(f.url) if f==f.page.main_frame else None)
            try: await pg.goto(u, timeout=30000, wait_until='domcontentloaded')
            except Exception as e: print('ERR', str(e)[:100])
            await pg.wait_for_timeout(6000)
            print('==', u); print('  navs:', navs); print('  final:', pg.url, (await pg.title())[:40])
            await pg.screenshot(path=f'chain{i}.png'); await pg.close()
        await b.close()
asyncio.run(main(sys.argv[1:]))
