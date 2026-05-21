B-Smart API Documentation 1.0.0  OAS 3.0
API documentation for B-Smart application

Servers

https://api.bebsmart.in - Production Server

Authorize
Ads
Advertisement management



GET
/api/ads/categories
Get all ad categories



POST
/api/ads/categories
Add a new ad category



GET
/api/ads/feed
Get active ads feed for user



GET
/api/ads/user/{userId}
Get all ads created by a user



GET
/api/ads
List all ads (Admin only)



POST
/api/ads
Create a new ad (Vendor only, currently not implemented)



GET
/api/ads/search
Search ads by category, hashtag, keyword, username, ad_title, or description



GET
/api/ads/{id}/stats
Get engagement stats for an ad



GET
/api/ads/{id}
Get ad by ID



DELETE
/api/ads/{id}
Delete an ad (Vendor only, soft delete)



PATCH
/api/ads/{id}/metadata
Update ad metadata (everything except media)



POST
/api/ads/{id}/view
Record an ad view (counts view and applies reward if eligible)



POST
/api/ads/{id}/click
Record an ad CTA or product-link click



POST
/api/ads/{id}/like
Like an ad (credits user wallet and spends ad budget)



POST
/api/ads/{id}/dislike
Reverse a previous like (deducts 10 coins from user and refunds ad budget)



POST
/api/ads/{id}/save
Save an ad (user earns 10 coins, deducted from ad creator wallet)



POST
/api/ads/{id}/unsave
Unsave an ad



POST
/api/ads/{id}/comments
Add a comment to an ad



GET
/api/ads/{id}/comments
Get comments for an ad



GET
/api/ads/comments/{commentId}/replies
Get replies for an ad comment



DELETE
/api/ads/comments/{commentId}
Delete a comment



POST
/api/ads/comments/{id}/like
Like or unlike a comment



POST
/api/ads/comments/{id}/dislike
Dislike or undislike a comment



PATCH
/api/admin/ads/{id}
Admin updates ad status (approve/reject/pause)



DELETE
/api/admin/ads/{id}
Admin permanently deletes an ad


Admin
Admin-only moderation APIs



GET
/api/ads
List all ads (Admin only)



DELETE
/api/admin/posts/{id}
Admin permanently deletes any post



DELETE
/api/admin/comments/{id}
Admin permanently deletes any comment



DELETE
/api/admin/replies/{id}
Admin permanently deletes any reply



DELETE
/api/admin/reels/{id}
Admin permanently deletes any reel



DELETE
/api/admin/stories/{id}
Admin permanently deletes any story



DELETE
/api/admin/users/{id}
Admin permanently deletes (soft delete) any user



DELETE
/api/admin/vendors/{id}
Admin permanently deletes (soft delete) any vendor



PATCH
/api/admin/ads/{id}
Admin updates ad status (approve/reject/pause)



DELETE
/api/admin/ads/{id}
Admin permanently deletes an ad


Auth
Authentication management



POST
/api/auth/register
Register a new user



POST
/api/auth/google/token
Login or Register with Google ID Token



POST
/api/auth/login
Login user



GET
/api/auth/me
Get current user profile



POST
/api/auth/change-password
Change user password



GET
/api/auth/users
Get all users with their posts, comments and likes



GET
/api/auth/google
Initiate Google Authentication



GET
/api/auth/google/callback
Google Authentication Callback


Chat
Direct messages, group chats, requests, and chat messages



POST
/api/chat/conversations
Create or return a direct conversation or pending request



GET
/api/chat/conversations
Get all conversations for the logged-in user



POST
/api/chat/groups
Create a new group conversation



POST
/api/chat/share
Share a post, reel, ad, or tweet to chats and group chats



PATCH
/api/chat/groups/{conversationId}
Update a group's name or avatar



POST
/api/chat/groups/{conversationId}/members
Add a member to a group conversation



DELETE
/api/chat/groups/{conversationId}/members/{userId}
Remove a member from a group conversation or leave the group



POST
/api/chat/groups/{conversationId}/leave
Leave a group conversation



DELETE
/api/chat/groups/{conversationId}/delete
Delete a group chat from inbox for the logged-in user



GET
/api/chat/online-users
Get currently online user IDs



GET
/api/chat/conversations/{conversationId}/messages
Get paginated messages for a conversation



POST
/api/chat/conversations/{conversationId}/messages
Send a new message in a conversation



PUT
/api/chat/conversations/{conversationId}/accept
Accept an incoming message request



DELETE
/api/chat/conversations/{conversationId}/decline
Decline an incoming message request



POST
/api/chat/conversations/{conversationId}/voice
Upload and send a voice message in one step



PUT
/api/chat/messages/{messageId}/seen
Mark a message as seen by the logged-in user



POST
/api/chat/messages/{id}/reaction
Add or replace the logged-in user's reaction on a message



DELETE
/api/chat/messages/{id}/reaction
Remove the logged-in user's reaction from a message



DELETE
/api/chat/messages/{messageId}
Unsend a message sent by the logged-in user



POST
/api/chat/conversations/{conversationId}/media
Upload one or more media files for a chat conversation


Content Reports
Report posts, reels, stories, ads, comments and tweets



GET
/api/content-reports/reasons
Get available report reasons



POST
/api/content-reports
Report a post, reel, story, ad, comment or tweet



GET
/api/content-reports/my
Get my submitted reports



GET
/api/content-reports/admin
List reported content for admin review



PATCH
/api/content-reports/admin/{id}
Update report review status


Countries
Country, State, City and Language data endpoints



GET
/api/countries/all
Get all countries with nested states, cities and languages


GET
/api/countries/{country}
Get a single country by name with nested states and cities


GET
/api/countries/{country}/states
Get all states of a country with their cities and languages


GET
/api/countries/{country}/states/{state}/cities
Get all cities of a specific state


GET
/api/countries/{country}/languages
Get languages spoken in a specific country


GET
/api/countries
Get all countries — flat list (250 countries)


GET
/api/states
Get all states — flat list (4963 states)


GET
/api/cities
Get all cities — flat list (148,038 cities)


GET
/api/languages
Get all unique languages (sorted A–Z)

Email
OTP and password reset email flows



POST
/api/email/send-otp
Send OTP for email verification, login 2FA, or forgot-password flow



POST
/api/email/verify-otp
Verify OTP and mark email verified when applicable



POST
/api/email/forgot-password
Send password reset link to the user's email



POST
/api/email/reset-password
Reset password using the token sent by email



POST
/api/email/send
Send an email to another user or external recipient


Follow
Follow / Unfollow users



POST
/api/follow
Follow a user



POST
/api/unfollow
Unfollow a user



POST
/api/follows/{userId}
Follow a user by URL param



GET
/api/follows/check/{userId}
Check follow status for a user



POST
/api/follows/status/bulk
Check follow status in bulk



GET
/api/users/{id}/followers
Get followers of a user



GET
/api/users/{id}/following
Get users that a user is following


Account Privacy
Make your account public or private (Instagram-style)



PATCH
/api/follow/privacy/toggle
Toggle account between public and private



PATCH
/api/follow/privacy/set
Set account privacy explicitly



GET
/api/follow/privacy/status
Get current privacy status


Follow Requests
Manage incoming and outgoing follow requests for private accounts



GET
/api/follow/requests
Get all incoming follow requests



POST
/api/follow/requests/{requesterId}/accept
Accept a follow request



POST
/api/follow/requests/{requesterId}/decline
Decline a follow request



DELETE
/api/follow/request/{userId}/cancel
Cancel a follow request you sent



DELETE
/api/follow/followers/{followerId}/remove
Remove a follower


Location
Google Places location search



GET
/api/location/search
Search for locations using Google Places Autocomplete


Notifications
Real-time notification management. For follow_request notifications, use /api/follow/requests/{requesterId}/accept or /api/follow/requests/{requesterId}/decline to take action.



GET
/api/notifications
Get all notifications for logged-in user



GET
/api/notifications/unread-count
Get count of unread notifications



PATCH
/api/notifications/mark-all-read
Mark all notifications as read



PATCH
/api/notifications/{id}/read
Mark a single notification as read



DELETE
/api/notifications/{id}
Delete a notification


NotificationPreferences
Turn on / off post & reel notifications for a user or vendor profile



POST
/api/notification-preferences/users/{targetUserId}/toggle
Toggle post/reel notifications for a user profile



GET
/api/notification-preferences/users/{targetUserId}/status
Check if notifications are turned on for a user profile



POST
/api/notification-preferences/vendors/{targetVendorId}/toggle
Toggle post notifications for a vendor profile



GET
/api/notification-preferences/vendors/{targetVendorId}/status
Check if notifications are turned on for a vendor profile


Reels
Reel management and viewing



POST
/api/posts/reels
Create a new reel



GET
/api/posts/reels
List all reels



GET
/api/posts/reels/{id}
Get a reel by ID



PATCH
/api/posts/reels/{id}/metadata
Update reel caption, location, tags and advanced settings



POST
/api/upload/thumbnail
Upload thumbnail image(s) for reels


PromoteReels
Promote reel management — reels with attached product listings



POST
/api/promote-reels
Create a new promote reel



GET
/api/promote-reels
List all promote reels (paginated)



GET
/api/promote-reels/{id}
Get a promote reel by ID



PATCH
/api/promote-reels/{id}
Update a promote reel (caption, location, tags, products, etc.)



DELETE
/api/promote-reels/{id}
Delete a promote reel (soft delete)



POST
/api/promote-reels/{id}/like
Like a promote reel



POST
/api/promote-reels/{id}/unlike
Unlike a promote reel



GET
/api/promote-reels/{id}/likes
Get users who liked a promote reel



POST
/api/promote-reels/{promoteReelId}/comments
Add a comment (or reply) to a promote reel



GET
/api/promote-reels/{promoteReelId}/comments
Get top-level comments for a promote reel



DELETE
/api/promote-reels/comments/{id}
Delete a comment on a promote reel



GET
/api/promote-reels/comments/{commentId}/replies
Get replies for a comment on a promote reel



DELETE
/api/promote-reels/comments/{commentId}/replies/{replyId}
Delete a specific reply on a promote reel comment



POST
/api/promote-reels/comments/{commentId}/like
Like a comment on a promote reel



POST
/api/promote-reels/comments/{commentId}/unlike
Unlike a comment on a promote reel


Sales
Sales officer management, profile, and vendor assignment APIs



GET
/api/sales/me
Get my sales profile



PUT
/api/sales/me
Update my sales profile



GET
/api/sales/users/{id}
Admin get user sales details



GET
/api/sales/officers
Get all sales officers



POST
/api/sales/assign
Assign a sales officer to a vendor



DELETE
/api/sales/assign/{vendor_user_id}
Unassign the sales officer from a vendor



GET
/api/sales/my-officer
Vendor — get my assigned sales officer



GET
/api/sales/officers/{sales_user_id}/vendors
Get all vendors assigned to a specific sales officer


Search
Instagram-like global search and search history



GET
/api/search
Search users, posts and reels



GET
/api/search/history/{userId}
Get recent search history by user id



DELETE
/api/search/history/{userId}
Delete all search history of a user



DELETE
/api/search/history/{userId}/{historyId}
Delete a single search history item


Suggestions
Suggestions for reels, ads, and users



GET
/api/suggestions
Get combined suggestions for reels, ads, and users



GET
/api/suggestions/users
Get suggested users



GET
/api/suggestions/reels
Get suggested reels



GET
/api/suggestions/ads
Get suggested ads



GET
/api/suggestions/vendors
Get suggested vendors


Tweets
Tweets-style posting, replies, likes, reposts and discovery



POST
/api/tweets/upload
Upload a tweet image



POST
/api/tweets
Create a tweet, reply, repost or quote repost



GET
/api/tweets/feed
Get public root tweets for the feed



GET
/api/tweets/trending
Get trending tweets from the last 48 hours



GET
/api/tweets/search
Search public tweets by content



GET
/api/tweets/user/{userId}
Get a user's root tweets and reposts



POST
/api/tweets/repost
Toggle repost or create a quote repost



POST
/api/tweets/{tweetId}/comments
Add a comment to a tweet



GET
/api/tweets/{tweetId}/comments
Get comments for a tweet



POST
/api/tweets/comments/{commentId}/like
Like a tweet comment



POST
/api/tweets/comments/{commentId}/unlike
Unlike a tweet comment



GET
/api/tweets/comments/{commentId}/replies
Get replies for a tweet comment



DELETE
/api/tweets/comments/{commentId}
Delete a tweet comment



GET
/api/tweets/{tweetId}/replies
Get direct replies for a tweet



POST
/api/tweets/{tweetId}/like
Toggle like for a tweet



POST
/api/tweets/{tweetId}/unlike
Unlike a tweet



GET
/api/tweets/{tweetId}
Get a single tweet by ID



DELETE
/api/tweets/{tweetId}
Soft delete a tweet


Users
User management



GET
/api/users
Get list of user profiles with posts, comments, likes, and views



GET
/api/users/{id}/profile-content
Get profile content (posts, reels, promote reels, tweets) in one response



GET
/api/users/{id}
Get user details



PUT
/api/users/{id}
Update user details



PATCH
/api/users/{id}
Admin update user fields



DELETE
/api/users/{id}
Delete user and their posts



GET
/api/users/{id}/posts
Get user's posts with comments and likes



PATCH
/api/users/{id}/status
Update user active status



GET
/api/users/{id}/interests
Get ad interest categories for a user profile



POST
/api/users/{id}/interests
Add or update ad interest categories (logged-in user only)


Vendors
Vendor management



GET
/api/vendors/profile/{userId}
Get vendor profile with percentage



POST
/api/vendors/profile/{userId}
Update vendor profile details by userId



GET
/api/vendors/dashboard/{userId}
Get vendor dashboard summary by userId



GET
/api/vendors/profile/{userId}/public
Get public vendor profile for users



POST
/api/vendors/profile/{userId}/cover-image
Upload multiple vendor cover images for a particular user



DELETE
/api/vendors/profile/{userId}/cover-image
Delete a single vendor cover image



DELETE
/api/vendors/profile/{userId}/avatar
Remove user avatar



POST
/api/vendors/{userId}/contacts
Add a contact for a vendor



GET
/api/vendors/{userId}/contacts
Get all contacts for a vendor



POST
/api/vendors/{userId}/contacts/{contactId}
Update a contact for a vendor



DELETE
/api/vendors/{userId}/contacts/{contactId}
Delete a contact for a vendor



POST
/api/vendors/profile/{userId}/admin-process
Admin Approve/Reject Vendor Profile



PATCH
/api/vendors/profile/{id}/approval
Admin approve or reject vendor profile



GET
/api/vendors/admin/all
Get all vendors (Admin only)



DELETE
/api/vendors/admin/user/{userId}
Delete vendor and associated user by User ID (Admin only)



POST
/api/vendors/profile/{vendorUserId}/viewProfile
Record a vendor profile view (credits member, deducts 10 coins from vendor wallet balance)


VendorPackages
Vendor package purchase, coin allocation & transaction history



GET
/api/vendor-packages/admin
List all packages for admin management



POST
/api/vendor-packages/admin
Create a new package (admin only)



GET
/api/vendor-packages/admin/purchases
List all vendor package purchases across all vendors (admin only)



PUT
/api/vendor-packages/admin/{packageId}
Update an existing package (admin only)



PATCH
/api/vendor-packages/admin/{packageId}
Partially update an existing package (admin only)



DELETE
/api/vendor-packages/admin/{packageId}
Deactivate a package (admin only)



GET
/api/vendor-packages/my/active
Get vendor's currently active package



POST
/api/vendor-packages/my/coin-preview
Preview ad budget coin breakdown based on vendor's active package tier



GET
/api/vendor-packages/my/history
Get vendor's package purchase history (paginated)



GET
/api/vendor-packages/my/transactions
Get vendor's full wallet transaction history (paginated)



GET
/api/vendor-packages
List all active packages



GET
/api/vendor-packages/{packageId}/preview
Preview a package's full pricing and coin details before buying



POST
/api/vendor-packages/{packageId}/buy
Purchase a package (vendor only)



GET
/api/vendor-packages/{packageId}
Get a single package by ID


Wallet
Wallet balance, recharge, and transaction history



GET
/api/wallet/me
Get my own wallet balance and recent transactions



POST
/api/wallet/recharge
Vendor self-recharge — converts rupee amount to coins based on active package tier



GET
/api/wallet/recharge/history
Get the logged-in vendor's own recharge history



GET
/api/wallet/recharge/history/{userId}
Get any vendor's recharge history (Admin only)



GET
/api/wallet/member/{userId}/history
Get a member's wallet history (rewards earned from ads)



GET
/api/wallet/vendor/{userId}/history
Get a vendor's wallet history (credits, recharges, ad budget deductions, refunds)



POST
/api/wallet/vendor/{userId}/recharge
Directly credit a vendor's wallet with coins (Admin only — no formula applied)



GET
/api/wallet/ads/{adId}/history
Get transaction history for a specific ad



GET
/api/wallet
Get all wallet transactions



POST
/api/wallet/admin/adjust
Manually credit or debit any user's wallet (Admin only)


Comments


POST
/api/posts/{postId}/comments
Add a comment to a post



GET
/api/posts/{postId}/comments
Get comments for a post



DELETE
/api/comments/{id}
Delete a comment



POST
/api/comments/{commentId}/like
Like a comment



POST
/api/comments/{commentId}/unlike
Unlike a comment



GET
/api/comments/{commentId}/replies
Get replies for a comment


Highlights


POST
/api/highlights
Create a new highlight



GET
/api/highlights/user/{userId}/stories
Get all highlights with story items by userId



GET
/api/highlights/user/{userId}
Get highlights of a user



POST
/api/highlights/{id}/items
Add story items to a highlight



GET
/api/highlights/{id}/items
Get items of a highlight



PATCH
/api/highlights/{id}
Update a highlight



DELETE
/api/highlights/{id}
Delete a highlight



DELETE
/api/highlights/{id}/items/{itemId}
Remove an item from a highlight


Posts


POST
/api/posts
Create a new post



GET
/api/posts/feed
Get posts feed



GET
/api/posts/{id}
Get a single post by ID



DELETE
/api/posts/{id}
Delete a post



PATCH
/api/posts/{id}/metadata
Update post caption, location, tags and advanced settings



POST
/api/posts/{id}/like
Like a post



POST
/api/posts/{id}/unlike
Unlike a post



GET
/api/posts/{id}/likes
Get users who liked a post



POST
/api/posts/{id}/save
Save a post



POST
/api/posts/{id}/unsave
Unsave a post



GET
/api/posts/saved
Get current user's saved posts



GET
/api/posts/{id}/stats
Get engagement stats for a post


Reports


GET
/api/reports/summary
Reports summary



GET
/api/reports/clicks
Click Report — click-through metrics per ad



GET
/api/reports/engagement
Engagement Report — likes, comments, saves & engagement rate per ad



GET
/api/reports/geographic
Geographic Report - country-wise impressions, clicks, CTR and reach



GET
/api/reports/performance-summary
Performance Summary — date-wise impressions, clicks, CTR, reach & frequency


Stories


POST
/api/stories
Create or append story items for current user



GET
/api/stories/feed
Get active stories feed



GET
/api/stories/user/{userId}
Get active stories by userId



GET
/api/stories/{storyId}/items
Get ordered items of a story



POST
/api/stories/items/{itemId}/view
Mark a story item as viewed



POST
/api/stories/items/{itemId}/like
Like or unlike a story item



GET
/api/stories/{storyId}/views
Get viewers list of a story (owner only)



POST
/api/stories/upload
Upload an image or video for a story item



GET
/api/stories/archive
Get archived stories for current user



DELETE
/api/stories/items/{itemId}
Delete a single story item (owner only)



DELETE
/api/stories/{storyId}
Delete a story (owner only)


Upload


POST
/api/upload
Upload a file (image or video). Videos are auto-converted to HLS (.m3u8).



POST
/api/upload/avatar
Upload avatar image for current user and update profile



POST
/api/upload/promote-product
Upload a product image for a promote reel product card


Views


POST
/api/views
Add a view for a reel



POST
/api/views/complete
Complete a view for a reel and reward user



Schemas
AdMedia
AdCta
AdBudget
AdTargeting
AdTracking
AdEngagementControls
AdAbVariant
AdAbTesting
AdTimeSlot
AdScheduling
AdCompliance
AdTaggedUser
AdGalleryItem
AdStatUser
AdGenderBucket
AdLikesByGender
AdAgeDemographics
AdDislikeGenderCount
AdDislikesByGender
AdViewByLocation
AdStatsResponse
User
UserWithPosts
ChatParticipant
ChatMessage
Conversation
OnlineUsersResponse
CreateGroupConversationRequest
ShareContentRequest
ShareContentFailure
ShareContentResponse
ShareContentForbiddenResponse
UpdateGroupRequest
AddGroupMemberRequest
SimpleSuccessResponse
Comment
StateNested
CountryNested
CountryFlat
StateFlat
CityFlat
Highlight
CreateHighlightRequest
UpdateHighlightRequest
AddHighlightItemsRequest
Notification
MediaItem
PostMediaItem
ReelMediaItem
Post
StatUser
GenderBucket
LikesByGender
PostAgeDemographics
DislikeGenderCount
DislikesByGender
RecentComment
ViewByLocation
PostStatsResponse
Product
PromoteReel
SalesProfile
SalesOfficerUser
AssignSalesRequest
AssignSalesResponse
AssignedOfficerResponse
VendorsByOfficerResponse
CreateStoryRequest
StoryItemPayload
Story
StoryItem
CreateStoryResponse
StoryFeedItem
StoryViewsResponse
TweetAuthor
TweetMedia
Tweet
CreateTweetRequest
RepostTweetRequest
TweetFeedResponse
TweetComment
Transaction