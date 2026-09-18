// City Pulse Service Worker — Offline Caching & Push Notification Handler
const CACHE_NAME = 'city-pulse-v1';
const STATIC_ASSETS = [
  '/',
  '/app.html',
  '/map.html',
  '/info.html',
  '/daily_report.html',
  '/cameras.html',
  '/city_dashboard.html',
  '/manifest.json'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(STATIC_ASSETS).catch((err) => {
        console.warn('SW pre-cache warning:', err);
      });
    })
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key))
      );
    })
  );
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;

  const url = new URL(event.request.url);

  // Network-first strategy for API calls
  if (url.pathname.startsWith('/api/')) {
    event.respondWith(
      fetch(event.request)
        .then((response) => {
          return response;
        })
        .catch(() => {
          return caches.match(event.request);
        })
    );
    return;
  }

  // Cache-first strategy for map tiles and static CDN assets
  if (url.hostname.includes('basemaps.cartocdn.com') || url.hostname.includes('openstreetmap.org') || url.hostname.includes('unpkg.com') || url.hostname.includes('cdnjs.cloudflare.com')) {
    event.respondWith(
      caches.match(event.request).then((cached) => {
        if (cached) return cached;
        return fetch(event.request).then((response) => {
          if (response && response.status === 200) {
            const copy = response.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(event.request, copy));
          }
          return response;
        }).catch(() => cached);
      })
    );
    return;
  }

  // Stale-while-revalidate for local HTML/JS/CSS
  event.respondWith(
    caches.match(event.request).then((cached) => {
      const fetchPromise = fetch(event.request).then((networkResponse) => {
        if (networkResponse && networkResponse.status === 200) {
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, networkResponse.clone()));
        }
        return networkResponse;
      }).catch(() => cached);

      return cached || fetchPromise;
    })
  );
});

// Push Notifications Listener
self.addEventListener('push', (event) => {
  let data = { title: 'Пульс города', body: 'Новое уведомление о событиях в Нижневартовске' };
  if (event.data) {
    try {
      data = event.data.json();
    } catch (e) {
      data.body = event.data.text();
    }
  }

  const options = {
    body: data.body || data.description || 'Обновлены события ЖКХ и дорожной обстановки',
    icon: 'https://cdn.jsdelivr.net/npm/@linecons/svg@1.0.2/svg/heart.svg',
    badge: 'https://cdn.jsdelivr.net/npm/@linecons/svg@1.0.2/svg/heart.svg',
    data: data.url || '/app.html',
    vibrate: [100, 50, 100],
    actions: [
      { action: 'open', title: 'Открыть карту' },
      { action: 'close', title: 'Закрыть' }
    ]
  };

  event.waitUntil(
    self.registration.showNotification(data.title || 'Пульс города', options)
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  if (event.action === 'close') return;

  const targetUrl = event.notification.data || '/app.html';
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url.includes(targetUrl) && 'focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(targetUrl);
      }
    })
  );
});
