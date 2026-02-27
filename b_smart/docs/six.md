App Name: b Smart - 6
Ads Page – Screen Structure & Flow
Purpose
The Ads Page displays rewarded video ads, allowing users to watch, interact, and earn coins, with clear visibility of categories, engagement actions, rewards, and advertiser details.

 
1. Ads Page Header – Category List
Layout
● Horizontal, scrollable Category Selector at the top
● First category: All
● Other categories based on platform taxonomy
(e.g. Accessories, Action Figures, Art Supplies, Baby Products, etc.)
Behavior
1. User lands on Ads Page.
2. Default category is All.
3. User can scroll horizontally and select a category.
4. Ads list refreshes based on selected category.
5. Only ads matching:
○ Selected category
○ User language
○ Preferences
○ Location
are shown.
Rule:
Category change does not reset daily limits or cooldowns.

 
2. Video Player Section (Main Content Area)
Layout
● Full-width / vertical video player (Reels-style)
● Single ad shown at a time
● Auto-play enabled (subject to eligibility)
 
Right-Side Overlay Actions (Vertical Stack)
Displayed on the right side of the video player:

1. Total Views Count
○ Shows number of views the ad has received
2. Like Button
○ Toggles like/unlike
3. Comment Button
○ Opens comments panel
4. Share Button
○ Opens native share options
5. Mute / Unmute Button
○ Controls ad audio
 
Video Interaction Rules
● Like, Comment, Share → Engagement only (no extra coins)
● Mute → Always allowed
● Pause → Allowed within defined pause limits
● Skipping → Not allowed for rewarded ads
 
3. Information Section (Above Footer Navigation)
Positioned above the Footer Nav Bar, below the video player.

 
3.1 Company Details Block
Displays:
● Company logo
● Company name
● Verified badge (if applicable)
Behavior:
● Tapping company name/logo opens Ad Company Detail Page
● Returning does not reset ad progress (within pause rules)
 
3.2 Ad Related Information
Displays:

● Ad category / tags
(e.g. “Related to: Electronics, Accessories”)
● Optional short ad description
 
3.3 Coins Reward Information
Clearly shows:

● Coins user can earn from this ad
○ Example: “Watch & Earn 15 Coins”
Rules:
● Coin value is ad-specific
● Reward value shown before and during playback
● Reward granted only after eligibility conditions are met
 
3.4 Video Progress Bar
Positioned below the reward information.

Behavior:
1. Shows real-time ad progress.
2. Indicates:
○ Total ad duration
○ Watched duration
3. Completion of progress bar = ad fully watched.
4. Progress pauses when:
○ App goes to background
○ User opens company details (within allowed limits)
 
4. Footer Navigation Bar
Persistent bottom navigation:

● Home
● Ads (active)
○ Create
● Reels
● Promoted Products Reels
 
5. Reward Completion Flow (From Ads Page)
1. Video reaches required watch percentage.
2. Progress bar completes.
3. System validates:
○ Eligibility
○ Fraud checks
4. Ledger entry created (AD_REWARD).
5. Wallet balance updated.
6. Success confirmation shown:
○ “You earned X coins.”
 
6. Edge & Error States
● Daily limit reached
○ Show message instead of video
● Ad unavailable
○ Load next eligible ad
● Network issue
○ Pause video + retry option
● Fraud flag
○ Reward blocked, video may still complete
○
7. Gesture-Based Navigation & Page Behavior
Purpose
To provide a smooth, reels-like ad browsing experience with intuitive gestures.

 
7.1 Vertical Swipe Behavior (Ad Navigation)
Swipe Up – Load Next Ad
Behavior:

1. User swipes up on the video player.
2. System checks:
○ Next eligible ad availability
○ User eligibility rules
3. Current ad playback stops.
4. Next ad loads and auto-plays.
5. Progress bar resets for the new ad.
Rules:

● Swipe up is allowed at any time.
● If ad is not completed:
○ No coins are granted
○ No ledger entry is created
● Cooldown rules still apply per ad.
 
Swipe Down – Load Previous Ad
Behavior:

1. User swipes down on the video player.
2. System loads the previously viewed ad (if available).
3. Ad resumes from:
○ Last watched position OR
○ Start (based on product decision)
Rules:

● Re-watching a previously rewarded ad:
○ Does NOT grant additional coins
● Reward eligibility remains locked to first valid completion only.
 
7.2 Horizontal Swipe Behavior (Tab Navigation)
Swipe Left / Right – Switch Tabs
Behavior:

1. User swipes left or right anywhere on the Ads Page.
2. System navigates to:
○ Previous tab OR
○ Next tab in the footer navigation
(e.g., Home ↔ Ads ↔ Reels)
Rules:

● Active ad playback:
○ Pauses when switching tabs
○ Progress preserved within pause limits
● If user stays away beyond pause threshold:
○ Reward eligibility is canceled
 
7.3 Gesture Conflict Resolution
Rules:
● Vertical swipes have priority over horizontal swipes inside video area.
● Horizontal swipe requires:
○ Clear left/right gesture
● Accidental gestures are ignored below a threshold distance.
 
7.4 State Management During Gestures
System Actions:
● Save ad playback state on every swipe.
● Track ad ID, watch time, and eligibility state.
● Ensure:
○ No duplicate reward triggers
○ No progress mismatch
 
7.5 Empty & Boundary States
Scenarios:
● No next ad available:
○ Show “No more ads available” message
● No previous ad available:
○ Swipe down disabled or ignored
● Category changed mid-swipe:
○ Ad list refreshes
○ Current playback stops safely
 
Final Behavior Summary (Add-On)
● Swipe up → Next ad loads
● Swipe down → Previous ad loads
● Swipe left/right → Navigate between main tabs
● Rewards only granted on valid, uninterrupted completion
● Gesture-based navigation does not bypass fraud or eligibility rules
 

 
Final Summary
● Header → Category-based ad discovery
● Main area → Rewarded video player
● Right overlay → Engagement actions + views
● Bottom info section → Company, ad details, coin reward, progress
● Rewards → Ad-specific, ledger-driven, fraud-protected
 

 