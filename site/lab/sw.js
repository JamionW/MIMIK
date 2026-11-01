// Lab only: makes /lab/?mt cross-origin isolated by adding COOP and COEP to its navigation
// response, which GitHub Pages cannot send. Isolation enables SharedArrayBuffer, which
// WebAssembly threads need. Every other request passes through untouched.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', e => e.waitUntil(self.clients.claim()));

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.mode !== 'navigate' || !new URL(req.url).searchParams.has('mt')) return;
  e.respondWith((async () => {
    const res = await fetch(req);
    const headers = new Headers(res.headers);
    headers.set('Cross-Origin-Opener-Policy', 'same-origin');
    headers.set('Cross-Origin-Embedder-Policy', 'require-corp');
    return new Response(res.body, { status: res.status, statusText: res.statusText, headers });
  })());
});
