App Name: b Smart - 9
Advertisements & Sponsored Posts – PRD & User Flow
 
1. Objective
Enable companies and creators to promote products within the video feed. Users can:

● See promoted posts with company branding
● Explore advertised products
● Click company/creator for detailed pages
● Filter videos by product categories or promotions
 
2. Entry Point
● User opens the Play/Video feed page (like your screenshots).
● Footer navigation remains fixed for consistent access: Home, Play, Categories, Account, Cart.
 
3. Layout & UI Components
3.1 Fixed Footer Navigation
● Standard 5-button layout
● Remains visible at all times
3.2 Top Section – Recent & Promoted Videos
● Recent videos carousel at the top, scrollable horizontally
● Filter/Category sidebar (on right or as top horizontal chips)
○ Filters: Product type, Brand, Price, Offers
● Each video card includes:
○ Video preview
○ Company name + logo (top-left overlay)
○ Product highlights (small carousel or horizontal scroll within the video card)
○ Promoted badge/tag (optional)
 
3.3 Video Feed Section
● Videos displayed vertically scrollable
● Sponsored videos appear interleaved with organic content, clearly labeled as “Promoted”
● Overlay controls:
○ Mute / Unmute
○ Like / Share
○ Product tags with clickable links
○ Company/Creator name clickable
 
4. Interaction Behavior
4.1 Clicking on Elements
Element
Action
Company Logo / Name
Redirect to Company Detail Page (overview, products, promotions)
Published User Name
Redirect to Creator Profile
Product Image / Carousel Item
Redirect to Product Detail Page (external or in-app e-commerce page)
Promoted Badge
Optional: show ad details or campaign info
 
4.2 Filters & Sorting
● Sidebar or horizontal chip filters allow:
○ Brand / Category
○ Price Range
○ Trending / New Arrivals
● Filtering updates the video feed to only show relevant promoted or product-related videos
 
4.3 Video Playback
● Vertical feed like TikTok / Reels style
● Auto-play as user scrolls
● Sponsored videos must display company branding prominently
● Option to expand product carousel overlay without leaving video
 
4.4 Product Carousel Overlay (Inside Video)
● Appears at bottom 20–25% of the video
● Horizontal scroll of promoted products
● Each product card includes:
○ Image
○ Name & price
○ Discount / offer badge
○ Add to Cart button
 
5. User Flow – Step by Step
1. User opens Play/Video feed page
○ Footer navigation fixed
○ Top carousel shows recent videos
○ Filter section visible
2. User scrolls vertically
○ Videos auto-play
○ Sponsored/promoted videos appear with badge
3. User interacts with elements on a promoted video
○ Click company logo/name → redirect to company detail page
○ Click creator name → redirect to creator profile
○ Click product in overlay carousel → redirect to product detail page
4. User filters videos
○ Chooses filter (e.g., “Shiny Hair Must-Haves”)
○ Feed refreshes with relevant promoted videos
○ Product carousel updates to match selected category
5. User interacts with product
○ Optional Add to Cart button if integrated with in-app shopping
○ Or redirected to external e-commerce platform
6. Video interaction continues
○ Swipe vertically for next video
○ Sponsored content clearly labeled
 
6. Non-Functional Requirements
● Smooth vertical video scrolling (60fps+)
● Promoted videos load without delay
● Product carousel interactive and responsive
● Ads labeled clearly to avoid misleading the user
● Click actions redirect efficiently to internal/external pages
 
7. Edge Cases / Error Handling
● If product link fails → show error toast
● If company/creator page unavailable → fallback page with “Page not found”
● Network issues → show placeholder product or video
 
✅ Summary

● Footer nav stays fixed
● Top carousel for recent videos + filter section
● Videos scroll vertically, interleaving sponsored posts
● Sponsored video overlays include company branding + promoted products
● Clickable elements navigate to company, product, or creator details
● Filters allow user to focus feed on specific products



