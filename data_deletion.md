DELETE
/api/settings/account/clear-content
Clear all my content and chat data (does NOT delete the account)


Soft-deletes every post, reel, tweet, and promote reel created by the current user, and clears their chat data — their own sent messages are removed and every conversation is hidden from their own view. The account itself, profile, and login remain intact.

Parameters
Try it out
No parameters

Responses
Code	Description	Links
200	
Content and chat data cleared

Media type

application/json
Controls Accept header.
Example Value
{
  "success": true,
  "message": "All your posts, reels, tweets, promote reels and chat data have been removed. Your account remains active.",
  "removed": {
    "posts_and_reels": 42,
    "tweets": 18,
    "promote_reels": 3,
    "messages": 210,
    "conversations_hidden": 12
  }
}
No links
401	
Unauthorized

No links
500	
Server error

No links

GET
/api/settings/account/export
Download all my data as a CSV file


Returns a CSV file (Content-Disposition attachment) containing the current user's profile information, plus every post/reel, tweet, and promote reel they created — each with its likes and comments count.

Parameters
Try it out
No parameters

Responses
Code	Description	Links
200	
CSV file download

Media type

text/csv
Controls Accept header.
Example Value
Schema
string
No links
401	
Unauthorized

No links
404	
User not found

No links
500	
Server error