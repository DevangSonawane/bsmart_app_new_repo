// Shared, self-contained WebRTC/ringtone helpers used by both CallOverlay
// (1:1 calls) and GroupCallOverlay (group calls) — pure utilities with no
// component state, so they live here instead of being duplicated.

// Cloudflare's Calls API is a single HTTP round trip per SDP exchange (no
// trickle-ICE signaling channel), so the offer/answer we send it must
// already contain all gathered ICE candidates.
export const waitForIceGatheringComplete = (pc, timeoutMs = 3000) => {
  if (pc.iceGatheringState === 'complete') return Promise.resolve();
  return new Promise((resolve) => {
    const onChange = () => {
      if (pc.iceGatheringState === 'complete') {
        pc.removeEventListener('icegatheringstatechange', onChange);
        resolve();
      }
    };
    pc.addEventListener('icegatheringstatechange', onChange);
    setTimeout(resolve, timeoutMs);
  });
};

// Classic telephone ringtone, synthesized with the Web Audio API so no
// audio asset needs to be shipped/licensed — a "ring-ring … pause" cadence
// using the traditional North American dual-tone pair (440Hz + 480Hz played
// together). Repeats on an interval for as long as an incoming call rings.
export const RING_INTERVAL_MS = 3000; // full cycle: ring-ring, then silence
const RING_TONES = [440, 480];
const RING_BURST_STARTS = [0, 0.6]; // two short bursts = "ring-ring"
const RING_BURST_DURATION = 0.4;
export const playRingChime = (ctx) => {
  if (ctx.state === 'suspended') ctx.resume().catch(() => {});
  const now = ctx.currentTime;
  RING_BURST_STARTS.forEach((offset) => {
    RING_TONES.forEach((freq) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sine';
      osc.frequency.value = freq;
      gain.gain.setValueAtTime(0, now + offset);
      gain.gain.linearRampToValueAtTime(0.18, now + offset + 0.02);
      gain.gain.setValueAtTime(0.18, now + offset + RING_BURST_DURATION - 0.03);
      gain.gain.linearRampToValueAtTime(0, now + offset + RING_BURST_DURATION);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(now + offset);
      osc.stop(now + offset + RING_BURST_DURATION + 0.02);
    });
  });
};

// Incoming-call attention-grabbers for when the tab is backgrounded or
// minimized — the ringtone itself keeps playing in a background tab (browsers
// don't mute inactive tabs), but there's otherwise no visual cue the user
// would notice without looking directly at the tab.

// Ask once per app load; safe to call from multiple components since the
// browser just no-ops if permission was already granted/denied.
export const requestNotificationPermission = () => {
  if (typeof Notification === 'undefined') return;
  if (Notification.permission === 'default') Notification.requestPermission().catch(() => {});
};

// Shows a system notification for an incoming call, only if permission is
// already granted and the tab isn't the focused one (no need to interrupt
// someone already looking at the ringing screen).
export const showIncomingCallNotification = (title, body) => {
  if (typeof Notification === 'undefined' || Notification.permission !== 'granted') return null;
  if (typeof document !== 'undefined' && !document.hidden) return null;
  try {
    const notification = new Notification(title, { body, tag: 'bsmart-incoming-call', renotify: true });
    notification.onclick = () => {
      window.focus();
      notification.close();
    };
    return notification;
  } catch {
    return null;
  }
};

// Flashes the browser tab's title between the real title and `flashText`
// so an incoming call is noticeable even in a background/minimized tab.
let titleFlashInterval = null;
let originalTitle = null;
export const startTitleFlash = (flashText) => {
  if (titleFlashInterval || typeof document === 'undefined') return;
  originalTitle = document.title;
  let showingFlash = false;
  titleFlashInterval = setInterval(() => {
    document.title = showingFlash ? originalTitle : flashText;
    showingFlash = !showingFlash;
  }, 1000);
};
export const stopTitleFlash = () => {
  if (titleFlashInterval) {
    clearInterval(titleFlashInterval);
    titleFlashInterval = null;
  }
  if (originalTitle !== null && typeof document !== 'undefined') {
    document.title = originalTitle;
    originalTitle = null;
  }
};
