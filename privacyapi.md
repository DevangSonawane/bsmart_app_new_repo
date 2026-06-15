Privacy Settings
Manage profile visibility, activity status, follow settings, messaging privacy, and search discovery



GET
/api/privacy
Get all privacy settings


Returns the full privacy configuration for the authenticated user, with defaults applied for any unset fields.

Parameters
Try it out
No parameters

Responses
Code	Description	Links
200	
Full privacy settings

Media type

application/json
Controls Accept header.
Example Value
Schema
{
  "profile_visibility": {
    "profile": "everyone",
    "posts": "everyone",
    "stories": "followers_only",
    "pulse": "everyone",
    "followers_list": "everyone",
    "following_list": "followers_only"
  },
  "activity_status": {
    "show_online_status": true,
    "show_last_seen": true,
    "show_read_receipts": false
  },
  "follow_settings": {
    "allow_follow_requests": true,
    "auto_approve_follow_requests": false
  },
  "messaging_privacy": "followers_only",
  "search_discovery": {
    "allow_search_by_username": true,
    "allow_search_by_email": false,
    "allow_search_by_phone": false,
    "appear_in_suggestions": true
  }
}
No links
401	
Unauthorized

No links
500	
Server error

No links

PATCH
/api/privacy/profile-visibility
Update profile visibility settings


Controls who can view each section of your profile. Send only the fields you want to change — others are left unchanged.

Visibility values:

Value	Meaning
everyone	Visible to all users
followers_only	Visible only to your followers
nobody	Hidden from everyone
Parameters
Try it out
No parameters

Request body

application/json
Example Value
Schema
{
  "profile": "everyone",
  "posts": "followers_only",
  "stories": "followers_only",
  "pulse": "everyone",
  "followers_list": "followers_only",
  "following_list": "followers_only"
}
Responses
Code	Description	Links
200	
Profile visibility updated

Media type

application/json
Controls Accept header.
Example Value
{
  "message": "Profile visibility updated",
  "profile_visibility": {
    "profile": "everyone",
    "posts": "followers_only",
    "stories": "followers_only",
    "pulse": "everyone",
    "followers_list": "followers_only",
    "following_list": "followers_only"
  }
}
No links
400	
Invalid visibility value or no fields provided

No links
401	
Unauthorized

No links
500	
Server error

No links

PATCH
/api/privacy/activity-status
Update activity status settings


Controls whether other users can see your online status, last seen time, and read receipts. Send only the fields you want to change.

Parameters
Try it out
No parameters

Request body

application/json
Example Value
Schema
{
  "show_online_status": true,
  "show_last_seen": false,
  "show_read_receipts": false
}
Responses
Code	Description	Links
200	
Activity status settings updated

Media type

application/json
Controls Accept header.
Example Value
{
  "message": "Activity status updated",
  "activity_status": {
    "show_online_status": true,
    "show_last_seen": false,
    "show_read_receipts": false
  }
}
No links
400	
No valid fields provided

No links
401	
Unauthorized

No links
500	
Server error

No links

PATCH
/api/privacy/follow-settings
Update follow settings


Controls who can follow you and whether follow requests are approved automatically.

allow_follow_requests — when false, nobody can send you follow requests.
auto_approve_follow_requests — when true, incoming follow requests are automatically accepted (no manual approval needed). Only applies when isPrivate is true.
Parameters
Try it out
No parameters

Request body

application/json
Example Value
Schema
{
  "allow_follow_requests": true,
  "auto_approve_follow_requests": false
}
Responses
Code	Description	Links
200	
Follow settings updated

Media type

application/json
Controls Accept header.
Example Value
{
  "message": "Follow settings updated",
  "follow_settings": {
    "allow_follow_requests": true,
    "auto_approve_follow_requests": false
  }
}
No links
400	
No valid fields provided

No links
401	
Unauthorized

No links
500	
Server error

No links

PATCH
/api/privacy/messaging
Update messaging privacy


Controls who can send you direct messages.

Visibility values:

Value	Meaning
everyone	Anyone on the platform can message you
followers_only	Only your followers can message you
nobody	Direct messages are disabled
Parameters
Try it out
No parameters

Request body

application/json
Example Value
Schema
{
  "messaging_privacy": "followers_only"
}
Responses
Code	Description	Links
200	
Messaging privacy updated

Media type

application/json
Controls Accept header.
Example Value
{
  "message": "Messaging privacy updated",
  "messaging_privacy": "followers_only"
}
No links
400	
Invalid or missing value

No links
401	
Unauthorized

No links
500	
Server error

No links

PATCH
/api/privacy/search-discovery
Update search & discovery settings


Controls how other users can find your account. Send only the fields you want to change.

allow_search_by_username — allows your account to appear in username search results.
allow_search_by_email — allows others to find you by your email address.
allow_search_by_phone — allows others to find you by your mobile number.
appear_in_suggestions — controls whether your account appears in "People you may know" suggestions.
Parameters
Try it out
No parameters

Request body

application/json
Example Value
Schema
{
  "allow_search_by_username": true,
  "allow_search_by_email": false,
  "allow_search_by_phone": false,
  "appear_in_suggestions": true
}
Responses
Code	Description	Links
200	
Search & discovery settings updated

Media type

application/json
Controls Accept header.
Example Value
{
  "message": "Search & discovery settings updated",
  "search_discovery": {
    "allow_search_by_username": true,
    "allow_search_by_email": false,
    "allow_search_by_phone": false,
    "appear_in_suggestions": true
  }
}
No links
400	
No valid fields provided

No links
401	
Unauthorized

No links
500	
Server error

No links
