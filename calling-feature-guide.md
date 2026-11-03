# Calling: Voice & Video (1:1 and Group)

Reference for the full calling feature set — 1:1 voice/video, group voice/video, adding people to an ongoing call, call history, and ringing behavior. Relevant for anyone building against these endpoints/events (web, or a future Flutter implementation — group/video calling has not been built on mobile yet, only the original audio-only 1:1 flow referenced in `flutter-developer-guide.md`).

Base URL: `https://bsmart-backend-dev.bsmart.workers.dev/api`. All endpoints below require `Authorization: Bearer <jwt>`. Socket events ride the same Socket.io connection chat already uses (`socket.emit('register', jwtToken)` first).

---

## 1. Architecture at a glance

Two parallel stacks, deliberately **not** merged into one data model:

| | 1:1 calls | Group calls |
|---|---|---|
| Model | `CallLog` (`caller_id`/`receiver_id` pair) | `GroupCall` (`participants[]` roster) |
| Socket module | `src/sockets/callSignaling.js` | `src/sockets/groupCallSignaling.js` |
| REST controller | `src/controllers/call.controller.js` | `src/controllers/groupCall.controller.js` |
| Routes | `/api/calls` | `/api/group-calls` |
| Frontend overlay | `src/components/CallOverlay.jsx` | `src/components/GroupCallOverlay.jsx` |

Both are mounted **globally** in `src/App.jsx` (not inside any one page) so an incoming call rings no matter what page you're on — see §7. Both use **Cloudflare Realtime** (an SFU) for media: each participant gets their own Cloudflare session, pushes their own track(s) to it, and pulls each other participant's track(s) from their session(s). `src/services/cloudflareRealtime.service.js` wraps the Cloudflare Calls HTTPS API and is shared, unchanged, by both stacks.

Roster/signaling changes (ringing, accept, decline, join, leave) go over **Socket.io**; actual WebRTC SDP negotiation (publish/pull/renegotiate) goes over **REST** — this split is consistent across both stacks.

---

## 2. 1:1 calls

### 2.1 `CallLog` model (`src/models/CallLog.js`)

```js
{
  caller_id, receiver_id,          // ObjectId refs
  call_type: 'voice' | 'video',
  status: 'pending' | 'answered' | 'missed' | 'rejected' | 'busy' | 'ended',
  caller_session_id, caller_tracks: [{ mid, name: 'audio'|'video' }],
  receiver_session_id, receiver_tracks: [{ mid, name }],
  started_at, answered_at, ended_at, duration_seconds, end_reason,
}
```

`caller_tracks`/`receiver_tracks` are **arrays** (one entry for audio-only, two for a video call) — this is what makes video calling possible without a new media model; a voice call still just has one `'audio'` entry.

### 2.2 Socket signaling (`call:*`)

| Event | Direction | Payload |
|---|---|---|
| `call:initiate` | → server | `{ receiverId, callType }` → ack `{ callId, status }` |
| `call:ringing` | server → receiver | `{ callId, callerId, callerName, callerAvatar, callType }` |
| `call:accept` | → server | `{ callId }` → ack `{ callId, status: 'answered' }` |
| `call:accepted` | server → caller | `{ callId }` |
| `call:reject` | → server | `{ callId, reason }` (one-way) |
| `call:rejected` | server → caller | `{ callId }` |
| `call:end` | → server | `{ callId, reason }` — works both pre-pickup (cancel) and mid-call (hangup) |
| `call:ended` | server → other party | `{ callId, status, duration_seconds, end_reason }` |
| `call:missed` | server → both | fires automatically 45s after `call:initiate` if never accepted/rejected |
| `call:track-published` | → server | `{ callId }`, sent right after a successful REST publish |
| `call:peer-ready` | server → both | sent once **both** sides have published — the signal to pull |

A busy check happens inside `call:initiate` — if either party already has a `pending`/`answered` call, a `status: 'busy'` `CallLog` is created and returned immediately, no ringing.

### 2.3 WebRTC media — `POST/PUT /api/calls/:id/webrtc/*`

**Publish** `POST /:id/webrtc/publish`
```json
{ "sdpOffer": "<local SDP offer>", "tracks": [{ "mid": "0", "kind": "audio" }, { "mid": "1", "kind": "video" }] }
```
- One entry for voice, two for video — `kind` comes straight from `pc.getTransceivers()[i].sender.track.kind` client-side, no SDP parsing needed.
- The legacy `{ sdpOffer, mid }` shape (implying one audio track) is still accepted for backward compatibility.
- Response: `{ success, sdpAnswer }` — set as the RTCPeerConnection's remote description.
- Creates the caller's/receiver's own Cloudflare session lazily on first publish (not at ring time).

**Pull** `POST /:id/webrtc/pull` — no body. Pulls the peer's `tracks[]` (all of them, audio+video, in one request). Response: `{ success, requiresImmediateRenegotiation, sdpOffer }` — if `requiresImmediateRenegotiation` is true, answer it via:

**Renegotiate** `PUT /:id/webrtc/renegotiate` — `{ "sdpAnswer": "..." }`.

### 2.4 Frontend flow (`CallOverlay.jsx`)

1. `getUserMedia({ audio: true, video: isVideo })`.
2. Build an `RTCPeerConnection` (STUN-only: `stun:stun.cloudflare.com:3478`), add local tracks, `createOffer` → `setLocalDescription` → wait for ICE gathering to fully complete (Cloudflare's API is a single HTTP round trip, no trickle-ICE).
3. `POST .../publish` with the offer + `tracks` built from `pc.getTransceivers()`.
4. Emit `call:track-published`; once `call:peer-ready` arrives, `POST .../pull`, answering any renegotiation offer.
5. `pc.ontrack` routes incoming tracks by `event.track.kind` — video → a `<video>` element, audio → a separate `<audio>` element (always present, even on video calls).

---

## 3. Group calls

### 3.1 `GroupCall` model (`src/models/GroupCall.js`)

```js
{
  conversation_id: ObjectId | null,   // null for a call escalated from a 1:1 (§4.2) — not tied to any group chat
  initiator_id,
  call_type: 'voice' | 'video',
  status: 'active' | 'ended',         // live from creation — the initiator is seeded in as already-joined
  participants: [{
    user_id,
    status: 'invited' | 'joined' | 'declined' | 'missed' | 'left',
    session_id, tracks: [{ mid, name }],
    joined_at, left_at,
  }],
  started_at, ended_at,
}
```

A group call always rings **every member** of the group `Conversation` it's started from (no ad-hoc member picker at creation) — any member can start it, not just the admin. Pressing "call" on a group that already has an active call **joins it** instead of creating a duplicate. Concurrent **joined** participants are capped at 12 (`MAX_GROUP_CALL_PARTICIPANTS` in `groupCallSignaling.js`) — invites still go out regardless of group size, the cap only blocks *joining* once 12 are already in.

### 3.2 Socket signaling (`group-call:*`)

| Event | Payload |
|---|---|
| `group-call:initiate` → ack | `{ conversationId, callType }` → `{ groupCallId, status, callType, conversationTitle, conversationAvatar, roster }` (`status: 'active'` for a fresh call, `'joined'` if it joined an existing one) |
| `group-call:ringing` (server → invitee) | `{ groupCallId, conversationId, conversationTitle, conversationAvatar, initiatorId, initiatorName, initiatorAvatar, callType }` |
| `group-call:join` → ack | `{ groupCallId }` → `{ status: 'joined', roster }` — rejects with `{error:'This call is full'}` at the 12-participant cap |
| `group-call:decline` | `{ groupCallId }` (one-way) |
| `group-call:leave` | `{ groupCallId, reason }` — if no one remains joined, the call is marked `ended` |
| `group-call:participant-joined` / `-left` (server → other joined participants) | `{ groupCallId, userId, name?, avatar? }` |
| `group-call:track-published` → server | `{ groupCallId }`, broadcasts `group-call:peer-ready` to every other joined participant |
| `group-call:peer-ready` (server → joined participants) | `{ groupCallId, fromUserId }` — pull from this one peer |
| `group-call:missed` (server → one invitee) | fires 45s after that *individual* invite if unanswered — doesn't affect the call for anyone else |

**`roster`** (returned on join, and seeded client-side on initiate) is an array of `{ userId, name, avatar, sessionId, tracks }` for every **already-published** joined participant — a joined-but-not-yet-published peer is intentionally excluded (pulling from them immediately would 409) and gets picked up later via `group-call:peer-ready` once they do publish, same as anyone else.

### 3.3 WebRTC media — `POST/PUT /api/group-calls/:id/webrtc/*`

Same shapes as the 1:1 endpoints (§2.3), with one difference: **pull is per-peer**.

**Pull** `POST /:id/webrtc/pull` — `{ "fromUserId": "..." }`. Pulls exactly one peer's tracks. The client calls this once per peer — for every entry in its initial `roster`, and again on each `group-call:peer-ready` — rather than one call pulling everyone. Pulls on the client are run **serially** (never overlapping) specifically so an incoming `ontrack` event can be reliably attributed to "whichever peer is currently being pulled," since Cloudflare doesn't label a pulled track with its origin.

### 3.4 Call history

`GET /api/group-calls` — paginated, same shape as `GET /api/calls` (`{ total, page, limit, totalPages, calls }`), populated `conversation_id` (`groupName`/`groupAvatar`, `null` for an escalated call) and `participants.user_id`. The frontend's Calls tab fetches both endpoints and merges them client-side into one date-grouped, chronological feed (`ChatPage.jsx`'s `combinedCallHistory`) — there's no backend cross-collection endpoint.

---

## 4. Adding people to an ongoing call

### 4.1 Inviting into an already-active group call

`group-call:invite` → ack — `{ groupCallId, userIds }`. Requester must be a currently-`joined` participant. New `userIds` not already in `participants` are added with `status: 'invited'` and rung exactly like a fresh `group-call:initiate` (same ring event, push notification, 45s timeout) via a shared `ringInvitees()` helper in `groupCallSignaling.js`.

### 4.2 Escalating a live 1:1 call into a group call

`call:escalate-to-group` → ack — `{ callId, userIds }`. Since a `GroupCall` is a different model from `CallLog`, this doesn't "convert" the document — it:
1. Ends the 1:1 `CallLog` (`status: 'ended', end_reason: 'escalated_to_group'`), closing both original Cloudflare sessions.
2. Creates a new `GroupCall` (`conversation_id: null`) with **both original parties pre-seeded as already-`joined`** plus the new `userIds` as `'invited'`.
3. Emits **`call:escalated`** `{ oldCallId, groupCallId, callType }` to *both* original parties.
4. Rings the new invitees via the same `ringInvitees()` helper as §4.1.

The two original parties' Cloudflare sessions are **not** carried over to the new `GroupCall` — both sides redo `getUserMedia` → publish into the new session, the same as any other participant joining a call. This is a deliberate simplification: migrating a live SFU session across two different models/session-management paths would be fragile for little benefit; the brief (~1s) reconnect is an acceptable, well-understood tradeoff.

On the frontend, both `CallOverlay` and `GroupCallOverlay` independently subscribe to `call:escalated` (the chat socket's pub/sub already supports multiple listeners per event) — `CallOverlay` tears down the 1:1 UI, `GroupCallOverlay` enters `'active'` directly (skipping the normal ring/join handshake, since it's already joined server-side) and begins media negotiation with an empty initial roster.

---

## 5. Ringing & background-tab alerting

- **Ringtone**: synthesized with the Web Audio API (`src/utils/callMedia.js`'s `playRingChime`) — a classic "ring-ring … pause" cadence using the traditional dual-tone pair (440Hz + 480Hz), repeating every 3s. No audio asset to ship/license. The AudioContext is silently created/resumed on the page's first click/keypress (browsers block un-gestured audio), so it's already unlocked by the time a real call rings.
- **45-second ring timeout**: `RING_TIMEOUT_MS` in both `callSignaling.js` and `groupCallSignaling.js`. If unanswered, the call (or, for a group call, just that one invitee) is marked `missed` automatically and both sides are notified.
- **Background-tab alerting** (also in `callMedia.js`): when a call rings, the document title flashes between the real title and "📞 Incoming call…" (`startTitleFlash`/`stopTitleFlash`), and — if the browser's Notification permission is already granted and the tab is hidden — a system notification is shown (`showIncomingCallNotification`). Permission is requested once per app load (`requestNotificationPermission`), not aggressively re-prompted.

---

## 6. Frontend architecture notes

- **Global mounting**: `CallOverlay`/`GroupCallOverlay` are mounted once in `src/App.jsx` (alongside `GlobalLoader`, gated on `isAuthenticated && token`), *not* inside any individual page. Earlier they lived only in `ChatPage.jsx`, which meant navigating away from Messages unmounted them and incoming calls silently stopped ringing — this is why they're global now.
- **Starting a call from any page**: pages that need to trigger `startCall`/`startGroupCall` (currently just `ChatPage.jsx`'s 1:1/group headers) import the shared ref singletons from `src/utils/callRefs.js` (`callOverlayRef`, `groupCallOverlayRef` — plain `createRef()` objects, not a context) rather than holding their own local ref, since the actual overlay instances now live in `App.jsx`.
- **`CallOverlay`'s compact widget mode**: a 1:1 call defaults to a small draggable widget anchored bottom-right (drag via `onMouseDown`/`onTouchStart`), expandable to the full-screen call UI and back (`Maximize2`/`Minimize2`). Audio/video elements exist in both the compact and full-screen JSX branches, so switching re-attaches the live `MediaStream`s from a cached ref (`remoteStreamsRef`) rather than losing them. `GroupCallOverlay` does not have this compact mode yet — it's still full-screen only.
- **Shared, pure utilities** live in `src/utils/callMedia.js` (ICE-gathering wait, ringtone synthesis, title-flash/notification helpers) specifically so `CallOverlay` and `GroupCallOverlay` don't duplicate them — everything else (the actual WebRTC/roster state machines) is intentionally **not** shared between the two components, since a 1:1 call's fixed two-party shape and a group call's dynamic N-party shape differ enough that forcing a shared abstraction would add more complexity than it saves.

---

## Appendix: known limitations / possible follow-ups

- No passive "call in progress" indicator inside a group chat for members who haven't pressed the call button yet — they only see it if they're online when the ring fires, or open the chat and press "call" themselves (which joins the live call).
- `GroupCallOverlay` has no compact/minimizable widget mode yet (unlike `CallOverlay`) — it's full-screen only while in a group call.
- No active-speaker highlighting in the group-call tile grid (no audio-level detection).
- Mobile (Flutter) only has the original 1:1 **audio-only** flow built — none of video calling, group calling, add-people, or the merged call history exist there yet.
