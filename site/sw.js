// VERSION is replaced with the commit SHA at deploy time; a new value refreshes the cache.
const VERSION = 'dev';
const CACHE = `mimik-${VERSION}`;
const SHELL = ['./', 'index.html', 'phrases.json', 'manifest.webmanifest', 'icon-180.png', 'icon-512.png'];

self.addEventListener('install', e => {
  e.waitUntil((async () => {
    const c = await caches.open(CACHE);
    await c.addAll(SHELL);
    const data = await (await c.match('phrases.json')).json();
    const ids = data.sections.flatMap(s => s.phrases.flatMap(p => [p, ...(p.alt || [])])).map(p => p.id);
    // Missing clips are tolerated; the page falls back to the device voice.
    await Promise.all(ids.map(id => c.add(`audio/${id}.mp3`).catch(() => {})));
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', e => {
  e.waitUntil((async () => {
    for (const k of await caches.keys()) if (k !== CACHE) await caches.delete(k);
    await self.clients.claim();
  })());
});

// Safari requests media with Range headers and will not play a plain 200 from a worker.
async function ranged(req, res) {
  const m = /bytes=(\d*)-(\d*)/.exec(req.headers.get('range') || '');
  if (!m) return res;
  const buf = await res.arrayBuffer();
  const start = m[1] ? +m[1] : 0;
  const end = m[2] ? Math.min(+m[2], buf.byteLength - 1) : buf.byteLength - 1;
  return new Response(buf.slice(start, end + 1), {
    status: 206,
    headers: {
      'Content-Type': res.headers.get('Content-Type') || 'audio/mpeg',
      'Content-Range': `bytes ${start}-${end}/${buf.byteLength}`,
      'Content-Length': String(end - start + 1),
      'Accept-Ranges': 'bytes',
    },
  });
}

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET' || new URL(req.url).origin !== location.origin) return;
  e.respondWith((async () => {
    const hit = await caches.match(req, { ignoreSearch: true });
    if (hit) return req.headers.has('range') ? ranged(req, hit) : hit;
    try {
      return await fetch(req);
    } catch {
      return req.mode === 'navigate' ? caches.match('index.html') : Response.error();
    }
  })());
});
