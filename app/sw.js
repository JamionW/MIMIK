// scripts/build.py copies this into each language folder and fills in LANG and VERSION.
// VERSION is the commit SHA at deploy time; a new value refreshes the cache.
const LANG = 'xx';
const VERSION = 'dev';
// Caches are shared by every worker on the origin, so each language owns a name prefix
// and only ever clears its own.
const PREFIX = `mimik-${LANG}-`;
const CACHE = PREFIX + VERSION;
const SHELL = ['./', 'index.html', 'phrases.json', 'manifest.webmanifest', 'icon-180.png', 'icon-512.png', 'icon.svg'];

// Clips the server answered 404 for at the last fill. They are left out of the offline
// count, since a clip that failed to generate can never be cached.
const ABSENT = 'offline-absent.json';
// Refills triggered by the page are spaced out so a flaky connection is not hammered.
const REFILL_GAP = 30000;
let filling = null, lastFill = 0;

const abs = p => new URL(p, location).pathname;

async function cachedPaths(c) {
  return new Set((await c.keys()).map(r => new URL(r.url).pathname));
}

async function clipPaths(c) {
  const res = (await c.match('phrases.json')) || (await fetch('phrases.json').catch(() => null));
  if (!res || !res.ok) return [];
  const data = await res.json();
  const ids = data.sections.flatMap(s => s.phrases.flatMap(p => [p, ...(p.alt || [])])).map(p => p.id);
  return ids.flatMap(id => [`audio/${id}.mp3`, `audio/f/${id}.mp3`]);
}

// Fetches whatever this version's cache is missing. A missing shell file throws; missing
// clips are tolerated, and the page falls back to the device voice for them.
async function fill() {
  const c = await caches.open(CACHE);
  const have = await cachedPaths(c);
  const shell = SHELL.filter(p => !have.has(abs(p)));
  if (shell.length) await c.addAll(shell);
  const absent = [];
  const want = (await clipPaths(c)).filter(p => !have.has(abs(p)));
  await Promise.all(want.map(async p => {
    try {
      const r = await fetch(p);
      if (r.ok) await c.put(p, r);
      else if (r.status === 404) absent.push(p);
    } catch {}
  }));
  // Every clip not already cached was retried above, so this list replaces the old one.
  await c.put(ABSENT, new Response(JSON.stringify(absent), { headers: { 'Content-Type': 'application/json' } }));
}

function startFill() {
  lastFill = Date.now();
  filling ||= fill().finally(() => { filling = null; });
  return filling;
}

async function status() {
  const c = await caches.open(CACHE);
  const have = await cachedPaths(c);
  const a = await c.match(ABSENT);
  const absent = new Set(a ? await a.json() : []);
  const clips = (await clipPaths(c)).filter(p => !absent.has(p));
  return {
    cached: clips.filter(p => have.has(abs(p))).length,
    total: clips.length,
    shell: SHELL.every(p => have.has(abs(p))),
    filling: !!filling,
  };
}

self.addEventListener('install', e => {
  e.waitUntil((async () => {
    await startFill();
    await self.skipWaiting();
  })());
});

// The page asks { type: 'offline-status', refill } over a MessageChannel. With refill set,
// an incomplete cache (iOS evicts storage of unused web apps) is topped up from the network.
self.addEventListener('message', e => {
  if (!e.data || e.data.type !== 'offline-status' || !e.ports[0]) return;
  e.waitUntil((async () => {
    const st = await status();
    let job = filling && filling.catch(() => {});
    if (!job && e.data.refill && (st.cached < st.total || !st.shell) && Date.now() - lastFill > REFILL_GAP) {
      job = startFill().catch(() => {});
      st.filling = true;
    }
    e.ports[0].postMessage(st);
    await job;
  })());
});

self.addEventListener('activate', e => {
  e.waitUntil((async () => {
    for (const k of await caches.keys()) if (k.startsWith(PREFIX) && k !== CACHE) await caches.delete(k);
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
    const c = await caches.open(CACHE);
    const hit = await c.match(req, { ignoreSearch: true });
    if (hit) return req.headers.has('range') ? ranged(req, hit) : hit;
    try {
      return await fetch(req);
    } catch {
      return req.mode === 'navigate' ? c.match('index.html') : Response.error();
    }
  })());
});
