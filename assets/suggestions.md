
Suggestions
Suggestions for reels, ads, and users

GET
/api/suggestions
Get combined suggestions for reels, ads, and users


Parameters
Try it out
Name	Description
limit
integer
(query)
Number of suggestions to return for each category

Default value : 10

10
Responses
Code	Description	Links
200	
Suggestions retrieved successfully

No links
500	
Server error

No links

GET
/api/suggestions/users
Get suggested users


Parameters
Try it out
Name	Description
limit
integer
(query)
Default value : 10

10
Responses
Code	Description	Links
200	
User suggestions retrieved successfully

No links

GET
/api/suggestions/reels
Get suggested reels


Parameters
Try it out
Name	Description
limit
integer
(query)
Default value : 10

10
Responses
Code	Description	Links
200	
Reel suggestions retrieved successfully

No links

GET
/api/suggestions/ads
Get suggested ads


Parameters
Try it out
Name	Description
limit
integer
(query)
Default value : 10

10
Responses
Code	Description	Links
200	
Ad suggestions retrieved successfully

No links

GET
/api/suggestions/vendors
Get suggested vendors


Parameters
Try it out
Name	Description
limit
integer
(query)
Default value : 10

10
Responses
Code	Description	Links
200	
Vendor suggestions retrieved successfully

No links
Tweets
Tweets-style posting, replies, likes, reposts and discovery

