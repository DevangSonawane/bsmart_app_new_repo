# Release Notes — Flutter Parity Release

This release focuses on reaching feature parity with the React web app for mobile (iOS & Android).

Highlights:
- Supabase service parity: added compatibility for RPCs and storage usage similar to web.
- Reels player improvements: prefetching and controller lifecycle management for smoother playback.
- Storage bucket alignment: Flutter now uploads to `post_images` bucket by default (same as web).
- Wallet/gifting flow: attempts atomic transfer via `transfer_coins` RPC and falls back to best-effort approach.
- Caching improvements: network images use cached provider for better performance.
- Routes centralized in `lib/routes.dart`.
- Added QA checklist and security checks documentation.
- Added a basic smoke test and QA docs.

Known limitations:
- Some server-side RPCs (e.g., `transfer_coins`, `append_post_id`) may need to be created on the Supabase instance if not present.
- Video caching beyond in-memory prefetch is best-effort; consider adding a dedicated video cache plugin for offline playback.

