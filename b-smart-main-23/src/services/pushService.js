import api from '../lib/api';

// ── VAPID public key — copy this from your backend .env VAPID_PUBLIC_KEY ──────
// Generate it once with: node -e "const wp=require('web-push');console.log(wp.generateVAPIDKeys())"
const VAPID_PUBLIC_KEY = import.meta.env.VITE_VAPID_PUBLIC_KEY || '';

// ─────────────────────────────────────────────────────────────────────────────
// Convert a base64 VAPID public key to the Uint8Array format the browser needs
// ─────────────────────────────────────────────────────────────────────────────
const urlBase64ToUint8Array = (base64String) => {
  const padding = '='.repeat((4 - (base64String.length % 4)) % 4);
  const base64  = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
  const rawData = window.atob(base64);
  return Uint8Array.from([...rawData].map((char) => char.charCodeAt(0)));
};

// ─────────────────────────────────────────────────────────────────────────────
/**
 * Register a web push subscription with the backend.
 * Call this once after the user logs in.
 * Silently skips if the browser doesn't support push or user denies permission.
 */
export const registerWebPush = async () => {
  try {
    // Check browser support
    if (!('serviceWorker' in navigator) || !('PushManager' in window)) {
      console.log('[WebPush] Not supported in this browser.');
      return;
    }

    if (!VAPID_PUBLIC_KEY) {
      console.warn('[WebPush] VITE_VAPID_PUBLIC_KEY not set in .env — skipping web push setup.');
      return;
    }

    // Request notification permission
    const permission = await Notification.requestPermission();
    if (permission !== 'granted') {
      console.log('[WebPush] Permission denied by user.');
      return;
    }

    // Wait for service worker to be ready
    const registration = await navigator.serviceWorker.ready;

    // Subscribe to push
    const subscription = await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: urlBase64ToUint8Array(VAPID_PUBLIC_KEY),
    });

    // Send subscription to backend
    await api.post('/push/register-web', { subscription });
    console.log('[WebPush] Subscription registered successfully.');
  } catch (err) {
    // Non-fatal — app works fine without push
    console.error('[WebPush] Registration error:', err.message);
  }
};

// ─────────────────────────────────────────────────────────────────────────────
/**
 * Unregister push tokens from backend on logout.
 * Silently fails if the request errors.
 */
export const unregisterPush = async () => {
  try {
    await api.delete('/push/unregister');
    console.log('[Push] Tokens cleared on logout.');
  } catch (err) {
    console.error('[Push] Unregister error:', err.message);
  }
};
