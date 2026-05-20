I have a Flutter app with a complex Instagram-like reel editor. I want to REPLACE the existing 
reel editor UI with a minimal, simple version. Do NOT touch pubspec.yaml. Do NOT delete any 
files — instead, rewrite their contents. Do NOT change anything outside the reel editor flow 
(reels_screen.dart, home screen, nav, etc.).

---

## CONTEXT: File Structure

The reel editor lives in:
  lib/screens/reel_editor/
    - reel_editor_screen.dart         ← MAIN FILE, rewrite this
    - reel_timeline_strip.dart        ← simplify drastically
    - reel_clip_context_menu.dart     ← simplify to delete-only
    - reel_audio_picker_screen.dart   ← keep but simplify UI
    - reel_caption_screen.dart        ← stub out (empty/disabled)
    - reel_transition_picker.dart     ← stub out (empty/disabled)
    - reel_voice_recorder_sheet.dart  ← stub out (empty/disabled)
    - reel_volume_panel.dart          ← stub out (empty/disabled)
    - reel_overlay_duration_sheet.dart← stub out (empty/disabled)
    - reel_export_service.dart        ← DO NOT TOUCH
    - reel_draft_service.dart         ← DO NOT TOUCH

  lib/screens/create_reel_details_screen.dart ← simplify this too

  lib/features/reel_timeline/         ← DO NOT TOUCH these files
  lib/instagram_text_editor/          ← DO NOT TOUCH these files
  lib/instagram_overlay/              ← DO NOT TOUCH these files

---

## GOAL: New Minimal Reel Editor

The new editor must feel like a simple, clean video composer — not Instagram. Think of it like 
a basic TikTok draft screen. Dark background (#000000). Minimal chrome. Only what's necessary.

---

## SCREEN 1: ReelEditorScreen (rewrite reel_editor_screen.dart)

### Layout (top to bottom):
  
  [TOP BAR]
    - Left: back chevron (white, circular semi-transparent button, same as current)
    - Center: nothing (or app name small text)
    - Right: "Next →" pill button (white background, black text, rounded, NOT blue)

  [VIDEO PREVIEW — 70% of screen height]
    - Full width, black background
    - Shows the currently active clip (video plays, image shows statically)
    - Tap anywhere on preview → toggle play/pause
    - No text overlays, no sticker overlays, no color matrix, no filter UI on preview
    - Small centered play icon (white, semi-transparent circle) shown only when paused
    - No delete zone, no draggable overlays

  [BOTTOM PANEL — remaining 30%]
    Background: #111111

    Row 1 — CLIP STRIP (height: 72px)
      - Horizontal scrollable list of clip thumbnails
      - Each thumbnail: rounded rect, 56x56px, shows video frame or image
      - Active clip has white border (2px)
      - Tap a clip → set as active, seek preview to start of that clip
      - Long press a clip → shows a small bottom sheet with ONLY two options: 
          "Delete clip" (red) and "Cancel" (white). Nothing else.
      - At the END of the clip strip: a "+" add button (same size, dashed border, white plus icon)
        Tap → image_picker pickMultipleMedia() to add more clips
      - No timeline ruler, no playhead scrub bar, no zoom, no reorder drag, 
        no transition pips, no trim handles

    Row 2 — PLAYBACK BAR (height: 40px)  
      - Left: play/pause icon button (white)
      - Center: time display "0:03 / 0:15" (white, monospace style)
      - Right: mute/unmute icon button (white)
      - Nothing else in this row

    Row 3 — TOOL BAR (height: 56px)
      - Horizontal scrollable row of simple icon+label buttons
      - Each button: icon on top, label below, white color, no background/border
      - Spacing: even, ~72px wide each
      - Buttons (in order):
          1. "Text"     icon: Icons.title
          2. "Music"    icon: Icons.music_note
          3. "Filter"   icon: Icons.auto_fix_high
          (Only these 3. Remove: Sticker, Overlay, Caption, Photo, Effects, Speed, Timer, Voice)
      
      Behavior:
        "Text" tap → show a simple bottom sheet:
            - TextField (white text, black bg, autofocused)
            - "Done" button
            - On done: add a single centered text overlay on the preview 
              (non-draggable, just displayed centered at bottom-third of preview)
            - Only ONE text allowed at a time (replace previous)
            - Text shown as white text with semi-transparent black rounded background
            - No font picker, no color picker, no size picker, no drag, no pinch

        "Music" tap → push ReelAudioPickerScreen (keep existing screen, just navigate to it)

        "Filter" tap → show a bottom sheet with the existing filter chips 
            (reuse the _buildFilterPicker logic but apply to ALL clips, not just active clip)
            Keep the same filter list: None, Vintage, B&W, Warm, Cool, Dramatic, Beauty
            When a filter is selected, apply colorMatrix to ALL clips uniformly

---

## SCREEN 2: CreateReelDetailsScreen (simplify create_reel_details_screen.dart)

Keep ALL existing API/upload/submit logic completely intact.
Only change the UI layout. The _submitReel() function and all API calls stay the same.

### New layout:

  [TOP BAR]
    - Left: back chevron
    - Center: "New Reel" title
    - Right: "Share" button (blue pill, same style as current)

  [BODY — scrollable]

    Section 1 — PREVIEW + CAPTION (side by side, like Instagram's final step)
      Row:
        Left: video thumbnail (100x140px, rounded 8px, from existing _selectedThumbnailBytes 
              or generated from video. Keep existing thumbnail generation logic.)
        Right: 
          TextField for caption (multiline, max 4 lines visible, hint: "Write a caption...")
          Below caption: small grey text showing character count if > 0

    Section 2 — OPTIONS (list of simple toggle rows, thin dividers between them)
      Each row: 44px tall, label on left, toggle or chevron on right

      Row 1: "Hide like count"     → Switch (maps to _hideLikes)
      Row 2: "Turn off comments"   → Switch (maps to _turnOffCommenting)
      
      REMOVE: location row, emoji picker, people tags, thumbnail picker row, 
              advanced settings accordion, sound toggle in details

    Section 3 — AUDIENCE (simple text row, no functionality needed)
      Just a static row: "Audience: Everyone" with a grey right chevron 
      (tapping does nothing for now, just placeholder UI)

  [BOTTOM]
    Full-width "Share" button (blue, rounded 12px, height 48px)
    Below it: small centered "Save as draft" text button (grey)
    (draft save calls existing _saveDraft or similar logic if it exists, 
     otherwise just Navigator.pop())

---

## STUBS: Files to stub out

For these files, keep their class names and constructor signatures EXACTLY the same 
(so imports don't break), but replace the body with a minimal stub that does nothing 
or shows a "Coming soon" snackbar if opened:

  reel_caption_screen.dart:
    class ReelCaptionScreen extends StatelessWidget {
      // keep same constructor params
      // build: return Scaffold showing "Captions coming soon"
    }

  reel_transition_picker.dart:
    class ReelTransitionPicker extends StatelessWidget {
      // keep same constructor params
      // build: return empty Container (it's shown as a bottom sheet, 
      //         so just close immediately in initState or show nothing)
    }

  reel_voice_recorder_sheet.dart:
    class ReelVoiceRecorderSheet extends StatelessWidget {
      // keep same constructor params  
      // build: return a sheet saying "Voice recording coming soon"
    }

  reel_volume_panel.dart:
    class ReelVolumePanel extends StatelessWidget {
      // keep same constructor params
      // build: return empty Container
    }

  reel_overlay_duration_sheet.dart:
    class ReelOverlayDurationSheet extends StatelessWidget {
      // keep same constructor params
      // build: return empty Container
    }

---

## CLIP STRIP (replaces reel_timeline_strip.dart)

Replace the contents of reel_timeline_strip.dart with a simple widget called 
SimpleClipStrip (keep class ReelTimelineStrip as an alias/wrapper so existing 
import in reel_editor_screen.dart still works):

  Widget: horizontal ListView of clip thumbnails
  Each clip tile:
    - Size: 56x56
    - Rounded corners: 8px
    - Shows: video thumbnail (use VideoThumbnail.thumbnailData) or Image.file for images
    - Active clip: white border 2px, slight scale 1.05
    - Inactive: no border, opacity 0.7
    - Tap: onClipSelected callback
    - Long press: onClipLongPress callback
  
  After all clips: AddClipButton (56x56, dashed border Color(0xFF444444), Icons.add in white)
    Tap: onAddClip callback

  The widget signature should accept at minimum:
    - List<ReelClip> clips
    - int? selectedClipIndex  
    - ValueChanged<int> onClipSelected
    - ValueChanged<int> onClipLongPress
    - VoidCallback onAddClip
  
  All other params from the original ReelTimelineStrip (playheadMs, pxPerMs, 
  onPlayheadScrub, onZoomChanged, etc.) should be accepted but IGNORED silently 
  to avoid breaking the call site in reel_editor_screen.dart.

---

## reel_clip_context_menu.dart

Keep class ReelClipContextMenu with same constructor.
But simplify build to show ONLY:
  - A bottom sheet (dark bg, rounded top)
  - Title: "Clip options"
  - Big red "Delete Clip" button
  - Grey "Cancel" button
  - All other callbacks (onSplit, onDuplicate, onReplace, onSpeedChanged, 
    onReverse, onFreeze) are accepted in constructor but do nothing

---

## DESIGN TOKENS to use throughout

Background:          Colors.black / Color(0xFF111111)
Surface:             Color(0xFF1C1C1E)
Border/divider:      Color(0xFF2C2C2E)
Active accent:       Colors.white (not blue)
Inactive:            Colors.white54
Text primary:        Colors.white
Text secondary:      Colors.white60
Destructive:         Color(0xFFFF3B30)
Button (primary):    Color(0xFF0095F6) only for the Share button in details screen
Border radius:       8px for tiles, 12px for sheets/cards, 999px for pills

Font sizes:
  Labels under icons: 11sp
  Body text:          14sp  
  Caption/metadata:   12sp

---

## IMPORTANT CONSTRAINTS

1. Do NOT break the flow: existing route that pushes ReelEditorScreen with 
   List<MediaItem> initialMedia must still work
2. Do NOT touch reel_export_service.dart — the _onNext() flow must still call 
   ReelExportService().export(...) and then push CreateReelDetailsScreen
3. The ReelClip model and ReelEditHistory from reel_timeline_models.dart must 
   still be used as-is
4. Keep _videoController initialization logic intact (the LRU cache can be 
   simplified to just a single controller — one video at a time)
5. Keep _togglePlayback(), _initControllerForActiveClip(), dispose() logic correct
6. Do NOT add any new packages — use only what's in pubspec.yaml
7. All color/filter matrix logic can be removed from the editor EXCEPT for 
   the filter bottom sheet (keep _buildFilterMatrixBase, _buildGrayscaleMatrix, 
   _buildSepiaMatrix, _reelFilterMatrixFor private methods)
8. Remove: undo/redo, split, grouping, reorder drag, trim handles, freeze frame, 
   reverse clip, speed control, voice recording, captions, stickers, transitions, 
   overlay duration sheet, playhead tooltip, multi-select
9. The simple text overlay (one centered text on preview) should be stored as a 
   single String? _overlayText in state — no ReelEditorTextOverlay class needed
10. Apply filter via ColorFiltered wrapping the preview Stack, using the selected 
    colorMatrix (stored as List<double>? _activeColorMatrix in state)