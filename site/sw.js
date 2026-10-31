// Root worker: keeps the language picker available offline. Each language folder registers
// its own worker with a narrower scope, which takes over for pages in that folder.
// VERSION is replaced with the commit SHA at deploy time; a new value refreshes the cache.
const VERSION = 'dev';
const PREFIX = 'mimik-root-';
const CACHE = PREFIX + VERSION;
const SHELL = ['./', 'index.html', 'languages.json', 'manifest.webmanifest', 'icon-180.png', 'icon-512.png', 'icon.svg'];
const OWN = new Set(SHELL.map(p => new URL(p, location).href));

self.addEventListener('install', e => {
  e.waitUntil((async () => {
    const c = await caches.open(CACHE);
    await c.addAll(SHELL);
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', e => {
  e.waitUntil((async () => {
    // The pre-language-folder cache (mimik-<sha>) is left for the picker, which uses it
    // to send an existing Portuguese install straight to pt/ and then deletes it.
    for (const k of await caches.keys()) if (k.startsWith(PREFIX) && k !== CACHE) await caches.delete(k);
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', e => {
  const req = e.request;
  const url = new URL(req.url);
  url.search = '';
  // Anything outside the picker's own files goes to the network untouched.
  if (req.method !== 'GET' || !OWN.has(url.href)) return;
  e.respondWith((async () => {
    const c = await caches.open(CACHE);
    const hit = await c.match(req, { ignoreSearch: true });
    if (hit) return hit;
    try {
      return await fetch(req);
    } catch {
      return req.mode === 'navigate' ? c.match('index.html') : Response.error();
    }
  })());
});
