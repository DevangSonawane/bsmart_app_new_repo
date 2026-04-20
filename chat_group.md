POST
/api/chat/conversations
Create or return a direct conversation or pending request


Parameters
Try it out
No parameters
Request body

Example Value
Schema
{
  "participantId": "string"
}
Responses
Code	Description	Links
200	
Conversation returned successfully
Media type

Controls Accept header.
Example Value
Schema
{
  "_id": "string",
  "isGroup": true,
  "groupName": "string",
  "groupAvatar": "string",
  "groupAdmin": "string",
  "createdBy": "string",
  "isRequest": true,
  "requestStatus": "pending",
  "requestedBy": "string",
  "participants": [
    {
      "_id": "string",
      "username": "string",
      "full_name": "string",
      "avatar_url": "string"
    }
  ],
  "lastMessage": "string",
  "lastMessageAt": "2026-04-20T11:58:11.990Z",
  "unreadCount": 0,
  "createdAt": "2026-04-20T11:58:11.990Z",
  "updatedAt": "2026-04-20T11:58:11.990Z"
}
No links
400	
Invalid request
No links
401	
Unauthorized
No links
404	
Participant not found
No links
500	
Server error
No links

GET
/api/chat/conversations
Get all conversations for the logged-in user


Parameters
Try it out
Name	Description
type
string
(query)
Fetch normal conversations or only incoming message requests
Available values : normal, requests

Default value : normal


Responses
Code	Description	Links
200	
Conversations fetched successfully
Media type

Controls Accept header.
Example Value
Schema
[
  {
    "_id": "string",
    "isGroup": true,
    "groupName": "string",
    "groupAvatar": "string",
    "groupAdmin": "string",
    "createdBy": "string",
    "isRequest": true,
    "requestStatus": "pending",
    "requestedBy": "string",
    "participants": [
      {
        "_id": "string",
        "username": "string",
        "full_name": "string",
        "avatar_url": "string"
      }
    ],
    "lastMessage": "string",
    "lastMessageAt": "2026-04-20T11:58:11.951Z",
    "unreadCount": 0,
    "createdAt": "2026-04-20T11:58:11.951Z",
    "updatedAt": "2026-04-20T11:58:11.951Z"
  }
]
No links
401	
Unauthorized
No links
500	
Server error
No links

POST
/api/chat/groups
Create a new group conversation


Parameters
Try it out
No parameters
Request body

Example Value
Schema
{
  "participantIds": [
    "string"
  ],
  "groupName": "string",
  "groupAvatar": "string"
}
Responses
Code	Description	Links
201	
Group conversation created successfully
Media type

Controls Accept header.
Example Value
Schema
{
  "_id": "string",
  "isGroup": true,
  "groupName": "string",
  "groupAvatar": "string",
  "groupAdmin": "string",
  "createdBy": "string",
  "isRequest": true,
  "requestStatus": "pending",
  "requestedBy": "string",
  "participants": [
    {
      "_id": "string",
      "username": "string",
      "full_name": "string",
      "avatar_url": "string"
    }
  ],
  "lastMessage": "string",
  "lastMessageAt": "2026-04-20T11:58:11.954Z",
  "unreadCount": 0,
  "createdAt": "2026-04-20T11:58:11.954Z",
  "updatedAt": "2026-04-20T11:58:11.954Z"
}
No links
400	
Invalid request
No links
401	
Unauthorized
No links
404	
One or more participants not found
No links
500	
Server error
No links

PATCH
/api/chat/groups/{conversationId}
Update a group's name or avatar


Parameters
Try it out
Name	Description
conversationId *
string
(path)

Request body

Example Value
Schema
{
  "groupName": "string",
  "groupAvatar": "string"
}
Responses
Code	Description	Links
200	
Group updated successfully
Media type

Controls Accept header.
Example Value
Schema
{
  "_id": "string",
  "isGroup": true,
  "groupName": "string",
  "groupAvatar": "string",
  "groupAdmin": "string",
  "createdBy": "string",
  "isRequest": true,
  "requestStatus": "pending",
  "requestedBy": "string",
  "participants": [
    {
      "_id": "string",
      "username": "string",
      "full_name": "string",
      "avatar_url": "string"
    }
  ],
  "lastMessage": "string",
  "lastMessageAt": "2026-04-20T11:58:11.956Z",
  "unreadCount": 0,
  "createdAt": "2026-04-20T11:58:11.956Z",
  "updatedAt": "2026-04-20T11:58:11.956Z"
}
No links
400	
Invalid conversationId
No links
401	
Unauthorized
No links
403	
Only the group admin can update the group
No links
404	
Group conversation not found
No links
500	
Server error
No links

POST
/api/chat/groups/{conversationId}/members
Add a member to a group conversation


Parameters
Try it out
Name	Description
conversationId *
string
(path)

Request body

Example Value
Schema
{
  "userId": "string"
}
Responses
Code	Description	Links
200	
Group member added successfully
Media type

Controls Accept header.
Example Value
Schema
{
  "_id": "string",
  "isGroup": true,
  "groupName": "string",
  "groupAvatar": "string",
  "groupAdmin": "string",
  "createdBy": "string",
  "isRequest": true,
  "requestStatus": "pending",
  "requestedBy": "string",
  "participants": [
    {
      "_id": "string",
      "username": "string",
      "full_name": "string",
      "avatar_url": "string"
    }
  ],
  "lastMessage": "string",
  "lastMessageAt": "2026-04-20T11:58:11.958Z",
  "unreadCount": 0,
  "createdAt": "2026-04-20T11:58:11.958Z",
  "updatedAt": "2026-04-20T11:58:11.958Z"
}
No links
400	
Invalid request
No links
401	
Unauthorized
No links
403	
Only the group admin can add members
No links
404	
Group conversation or user not found
No links
500	
Server error
No links

DELETE
/api/chat/groups/{conversationId}/members/{userId}
Remove a member from a group conversation or leave the group


Parameters
Try it out
Name	Description
conversationId *
string
(path)

userId *
string
(path)

Responses
Code	Description	Links
200	
Group member removed successfully
Media type

Controls Accept header.
Example Value
Schema
{
  "_id": "string",
  "isGroup": true,
  "groupName": "string",
  "groupAvatar": "string",
  "groupAdmin": "string",
  "createdBy": "string",
  "isRequest": true,
  "requestStatus": "pending",
  "requestedBy": "string",
  "participants": [
    {
      "_id": "string",
      "username": "string",
      "full_name": "string",
      "avatar_url": "string"
    }
  ],
  "lastMessage": "string",
  "lastMessageAt": "2026-04-20T11:58:11.960Z",
  "unreadCount": 0,
  "createdAt": "2026-04-20T11:58:11.960Z",
  "updatedAt": "2026-04-20T11:58:11.960Z"
}
No links
400	
Invalid request
No links
401	
Unauthorized
No links
403	
Not authorized to remove this member
No links
404	
Group conversation or member not found
No links
500	
Server error
No links

GET
/api/chat/online-users
Get currently online user IDs


Parameters
Try it out
Name	Description
ids
string
(query)
Optional comma-separated list of user IDs to filter against

Responses
Code	Description	Links
200	
Online users fetched successfully
Media type

Controls Accept header.
Example Value
Schema
{
  "onlineUserIds": [
    "string"
  ]
}
No links
401	
Unauthorized
No links
500	
Server error
No links

GET
/api/chat/conversations/{conversationId}/messages
Get paginated messages for a conversation


Parameters
Try it out
Name	Description
conversationId *
string
(path)

page
integer
(query)
Default value : 1

limit
integer
(query)
Default value : 20

Responses
Code	Description	Links
200	
Messages fetched successfully
Media type

Controls Accept header.
Example Value
Schema
{
  "messages": [
    {
      "_id": "string",
      "conversationId": "string",
      "sender": "string",
      "text": "string",
      "mediaUrl": "string",
      "mediaType": "image",
      "audioDuration": 0,
      "seenBy": [
        "string"
      ],
      "reactions": [
        {
          "userId": "string",
          "emoji": "string",
          "createdAt": "2026-04-20T11:58:11.962Z"
        }
      ],
      "isDeleted": true,
      "deletedAt": "2026-04-20T11:58:11.962Z",
      "createdAt": "2026-04-20T11:58:11.962Z",
      "updatedAt": "2026-04-20T11:58:11.962Z"
    }
  ],
  "page": 0,
  "limit": 0,
  "hasMore": true
}
No links
400	
Invalid conversationId
No links
401	
Unauthorized
No links
404	
Conversation not found
No links
500	
Server error
No links

POST
/api/chat/conversations/{conversationId}/messages
Send a new message in a conversation


Parameters
Try it out
Name	Description
conversationId *
string
(path)

Request body

Example Value
Schema
{
  "text": "string",
  "mediaUrl": "string",
  "mediaType": "image"
}
Responses
Code	Description	Links
200	
Message created successfully
Media type

Controls Accept header.
Example Value
Schema
{
  "_id": "string",
  "conversationId": "string",
  "sender": "string",
  "text": "string",
  "mediaUrl": "string",
  "mediaType": "image",
  "audioDuration": 0,
  "seenBy": [
    "string"
  ],
  "reactions": [
    {
      "userId": "string",
      "emoji": "string",
      "createdAt": "2026-04-20T11:58:11.964Z"
    }
  ],
  "isDeleted": true,
  "deletedAt": "2026-04-20T11:58:11.964Z",
  "createdAt": "2026-04-20T11:58:11.964Z",
  "updatedAt": "2026-04-20T11:58:11.964Z"
}
No links
400	
Invalid request
No links
401	
Unauthorized
No links
404	
Conversation not found
No links
500	
Server error
No links

PUT
/api/chat/conversations/{conversationId}/accept
Accept an incoming message request


Parameters
Try it out
Name	Description
conversationId *
string
(path)

Responses
Code	Description	Links
200	
Message request accepted successfully
Media type

Controls Accept header.
Example Value
Schema
{
  "_id": "string",
  "isGroup": true,
  "groupName": "string",
  "groupAvatar": "string",
  "groupAdmin": "string",
  "createdBy": "string",
  "isRequest": true,
  "requestStatus": "pending",
  "requestedBy": "string",
  "participants": [
    {
      "_id": "string",
      "username": "string",
      "full_name": "string",
      "avatar_url": "string"
    }
  ],
  "lastMessage": "string",
  "lastMessageAt": "2026-04-20T11:58:11.965Z",
  "unreadCount": 0,
  "createdAt": "2026-04-20T11:58:11.965Z",
  "updatedAt": "2026-04-20T11:58:11.965Z"
}
No links
400	
Invalid request or request is not pending
No links
401	
Unauthorized
No links
403	
Only the recipient can accept
No links
404	
Conversation not found
No links
500	
Server error
No links

DELETE
/api/chat/conversations/{conversationId}/decline
Decline an incoming message request


Parameters
Try it out
Name	Description
conversationId *
string
(path)

Responses
Code	Description	Links
200	
Message request declined successfully
Media type

Controls Accept header.
Example Value
Schema
{
  "success": true,
  "conversationDeleted": true
}
No links
400	
Invalid request or request is not pending
No links
401	
Unauthorized
No links
403	
Only the recipient can decline
No links
404	
Conversation not found
No links
500	
Server error
No links

POST
/api/chat/conversations/{conversationId}/voice
Upload and send a voice message in one step


Parameters
Try it out
Name	Description
conversationId *
string
(path)

Request body

audio
string($binary)
duration
string
Duration in seconds
Responses
Code	Description	Links
200	
Voice message created successfully
Media type

Controls Accept header.
Example Value
Schema
{
  "_id": "string",
  "conversationId": "string",
  "sender": "string",
  "text": "string",
  "mediaUrl": "string",
  "mediaType": "image",
  "audioDuration": 0,
  "seenBy": [
    "string"
  ],
  "reactions": [
    {
      "userId": "string",
      "emoji": "string",
      "createdAt": "2026-04-20T11:58:11.968Z"
    }
  ],
  "isDeleted": true,
  "deletedAt": "2026-04-20T11:58:11.968Z",
  "createdAt": "2026-04-20T11:58:11.968Z",
  "updatedAt": "2026-04-20T11:58:11.968Z"
}
No links
400	
Invalid request
No links
401	
Unauthorized
No links
404	
Conversation not found
No links
500	
Server error
No links

PUT
/api/chat/messages/{messageId}/seen
Mark a message as seen by the logged-in user


Parameters
Try it out
Name	Description
messageId *
string
(path)

Responses
Code	Description	Links
200	
Message updated successfully
Media type

Controls Accept header.
Example Value
Schema
{
  "_id": "string",
  "conversationId": "string",
  "sender": "string",
  "text": "string",
  "mediaUrl": "string",
  "mediaType": "image",
  "audioDuration": 0,
  "seenBy": [
    "string"
  ],
  "reactions": [
    {
      "userId": "string",
      "emoji": "string",
      "createdAt": "2026-04-20T11:58:11.969Z"
    }
  ],
  "isDeleted": true,
  "deletedAt": "2026-04-20T11:58:11.969Z",
  "createdAt": "2026-04-20T11:58:11.969Z",
  "updatedAt": "2026-04-20T11:58:11.969Z"
}
No links
400	
Invalid messageId
No links
401	
Unauthorized
No links
403	
Forbidden
No links
404	
Message not found
No links
500	
Server error
No links

POST
/api/chat/messages/{id}/reaction
Add or replace the logged-in user's reaction on a message


Parameters
Try it out
Name	Description
id *
string
(path)

Request body

Example Value
Schema
{
  "emoji": "string"
}
Responses
Code	Description	Links
200	
Reaction updated successfully
Media type

Controls Accept header.
Example Value
Schema
{
  "_id": "string",
  "conversationId": "string",
  "sender": "string",
  "text": "string",
  "mediaUrl": "string",
  "mediaType": "image",
  "audioDuration": 0,
  "seenBy": [
    "string"
  ],
  "reactions": [
    {
      "userId": "string",
      "emoji": "string",
      "createdAt": "2026-04-20T11:58:11.971Z"
    }
  ],
  "isDeleted": true,
  "deletedAt": "2026-04-20T11:58:11.971Z",
  "createdAt": "2026-04-20T11:58:11.971Z",
  "updatedAt": "2026-04-20T11:58:11.971Z"
}
No links
400	
Invalid request
No links
401	
Unauthorized
No links
403	
Forbidden
No links
404	
Message not found
No links
500	
Server error
No links

DELETE
/api/chat/messages/{id}/reaction
Remove the logged-in user's reaction from a message


Parameters
Try it out
Name	Description
id *
string
(path)

Responses
Code	Description	Links
200	
Reaction removed successfully
Media type

Controls Accept header.
Example Value
Schema
{
  "_id": "string",
  "conversationId": "string",
  "sender": "string",
  "text": "string",
  "mediaUrl": "string",
  "mediaType": "image",
  "audioDuration": 0,
  "seenBy": [
    "string"
  ],
  "reactions": [
    {
      "userId": "string",
      "emoji": "string",
      "createdAt": "2026-04-20T11:58:11.972Z"
    }
  ],
  "isDeleted": true,
  "deletedAt": "2026-04-20T11:58:11.972Z",
  "createdAt": "2026-04-20T11:58:11.972Z",
  "updatedAt": "2026-04-20T11:58:11.972Z"
}
No links
400	
Invalid messageId
No links
401	
Unauthorized
No links
403	
Forbidden
No links
404	
Message not found
No links
500	
Server error
No links

DELETE
/api/chat/messages/{messageId}
Unsend a message sent by the logged-in user


Parameters
Try it out
Name	Description
messageId *
string
(path)

Responses
Code	Description	Links
200	
Message unsent successfully
Media type

Controls Accept header.
Example Value
Schema
{
  "success": true,
  "messageId": "string"
}
No links
400	
Invalid messageId
No links
401	
Unauthorized
No links
403	
Forbidden
No links
404	
Message not found
No links
500	
Server error
No links

POST
/api/chat/conversations/{conversationId}/media
Upload one or more media files for a chat conversation


Parameters
Try it out
Name	Description
conversationId *
string
(path)

Request body

media
array<string>
Responses
Code	Description	Links
200	
Media uploaded successfully
Media type

Controls Accept header.
Example Value
Schema
{
  "media": [
    {
      "mediaUrl": "string",
      "mediaType": "image",
      "originalName": "string",
      "filename": "string",
      "mimetype": "string",
      "size": 0
    }
  ],
  "mediaUrl": "string",
  "mediaType": "image"
}
No links
400	
Invalid request
No links
401	
Unauthorized
No links
404	
Conversation not found
No links
500	
Server error
No link