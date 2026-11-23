# What's new: Pinned Posts

Users can now pin up to **3** of their own posts to the top of their profile. This was partially scaffolded already (the `pinned_at` field, the `/pin`/`/unpin` routes, and the owner options menu's "Pin to Moments" button all existed) — this update closes the remaining gaps: the 3-pin limit, a uniform `is_pinned` flag everywhere a post is returned, pinned-first ordering on the profile, and the pin action/badge actually wired into the main feed/explore post card (it previously only worked from inside the post-detail modal).

## Rules

- **Up to 3 pinned posts per user**, enforced server-side — pinning a 4th is rejected with `400` until one is unpinned.
- **Only the post's own author** can pin/unpin it (`403` otherwise).
- Pinning applies to plain **posts** only, not reels or ads.
- Pinned posts show **first on that user's own profile grid** (most recently pinned first), and carry a small pin badge **wherever the post card renders** — profile grid, main feed, explore.

## API

```
PATCH /api/posts/:id/pin
PATCH /api/posts/:id/unpin
```
Both require auth (`verifyToken`) and ownership of the post. Response is the full updated post object (same shape as everywhere else a post is returned).

**New response field, on every post everywhere** (feed, explore, profile, post detail):
```json
{ "is_pinned": true, "pinned_at": "2026-11-23T10:00:00.000Z", ... }
```
`is_pinned` is a convenience boolean derived from `pinned_at` — use whichever is more convenient; both are always present and consistent.

**Error when the limit is hit:**
```json
{ "message": "You can only pin up to 3 posts — unpin one first" }
```

## Where this lives

| | File |
|---|---|
| Schema (`pinned_at`, pre-existing) | `src/models/Post.js` |
| Serializer (`is_pinned` flag) | `src/controllers/post.controller.js` — `transformPost` |
| Pin/unpin handler + 3-pin limit | `src/controllers/post.controller.js` — `setPostPinned` |
| Routes (pre-existing) | `src/routes/post.routes.js` |
| Profile grid fetch (pinned-first sort) | `src/controllers/user.controller.js` — `getUserPostsDetails`, `getUserProfileContent` |
| Profile grid badge + client-side sort (pre-existing) | `b-smart/src/pages/Profile.jsx` |
| Post-detail modal pin action (pre-existing) | `b-smart/src/components/PostDetailModal.jsx` |
| Main feed/explore card — pin action + badge (**new**) | `b-smart/src/components/PostCard.jsx` |
| "..." menu Pin/Unpin button (pre-existing) | `b-smart/src/components/OwnerContentOptionsModal.jsx` |

## Known limitation

Among 3 pinned posts, there's no manual re-ordering — they're always shown most-recently-pinned first. Re-pin a post (unpin then pin again) to bring it back to the front.

## Flutter app (this repo)

| | File |
|---|---|
| `isPinned` / `pinnedAt` on posts, parsers, pinned-first sort | `lib/models/feed_post_model.dart` — `FeedPost.parsePinnedAt`, `parseIsPinned`, `sortPinnedFirst` |
| `PATCH /posts/:id/pin` + `/unpin` | `lib/api/posts_api.dart` — `pinPost`, `unpinPost` |
| Pin/unpin + change stream + snackbar (shows the server's 3-pin-limit message) | `lib/services/post_pin_service.dart` |
| Redux update | `lib/state/feed_actions.dart` (`UpdatePostPinned`), `lib/state/feed_reducer.dart` |
| Feed parsing (`pinned_at` / `is_pinned`) | `lib/services/feed_service.dart` |
| Profile grid: pinned-first sort + live update on pin/unpin | `lib/screens/profile_screen.dart` |
| Pin badge (grid overlay + inline in feed card header) | `lib/widgets/pinned_badge.dart`, `lib/widgets/posts_grid.dart`, `lib/widgets/post_card.dart` |
| "..." menu Pin to Moments / Unpin from Moments (owner only, plain posts only) | `lib/screens/home_dashboard.dart` (`_onMorePost`), `lib/screens/post_detail_screen.dart`, `lib/widgets/post_detail_modal.dart` |
