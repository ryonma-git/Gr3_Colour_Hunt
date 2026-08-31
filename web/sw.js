// オフラインでも動くようにする最小限のサービスワーカー。
// 一度ひらけば、次からはネットが無くても起動する。
//
// 方針: ネットがあるときは必ず最新を取りに行く（network first）。
// これにより colors.js の判定値を直したら、再読み込みだけで反映される。
// ネットが無いときだけキャッシュから返す。

const CACHE_NAME = 'colorhunt-v1';
const ASSETS = [
  './',
  './index.html',
  './styles.css',
  './icon.svg',
  './manifest.webmanifest',
  './js/app.js',
  './js/colors.js',
  './js/hsv.js',
  './js/detector.js',
  './js/camera.js',
  './js/speech.js',
  './js/storage.js',
  './js/share.js'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(ASSETS)).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

// ネットがあるときは必ず新しいものを取りに行き、無いときだけキャッシュを使う。
// （キャッシュ優先にすると、colors.js の判定値を直しても反映されず、
//   教室で「直したのに変わらない」という事故になるため）
self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  if (new URL(req.url).origin !== self.location.origin) return;

  event.respondWith(
    fetch(req)
      .then((res) => {
        const copy = res.clone();
        caches.open(CACHE_NAME).then((cache) => cache.put(req, copy)).catch(() => {});
        return res;
      })
      .catch(() => caches.match(req).then((hit) => hit || caches.match('./index.html')))
  );
});
