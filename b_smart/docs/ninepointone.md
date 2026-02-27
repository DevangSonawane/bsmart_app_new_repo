App Name: b Smart - 9.1
 
Sponsored Video Creation – Requirements & Permissions
 
1. Who Can Create Sponsored Videos? (Eligibility Rules)
Not every logged-in user should create sponsored posts by default.

User Eligibility Levels
Level 1: Regular User
● ❌ Cannot create sponsored videos
● ✅ Can create normal posts only
Level 2: Creator
● ✅ Can apply to create sponsored videos
● Requirements:
○ Verified email & phone
○ Minimum followers / engagement (configurable)
○ No policy violations
○ Creator account enabled
Level 3: Business / Brand Account
● ✅ Full access to sponsored videos
● Can:
○ Promote own products
○ Run paid campaigns
○ Attach product catalogs
2. Required Account Permissions & Flags
Backend Account Flags
{
 "account_type": "creator | business",
 "can_create_ads": true,
 "ad_account_verified": true,
 "payment_verified": true
}
 
Permission Checks (Before Showing “Sponsored” Option)
● User is logged in
● Account type = Creator or Business
● Ad account approved
● Payment method added (if paid promotion)
● Product catalog connected
 
3. Sponsored Video Creation Flow (Restricted & Structured)
Step 1: Create Sponsored Video Screen
User sees Sponsored Creation Form, not the normal camera flow.

Mandatory Sections
1. Upload Video
2. Upload Product Images
3. Product Details
4. Preview & Submit
5. Step-by-Step Sponsored Creation Flow
 
Step 1: Upload Video (Mandatory)
UI

● Upload button (no live camera)
● Supported formats: MP4, MOV
● Duration limits enforced
Behavior

● Auto thumbnail generated
● Video preview shown
● Cannot proceed without video
 
Step 2: Upload Product-Related Images
Purpose

● Used for product cards, carousel, thumbnails
Rules

● Minimum: 1 image
● Maximum: configurable (e.g. 5)
Supported

● JPG / PNG
● Square or vertical preferred
 
Step 3: Product Basic Details (Mandatory)
Required Fields
● Product Name
● Short Description
● Price
● Discount (optional)
● Product Category
● Brand / Company Name
● Product URL (redirect destination)
Optional Fields
● SKU
● Variant (color, size)
● Offer validity
● Affiliate ID
 
Step 4: Auto-Applied Sponsored Metadata
These are non-editable:

● Sponsored badge
● Disclosure (“Sponsored” / “Paid Partnership”)
● Creator attribution
● Timestamp & campaign ID
 
Step 5: Preview Sponsored Video
User sees exact consumer view:

● Video playback
● Product carousel
● Price & redirect to Product Page - out side of the App
● Sponsored badge
● Company name clickable
● Creator name clickable
 
Step 6: Submit for Review
CTA: Submit Sponsored Video

System actions:

● Content policy scan
● Product validation
● URL & pricing check
● Audio copyright check
 
6. Post-Submission Status Flow
Sponsored video enters one of these states:

● Draft
● Under Review
● Approved
● Rejected (with reason)
● Live
● Paused
 
7. Where Sponsored Videos Appear (Consumer Side)
Once approved:

● Sponsored Feed
● Play / Video Feed (interleaved)
● Category-based filtered feeds
Clearly marked as Sponsored

 
8. Why This Restriction Is Good (Design Rationale)
✔ Prevents accidental sponsored posts
✔ Strong legal & ad-policy compliance
✔ Cleaner Create (+) experience for normal users
✔ Easier moderation & analytics
✔ Scales well for Ads Dashboard later

This is exactly how mature platforms evolve, even if UI looks simple.

 
9. Updated Permissions Summary
Feature

Requirement

Create Sponsored Video

Creator/Business + Approved

Upload Video

Mandatory

Upload Product Images

Mandatory

Add Product Details

Mandatory

Publish Without Review

❌ No

Use Normal Create (+)

❌ No

 
10. Final Summary (One-Liner)
Sponsored videos can only be created from the Sponsored Page, using a structured flow that requires video upload, product images, and product details, ensuring compliance, clarity, and high-quality ad content.

 
Next steps I can help with:
● Sponsored Page wireframe with Create CTA
● Sponsored Creation form wireframe
● Backend API + schema
● Review & rejection rules list
● Comparison with Instagram Branded Content flow
 

 