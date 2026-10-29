# Service Pricing: Variants, Quantities & Per-Subservice Images

This covers a change to how services are priced and booked — relevant for anyone building against `InfluencerService` and `ServiceBooking`/`ServiceOrder` endpoints (web, Flutter, or any other client).

A service is now priced in one of two mutually exclusive ways, and both subservices and the base service itself can optionally be booked in a quantity greater than 1. Each subservice can also carry its own photo.

---

## 1. Reading a service

`GET /influencer-services`, `GET /influencer-services/:id`, `GET /influencer-services/my` — relevant fields on the service object:

```json
{
  "price": 0,
  "rate_type": "fixed",
  "duration": "1 hour",
  "has_variants": true,
  "allow_multiple": false,
  "subservices": [
    {
      "name": "Tap repair",
      "price": 150,
      "hours": 0.5,
      "sqft": 0,
      "allow_multiple": true,
      "image": { "fileName": "uploads/...", "fileUrl": "https://.../uploads/..." }
    },
    {
      "name": "Jet spray repair",
      "price": 300,
      "hours": 1,
      "sqft": 0,
      "allow_multiple": false,
      "image": null
    }
  ]
}
```

- **`has_variants: true`** — the flat `price` / `rate_type` / `duration` are not bookable; the customer picks from `subservices` instead, each with its own price. Render the booking screen with one row per subservice.
- **`has_variants: false`** — book against the flat `price` as before; `subservices` is typically empty.
- **`allow_multiple` (top-level)** — only meaningful when `has_variants` is `false`. When `true`, let the customer pick a quantity (stepper) of the base service itself; when `false` (the common case), it's just 1 unit.
- **`subservices[].allow_multiple`** — per-item. `true` → show a quantity stepper for that row (e.g. "4× Tap repair"). `false` → show a simple select/checkbox (0 or 1 unit), same as before this feature shipped.
- **`subservices[].image`** — optional, `null` when not set. Same `{ fileName, fileUrl }` shape as the main service gallery; `fileUrl` is already absolute and ready to display directly.

## 2. Booking with quantities

`POST /service-bookings/orders` — each item's shape:

```json
{
  "items": [
    {
      "service_id": "...",
      "booking_date": "2026-11-05",
      "time_slot": { "start": "10:00", "end": "12:00" },
      "selected_subservices": [
        { "name": "Tap repair", "quantity": 4 },
        { "name": "Jet spray repair", "quantity": 1 }
      ],
      "base_quantity": 2,
      "customer_address": { "address_line1": "...", "city": "...", "pincode": "..." },
      "notes": "optional"
    }
  ],
  "coins_to_use": 0
}
```

- `selected_subservices[].quantity` — send the customer's chosen quantity for any subservice they selected. It's safe to always include this field (default to `1`) even for subservices where `allow_multiple` is `false` — the server silently clamps those to `1` regardless of what's sent, rather than rejecting the request, so stale client state never hard-fails a booking.
- `base_quantity` — only send this when the service has `has_variants: false` and `allow_multiple: true`; otherwise omit it (it defaults to `1` and is ignored for variant-based or non-multiple services).
- **Never compute the total client-side and send it.** The server always derives the line total itself as `price × base_quantity + Σ(subservice.price × subservice.quantity)` using the service's current prices — use client-side totals only to render a live running total in the UI, not as the source of truth for what gets charged.
- The booking/order item returned in the response echoes back the resolved `selected_subservices` (now including `quantity`) plus `base_quantity`, `base_price`, and `subservices_total` — use these for the order-confirmation and order-history screens rather than re-deriving them.

## 3. Creating/editing a service (seller side)

`POST /influencer-services` / `PATCH /influencer-services/:id` accept the same fields back:

```json
{
  "has_variants": true,
  "allow_multiple": false,
  "subservices": [
    {
      "name": "Tap repair",
      "price": 150,
      "hours": 0.5,
      "sqft": 0,
      "allow_multiple": true,
      "image": { "fileName": "uploads/..." }
    }
  ]
}
```

- Subservice images go through the **existing** `POST /upload/influencer-service` batch upload endpoint — no new upload API was added. Upload the file(s) first, then submit the returned `fileName` in the subservice's `image` field.
- When `has_variants` is `true`, at least one subservice with a non-blank name and price is required; the flat `price`/`rate_type`/`duration` fields become irrelevant (and are not validated).
- When `has_variants` is `false`, the flat `price` is required as before and `subservices` can be left empty.

## 4. Where this touched existing behavior

- `selected_subservices` items used to be just `{ name }` — they're now `{ name, quantity }`. Older clients that omit `quantity` still work (it defaults to `1` server-side).
- Order/booking items gained `base_quantity` (default `1`) alongside the existing `base_price`.
- `InfluencerService.subservices[]` gained `allow_multiple` (default `false`) and `image` (default `null`); the service itself gained `has_variants` (default `false`) and `allow_multiple` (default `false`). All default to the pre-existing behavior, so services created before this change keep working unmodified.
