Content Reports
Report posts, reels, stories, ads, comments and tweets



GET
/api/content-reports/reasons
Get available report reasons


Parameters
Try it out
No parameters

Responses
Code	Description	Links
200	
Report reasons list

Media type

application/json
Controls Accept header.
Example Value
{
  "success": true,
  "reasons": [
    "I just don't like it",
    "Bullying or unwanted contact",
    "Suicide, self-injury or eating disorders",
    "Violence, hate or exploitation",
    "Selling or promoting restricted items",
    "Nudity or sexual activity",
    "Scam, fraud or spam",
    "False information"
  ]
}
No links

POST
/api/content-reports
Report a post, reel, story, ad, comment or tweet


Parameters
Try it out
No parameters

Request body

application/json
Example Value
Schema
{
  "content_type": "post",
  "content_id": "67e3aa001122334455667801",
  "reason": "Scam, fraud or spam",
  "details": "This content looks misleading."
}
Responses
Code	Description	Links
201	
Report submitted successfully

Media type

application/json
Controls Accept header.
Example Value
{
  "success": true,
  "message": "Report submitted successfully",
  "report": {
    "_id": "67e3aa001122334455668101",
    "reporter_id": "67e3aa001122334455667711",
    "owner_id": "67e3aa001122334455667712",
    "content_type": "post",
    "content_id": "67e3aa001122334455667801",
    "reason": "Scam, fraud or spam",
    "details": "This content looks misleading.",
    "status": "pending",
    "createdAt": "2026-03-28T10:00:00.000Z"
  }
}
No links
400	
Validation error or already reported

No links
401	
Not authorized

No links
404	
Content not found

No links

GET
/api/content-reports/my
Get my submitted reports


Parameters
Try it out
No parameters

Responses
Code	Description	Links
200	
My report list

Media type

application/json
Controls Accept header.
Example Value
{
  "success": true,
  "total": 2,
  "reports": [
    {
      "_id": "67e3aa001122334455668101",
      "reporter_id": "67e3aa001122334455667711",
      "owner_id": "67e3aa001122334455667712",
      "content_type": "post",
      "content_id": "67e3aa001122334455667801",
      "reason": "Scam, fraud or spam",
      "details": "This content looks misleading.",
      "status": "pending",
      "createdAt": "2026-03-28T10:00:00.000Z",
      "updatedAt": "2026-03-28T10:00:00.000Z"
    }
  ]
}