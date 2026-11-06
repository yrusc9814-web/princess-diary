import asyncio, sys, json
from playwright.async_api import async_playwright
UA='Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36'
async def main(url, tag):
    async with async_playwright() as p:
        b = await p.chromium.launch(executable_path='/usr/bin/chromium', args=['--no-sandbox'], proxy={'server':'http://127.0.0.1:3128'})
        ctx = await b.new_context(user_agent=UA, viewport={'width':412,'height':915}, device_scale_factor=2.625, is_mobile=True, has_touch=True, locale='zh-CN')
        pg = await ctx.new_page()
        try:
            await pg.goto(url, timeout=45000, wait_until='domcontentloaded')
        except Exception as e: print('goto err', e)
        await pg.wait_for_timeout(8000)
        print('final', pg.url, await pg.title())
        await pg.screenshot(path=f'{tag}.png')
        html = await pg.content(); open(f'{tag}.html','w').write(html)
        await b.close()
asyncio.run(main(sys.argv[1], sys.argv[2]))
