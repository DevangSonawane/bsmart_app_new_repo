BugReports
In-app bug reporting — technical/app issues



POST
/api/bug-reports
Submit a bug report


Parameters
Try it out
No parameters

Request body

application/json
Example Value
Schema
{
  "category": "app_crash",
  "description": "App crashes when I open the wallet screen",
  "attachments": [
    {
      "url": "string",
      "type": "image"
    }
  ],
  "app_version": "2.4.1",
  "os_type": "android",
  "os_version": "14",
  "device_model": "Pixel 7",
  "network_type": "wifi"
}
Responses
Code	Description	Links
201	
Report submitted

Media type

application/json
Controls Accept header.
Example Value
{
  "success": true,
  "message": "Thank you. Your report has been submitted successfully.",
  "data": {
    "ticket_id": "BUG-A1B2C3D4",
    "status": "new",
    "priority": "medium"
  }
}
No links
400	
Validation error

No links

GET
/api/bug-reports/my
Get my submitted bug reports


Parameters
Try it out
Name	Description
status
string
(query)
Available values : new, in_progress, fixed, closed


--
Responses
Code	Description	Links
200	
My bug reports