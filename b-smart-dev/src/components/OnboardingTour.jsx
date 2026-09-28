import { useEffect, useState } from 'react';
import { createPortal } from 'react-dom';
import { X } from 'lucide-react';
import { useSelector } from 'react-redux';
import { MEMBER_TOUR_STEPS, VENDOR_TOUR_STEPS } from '../constants/tourSteps';
import { completeTour, getVisibleTourElement, isNewSignupPending, isTourCompleted } from '../utils/tour';

const TOOLTIP_WIDTH = 320;
const TOOLTIP_EST_HEIGHT = 170;
const MARGIN = 12;
const PAD = 8;

const isStepValid = (step) => step.id === 'welcome' || Boolean(getVisibleTourElement(step.id));

// Guided, one-time product tour for brand-new accounts — spotlights each nav
// item / wallet / location in turn with a Next/Back/Skip tooltip. Fires once,
// right after Signup/VendorSignup, mirroring LocationSelector's portal +
// viewport-flip pattern so the highlight and tooltip are never clipped.
const OnboardingTour = () => {
  const { userObject } = useSelector((state) => state.auth);
  const userId = userObject?._id || userObject?.id;
  const isVendor = userObject?.role === 'vendor';
  const steps = isVendor ? VENDOR_TOUR_STEPS : MEMBER_TOUR_STEPS;

  const [active, setActive] = useState(false);
  const [stepIndex, setStepIndex] = useState(0);
  const [rect, setRect] = useState(null);

  // Trigger once, only for accounts that just came through Signup/VendorSignup.
  useEffect(() => {
    if (!userId || active) return;
    if (isTourCompleted(userId) || !isNewSignupPending()) return;
    const t = setTimeout(() => { setStepIndex(0); setActive(true); }, 600);
    return () => clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [userId]);

  // Track the current step's target element, skipping steps whose target
  // isn't present at this breakpoint/route (e.g. location is desktop-only).
  useEffect(() => {
    if (!active) return;
    const step = steps[stepIndex];
    if (!step) return;

    if (step.id === 'welcome') { setRect(null); return; }

    const el = getVisibleTourElement(step.id);
    if (!el) {
      const next = findValidIndex(steps, stepIndex + 1, 1);
      if (next === -1) finish(); else setStepIndex(next);
      return;
    }

    const update = () => setRect(el.getBoundingClientRect());
    update();
    window.addEventListener('resize', update);
    window.addEventListener('scroll', update, true);
    return () => {
      window.removeEventListener('resize', update);
      window.removeEventListener('scroll', update, true);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [active, stepIndex]);

  const finish = () => {
    completeTour(userId);
    setActive(false);
  };

  const goNext = () => {
    const next = findValidIndex(steps, stepIndex + 1, 1);
    if (next === -1) { finish(); return; }
    setStepIndex(next);
  };

  const goBack = () => {
    const prev = findValidIndex(steps, stepIndex - 1, -1);
    if (prev !== -1) setStepIndex(prev);
  };

  if (!active) return null;

  const step = steps[stepIndex];
  const isWelcome = step.id === 'welcome';
  const isLast = findValidIndex(steps, stepIndex + 1, 1) === -1;
  const canGoBack = !isWelcome && findValidIndex(steps, stepIndex - 1, -1) !== -1;

  const tooltipPos = rect ? computeTooltipPos(rect) : null;

  return createPortal(
    <div className="fixed inset-0 z-[500]">
      {/* Spotlight cutout — box-shadow dims everything except the target */}
      {rect ? (
        <div
          className="fixed rounded-2xl transition-all duration-200 ease-out"
          style={{
            top: rect.top - PAD, left: rect.left - PAD,
            width: rect.width + PAD * 2, height: rect.height + PAD * 2,
            boxShadow: '0 0 0 9999px rgba(0,0,0,0.72)',
            pointerEvents: 'none',
          }}
        />
      ) : (
        <div className="fixed inset-0 bg-black/70" />
      )}

      {/* Click-blocker so the rest of the app can't be interacted with mid-tour */}
      <div className="fixed inset-0" onClick={(e) => e.stopPropagation()} />

      {isWelcome ? (
        <div className="fixed inset-0 flex items-center justify-center p-4">
          <div className="w-full max-w-sm bg-white dark:bg-[#1c1c1c] rounded-2xl shadow-2xl border border-gray-100 dark:border-white/10 p-6 text-center">
            <h3 className="text-lg font-bold text-gray-900 dark:text-white mb-2">{step.title}</h3>
            <p className="text-sm text-gray-500 dark:text-gray-400 mb-6">{step.description}</p>
            <div className="flex flex-col gap-2">
              <button
                onClick={goNext}
                className="w-full py-2.5 rounded-xl bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange text-white font-bold shadow-lg shadow-insta-pink/20 hover:opacity-90 transition-opacity"
              >
                Start tour
              </button>
              <button
                onClick={finish}
                className="w-full py-2.5 rounded-xl text-gray-500 dark:text-gray-400 font-semibold hover:text-gray-700 dark:hover:text-gray-200 transition-colors"
              >
                Skip
              </button>
            </div>
          </div>
        </div>
      ) : tooltipPos && (
        <div
          className="fixed w-[320px] bg-white dark:bg-[#1c1c1c] rounded-2xl shadow-2xl border border-gray-100 dark:border-white/10 p-4"
          style={{ top: tooltipPos.top, left: tooltipPos.left }}
        >
          <div className="flex items-start justify-between gap-2 mb-1">
            <h4 className="text-base font-bold text-gray-900 dark:text-white">{step.title}</h4>
            <button onClick={finish} aria-label="Close tour" className="p-1 -m-1 rounded-full text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 hover:bg-gray-100 dark:hover:bg-white/10 transition-colors shrink-0">
              <X size={16} />
            </button>
          </div>
          <p className="text-sm text-gray-500 dark:text-gray-400 mb-4">{step.description}</p>
          <div className="flex items-center justify-between gap-2">
            <button onClick={finish} className="text-xs font-semibold text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 transition-colors">
              Skip tour
            </button>
            <div className="flex items-center gap-2">
              {canGoBack && (
                <button onClick={goBack} className="px-3 py-1.5 rounded-lg text-xs font-semibold text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-white/10 transition-colors">
                  Back
                </button>
              )}
              <button
                onClick={goNext}
                className="px-4 py-1.5 rounded-lg text-xs font-bold text-white bg-gradient-to-r from-insta-purple via-insta-pink to-insta-orange hover:opacity-90 transition-opacity"
              >
                {isLast ? 'Finish' : 'Next'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>,
    document.body
  );
};

// Scans in `direction` (+1/-1) from `from`, returning the first index whose
// step target is currently present, or -1 if none remain.
function findValidIndex(steps, from, direction) {
  for (let i = from; i >= 0 && i < steps.length; i += direction) {
    if (isStepValid(steps[i])) return i;
  }
  return -1;
}

function computeTooltipPos(rect) {
  const spaceBelow = window.innerHeight - rect.bottom;
  const spaceAbove = rect.top;
  const placeBelow = spaceBelow >= TOOLTIP_EST_HEIGHT || spaceBelow >= spaceAbove;
  const top = placeBelow
    ? rect.bottom + MARGIN
    : Math.max(MARGIN, rect.top - TOOLTIP_EST_HEIGHT - MARGIN);
  const preferredLeft = rect.left + rect.width / 2 - TOOLTIP_WIDTH / 2;
  const maxLeft = window.innerWidth - TOOLTIP_WIDTH - MARGIN;
  const left = Math.min(Math.max(MARGIN, preferredLeft), Math.max(MARGIN, maxLeft));
  return { top, left };
}

export default OnboardingTour;
