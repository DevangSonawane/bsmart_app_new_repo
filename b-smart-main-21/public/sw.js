/* eslint-disable no-restricted-globals */
// ─── Bsmart Service Worker ─────────────────────────────────────────────────────

self.addEventListener('install',  () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));

// ── Emoji icon map per notification type ──────────────────────────────────────
const TYPE_ICON = {
  like:                     '❤️',
  comment:                  '💬',
  follow:                   '👤',
  follow_request:           '👤',
  follow_accepted:          '✅',
  mention:                  '📣',
  comment_like:             '❤️',
  comment_reply:            '💬',
  post_save:                '🔖',
  ad_comment:               '💬',
  ad_like:                  '❤️',
  coins_credited:           '🪙',
  coins_debited:            '🪙',
  subscribed_user_post:     '📸',
  subscribed_user_reel:     '🎬',
  subscribed_vendor_post:   '🏪',
  subscription_expiring:    '⏳',
  subscription_expired:     '⚠️',
  vendor_approved:          '✅',
  ad_approved:              '✅',
  ad_rejected:              '❌',
  vendor_rejected:          '❌',
  order:                    '📦',
  payout:                   '💸',
  story_view:               '👁️',
  login_alert:              '🔐',
  chat:                     '💬',
  general:                  '🔔',
};

// ── Push handler ──────────────────────────────────────────────────────────────
self.addEventListener('push', (event) => {
  let data = {};
  try {
    data = event.data?.json() || {};
  } catch {
    data = { body: event.data?.text() || 'You have a new notification.' };
  }

  const {
    title       = 'Bsmart',
    body        = 'You have a new notification.',
    link        = '/',
    type        = 'general',
    senderName  = '',
    senderAvatar = '',
  } = data;

  const emoji   = TYPE_ICON[type] || '🔔';
  const isChat  = type === 'chat';

  // ── Build rich notification options ────────────────────────────────────────
  const options = {
    body,
    icon:  '/bsmart-logo.png',     // your app logo — place in /public/bsmart-logo.png
    badge: '/bsmart-badge.png',    // small monochrome icon — place in /public/bsmart-badge.png
    image: isChat && senderAvatar ? senderAvatar : undefined,  // show avatar in chat notifications
    data:  { link, type },
    vibrate:         [100, 50, 100, 50, 100],
    tag:             isChat ? `chat-${link}` : type,   // chat notifications group by conversation
    renotify:        true,
    requireInteraction: isChat,    // chat stays until dismissed; others auto-dismiss
    silent:          false,

    // Action buttons
    actions: isChat
      ? [
          { action: 'reply',    title: '💬 Open Chat' },
          { action: 'dismiss',  title: '✕ Dismiss'   },
        ]
      : [
          { action: 'open',    title: `${emoji} View` },
          { action: 'dismiss', title: '✕ Dismiss'    },
        ],
  };

  event.waitUntil(
    self.registration.showNotification(title, options)
  );
});

// ── Notification click handler ────────────────────────────────────────────────
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  if (event.action === 'dismiss') return;

  const link    = event.notification.data?.link || '/';
  const fullUrl = self.location.origin + link;

  event.waitUntil(
    self.clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        // Focus existing tab if open
        for (const client of clientList) {
          if (client.url.startsWith(self.location.origin) && 'focus' in client) {
            client.focus();
            client.navigate(fullUrl);
            return;
          }
        }
        // Open new tab
        if (self.clients.openWindow) {
          return self.clients.openWindow(fullUrl);
        }
      })
  );
});