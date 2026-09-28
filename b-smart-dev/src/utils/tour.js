// Shared helpers for the first-time-user onboarding tour.
// Keyed off account creation (Signup/VendorSignup), not plain login, since the
// backend has no "is this a brand-new account" flag on the login response.

const NEW_SIGNUP_KEY = 'bsmart_new_signup';
const tourCompletedKey = (userId) => `bsmart_tour_completed_${userId}`;

export const markNewSignup = () => {
  try { localStorage.setItem(NEW_SIGNUP_KEY, '1'); } catch { /* ignore */ }
};

export const isNewSignupPending = () => {
  try { return localStorage.getItem(NEW_SIGNUP_KEY) === '1'; } catch { return false; }
};

export const isTourCompleted = (userId) => {
  try { return localStorage.getItem(tourCompletedKey(userId)) === '1'; } catch { return false; }
};

export const completeTour = (userId) => {
  try {
    if (userId) localStorage.setItem(tourCompletedKey(userId), '1');
    localStorage.removeItem(NEW_SIGNUP_KEY);
  } catch { /* ignore */ }
};

// Sidebar (desktop) and BottomNav (mobile) render the same nav in parallel,
// tagged with matching data-tour ids — only one is visible at a given
// breakpoint, so pick whichever currently has a non-zero rect.
export const getVisibleTourElement = (id) => {
  const els = document.querySelectorAll(`[data-tour="${id}"]`);
  for (const el of els) {
    const rect = el.getBoundingClientRect();
    if (rect.width > 0 && rect.height > 0) return el;
  }
  return null;
};
