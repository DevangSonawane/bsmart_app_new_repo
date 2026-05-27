GET
/api/users/{id}/interests
Get ad interest categories for a user profile


Parameters
Try it out
Name	Description
id *
string
(path)
User ID

id
Responses
Code	Description	Links
200	
User's ad interests and available categories

No links
404	
User not found

No links

POST
/api/users/{id}/interests
Add or update ad interest categories (logged-in user only)


Parameters
Try it out
Name	Description
id *
string
(path)
User ID (must match authenticated user)

id
Request body

application/json
Example Value
Schema
{
  "interests": [
    "string"
  ],
  "add": [
    "string"
  ],
  "remove": [
    "string"
  ]
}
Responses
Code	Description	Links
200	
Interests updated successfully

No links
400	
Invalid category value(s)

No links
401	
Unauthorized

No links
403	
Not allowed to update another user's interests

No links
404	
User not found


