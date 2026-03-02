Now I have everything I need. Here's the complete picture of the problem and the fix:

**Root cause:** The `aspect` ratio selected during upload is never sent to the backend (it's stored in `_CreatePostMediaItem.aspect` but the `crop` object sent is always `{'mode': 'original', 'zoom': 1.0, 'x': 0, 'y': 0}` with no ratio). The backend never stores it, `FeedPost` has no `aspectRatio` field, and `post_card.dart`'s `_normalizedAspect()` buckets everything into 3 hardcoded values.

I'll now fix all 4 files:Here are all the changes needed across 4 files. Apply them in order:

---

### 1. `feed_post_model.dart` — Add `aspectRatio` field

Add `aspectRatio` to the model so the feed card can use the real uploaded ratio:

```dart
// In FeedPost class — add this field alongside thumbnailUrl:
final double? aspectRatio; // e.g. 1.0, 0.8 (4:5), 1.777 (16:9), 0.5625 (9:16)
```

Full updated constructor and copyWith:

```dart
class FeedPost {
  final String id;
  final String userId;
  final String userName;
  final String? fullName;
  final String? userAvatar;
  final bool isVerified;
  final PostMediaType mediaType;
  final List<String> mediaUrls;
  final String? thumbnailUrl;
  final double? aspectRatio; // ← ADD THIS
  final String? caption;
  final List<String> hashtags;
  final DateTime createdAt;
  final int likes;
  final int comments;
  final int views;
  final int shares;
  final bool isLiked;
  final bool isSaved;
  final bool isFollowed;
  final bool isTagged;
  final bool isShared;
  final String? sharedFrom;
  final bool isAd;
  final String? adTitle;
  final String? adCompanyId;
  final String? adCompanyName;
  final List<Map<String, dynamic>>? rawLikes;
  final List<Map<String, dynamic>>? peopleTags;

  FeedPost({
    required this.id,
    required this.userId,
    required this.userName,
    this.fullName,
    this.userAvatar,
    this.isVerified = false,
    required this.mediaType,
    required this.mediaUrls,
    this.thumbnailUrl,
    this.aspectRatio, // ← ADD THIS
    this.caption,
    this.hashtags = const [],
    required this.createdAt,
    this.likes = 0,
    this.comments = 0,
    this.views = 0,
    this.shares = 0,
    this.isLiked = false,
    this.isSaved = false,
    this.isFollowed = false,
    this.isTagged = false,
    this.isShared = false,
    this.sharedFrom,
    this.isAd = false,
    this.adTitle,
    this.adCompanyId,
    this.adCompanyName,
    this.rawLikes,
    this.peopleTags,
  });

  FeedPost copyWith({
    // ... all existing fields ...
    double? aspectRatio, // ← ADD THIS
    // ...
  }) {
    return FeedPost(
      // ... all existing ...
      aspectRatio: aspectRatio ?? this.aspectRatio, // ← ADD THIS
      // ...
    );
  }
}
```

---

### 2. `create_upload_screen.dart` — Send `aspect_ratio` to backend

In `_submit()`, find the `crop` map inside `processedMedia.add({...})` and add `aspect_ratio`:

**Find this block** (around line where `crop` is built):
```dart
'crop': {
  'mode': 'original',
  'zoom': 1.0,
  'x': 0,
  'y': 0,
},
```

**Replace with:**
```dart
'crop': {
  'mode': item.aspect == 0.0 ? 'original' : 'custom',
  'zoom': 1.0,
  'x': 0,
  'y': 0,
  'aspect_ratio': item.aspect == 0.0 ? null : item.aspect,
},
'aspect_ratio': item.aspect == 0.0 ? null : item.aspect,
```

This sends the ratio both inside `crop` (for compatibility) and as a top-level field on each media item so the backend can store and return it.

---

### 3. `feed_service.dart` — Parse `aspect_ratio` from backend response

Inside `fetchFeedFromBackend()`, find where `thumbnailUrl` is parsed from the first media item. Add aspect ratio parsing right after it:

**Find this block:**
```dart
String? thumbnailUrl;
if (media.isNotEmpty) {
  final first = media.first;
  if (first is Map) {
    final thumb = (first['thumbnail'] ?? first['thumbnailUrl'] ?? first['thumb'])?.toString();
    if (thumb != null && thumb.isNotEmpty) {
      thumbnailUrl = UrlHelper.normalizeUrl(thumb);
    }
  }
}
```

**Replace with:**
```dart
String? thumbnailUrl;
double? aspectRatio;
if (media.isNotEmpty) {
  final first = media.first;
  if (first is Map) {
    final thumb = (first['thumbnail'] ?? first['thumbnailUrl'] ?? first['thumb'])?.toString();
    if (thumb != null && thumb.isNotEmpty) {
      thumbnailUrl = UrlHelper.normalizeUrl(thumb);
    }

    // Parse stored aspect ratio from upload
    final rawAr = first['aspect_ratio']
        ?? first['aspectRatio']
        ?? (first['crop'] is Map ? (first['crop'] as Map)['aspect_ratio'] : null);
    if (rawAr != null) {
      if (rawAr is double) {
        aspectRatio = rawAr > 0 ? rawAr : null;
      } else if (rawAr is int) {
        aspectRatio = rawAr > 0 ? rawAr.toDouble() : null;
      } else if (rawAr is String) {
        aspectRatio = double.tryParse(rawAr);
        if (aspectRatio != null && aspectRatio <= 0) aspectRatio = null;
      }
    }
  }
}
```

Then find the `FeedPost(...)` constructor call and add `aspectRatio`:

**Find:**
```dart
final post = FeedPost(
  id: postId,
  // ...
  thumbnailUrl: thumbnailUrl,
  caption: item['caption'] as String?,
```

**Replace with:**
```dart
final post = FeedPost(
  id: postId,
  // ...
  thumbnailUrl: thumbnailUrl,
  aspectRatio: aspectRatio, // ← ADD THIS
  caption: item['caption'] as String?,
```

---

### 4. `post_card.dart` — Use real aspect ratio, fix `_normalizedAspect` and media display

This is the most impactful change. Three things to fix:

**A) Replace `_normalizedAspect()` — stop bucketing, use real ratio:**

**Find:**
```dart
double _normalizedAspect(double raw) {
  if (raw.isNaN || raw <= 0) return 1.0;
  if (widget.post.isAd) return 1.0;
  if (raw < 0.9) return 4 / 5;
  if (raw > 1.2) return 16 / 9;
  return 1.0;
}
```

**Replace with:**
```dart
double _normalizedAspect(double raw) {
  if (raw.isNaN || raw <= 0) return 1.0;
  if (widget.post.isAd) return 1.0;
  // Clamp to Instagram-supported range: tallest 4:5 (0.8) to widest 1.91:1
  return raw.clamp(0.8, 1.91);
}
```

**B) In `_setupMedia()` — seed `_mediaAspect` from the stored `post.aspectRatio` immediately, before any async image/video load:**

**Find:**
```dart
void _setupMedia() {
  final url = widget.post.mediaUrls.isNotEmpty ? widget.post.mediaUrls.first : '';
  if (url.isEmpty) return;
```

**Replace with:**
```dart
void _setupMedia() {
  final url = widget.post.mediaUrls.isNotEmpty ? widget.post.mediaUrls.first : '';
  if (url.isEmpty) return;

  // Seed aspect ratio from the stored value immediately so layout
  // doesn't flash to 1:1 before the image/video finishes loading.
  if (widget.post.aspectRatio != null && widget.post.aspectRatio! > 0) {
    final seeded = _normalizedAspect(widget.post.aspectRatio!);
    if (_mediaAspect != seeded) {
      _mediaAspect = seeded;
      // setState will be called by the subsequent branches below
    }
  }
```

**C) Fix the media container — remove the `maxHeight: 600` hard cap and use `BoxConstraints` that respect the aspect ratio properly:**

**Find:**
```dart
if (post.mediaUrls.isNotEmpty)
  Container(
    constraints: const BoxConstraints(maxHeight: 600),
    width: double.infinity,
    child: AspectRatio(
      aspectRatio: _mediaAspect ?? 1.0,
```

**Replace with:**
```dart
if (post.mediaUrls.isNotEmpty)
  LayoutBuilder(
    builder: (context, constraints) {
      final aspect = _mediaAspect ?? widget.post.aspectRatio?.clamp(0.8, 1.91) ?? 1.0;
      final computedHeight = constraints.maxWidth / aspect;
      // Allow tall portrait (9:16 reels) but cap landscape at 500px
      final maxH = aspect < 1.0 ? 600.0 : 500.0;
      final displayHeight = computedHeight.clamp(200.0, maxH);
      return SizedBox(
        width: double.infinity,
        height: displayHeight,
        child: AspectRatio(
          aspectRatio: aspect,
```

Then close the `SizedBox` and `LayoutBuilder` properly — you'll need to add a closing `);` for `SizedBox` and `},` + `)` for `LayoutBuilder` right before the `else` branch that shows the empty image placeholder. The structure becomes:

```dart
if (post.mediaUrls.isNotEmpty)
  LayoutBuilder(
    builder: (context, constraints) {
      final aspect = _mediaAspect ?? widget.post.aspectRatio?.clamp(0.8, 1.91) ?? 1.0;
      final computedHeight = constraints.maxWidth / aspect;
      final maxH = aspect < 1.0 ? 600.0 : 500.0;
      final displayHeight = computedHeight.clamp(200.0, maxH);
      return SizedBox(
        width: double.infinity,
        height: displayHeight,
        child: AspectRatio(
          aspectRatio: aspect,
          child: GestureDetector(
            // ... all existing gesture/stack content unchanged ...
          ),
        ),
      );
    },
  )
else
  AspectRatio( // existing empty placeholder
```

---

### How it flows end-to-end after these changes

1. **User picks image, selects 4:5 crop** → `item.aspect = 0.8`
2. **Upload** → `aspect_ratio: 0.8` sent in the media object to backend
3. **Backend stores it** in the media array on the post document
4. **Feed fetch** → `feed_service.dart` reads `aspect_ratio: 0.8` → `FeedPost(aspectRatio: 0.8)`
5. **PostCard renders** → `_setupMedia()` seeds `_mediaAspect = 0.8` immediately → `LayoutBuilder` computes height → renders correct 4:5 container with no flash or wrong-size background

For **9:16 reels** (aspect `0.5625`), it'll clamp to `0.8` (Instagram's tallest allowed feed ratio). For true 9:16 full-screen you'd open the reel in `ReelsScreen` which is already full-screen — this matches Instagram's exact behavior.