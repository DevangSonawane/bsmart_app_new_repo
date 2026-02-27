# Manual QA Checklist — Flutter parity with React (mobile)

Run these checks against the same Supabase instance the React app uses.

1. Authentication
   - [ ] Sign up with email and verify OTP flow.
   - [ ] Log in and log out; check session persistence across app restarts.
2. Home / Feed
   - [ ] Open Home feed; posts load and images display.
   - [ ] Create a post with image and verify it appears in feed (and in web app).
3. Reels
   - [ ] Open Reels; videos autoplay and can be swiped vertically.
   - [ ] Like, comment, save and share actions work and reflect counts.
4. Profile
   - [ ] Open Profile; posts and reels lists load correctly.
   - [ ] Edit profile and verify updates persist.
5. Create Post
   - [ ] Pick image/video, crop, apply filter, publish; verify storage bucket `post_images` contains file and post is created.
6. Wallet & Gifting
   - [ ] View coin balance.
   - [ ] Send gift to another user; verify sender balance reduces and recipient balance increases (if server RPC present).
7. Notifications
   - [ ] Notification list shows recent items; mark as read/clear all works.
8. Performance
   - [ ] Reels prefetching: swipe quickly through 10+ reels and observe playback smoothness.
   - [ ] Images load progressively and are cached (restart app and revisit).
9. Security
   - [ ] Verify authenticated API calls include session token and protected endpoints return expected data.
10. Edge cases
   - [ ] Network offline scenarios: posting gracefully fails with error messages.
   - [ ] Large video upload: ensure upload progress and failure handling.

Notes:
- If any server-side RPCs are missing (transfer_coins, append_post_id), fall back to best-effort flows and log for backend implementation.

