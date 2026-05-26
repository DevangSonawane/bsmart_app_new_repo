/* eslint-disable no-restricted-globals */
// ─── Bsmart Service Worker ────────────────────────────────────────────────────
// Place this file at: public/sw.js
// It handles background push notifications for the web app.

const CACHE_NAME = 'bsmart-v1';

// ── Install — cache nothing critical, just activate immediately ───────────────
self.addEventListener('install', (event) => {
  self.skipWaiting();
});

// ── Activate — take control of all open tabs immediately ─────────────────────
self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

// ── Push — show notification when a push arrives from the server ──────────────
self.addEventListener('push', (event) => {
  let data = {};

  try {
    data = event.data?.json() || {};
  } catch {
    data = { title: 'Bsmart', body: event.data?.text() || 'You have a new notification.' };
  }

  const {
    title = 'Bsmart',
    body  = 'You have a new notification.',
    link  = '/',
    type  = 'general',
    icon  = '/bsmart-icon.png',   // put your app icon in /public/bsmart-icon.png
    badge = '/bsmart-badge.png',  // small monochrome badge icon (optional)
  } = data;

  const options = {
    body,
    icon,
    badge,
    data: { link, type },
    vibrate: [100, 50, 100],
    tag: type,              // groups notifications of the same type (replaces older ones)
    renotify: true,         // vibrate even if same tag
    requireInteraction: false,
  };

  event.waitUntil(
    self.registration.showNotification(title, options)
  );
});

// ── Notification click — open/focus the app and navigate to the link ──────────
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const link = event.notification.data?.link || '/';
  const fullUrl = self.location.origin + link;

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      // If a tab with the app is already open, focus it and navigate
      for (const client of clientList) {
        if (client.url.startsWith(self.location.origin) && 'focus' in client) {
          client.focus();
          client.navigate(fullUrl);
          return;
        }
      }
      // Otherwise open a new tab
      if (self.clients.openWindow) {
        return self.clients.openWindow(fullUrl);
      }
    })
  );
});
