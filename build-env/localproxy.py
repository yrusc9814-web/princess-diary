import asyncio, base64, os, urllib.parse as p
up = p.urlparse(os.environ.get('https_proxy') or os.environ['HTTPS_PROXY'])
AUTH = b'Proxy-Authorization: Basic ' + base64.b64encode(f"{p.unquote(up.username)}:{p.unquote(up.password or '')}".encode()) + b'\r\n'

async def pipe(r, w):
    try:
        while True:
            d = await r.read(65536)
            if not d: break
            w.write(d); await w.drain()
    except Exception: pass
    finally:
        try: w.close()
        except Exception: pass

async def handle(cr, cw):
    try:
        head = await cr.readuntil(b'\r\n\r\n')
    except Exception:
        cw.close(); return
    lines = head.split(b'\r\n')
    lines = [l for l in lines if not l.lower().startswith(b'proxy-authorization') and not l.lower().startswith(b'proxy-connection')]
    newhead = lines[0] + b'\r\n' + AUTH + b'\r\n'.join(lines[1:])
    try:
        ur, uw = await asyncio.open_connection(up.hostname, up.port)
    except Exception:
        cw.close(); return
    uw.write(newhead); await uw.drain()
    await asyncio.gather(pipe(cr, uw), pipe(ur, cw))

async def main():
    s = await asyncio.start_server(handle, '127.0.0.1', 3128)
    async with s: await s.serve_forever()
asyncio.run(main())
