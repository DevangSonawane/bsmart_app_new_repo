# Cloudflare Migration & Per-Date Service Availability Blocking

Two unrelated pieces of work, both covered here for a single record of what changed, where, and why:

1. **Infrastructure** — moved production off AWS EC2 onto Cloudflare Workers + Containers, with storage consolidated onto Cloudflare R2.
2. **Feature** — services can now be marked unavailable (or given custom hours) on specific calendar dates, independent of their recurring weekly schedule. Backend in `bsmart-backend`, UI in `b-smart`.

---

## Part 1 — AWS → Cloudflare Migration

### What moved

- Production API, previously on an AWS EC2 instance (deployed via GitHub Actions + PM2), now runs as a Cloudflare Worker + Container, same codebase/Dockerfile as the existing `dev` Worker.
- Production file storage moved from AWS S3 (behind CloudFront) to a dedicated Cloudflare R2 bucket.
- MongoDB Atlas is unchanged — it was never on AWS, so no database migration was needed. **Dev and production share the same Atlas database.**
- AWS EC2 is **not yet decommissioned** — DNS (`api.bebsmart.in`) still points at it. Cutover and shutdown are deliberately separate, user-approved steps not yet taken.

### New/changed files

| File | Change |
|---|---|
| `worker/src/index.js` | Added a second Durable Object class `BsmartProd` (parallel to the existing `BsmartDev`, not a rename — zero risk to dev). Fixed two latent bugs in the shared `ENV_KEYS` forwarding list: `APPLE_PRIVATE_KEY_PATH` and the AWS `AWS_REGION`/`AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` (needed by SNS for Android push) were never being forwarded from the Worker into the container, on **both** dev and prod. Also added `CLOUDFRONT_BASE_URL` to the list (see below). |
| `wrangler.production.jsonc` | **New.** Production's own Wrangler config — separate `name`, `containers`/`durable_objects` block (`BsmartProd`), separate `migrations` tag. Same `Dockerfile` as dev. |
| `push-secrets.sh` / `push-secrets.ps1` | Added an optional second argument/parameter for which Wrangler config to target, so the same script pushes secrets to either dev or prod. |
| `.env.production` | **New, gitignored.** Production secrets, assembled from the user-supplied `.env` plus corrected/added values (see "Issues found" below). |
| `src/utils/publicUrl.js`, `src/controllers/post.controller.js` (and ~15 other controllers with the same inlined helper) | Fixed legacy-URL resolution precedence — see below. |
| `server.js` | CORS `allowedHeaders` fix — see below. |

### Deployment process

Production deploys manually for now (not wired into GitHub Actions):

```bash
npx wrangler deploy --config wrangler.production.jsonc --containers-rollout=immediate
```

**Known gotcha:** the container runs as a long-lived singleton (`sleepAfter: "30m"`). Redeploying updates the Worker script and the container *image* immediately, but an already-warm container keeps running the **old** code/secrets until it naturally goes idle for 30 minutes — simply redeploying is not enough to verify a change took effect. To force a true cold restart for verification: delete and recreate the container application (`wrangler containers delete <app-id>`, then redeploy), or temporarily drop `sleepAfter` to something short (e.g. `"10s"`) for one deploy, hit it once, wait past the timeout, then restore `"30m"`.

### Secrets

Pushed via `push-secrets.sh .env.production wrangler.production.jsonc`. Notable corrections made versus the raw values supplied:

- `APPLE_PRIVATE_KEY_PATH` — corrected from the EC2 filesystem path (`/home/ubuntu/...`) to the container's actual path (`/app/secrets/AuthKey_XD4N3XM65V.p8`), since the `.p8` file is baked into the Docker image, not present on Cloudflare's filesystem otherwise.
- `FIREBASE_SERVICE_ACCOUNT_JSON` — the original `.env` only had a filesystem path (`FIREBASE_SERVICE_ACCOUNT_PATH`), unusable in a container. Generated a fresh service account key from the Firebase console (project `bsmart-930c6`) and set it as inline JSON instead.
- `RAZORPAY_PUBLISHING_PLAN_ID` / `RAZORPAY_WEBHOOK_SECRET` — not present in the original `.env` (those were test-mode values in dev, not reusable for live). Created a live-mode Razorpay plan and a new webhook (pointed at the Worker's `workers.dev` URL for now, to be updated once DNS cuts over) to get these.
- Excluded `S3_BUCKET_NAME` / `CLOUDFRONT_BASE_URL` from the *secret push* originally, then re-added `CLOUDFRONT_BASE_URL` after discovering it's still required for legacy media resolution (see next section).

### Storage consolidation (R2)

Production got its own dedicated R2 bucket (`bsmart-prod-storage`), isolated from dev's (`bsmart-dev-storage`) per an explicit decision to keep storage separate. Because dev and prod share one MongoDB database, and media is stored as a relative key (not an absolute URL) reconstructed at read-time against whichever backend serves the request, a *new, empty* bucket meant every pre-existing post/image/video broke when served through the new production Worker.

Fixed by populating the new bucket from the two places real content actually lived, using the AWS SDK (R2 is S3-API-compatible) for both:

1. **AWS S3 → R2**: all 2,132 objects from the original `bsmart-media-615894661827` S3 bucket (the true legacy content, predating any R2 usage) copied into `bsmart-prod-storage`, same keys.
2. **Dev R2 → Prod R2 (56 files only)**: of dev's bucket's ~2,188 objects, 2,132 were already identical to the S3 set (so skipped); the remaining 56 were genuinely dev-only uploads, some of which are referenced by real, currently-visible posts (shared DB) — copied individually rather than mirroring dev's whole bucket, to avoid pulling in unrelated dev-only test data.

### Bugs found and fixed along the way

- **Legacy URL resolution precedence** (`src/utils/publicUrl.js`, `src/controllers/post.controller.js`, and the same inlined pattern in ~15 other controllers): old `api.bebsmart.in/uploads/...` links were being rewritten using `R2_PUBLIC_BASE_URL` in preference to `CLOUDFRONT_BASE_URL`, which breaks as soon as `R2_PUBLIC_BASE_URL` points at a bucket that doesn't have the old files (exactly the new dedicated prod bucket). Swapped the precedence in `publicUrl.js` so `CLOUDFRONT_BASE_URL` (the original, still-live source) wins when set. The other controllers' copies of this same logic were left as-is once the R2 bucket was fully populated (see above), since at that point the precedence no longer matters for existing content — noted here in case it resurfaces for a future environment.
- **CORS blocked a `Cache-Control` request header** (`server.js`): the frontend sends `Cache-Control: no-cache, no-store` on wallet requests; the backend's CORS `allowedHeaders` list didn't include it, so the browser blocked the preflight. Added `Cache-Control` and `Pragma` to the allowed list.

---

## Part 2 — Per-Date Service Availability Blocking

### What this adds

A service owner can mark a specific **future (or today's) date** as fully unavailable, or give it different hours than its normal weekly schedule — without touching the recurring `weekly_availability`. Each block also carries a reason: **Unavailable**, **Fully Booked / Seats Full**, **On Leave**, or **Custom Reason** (with free text).

### Backend (`bsmart-backend`)

**`src/models/InfluencerService.js`** — new field on the service schema:

```js
date_overrides: [{
  date: Date,                                   // required
  slots: [{ start: String, end: String }],      // empty = whole date blocked
  reason: 'unavailable' | 'fully_booked' | 'on_leave' | 'custom',
  custom_reason: String,                          // required when reason === 'custom'
}]
```

**`src/controllers/influencerService.controller.js`** — `validateServiceBody`/`buildServiceData` now validate and normalize `date_overrides` (valid date, no duplicate dates per service, valid `{start,end}` slots, `custom_reason` required when `reason` is `custom`); `date_overrides` added to `updateService`'s field whitelist.

**`src/controllers/serviceBooking.controller.js`** — checkout (`prepareOrderItem`) now checks for a `date_overrides` entry matching the booking date *before* falling back to `weekly_availability`. A match's `slots` fully replace the weekday pattern for that one date (empty `slots` = reject any booking that date). The rejection message includes the reason, e.g. `"<service> is not available on 2026-12-25 at that time (On Leave)"`.

**`src/routes/influencerService.routes.js`** — Swagger docs updated with the new field's shape and an example.

#### API example

```json
PATCH /influencer-services/:id
{
  "date_overrides": [
    { "date": "2026-12-25", "slots": [], "reason": "on_leave" },
    { "date": "2026-12-31", "slots": [{ "start": "09:00", "end": "13:00" }], "reason": "fully_booked" },
    { "date": "2026-11-20", "slots": [], "reason": "custom", "custom_reason": "Equipment maintenance" }
  ]
}
```

Returned as-is on `GET /influencer-services/:id` and `GET /influencer-services` (full passthrough, same as `weekly_availability`).

### Frontend (`b-smart`)

| File | Role |
|---|---|
| `src/myStore/components/DateOverridesEditor.jsx` | **New.** The actual add/edit/remove UI — date picker, Entire day / Specific hours toggle, multiple time ranges, Reason dropdown (custom portal-rendered, not the shared clipped `Dropdown`), a date-range mode that expands into one entry per day (capped at 60 days, skips dates already blocked), and the "Blocked dates & hours" table. Shared between the full edit form and the standalone modal below. |
| `src/myStore/components/ServiceForm.jsx` | Create/Edit Service wizard gained a 4th step, "Special Dates / Time Off", which just embeds `DateOverridesEditor`. Visible for every service method (Online included — there was no pre-existing restriction to fix). |
| `src/myStore/components/BlockDatesModal.jsx` | **New.** Quick-access modal from the services list, without opening the full edit wizard. Single-service mode loads and replaces that service's actual blocks; multi-select (bulk) mode merges new block(s) into each selected service's *existing* blocks rather than replacing them. |
| `src/myStore/pages/Services.jsx` | Added "Block dates" to each row's "⋮" menu (opens the modal for that one service) and a "Block dates" button to the bulk-selection action bar (opens it in bulk mode for all checked rows). |
| `src/components/CalendarDatePicker.jsx` | Shared date-picker component, extended (backward-compatibly — two other existing usages unaffected): a new optional `dateStatus(date)` prop renders a dot + hover tooltip on days that already have a block. Also fixed two real bugs: (1) it defaulted to showing the *far-future* month when nothing was selected and a large `maxDate` was passed (now prefers the month containing "today" whenever today is in range); (2) its popup's `z-[300]` rendered *underneath* any modal using `z-[9999]` since both portal to `document.body` — bumped to `z-[10000]`/`z-[10001]`. |
| `src/pages/ServiceDetail.jsx`, `src/myStore/data/serviceBooking.js` | Customer-facing booking calendar: `availableTimes()` now checks `date_overrides` before falling back to the weekly pattern; the date quick-pick buttons show "Unavailable" (grayed, struck through, disabled, with a hover tooltip) for any date with zero available times — this didn't previously exist as dynamic, data-driven behavior. |
| `src/services/influencerServiceService.js` | `dateOverridesFromApi`/`dateOverridesToApi` mappers (API's snake_case `date_overrides` ↔ the frontend's per-entry draft shape), `REASON_OPTIONS` constant, wired into `normalizeInfluencerService` and `serviceFormToApiPayload`. |

### Known limitations

- A date-range block (UI convenience) expands into independent single-date entries server-side — there's no "range" concept in storage, so editing later is always per individual date.
- Bulk-apply from the services list only *adds* blocks; it has no bulk-remove equivalent yet.
