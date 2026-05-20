# Media / Image Posting Architecture (b_smart)

This document describes the **real media pipeline** implemented in this repo (Flutter client) for posts/reels/stories/chat media. It is written for senior engineers who need to understand how uploads become normalized feed items, how aspect ratios are stabilized, how “layouts” are chosen, and how rendering avoids jank.

> Scope note (important): this repository contains the **client-side pipeline** and the **REST contract surface** (endpoints + payload shapes). The actual server-side image transformation/worker/CDN code is **not** present here, so backend processing details are described only where the Flutter app makes them explicit (paths, fields, expectations). Anywhere the backend behavior is unknown, this doc calls it out.

---

## 1) Overall Media Pipeline

### 1.1 End-to-end flow (posts)

**High-level chain**

```text
Gallery/Picker
→ Edit preview (frame selection + optional crop + overlays + filter/adjustments)
→ (Optional) local rasterization / image rewrite
→ Upload (multipart)
→ Create Post (JSON payload: media[] + metadata)
→ Feed fetch (post objects)
→ URL normalization + aspect ratio stabilization
→ Feed rendering (cover/contain rules + lazy video playback)
```

**Frontend implementation flow**

1. **Select media (local device):**
   - Entry screen: `b_smart/lib/screens/create_upload_screen.dart`
   - Uses `photo_manager` to query device assets and builds an Instagram-style picker.
   - Creates app-level media objects: `MediaItem` (`b_smart/lib/models/media_model.dart`).

2. **Edit/normalize prior to upload:**
   - Editor: `b_smart/lib/screens/create_edit_preview_screen.dart`
   - Key behaviors:
     - **Post flow** chooses a single fixed “post frame aspect” for the whole post (including carousels) using `_postFrameAspect()` and `_autoPostAspectFor(...)`.
     - **Reel flow** locks the frame to `9:16`.
     - **Cropping** is implemented as *a file rewrite*: it computes a crop rect and writes a cropped image file.
     - **Text/sticker overlays** can be composited into the final raster (post flow for images with overlays).
     - **Filter/adjustments** can be baked into the output image file (post flow images).

3. **Upload:**
   - Upload wrapper: `b_smart/lib/api/upload_api.dart`
   - Under the hood: multipart HTTP in `b_smart/lib/api/api_client.dart` (`multipartPost`, `multipartPostBytes`, `multipartPostManyBytes`).
   - Typical form field is `file` (see `UploadApi`).

4. **Create post (record in backend DB):**
   - REST wrapper: `b_smart/lib/api/posts_api.dart` (`createPost` → `POST /api/posts`)
   - The media list is sent in the body as `media: [{fileName, fileUrl?, ratio, filter, type, adjustments?, thumbnails?, crop_settings?}]`
   - For reels: `b_smart/lib/api/reels_api.dart` creates reels at `POST /api/posts/reels`.

5. **Feed fetch + normalization:**
   - Feed object parsing: `b_smart/lib/models/feed_post_model.dart` (`FeedPost.fromJson`)
   - URL normalization: `b_smart/lib/utils/url_helper.dart` (`normalizeUrl`, `absoluteUrl`)
   - Feed list orchestration: `b_smart/lib/services/feed_service.dart` (contains both dummy feed generation and backend fetch glue).

6. **Rendering:**
   - Feed card: `b_smart/lib/widgets/post_card.dart`
   - Media element: `b_smart/lib/widgets/dynamic_media_widget.dart`
   - Aspect ratio stabilization cache: `b_smart/lib/services/media_aspect_cache.dart`
   - Defensive image decoding: `b_smart/lib/widgets/safe_network_image.dart`
   - Expanded post modal: `b_smart/lib/widgets/post_detail_modal.dart` (uses different “contain” rules vs feed).

### 1.2 End-to-end flow (reels)

```text
Gallery/Picker
→ Edit preview (Reel mode frame fixed at 9:16; video trim window; optional multi-clip timeline)
→ Upload video (bytes)
→ Upload thumbnail (optional; can be generated from a video frame)
→ Create Reel via /posts/reels with media schema (video_meta + thumbnails + crop_settings)
→ Reels feed rendering (thumbnail-first; active reel plays)
```

Key files:
- Editor: `b_smart/lib/screens/create_edit_preview_screen.dart` (reel frame logic)
- Details + publish: `b_smart/lib/screens/create_reel_details_screen.dart` (upload + payload)
- Upload endpoints: `b_smart/lib/api/upload_api.dart`
- Reels endpoint wrapper: `b_smart/lib/api/reels_api.dart`

### 1.3 Backend lifecycle / queues / workers

From this repo we can assert:
- The client uploads raw media and (sometimes) thumbnails via `POST /api/upload` and `POST /api/upload/thumbnail`. See `b_smart/lib/api/upload_api.dart:16`.
- Posts/reels are created via `POST /api/posts` and `POST /api/posts/reels`. See `b_smart/lib/api/posts_api.dart` and `b_smart/lib/api/reels_api.dart`.

What we **cannot** assert from this repo:
- Whether the backend runs any async worker pipeline (queues, jobs) for resizing, smart cropping, moderation, or CDN variant generation.
- Which storage provider (S3/GCS/local) is used.
- Which derivative sizes are generated and how URLs encode variants.

This doc therefore treats “processing lifecycle” on the backend as a **contract**: the backend is expected to return stable `fileUrl` and (ideally) `aspectRatio` and `thumbnailUrl`.

---

## 2) Image Upload Architecture

### 2.1 Upload endpoints (client-side)

**Upload API wrapper**: `b_smart/lib/api/upload_api.dart`

- File upload:
  - Path: `POST /api/upload` (or `/upload` when `baseUrl` already ends with `/api`)
  - Method: `UploadApi.uploadFile(...)` / `UploadApi.uploadFileBytes(...)`
  - Form field: `file`
  - Returns: `{ fileName, fileUrl }` (client expects these keys; it also tolerates backend returning `url`/`filename` in some flows).
  - Reference: `b_smart/lib/api/upload_api.dart:16`

- Thumbnail upload (reels):
  - Path: `POST /api/upload/thumbnail`
  - Method: `UploadApi.uploadThumbnailBytes(...)`
  - Returns: `{ thumbnails: [...] }`
  - Reference: `b_smart/lib/api/upload_api.dart:23`

- Avatar upload (cropped avatars):
  - Path: `POST /api/upload/avatar`
  - Method: `UploadApi.uploadAvatarBytes(...)`
  - Returns: `{ avatar_url }` or `{ url }`
  - Reference: `b_smart/lib/api/upload_api.dart:30`

Other upload surfaces (not feed posts, but relevant to “media system”):
- Stories: `POST /api/stories/upload` via `b_smart/lib/api/stories_api.dart:33`
- Chat media: `POST /chat/conversations/:id/media` via `b_smart/lib/api/chat_api.dart:220`
- Chat voice: `POST /chat/conversations/:id/voice` via `b_smart/lib/api/chat_api.dart:244`

### 2.2 Accepted formats (client-declared content types)

The multipart client assigns `Content-Type` based on extension via `ApiClient._contentTypeForFilename(...)`:

- Images: `.jpg/.jpeg` → `image/jpeg`, `.png` → `image/png`, `.gif` → `image/gif`
- Video: `.mp4` → `video/mp4`, `.mov` → `video/quicktime`
- Audio: `.aac`, `.m4a`, `.mp3`, `.wav`, `.ogg/.oga`

Reference: `b_smart/lib/api/api_client.dart:385`

### 2.3 Validation and pre-upload processing (client)

**Video duration validation (60s cap):**
- `CreateUploadScreen` validates selection using `CreateService.validateMedia(...)` (max 60s) before continuing.
- Reference: `b_smart/lib/services/create_service.dart` and the callsite in `b_smart/lib/screens/create_upload_screen.dart` (selection validation loop).

**Image compression (posts):**
- In `CreatePostDetailsScreen`, images are converted/compressed to JPEG:
  - Initial quality: 85
  - If output size exceeds 4MB, recompress at quality 70
- Reference: `b_smart/lib/screens/create_post_details_screen.dart:244` (inside `_proceedWithPosting`).

**Thumbnail generation (reels):**
- `CreateReelDetailsScreen` may:
  - Accept a user-selected thumbnail from gallery, OR
  - Pick a thumbnail from a specific video frame, OR
  - Fallback to generating a deterministic frame from the selected trim window midpoint using `video_thumbnail`.
- Reference: `b_smart/lib/screens/create_reel_details_screen.dart:144` and `_uploadThumbnailForVideo(...)`.

### 2.4 Metadata extraction: width/height, orientation, aspect ratio

This app uses **two different sources** for width/height/aspect ratio:

1) **Local file pixel sizes during editing (pre-upload)**:
- `CreateEditPreviewScreen` reads the decoded pixel size for images to drive cropping math and “post frame” choice.
- It computes aspect ratio and then normalizes it via `_autoPostAspectFor(...)` / `_clampInstagramPostAspect(...)`.
- Reference: `b_smart/lib/screens/create_edit_preview_screen.dart:477` and `b_smart/lib/screens/create_edit_preview_screen.dart:549`.

2) **Remote image decode at render time (post-upload)**:
- The feed renderer does not rely solely on backend-provided `aspectRatio`.
- `MediaAspectCache.resolveImageRatio(url)` resolves the decoded image size once using an `ImageStreamListener`, clamps it, and caches it.
- Reference: `b_smart/lib/services/media_aspect_cache.dart:21`

**Orientation detection**
- There is no explicit “EXIF orientation” correction logic in the client code shown here.
- Orientation is implicitly handled by platform decoders (Flutter image codecs), and by aspect ratio math (`width/height`).

---

## 3) Layout System (most important)

This app’s “layout system” is implemented primarily as **aspect ratio normalization + a small number of rendering templates**. Unlike Instagram’s multi-tile grids inside a single post, the feed post renderer uses:

- **Single media**: size is derived from the media’s resolved aspect ratio at runtime.
- **Carousel**: a single **shared** aspect ratio frame is chosen for the entire carousel, and each page fills that frame.
- **Reels**: `9:16` dominates the editor; feed displays video using resolved aspect ratio (thumbnail-based when inactive).

### 3.1 Canonical “frame types” used by the app

Below are the fixed “frames” that the code actually enforces (either as hard clamps or as default-aspect buckets).

#### POST_PORTRAIT_4_5 (a.k.a. “min portrait” for posts)

- Ratio: `4:5` = `0.8`
- Used in:
  - Post editor normalization: `minPortrait = 4/5` in `_autoPostAspectFor(...)`
  - Post editor clamp: `_clampInstagramPostAspect(...)` clamps to min `4/5`
- Trigger:
  - If the underlying media aspect is **< 0.8**, or in `[0.8, 0.95)`
- References:
  - `b_smart/lib/screens/create_edit_preview_screen.dart:477`
  - `b_smart/lib/screens/create_edit_preview_screen.dart:549`

**Why it exists:** feed “normalization” to avoid ultra-tall media taking over the feed height, while still allowing portrait.

#### POST_SQUARE_1_1

- Ratio: `1.0`
- Used in:
  - Editor bucketing: if aspect is within `0.95..1.05`, normalize to `1.0`
  - Special-case: if current media is a square-ish **video**, keep `1.0` (tolerance `±0.05`)
- Trigger:
  - `0.95 <= aspect <= 1.05` (bucket), OR
  - square-ish video in post flow
- References:
  - Bucket: `b_smart/lib/screens/create_edit_preview_screen.dart:549`
  - Video special-case: `b_smart/lib/screens/create_edit_preview_screen.dart:503`

#### POST_LANDSCAPE_UP_TO_1_91 (a.k.a. “max landscape”)

- Ratio: max `1.91:1`
- Used in:
  - Editor clamp: `_clampInstagramPostAspect(...)` clamps max to `1.91`
  - Render-time clamp: `MediaAspectCache._clamp(...)` clamps max to `1.91`
- Trigger:
  - Any aspect > `1.91` is clamped down to `1.91`
- References:
  - Editor: `b_smart/lib/screens/create_edit_preview_screen.dart:477`
  - Render cache: `b_smart/lib/services/media_aspect_cache.dart:45`

#### REEL_FRAME_9_16

- Ratio: `9:16` = `0.5625`
- Used in:
  - Editor: reel flow locks edit frame to `9/16`
  - Aspect cache clamp: minPortrait set to `9/16` to allow reel/story portrait thumbs
- Trigger:
  - Editor: `isReelFlow`
  - Renderer: any resolved ratio below `9/16` is clamped up
- References:
  - Editor lock: `b_smart/lib/screens/create_edit_preview_screen.dart:531`
  - Render clamp min: `b_smart/lib/services/media_aspect_cache.dart:49`

#### FEED_FALLBACK_4_5

- Ratio: `4:5` default used by feed card when backend does not provide an aspect ratio.
- Trigger:
  - When `FeedPost.aspectRatio == null`, `PostCard` uses `4/5` for carousel framing and for empty media placeholder blocks.
- Reference: `b_smart/lib/widgets/post_card.dart:226`

#### DETAIL_MODAL_FLEX (0.35..4.0 clamp, contain)

The expanded post modal uses a different set of constraints:

- Aspect clamp: `0.35..4.0`
- Fit: `BoxFit.contain` for images
- Goal: show as much as possible without aggressive feed-style cropping
- References:
  - Clamp: `b_smart/lib/widgets/post_detail_modal.dart:912`
  - `BoxFit.contain`: `b_smart/lib/widgets/post_detail_modal.dart:997`

### 3.2 Media count support and templates

**Single-media posts**
- Template: `PostCard` renders a `DynamicMediaWidget` directly (no outer `AspectRatio` wrapper).
- The actual displayed height in the feed depends on `DynamicMediaWidget`’s internal `AspectRatio(aspect)` which updates once the ratio resolves.
- Reference: `b_smart/lib/widgets/post_card.dart:271`

**Carousel posts**
- Template: `PostCard` wraps `PageView.builder` in an `AspectRatio(aspect)` frame.
- That aspect is `post.aspectRatio ?? 4/5` and is shared for the entire carousel.
- Each page still uses `DynamicMediaWidget`, but it is constrained inside the frame.
- Reference: `b_smart/lib/widgets/post_card.dart:304`

**Reels/videos in feed**
- `DynamicMediaWidget` uses thumbnail-first rendering:
  - Always paints thumbnail (`SafeNetworkImage`).
  - When active, it attaches a controller via `VideoPool` and fades the video in over the thumbnail.
- Reference: `b_smart/lib/widgets/dynamic_media_widget.dart:293` onwards.

### 3.3 Responsive behavior (mobile vs desktop)

The primary “responsive split” in the media system is:

- Feed cards are column-based and rely on device width; the media frame scales naturally with available width.
- Expanded view uses an explicit breakpoint in `PostDetailModal`:
  - Mobile: image column above details column
  - Desktop/tablet: image fixed-width (400) + details expanded
- Reference: `b_smart/lib/widgets/post_detail_modal.dart:871`

---

## 4) Layout Decision Engine

There are **two** layout decision engines:

1) **Editor-time “post frame” selection** (decides the canonical post frame aspect for uploads and carousels).
2) **Render-time ratio resolution + clamp** (stabilizes layout in the feed when backend aspectRatio is missing/wrong).

### 4.1 Editor-time decision engine (CreateEditPreviewScreen)

Key functions:
- `_postFrameAspect()` picks the active frame aspect for the editor’s preview.
  - Reference: `b_smart/lib/screens/create_edit_preview_screen.dart:484`
- `_autoPostAspectFor(aspect)` applies bucketing rules.
  - Reference: `b_smart/lib/screens/create_edit_preview_screen.dart:549`

**Bucketing rules (exact thresholds)**

From `_autoPostAspectFor(...)`:
- `minPortrait = 4/5 = 0.8`
- `maxLandscape = 1.91`
- Buckets:
  - `< 0.8` → `0.8`
  - `0.8 <= aspect < 0.95` → `0.8`
  - `0.95 <= aspect <= 1.05` → `1.0`
  - `1.05 < aspect <= 1.91` → keep `aspect` as-is
  - `> 1.91` → `1.91`

**Pseudocode (mirrors implementation)**

```pseudo
function autoPostAspectFor(aspect):
  if aspect <= 0 or NaN: return 1.0
  if aspect < 0.8: return 0.8
  if 0.8 <= aspect < 0.95: return 0.8
  if 0.95 <= aspect <= 1.05: return 1.0
  if 1.05 < aspect <= 1.91: return aspect
  return 1.91
```

**Carousel/video interactions (shared frame)**

In post flow, the editor attempts to maintain one shared “post aspect”:
- If current media is a square-ish video (`abs(aspect - 1.0) < 0.05`), keep `1:1`.
- If there is any image in the carousel and current is video, default the frame to `4:5` until an image sets the fixed aspect.
- The chosen aspect is memoized into `_postFixedAspect`.

Reference: `b_smart/lib/screens/create_edit_preview_screen.dart:502`

### 4.2 Render-time decision engine (MediaAspectCache + DynamicMediaWidget)

**Goal:** prevent feed “jumping” and broken framing when the backend does not provide a reliable `aspectRatio` (or when media URLs are inconsistent).

Key components:
- `MediaAspectCache` (global in-memory cache): `b_smart/lib/services/media_aspect_cache.dart`
- `DynamicMediaWidget` (per-media renderer): `b_smart/lib/widgets/dynamic_media_widget.dart`
- Feed host that passes initial hints: `PostCard` → `DynamicMediaWidget(initialAspectRatio: post.aspectRatio)` (`b_smart/lib/widgets/post_card.dart:279`)

**Resolution algorithm**

For images:
1. Try cache hit (`MediaAspectCache.get(url)`).
2. If missing, decode the network image once via `CachedNetworkImageProvider(...).resolve(...)`.
3. Clamp the decoded aspect ratio to a safe range and cache it.

Clamp range (exact constants):
- `minPortrait = 9/16 = 0.5625`
- `maxLandscape = 1.91`
- Reference: `b_smart/lib/services/media_aspect_cache.dart:45`

For videos:
- `DynamicMediaWidget` uses:
  - the provided `initialAspectRatio` hint (from backend) if available, else
  - the thumbnail ratio if a thumbnail is present, else
  - defaults to `9/16` for videos.
- When a video controller becomes available, it updates the aspect ratio to `controller.value.aspectRatio`.
- References:
  - Ratio priming: `b_smart/lib/widgets/dynamic_media_widget.dart:390`
  - Video attach + aspect update: `b_smart/lib/widgets/dynamic_media_widget.dart:417`

**Pseudocode**

```pseudo
function resolveImageRatio(url):
  if cache[url] exists: return cache[url]
  (w,h) = decodeImage(url)
  r = w/h
  r = clamp(r, 9/16, 1.91)
  cache[url] = r
  return r
```

**Why there are two clamp regimes**

- Editor clamp (posts): min portrait is `4/5` (0.8). This is an Instagram-like constraint for *posts*.
- Render clamp (feed): min portrait is `9/16` (0.5625). This exists to allow reel/story-like portrait thumbs without forcing 4:5.
- This means extremely tall images may be “normalized” differently depending on whether you’re in the editor or just rendering a remote URL.

---

## 5) Cropping System

### 5.1 Where cropping happens

There are two “cropping” concepts in this app:

1) **Editor viewport crop (pre-upload, destructive)**:
   - For post flow images, the crop is applied by **writing a new image file** and swapping `MediaItem.filePath` to point at it.
   - This happens in `CreateEditPreviewScreen._proceedToPostDetails()` when `cropRect != null`.
   - Reference: `b_smart/lib/screens/create_edit_preview_screen.dart:2325`

2) **Render-time crop (non-destructive)**
   - The feed uses `BoxFit.cover` for images (`DynamicMediaWidget` → `SafeNetworkImage(... fit: BoxFit.cover)`).
   - That is a *visual crop only*; it does not change the source asset.
   - Reference: `b_smart/lib/widgets/dynamic_media_widget.dart:528`

There is **no “smart crop” / object-aware crop** logic in this repo. Cropping is either:
- user-driven (pan/zoom in editor), or
- center/cover behavior from `BoxFit.cover`.

### 5.2 Editor crop math (exact)

The editor implements a custom zoom/pan crop for images. At “Next” time, it computes the crop rect in source-pixel coordinates from:
- current drawn scale `s`
- current drawn offset `o`
- viewport size `(vW, vH)`
- original image pixel size `(imgW, imgH)`

Implementation (mirrors the code in `_proceedToPostDetails()`):

```pseudo
left   = clamp((-o.dx / s),            0, imgW)
top    = clamp((-o.dy / s),            0, imgH)
right  = clamp(((vW - o.dx) / s),      0, imgW)
bottom = clamp(((vH - o.dy) / s),      0, imgH)
cropRect = Rect(left, top, right, bottom)
```

Reference: `b_smart/lib/screens/create_edit_preview_screen.dart:2331`

Once `cropRect` is computed:
- Aspect is normalized via `_clampInstagramPostAspect(cropW/cropH)` (clamp to `0.8..1.91`)
- Cropped file is written via `_writeCroppedImageFile(...)` (uses `dart:ui` decode + pixel crop + encode)
- The post continues with `MediaItem.filePath = croppedPath`

### 5.3 Crop persistence in backend payloads

**Posts**
- In the “post details” publish flow (`CreatePostDetailsScreen`), the media payload includes:
  - `fileName`, optional `fileUrl`, `ratio` (currently hardcoded to `1.0`), and `filter`.
- It does **not** send a structured `crop_settings` for posts in this screen.
- Reference: `b_smart/lib/screens/create_post_details_screen.dart:259`

**Reels**
- The reel payload explicitly sends `crop_settings` (mode `original`, aspect_ratio `original`, zoom 1, x/y 0).
- Reference: `b_smart/lib/screens/create_reel_details_screen.dart:356`

**Ads**
- The advertiser flow builds a `crop_settings` object when uploading media (separate from the main feed post flow).
- Reference: `b_smart/lib/screens/advertiser_create_ad_screen.dart` (search for `crop_settings`).

### 5.4 Preview vs expanded rendering

- Feed preview images: `BoxFit.cover` (aggressive crop to fill frame).
  - Reference: `b_smart/lib/widgets/dynamic_media_widget.dart:528`
- Expanded modal images: `BoxFit.contain` (letterbox/pillarbox allowed).
  - Reference: `b_smart/lib/widgets/post_detail_modal.dart:997`

---

## 6) Frontend Rendering Architecture

### 6.1 Feed renderer and composition

**Primary feed unit**: `PostCard` (`b_smart/lib/widgets/post_card.dart`)

Key responsibilities:
- Chooses between tweet rendering vs media post rendering.
- Determines whether a post is single vs carousel.
- Owns the `PageController` for carousel swiping.
- Controls “active/inactive” for videos via:
  - `isActive` boolean from parent (center-of-screen detection in feed list)
  - `activeIdListenable` (optional) to coordinate activation at a higher level

Media rendering pathways:
- Single: `DynamicMediaWidget(id: post.id, url: mediaUrls.first, ...)`
- Carousel: `AspectRatio(aspectRatio: post.aspectRatio ?? 4/5) → PageView.builder → DynamicMediaWidget(id: '${post.id}_$i', ...)`

Reference: `b_smart/lib/widgets/post_card.dart:216`

### 6.2 Media component: DynamicMediaWidget

File: `b_smart/lib/widgets/dynamic_media_widget.dart`

Responsibilities:
- Resolve and cache aspect ratio **once** (per URL) via `MediaAspectCache`.
- For images:
  - Render via `SafeNetworkImage` with `BoxFit.cover`.
- For videos:
  - Show thumbnail/poster first.
  - Only attach video playback when the item is active (`isActive == true`).
  - Use `VideoPool` to reuse controllers and avoid rebuffering/black frames.
  - Apply filter/adjustments overlays for videos via `ColorFiltered` matrix stacking.

Activation and playback:
- When becoming active, `_ensureVideo()` calls `VideoPool.instance.attach(id, url)` and stores the resulting `VideoPlayerController`.
- When becoming inactive, it pauses via `VideoPool.instance.pauseIf(id)` but keeps the last frame visible.

### 6.3 Defensive decoding + format handling: SafeNetworkImage

File: `b_smart/lib/widgets/safe_network_image.dart`

Problems it solves:
- Backend/CDN may sometimes return **HTML** or **JSON** (403/redirect) to an image request.
- Some formats might be unsupported (AVIF/HEIC) on certain platforms.
- Some “thumbnails” might actually be video URLs (`.mp4`, `.m3u8`).

Heuristics:
- Extension indicates SVG → `SvgPicture.network`.
- Extension indicates unsupported/video → return error widget.
- Otherwise probe (`HEAD` → ranged `GET`) and infer from `Content-Type` or magic bytes.

### 6.4 Aspect-ratio handling (where it lives)

There are 3 layers of aspect ratio logic:

1) **Feed container framing** (carousel only): `AspectRatio(post.aspectRatio ?? 4/5)` in `PostCard`.
2) **Media widget framing** (all media): `AspectRatio(_ratio ?? fallback)` inside `DynamicMediaWidget`.
3) **Expanded modal sizing**: `PostDetailModal` computes a centered `SizedBox` within constraints and uses `BoxFit.contain` for images.

### 6.5 Lazy loading / scroll performance

The media system is designed for scrolling performance:
- `DynamicMediaWidget` defers video attachment unless active.
- `PostCard` wraps media widgets with `RepaintBoundary`.
- `cached_network_image` provides caching; `SafeNetworkImage` reduces decode crashes/noise for bad payloads.

---

## 7) Backend Processing (as visible from this repo)

### 7.1 What the client assumes the backend does

From the contract implied by upload + feed parsing:
- Accept multipart uploads and return `fileName` and a retrievable URL (`fileUrl` or `url`).
- Serve media under `/uploads/...` or `/api/uploads/...` patterns (see URL normalization).
- For reels/videos: support thumbnail uploads returning a `thumbnails` array.
- For feed posts: ideally provide `aspectRatio` and `thumbnailUrl` for videos/reels.

### 7.2 URL/storage normalization rules (client)

All remote media URLs flow through `UrlHelper.normalizeUrl(...)` / `UrlHelper.absoluteUrl(...)` (`b_smart/lib/utils/url_helper.dart`):

- If a URL is relative and does not contain `uploads/` or `api/`, the helper prepends `uploads/`.
  - Reference: `b_smart/lib/utils/url_helper.dart:161`
- It then attaches the API origin (`ApiConfig.baseUrl`) to create an absolute URL.
- It avoids double-prefixing `/api/api/...` when `baseUrl` already contains `/api`.

### 7.3 Generated derivative sizes / CDN variants

This client does not request explicit width-based variants (no `?w=` or `srcset` equivalent). Therefore:
- Any resizing/thumbnailing strategy must be encoded into the URLs returned by the backend/CDN, or handled transparently server-side.

The only explicit “derivative generation” performed on the client is:
- re-encoding images (crop + filters + overlays) into new local files before upload, and
- generating reel thumbnails via `video_thumbnail` prior to upload.

---

## 8) Feed Constraints

### 8.1 Why aspect ratios are clamped

The code enforces a maximum landscape ratio of `1.91` in both editor and renderer, and uses minimum portrait of:
- `0.8` (post editor)
- `0.5625` (render-time cache)

This prevents extreme media from destabilizing card heights and scroll performance.

### 8.2 Why the carousel uses a single shared aspect

The editor and feed renderer treat a carousel as a single frame to avoid height changes while swiping.

Implemented by:
- Editor selecting `_postFixedAspect` (`CreateEditPreviewScreen`), and
- Feed using `post.aspectRatio` or fallback `4/5` as a single `AspectRatio` wrapper (`PostCard`).

---

## 9) Database Structure / API Schema Surface (as implied by models)

### 9.1 Feed post object (client expectations)

`FeedPost.fromJson` expects a “post-like” object with (at minimum):

```json
{
  "id": "string",
  "userId": "string",
  "username": "string",
  "mediaType": "image|video|carousel|reel",
  "media": [
    {
      "fileUrl": "string",
      "fileName": "string",
      "filter": "string|{...}",
      "adjustments": { "brightness": 0, "contrast": 0, "saturation": 0, "temperature": 0, "fade": 0 }
    }
  ],
  "thumbnailUrl": "string",
  "aspectRatio": "1.0",
  "caption": "string",
  "hashtags": ["#tag"],
  "createdAt": "ISO-8601"
}
```

Important parsing behaviors:
- Media URLs are extracted from either `mediaUrls` or `media`, and tolerate key aliases (`fileUrl`, `file_url`, `url`, `path`, etc.).
- `aspectRatio` is parsed only from `json['aspectRatio']`. If the backend sends `aspect_ratio`, the current parser won’t read it.
- Reference: `b_smart/lib/models/feed_post_model.dart:282`

### 9.2 Create post payload (client sends)

`PostsApi.createPost(...)` sends `media[]` plus metadata (caption, tags, people tags, and toggles). Reference: `b_smart/lib/api/posts_api.dart:27`.

### 9.3 Create reel payload (client sends)

Reels include:
- `video_meta` (duration + trim window + `thumbnail_time`)
- `timing_window`
- `thumbnails` (from `/upload/thumbnail`)
- `crop_settings`

Reference: `b_smart/lib/screens/create_reel_details_screen.dart:333`.

---

## 10) File/Folder Map

### Picking + editor
- `b_smart/lib/screens/create_upload_screen.dart`
- `b_smart/lib/screens/create_edit_preview_screen.dart`
- `b_smart/lib/models/media_model.dart`

### Publish
- `b_smart/lib/api/upload_api.dart`
- `b_smart/lib/api/api_client.dart`
- `b_smart/lib/api/posts_api.dart`
- `b_smart/lib/screens/create_post_details_screen.dart`
- `b_smart/lib/api/reels_api.dart`
- `b_smart/lib/screens/create_reel_details_screen.dart`
- `b_smart/lib/api/stories_api.dart`
- `b_smart/lib/api/chat_api.dart`

### Feed rendering
- `b_smart/lib/models/feed_post_model.dart`
- `b_smart/lib/widgets/post_card.dart`
- `b_smart/lib/widgets/dynamic_media_widget.dart`
- `b_smart/lib/services/media_aspect_cache.dart`
- `b_smart/lib/widgets/safe_network_image.dart`
- `b_smart/lib/utils/url_helper.dart`
- `b_smart/lib/widgets/post_detail_modal.dart`

---

## 11) Known Limitations

1) `CreatePostDetailsScreen` sends `'ratio': 1.0` (likely wrong for many posts). Reference: `b_smart/lib/screens/create_post_details_screen.dart:259`.
2) `FeedPost.fromJson` reads only `aspectRatio` (camelCase) and ignores `aspect_ratio`. Reference: `b_smart/lib/models/feed_post_model.dart:285`.
3) Carousels use a single shared aspect frame; mixed-aspect carousels can show letterboxing/cropping inconsistencies. Reference: `b_smart/lib/widgets/post_card.dart:304`.
4) No smart crop; post crop settings are not persisted as structured metadata in the standard post flow.
5) `SafeNetworkImage` blocks AVIF/HEIC/HEIF and video URLs when used as images; incompatible backend formats will show placeholders. Reference: `b_smart/lib/widgets/safe_network_image.dart:172`.

---

## 12) Architecture Summary

1) Selection: `CreateUploadScreen` builds `MediaItem`s from device assets.
2) Normalization: `CreateEditPreviewScreen` picks a canonical post frame aspect (0.8/1.0/1.91 buckets) and optionally writes new image files for crops/overlays/filters.
3) Upload: `UploadApi` performs multipart upload to `/api/upload` (and `/api/upload/thumbnail` for reel thumbs).
4) Record creation: `PostsApi.createPost` / `ReelsApi.createReel`.
5) Feed rendering: `FeedPost.fromJson` normalizes URLs, and `DynamicMediaWidget` stabilizes aspect ratios using `MediaAspectCache` and renders with `SafeNetworkImage`/`VideoPool`.
