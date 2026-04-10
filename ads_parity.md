# Ads parity (React → Flutter)

This repo contains:
- React web app: `b-smart-main-13/`
- Flutter app: `b_smart/`

## React routes (Ads-related)

From `b-smart-main-13/src/App.jsx`:
- `/ads` → `Ads` (vendors redirect to `/vendor-ads`)
- `/vendor-ads` → `VendorAds` (non-vendors redirect to `/ads`)
- `/ads/:adId/details` → `AdPublicDetail`
- `/vendor/ads-management` → `AdsManagement`
- `/vendor/ads-management/:adId` → `AdDetails`

Role redirects:
- `Ads.jsx`: if `feedMode === 'user'` and user role is `vendor` → redirect to `/vendor-ads`
- `VendorAds.jsx`: if user role is not `vendor` → redirect to `/ads`

## React API base URL

From `b-smart-main-13/src/lib/api.js`:
- `VITE_API_URL` (default `https://api.bebsmart.in/api`)

## React API endpoints used (Ads)

Observed from `b-smart-main-13/src/pages/Ads.jsx`, `AdPublicDetail.jsx`, `vendor-pages/AdsManagement.jsx`, `vendor-pages/AdDetails.jsx`, `services/commentServiceJS.js`:
- `GET  /api/ads/feed`
- `GET  /api/ads/search?q=&category=&page=&limit=&...`
- `GET  /api/ads/:adId`
- `POST /api/ads/:adId/view`
- `POST /api/ads/:adId/click`
- `POST /api/ads/:adId/like`
- `POST /api/ads/:adId/unlike` (some places) / `POST /api/ads/:adId/dislike` (some places)
- `POST /api/ads/:adId/save` / `POST /api/ads/:adId/unsave` (used in feed actions)
- `GET  /api/ads/:adId/comments` (optionally `?page=&limit=`)
- `POST /api/ads/:adId/comments` (`{ text, parent_id? }`)
- `GET  /api/ads/comments/:commentId/replies`
- `POST /api/ads/comments/:commentId/like`
- `POST /api/ads/comments/:commentId/unlike` (some places) / `POST /api/ads/comments/:commentId/dislike` (some places)
- `GET  /api/ads/categories`
- `GET  /api/ads/user/:userId`
- `PATCH /api/ads/:adId/metadata` (vendor status update)
- `GET  /api/ads/:adId/stats` (vendor analytics)
- `GET  /api/wallet/ads/:adId/history?page=&limit=` (vendor billing/ledger)
- `DELETE /api/ads/:adId` (vendor delete)

## Flutter parity mapping

Flutter routes are defined in:
- `b_smart/lib/routes.dart` (static)
- `b_smart/lib/main.dart` (`onGenerateRoute` dynamic)

Implemented route parity:
- `/ads` → `RoleRedirectGate` → `AdsPageScreen` (vendors redirected to `/vendor-ads`)
- `/vendor-ads` → `RoleRedirectGate` → `AdsPageScreen` (non-vendors redirected to `/ads`)
- `/ads/:adId/details` → `AdDetailScreen(adId)`
- `/ad/:adId` → `AdDetailScreen(adId)` (existing Flutter deep link)
- `/vendor/ads-management` → `RoleRedirectGate` → `AdvertiserAdsListScreen`
- `/vendor/ads-management/create` → `RoleRedirectGate` → `AdvertiserCreateAdScreen`
- `/vendor/ads-management/:adId` → `AdDetailScreen(adId)` (basic parity; can be upgraded to a dedicated analytics screen later)

Flutter API wrappers:
- `b_smart/lib/api/ads_api.dart` covers `/ads/*` and now includes fallbacks for backend variants (`unlike` vs `dislike`, comment `unlike` vs `dislike`) plus vendor endpoints (`stats`, `metadata`, ad wallet history, click tracking).

