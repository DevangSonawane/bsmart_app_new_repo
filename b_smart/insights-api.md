# Insights API — Posts, Reels, Promoted Reels & Account

Four endpoints power the Insights pages in the app (per-post, per-promoted-reel, and account-wide). Every number in every response is read from something real that already happened — a like, a comment, a follow, a tracked view — never estimated or filled in to look complete. Where the data model genuinely can't support a metric yet (e.g. location breakdown for promoted reels), the field is honestly empty rather than guessed.

All four endpoints require a valid auth token and are **owner-only** — requesting insights for content/an account that isn't yours returns `403`.

---

## 1. Single post or reel — `GET /api/posts/:id/stats`

**Controller:** `src/controllers/poststats.controller.js` → `getPostStats`
**Frontend:** `b-smart/src/pages/PostInsights.jsx`, linked from each post/reel's owner options menu ("View Insights")

Returns, for one post or reel:

| Field | What it is |
|---|---|
| `likes.by_gender` / `likes.by_age` | Who liked it, bucketed from each liker's profile `gender`/`age` |
| `dislikes.*` | Viewers who watched but didn't like (reels only — needs a view log) |
| `comments.total` / `comments.recent` | Comment count + latest 5 |
| `views.total` / `views.unique` / `views.completed` | From the post's own lifetime counters |
| `views.by_location` / `views.by_age` | Per-viewer breakdown — **reels only**, since only reels get a `PostView` row per viewer |
| `retention_curve` | For reels: % of viewers who watched at least 10%, 20%, … 100% of the way through, from each viewer's max-reached `watch_fraction`. Empty array for image posts — there's no watch-progress to plot |
| `platform_avg_retention_curve` | Same shape, averaged across other reels platform-wide (sampled up to 5,000 views for cost) — a real comparison baseline, not a guessed "industry average" |
| `thumbnail_url` | The post's first media item, resolved through the same R2/CloudFront URL logic the main feed uses |

## 2. Promoted reel — `GET /api/promote-reels/:id/stats`

**Controller:** `src/controllers/promoteReel.controller.js` → `getPromoteReelStats`
**Frontend:** `b-smart/src/pages/PromoteReelInsights.jsx`, linked from the same owner options menu on a promoted reel

Same shape as above for likes/comments/views, but **no location or age breakdown for views, and no retention curve** — `PromoteReel` only keeps lifetime counters (`views_count`, `unique_views_count`, `completed_views_count`), not a per-viewer log like `PostView`. Building those would need a new `PromoteReelView` model; nothing fakes that gap in the meantime, the UI just shows an honest note that this level of detail isn't tracked yet for promoted reels.

## 3. Account-wide insights — `GET /api/users/:id/insights`

**Controller:** `src/controllers/user.controller.js` → `getUserInsights`
**Frontend:** `b-smart/src/pages/UserInsights.jsx`, linked from an Insights icon on your own profile

| Field | What it is |
|---|---|
| `totals` | Posts / views / likes / comments / followers / following, summed across your content |
| `top_posts` / `recent_content` | Your top 5 by views, and your latest 20 (for a content-library table) |
| `follower_growth` | Real daily new-follower counts for the last 30 days, from `Follow` document timestamps |
| `reel_viewer_reach` | Unique reel viewers split into followers vs. non-followers, **reel-only** (same `PostView`-only limitation as above) |
| `top_territories` | Your top 5 viewer locations by unique reel viewer |
| `posting_time_heatmap` | 7×24 grid (day of week × hour, IST) of when your reel views land — helps spot your best posting windows |

## 4. Content performance (period comparison) — `GET /api/users/:id/content-performance?days=28`

**Controller:** `src/controllers/user.controller.js` → `getUserContentPerformance`

Compares a trailing window (default 28 days, 7–90 accepted) against the equal-length period before it, broken down by `all` / `reel` / `post` / `story`:

- `content_count`, `plays`, `likes`, `comments`, `saves` — summed from each item's own counters / `SavedPost` for items **published** in that window
- `watch_time_ms` — reels only, summed from each viewer's real completed `watchTimeMs` on `PostView`
- `engagement_rate` — `(likes + comments + saves) / plays`, rounded to one decimal

Returns `{ period, previous_period, current, previous }` so the frontend can show "+18.4% vs. previous 28 days" style deltas — real deltas, computed, never typed in.

---

## What's deliberately not here

Two sections from an early design reference for this feature were explicitly left out because there's no honest data behind them yet: **discovery channels** (how viewers found a reel — Explore feed vs. profile vs. search) and **tagged-product revenue** (sales attributed to a tagged product inside a reel). Both would need new instrumentation that doesn't exist; rather than show invented numbers, they're simply not in the response.

## Where this lives

| | File |
|---|---|
| Post/reel stats | `src/controllers/poststats.controller.js` |
| Promoted reel stats | `src/controllers/promoteReel.controller.js` |
| Account insights + content performance | `src/controllers/user.controller.js` |
| Per-viewer view log (reels only) | `src/models/PostView.js` |
| Routes | `src/routes/post.routes.js` (and `poststats.routes.js`), `src/routes/promoteReel.routes.js`, `src/routes/user.routes.js` |
| Post insights page | `b-smart/src/pages/PostInsights.jsx` |
| Promoted reel insights page | `b-smart/src/pages/PromoteReelInsights.jsx` |
| Account insights page | `b-smart/src/pages/UserInsights.jsx` |
