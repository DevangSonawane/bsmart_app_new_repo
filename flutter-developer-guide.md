# Flutter Developer Guide — Calling, Marketplace Upgrade & Wallet Credits

This guide covers everything a Flutter developer needs to integrate three recent backend features:

1. [Voice/video calling](#1-voicevideo-calling)
2. [Marketplace upgrade — multi-vendor cart, hybrid coins+Razorpay payment, influencer subscriptions](#2-marketplace-upgrade)
3. [Wallet credits — signup bonus & daily login reward](#3-wallet-credits)

Base URL for all REST calls: `https://bsmart-backend-dev.bsmart.workers.dev/api` (dev). All endpoints below are relative to this, e.g. `POST /calls/voip-token` means `POST {base}/api/calls/voip-token`. Every endpoint requires `Authorization: Bearer <jwt>` unless stated otherwise.

---

## 1. Voice/video calling

Call **signaling** (who's calling whom, ringing, accept/reject/hangup) happens over the existing **Socket.io connection** — the same one used for chat. Call **media** (actual audio) is handled separately via Cloudflare Realtime (a WebRTC SFU), using plain REST calls plus raw WebRTC (`flutter_webrtc` package).

### 1.1 Socket connection & registration

Connect to the same Socket.io server already used for chat (`io(baseUrl, {...})`). Once connected, you **must** emit a `register` event with the user's **JWT access token** (not a bare user ID):

```dart
socket.emit('register', jwtToken);
```

The server verifies the token server-side and binds `socket.userId` to the decoded user id. All call events below are scoped to this registration — if you skip it, every `call:*` emit will fail with `{ error: 'Not registered' }`.

### 1.2 Call signaling events

| Direction | Event | Payload | Notes |
|---|---|---|---|
| Client → Server | `call:initiate` | `{ receiverId, callType }` (`callType`: `'voice'` \| `'video'`) | Ack callback returns `{ callId, status: 'pending' }` or `{ error }`. Requires the caller and receiver to **mutually follow** each other — check first with `GET /calls/can-call/:userId` → `{ can_call: boolean }`. |
| Server → Receiver | `call:ringing` | `{ callId, callerId, callerName, callerAvatar, callType }` | Show your incoming-call UI (CallKit / full-screen notification) here. |
| Client → Server | `call:accept` | `{ callId }` | Ack returns `{ callId, status: 'answered' }`. Only the receiver may call this. |
| Server → Caller | `call:accepted` | `{ callId }` | Caller should now start the WebRTC publish flow (§1.3). |
| Client → Server | `call:reject` | `{ callId, reason }` | No ack; one-way. |
| Server → Caller | `call:rejected` | `{ callId }` | |
| Client → Server | `call:end` | `{ callId, reason }` | Works both pre-pickup ("cancel") and mid-call ("hang up"). |
| Server → Other party | `call:ended` | `{ callId, status, duration_seconds, end_reason }` | |
| Server → Both | `call:missed` | `{ callId }` | Fired automatically after a 45s ring timeout. |
| Client → Server | `call:track-published` | `{ callId }` | Emit this right after your `POST /calls/:id/webrtc/publish` call succeeds (§1.3). |
| Server → Both | `call:peer-ready` | `{ callId }` | Fired once **both** sides have published — this is your signal to pull the other side's audio (§1.3). |

A call is only ever `voice` type today — **video isn't wired up yet** (audio-only MVP); `callType: 'video'` is accepted by the API but the media flow below only negotiates one audio track.

### 1.3 Media: Cloudflare Realtime SFU (audio)

The backend never touches raw media — it only proxies SDP exchanges to Cloudflare's Calls API (you can't call Cloudflare directly from the app; the App Token is a server secret). The flow, once `call:accepted` fires (caller) or right after you call `call:accept` successfully (receiver), is the same on both sides:

1. **Get local mic audio** via `flutter_webrtc`'s `getUserMedia({'audio': true})`.
2. **Create an `RTCPeerConnection`** with a STUN-only ICE server — no TURN needed, Cloudflare's SFU is the relay itself:
   ```dart
   final config = {
     'iceServers': [{'urls': 'stun:stun.cloudflare.com:3478'}],
   };
   ```
3. Add the local audio track, create an SDP **offer**, `setLocalDescription`, then **wait for ICE gathering to complete** (`iceGatheringState == complete`) before sending it anywhere — Cloudflare's API is a single HTTP round trip per SDP exchange (no trickle-ICE signaling channel), so the offer must already contain every gathered candidate.
4. **Publish**: `POST /calls/:id/webrtc/publish` with body:
   ```json
   { "sdpOffer": "<full local SDP offer>", "mid": "<the audio transceiver's mid, e.g. \"0\">" }
   ```
   Response: `{ success: true, sdpAnswer: "<SDP answer>" }` — set this as your peer connection's remote description.
5. Emit `call:track-published` over the socket (§1.2).
6. On receiving `call:peer-ready`, **pull** the other side's track: `POST /calls/:id/webrtc/pull` (no body). Response:
   ```json
   { "success": true, "requiresImmediateRenegotiation": true, "sdpOffer": "<new SDP offer, or null>" }
   ```
   If `requiresImmediateRenegotiation` is `true`: `setRemoteDescription` with that offer, create an SDP **answer**, `setLocalDescription`, wait for ICE gathering again, then `PUT /calls/:id/webrtc/renegotiate` with `{ "sdpAnswer": "<your answer>" }`.
7. The remote audio track arrives via your peer connection's `onTrack` callback — attach it to an audio renderer/player. This is the moment to flip your UI from "Connecting…" to the live call screen with a timer.
8. On hangup (either side), call the `call:end` socket event — the backend closes both Cloudflare sessions server-side; you don't need to call anything else.

### 1.4 REST endpoints (call history & permission)

| Endpoint | Purpose |
|---|---|
| `GET /calls/can-call/:userId` | `{ can_call: boolean }` — check before showing a call button (requires mutual follow). |
| `GET /calls?page=&limit=` | Paginated call history (incoming + outgoing) for the logged-in user. |
| `GET /calls/:id` | Single call detail — 404 if you weren't a party to it. |
| `POST /calls/voip-token` | `{ voip_token }` — register this iOS device's **Apple PushKit** token (see §1.5). Android uses the existing `POST /push/register-fcm` instead. |

### 1.5 iOS background ringing (PushKit)

For the phone to ring when the app is backgrounded or killed, iOS needs a **PushKit VoIP push**, separate from a normal notification. Register the device's PushKit token via `POST /calls/voip-token` on app start / token refresh. The backend sends a push with `apns-push-type: voip` and topic `<bundle-id>.voip` containing `{ type: 'incoming_call', callId, callerId, callerName, callerAvatar, callType }` — wire your `PKPushRegistry` delegate to show the native CallKit incoming-call UI from this payload, then connect the Socket.io call flow once the user answers from the lock screen.

Android gets an equivalent high-priority FCM data message (same payload shape, `type: 'incoming_call'`) — the exact `data` keys should be confirmed with whoever wires up `flutter_callkit_incoming` on the Flutter side, since that integration hasn't been built/tested yet.

---

## 2. Marketplace upgrade

### 2.1 Multi-vendor service booking cart

Previously, booking a service was one service at a time. Now a customer can add subservices from **multiple different services (even different sellers)** and check out together in a single order:

**`POST /service-bookings/orders`**
```json
{
  "items": [
    {
      "service_id": "...",
      "booking_date": "2026-11-05",
      "time_slot": { "start": "10:00", "end": "12:00" },
      "selected_subservices": [{ "name": "Deep clean" }],
      "customer_address": { "address_line1": "...", "city": "...", "pincode": "..." },
      "notes": "optional"
    }
  ],
  "coins_to_use": 50
}
```
- `items` can contain 1 or more entries — each is validated independently the same way a single booking always was (availability, slot conflicts, subservice pricing).
- `customer_address` is only required per-item when that service's method is `at_customer_location`.
- See §2.2 for `coins_to_use`.

Response (coins fully cover the total): `{ success: true, order: {...} }` with `order.payment_status === 'paid'` — booking is confirmed immediately, no further action needed.

Response (remainder needs Razorpay): `{ success: true, order: {...}, razorpay: { order_id, amount, currency, key_id } }` — open Razorpay Checkout (standard **order** mode, not subscription mode) with these, then call:

**`POST /service-bookings/orders/:id/verify-payment`**
```json
{ "razorpay_order_id": "...", "razorpay_payment_id": "...", "razorpay_signature": "..." }
```
(the three fields Razorpay's checkout `handler` callback gives you). On success, the order and every item's booking flip to `confirmed`.

### 2.2 Hybrid payment: coins first, Razorpay for the rest

This same pattern — `coins_to_use` in the request, `razorpay` block only present if something's still owed — is now used in **three** places:

| Flow | Endpoint |
|---|---|
| Service booking checkout | `POST /service-bookings/orders` |
| Product cart checkout | `POST /orders/checkout` — now takes `{ coins_to_use, shipping_address }` (the old `payment_method: 'wallet'\|'razorpay'` field is gone) |
| Becoming an influencer | `POST /listing-subscriptions/account` (see §2.3 — different payment model, same idea) |

Important behavior: **coins are not deducted from the wallet until the full payment (coins + any Razorpay remainder) is actually confirmed.** If the user abandons the Razorpay checkout sheet, nothing is charged and no coins are lost — so it's safe to let the user retry freely. Always re-check the wallet balance (`GET /wallet/me`) before showing how many coins are "available" to spend, since a concurrent purchase elsewhere could have changed it (the server clamps `coins_to_use` to the real balance regardless, so over-requesting is never a hard error).

**UI suggestion**: a single drag/slider control from `0` to `min(walletBalance, orderTotal)` showing live "Coins ₹X / Razorpay ₹Y" labels — this is what the web app uses (see `PaymentSplitSlider` component for reference if useful), defaulting to `0` (fully Razorpay) unless the user drags it.

### 2.3 Becoming an influencer: 7-day free trial vs ₹99/month

This is a **true auto-debit Razorpay Subscription**, not a one-time payment — different mechanics from §2.2.

Flow:
1. User fills in store details (business type, store name, etc.) in your "Create Store" screen.
2. User picks **"7-day free trial"** or **"Subscribe now"**.
3. `POST /listing-subscriptions/account` with `{ "start_trial": true | false }`. Response: `{ success: true, subscription: {...}, razorpay: { subscription_id, key_id } }`.
4. Open Razorpay Checkout in **subscription mode** (pass `subscription_id`, not `order_id`/`amount`) — this authorizes a payment mandate today regardless of which option was picked; the only difference is whether the first ₹99 charge happens today or after 7 days.
5. **Only after the Razorpay checkout `handler` fires successfully**, call the existing role-switch endpoint: `PATCH /users/:id/role` with `{ role: 'influencer', business_type, store_name, store_description, products_type, service_type }`. This ordering matters — don't flip the role before the mandate is confirmed, or an abandoned checkout grants free influencer access.

Status & management:
- `GET /listing-subscriptions/account/me` → `{ subscription }` (or `null` if never subscribed). Key fields: `status` (`created` \| `trialing` \| `active` \| `past_due` \| `halted` \| `cancelled`), `trial_ends_at`, `current_period_end`.
- `POST /listing-subscriptions/account/upgrade` — mid-trial, skip the wait and start billing today. Returns a **new** `subscription_id` requiring a fresh Checkout authorization (Razorpay can't reschedule an already-authorized mandate's first charge, so this cancels the trial subscription and creates a new one).
- `POST /listing-subscriptions/:id/cancel` — cancels the Razorpay subscription and **reverts the account to a plain member** (loses influencer role and My Store access). Pass the subscription's own `_id` (from the `GET .../me` response), not the Razorpay subscription id.
- If a renewal charge fails and Razorpay exhausts its retries, or the user cancels, a server-side webhook automatically downgrades the role the same way — no polling needed, but refresh `GET /auth/me` periodically (or on app resume) to pick up the change if it happens while the app is backgrounded.

---

## 3. Wallet credits

Both of these are **automatic** — no new endpoint to call, just new fields to read off responses you're likely already handling.

### 3.1 Signup bonus — 50 coins

Every registration path (`POST /auth/register`, `POST /auth/google/token`, `POST /auth/apple/token`) now grants **50 coins** to a brand-new account's wallet automatically. The email/password `register` response includes:
```json
{ "token": "...", "user": {...}, "registration_bonus_amount": 50 }
```
For Google/Apple, `registration_bonus_amount` is only present when the call actually created a new account (an existing user logging in via Google/Apple won't see it). Show a small "Welcome! +50 coins" moment on first successful signup using this field — don't infer it from the wallet balance alone, since that's fragile if the bonus amount ever changes.

### 3.2 Daily login reward — 5 coins, once per calendar day

`POST /auth/login` now also returns:
```json
{ "token": "...", "user": {...}, "daily_reward_granted": true, "daily_reward_amount": 5 }
```
`daily_reward_granted` is `false` (and `daily_reward_amount` is `0`) if the user already claimed today's reward (e.g., logged in earlier the same day) — this is enforced server-side per calendar day, so don't try to show the reward UI more than once per day client-side either; just trust this flag on every login response.

---

## Appendix: Razorpay Checkout modes used

Flutter apps typically use the `razorpay_flutter` package. Two distinct modes are used across this app — don't mix them up:

- **Order mode** (one-time payment) — used by service bookings, product checkout. Pass `order_id`, `amount`, `currency`. Result gives you `razorpay_order_id`, `razorpay_payment_id`, `razorpay_signature` to verify server-side.
- **Subscription mode** (recurring mandate) — used only for becoming an influencer (§2.3). Pass `subscription_id` instead of `order_id`/`amount`. The checkout UI looks similar but authorizes a recurring mandate rather than a single charge.

In both modes, `key_id` from the relevant create-response is the Razorpay public key to pass to the checkout widget.
