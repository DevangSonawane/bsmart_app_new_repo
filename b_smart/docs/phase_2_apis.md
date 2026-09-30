 
bSmart – Phase 2 API Documentation
Environment: Development
 Base URL: https://bsmart-backend-dev.bsmart.workers.dev
 Swagger: https://bsmart-backend-dev.bsmart.workers.dev/api-docs/#/
Common Headers
All authenticated endpoints require:
Authorization: Bearer <token>
Content-Type: application/json

Modules
User Role Switch
Influencer Products
Influencer Services
Cart
Checkout
Payment Verification
Order Tracking
Service Bookings

1. User Role Switch
PATCH /api/users/:id/role
Switches a user between member and influencer.
Request: Switch to Member
{
  "role": "member"
}

Request: Switch to Influencer
All five influencer fields are required.
{
  "role": "influencer",
  "business_type": "Fashion",
  "store_name": "Aniket's Closet",
  "store_description": "Curated streetwear and accessories",
  "products_type": ["clothing", "accessories"],
  "service_type": ["styling consultation"]
}

Success Response (200)
{
  "success": true,
  "id": "68f...",
  "role": "influencer",
  "influencer_profile": {
    "business_type": "Fashion",
    "store_name": "Aniket's Closet",
    "store_description": "Curated streetwear and accessories",
    "products_type": ["clothing", "accessories"],
    "service_type": ["styling consultation"]
  }
}

Error Responses
Code
Meaning
400
Invalid role value, or a required influencer field is missing (e.g. {"message": "store_name is required"})
403
Trying to change another user's role without admin rights
404
User not found


2. Influencer Products
Endpoints
Method
Path
Access
POST
/api/influencer-products
Influencer only
GET
/api/influencer-products
Public (marketplace browse)
GET
/api/influencer-products/my
Authenticated
GET
/api/influencer-products/:id
Public
PATCH
/api/influencer-products/:id
Owner only
DELETE
/api/influencer-products/:id
Owner only

Create Product
POST /api/influencer-products
 Access: Authenticated, role must be influencer
 Note: At least one image is required.
{
  "images": [{ "fileName": "uploads/users/.../product1.jpg" }],
  "name": "Classic Brown Leather Tote",
  "category": "Fashion",
  "brand": "UrbanHide",
  "short_description": "A timeless everyday tote in genuine leather.",
  "key_highlights": ["Premium full-grain leather", "Handstitched", "Water resistant"],

  "mrp": 2999,
  "selling_price": 2499,
  "stock_quantity": 25,
  "seller_sku": "SKU-001",
  "track_inventory": true,
  "status": "active",
  "variants": [
    { "color": "#8B5E3C", "size": "One Size", "stock_quantity": 25, "price": 2499 }
  ],

  "package_weight": 1.2,
  "weight_unit": "kg",
  "dimensions": { "length": 30, "width": 20, "height": 10, "unit": "cm" },
  "dispatch_time": "1-2 Days",
  "hsn_gst": "4202",
  "country_of_origin": "India",
  "return_policy": "7 Days Replacement",
  "use_store_delivery_settings": true,
  "use_store_return_policy": true,
  "warranty": "None"
}



Field Groups
Group
Fields
Basic info
images, name, category, brand, short_description, key_highlights
Pricing & inventory
mrp, selling_price, stock_quantity, seller_sku, track_inventory, status, variants
Shipping & compliance
package_weight, weight_unit, dimensions, dispatch_time, hsn_gst, country_of_origin
Policies
return_policy, use_store_delivery_settings, use_store_return_policy, warranty


3. Influencer Services
Endpoints
Method
Path
Access
POST
/api/influencer-services
Influencer only
GET
/api/influencer-services
Public (marketplace browse, supports search)
GET
/api/influencer-services/my
Authenticated
GET
/api/influencer-services/:id
Public
PATCH
/api/influencer-services/:id
Owner only
DELETE
/api/influencer-services/:id
Owner only

Create Service
POST /api/influencer-services
 Access: Authenticated, role must be influencer
{
  "images": [],
  "name": "Home Cleaning",
  "category": "Home Services",
  "provider": "Sparkle Clean Co.",
  "short_description": "Thorough home cleaning with eco-friendly products.",
  "key_highlights": ["All equipment included", "Eco-friendly products", "Trained staff"],

  "price": 999,
  "rate_type": "starting_from",
  "duration": "1 hour",
  "subservices": [
    { "name": "Deep clean", "hours": 3, "price": 2499 }
  ],

  "service_method": "at_customer_location",
  "weekly_availability": {
    "monday":    [{ "start": "09:00", "end": "17:00" }],
    "tuesday":   [{ "start": "09:00", "end": "17:00" }],
    "wednesday": [{ "start": "09:00", "end": "17:00" }],
    "thursday":  [{ "start": "09:00", "end": "17:00" }],
    "friday":    [{ "start": "09:00", "end": "17:00" }],
    "saturday":  [],
    "sunday":    []
  },
  "visible_to_customers": true
}

Notes
images is optional for services (products require at least one).
An empty array for a weekday means Unavailable, matching the UI.
Allowed Values
Field
Values
rate_type
starting_from, fixed, per_hour, per_session
service_method
at_customer_location, online, at_my_location


Search & Filter (Products and Services)
Available on both public list endpoints:
 GET /api/influencer-products and GET /api/influencer-services
Parameter
Description
q=<text>
Case-insensitive search across name, description, category, brand/provider and key highlights
category=<name>
Exact category match

Both can be combined:
GET /api/influencer-services?q=cleaning&category=Home+Services


4. Cart
Method
Path
Purpose
GET
/api/cart
View cart with live prices and stock
POST
/api/cart/items
Add a product
PATCH
/api/cart/items/:productId
Change quantity or variant (quantity 0 removes the item)
DELETE
/api/cart/items/:productId
Remove one item
DELETE
/api/cart
Clear the cart

Add to Cart: Request Body
{
  "product_id": "...",
  "quantity": 1,
  "variant": { "color": "#8B5E3C", "size": "One Size" }
}


5. Checkout
POST /api/orders/checkout
{
  "payment_method": "wallet",
  "shipping_address": {
    "name": "Aniket",
    "phone": "9876543210",
    "address_line1": "221B Baker St",
    "city": "Mumbai",
    "state": "MH",
    "pincode": "400001"
  }
}

payment_method can be wallet or razorpay.
Payment Methods
Wallet
Coins are deducted immediately (1 coin = ₹1, the same rate used for ad budgets).
The order is returned as paid / confirmed.
Stock is decremented and the cart is cleared.
All of this happens in one atomic transaction.
Razorpay
Creates a real Razorpay order using the existing RAZORPAY_KEY_ID / RAZORPAY_SECRET (same keys as vendor packages).
Returns the following for the frontend to open Razorpay Checkout:
{
  "order": { ... },
  "razorpay": { "order_id": "...", "amount": 0, "key_id": "..." }
}

The order stays pending. Stock and cart are not touched until payment is verified, so nothing is lost if the buyer abandons payment.

6. Payment Verification
POST /api/orders/:id/verify-payment
Call this after Razorpay Checkout succeeds.
{
  "razorpay_order_id": "...",
  "razorpay_payment_id": "...",
  "razorpay_signature": "..."
}


7. Order Tracking
Method
Path
Access / Description
GET
/api/orders
Buyer's own order history
GET
/api/orders/:id
Details of a single order
PATCH
/api/orders/:id/cancel
Buyer cancels (only while pending / confirmed / processing)
GET
/api/orders/seller/mine
Influencer sees orders containing their products (only their line items)
PATCH
/api/orders/:id/status
Seller or admin advances the status

Cancellation Behaviour
Wallet payments are refunded to the wallet instantly.
Razorpay payments are refunded through Razorpay's refund API.
Items are restocked in both cases.
Order Status Flow
confirmed → processing → shipped → delivered


8. Service Bookings
Services have no cart. The user books one service directly with a chosen date and time slot, so the create call is the checkout.
Create Booking
POST /api/service-bookings
{
  "service_id": "...",
  "booking_date": "2026-10-05",
  "time_slot": { "start": "10:00", "end": "12:00" },
  "selected_subservices": [{ "name": "Deep clean" }],
  "customer_address": {
    "address_line1": "...",
    "city": "...",
    "pincode": "..."
  },
  "payment_method": "wallet"
}

Server-Side Validation (before any charge)
Check
What it does
Availability
Looks up the service's weekly_availability for that weekday and rejects the request if the time slot doesn't fully fit inside a published slot
Conflict
Returns 409 if the slot overlaps another active booking for the same service (no double-booking)
Price integrity
Subservices are matched by name against the service's own list; prices always come from the server, never from the client
Address
customer_address is required only when service_method is at_customer_location

Payment
Payment works the same way as for products:
Wallet: instant deduction; the booking is returned as paid / confirmed.
Razorpay: creates a Razorpay order for frontend checkout; the booking stays pending until verified.
Verify payment: POST /api/service-bookings/:id/verify-payment (same signature verification as orders)
Endpoints
Method
Path
Access / Description
POST
/api/service-bookings
Any authenticated user can book
POST
/api/service-bookings/:id/verify-payment
Buyer
GET
/api/service-bookings
Buyer's own bookings
GET
/api/service-bookings/:id
Buyer, booking details
PATCH
/api/service-bookings/:id/cancel
Buyer cancels before the service starts; refunded if already paid
GET
/api/service-bookings/seller/mine
Influencer sees bookings for their services
PATCH
/api/service-bookings/:id/status
Seller or admin updates the status

Booking Status Flow
confirmed → in_progress → completed





9. Wishlist
Endpoints
Method
Path
Purpose
GET
/api/wishlist
Get all wishlisted items with full product data, newest first
POST
/api/wishlist/items
Add a product to the wishlist
DELETE
/api/wishlist/items/:productId
Remove one item
DELETE
/api/wishlist
Clear the whole wishlist

Access: Authenticated
Add to Wishlist: Request Body
POST /api/wishlist/items
{
  "product_id": "..."
}

Adding is idempotent: if the product is already in the wishlist, no error is returned.
Get Wishlist: Response
GET /api/wishlist
{
  "success": true,
  "total": 2,
  "products": [
    {
      "...full InfluencerProduct object...": "",
      "images": ["<resolved image URLs>"],
      "wishlisted_at": "2026-09-29T08:30:00.000Z"
    }
  ]
}

Notes
Each item is the full InfluencerProduct object (not just the ID), with resolved image URLs.
Each item includes a wishlisted_at timestamp.
Items are sorted newest-added first.
If a wishlisted product has been deleted, it is silently left out of the response instead of causing an error.

10. Store Profile
New Fields on influencer_profile
Field
Type
Example
service_areas
array of strings
["Mumbai", "Online"]
languages
array of strings
["English", "Hindi"]
store_type
string
"Personal Store"
trust_badges
array of strings
["Professional", "Trusted", "Reliable"]

These fields are optional. They can be sent during the role switch (PATCH /api/users/:id/role) or updated any time later with the endpoint below.
Endpoints
Method
Path
Access
PATCH
/api/users/me/store-profile
Influencer only (own profile)
GET
/api/users/:id/store-profile
Public

Update Store Profile
PATCH /api/users/me/store-profile
You can send any subset of the fields. Only the fields you include are updated.
{
  "service_areas": ["Mumbai", "Online"],
  "languages": ["English", "Hindi"],
  "store_type": "Personal Store",
  "trust_badges": ["Professional", "Trusted", "Reliable"]
}

Get Store Profile
GET /api/users/:id/store-profile
Returns everything the storefront header needs in a single call.
{
  "store": {
    "store_name": "Harsh Nikharge's Store",
    "store_type": "Personal Store",
    "about": "...",
    "service_areas": ["Mumbai", "Online"],
    "languages": ["English", "Hindi"],
    "trust_badges": ["Professional", "Trusted", "Reliable"],
    "followers_count": 0,
    "following_count": 0,
    "is_following": false,
    "product_count": 0,
    "service_count": 0,
    "member_since": "..."
  }
}

Notes
This endpoint uses optional authentication, so it works for both logged-in and anonymous viewers.
is_following is calculated only when the request includes a valid token. For anonymous viewers it is returned as false.
11. Saved Addresses
Endpoints
Method
Path
Purpose
GET
/api/addresses
List saved addresses, default first
POST
/api/addresses
Save a new address
PATCH
/api/addresses/:id
Update an address (owner only)
DELETE
/api/addresses/:id
Delete an address (soft delete)
PATCH
/api/addresses/:id/default
Set an address as the default

Access: Authenticated
Save Address
POST /api/addresses
{
  "label": "Home",
  "name": "Aniket",
  "phone": "9876543210",
  "address_line1": "221B Baker St",
  "city": "Mumbai",
  "state": "Maharashtra",
  "pincode": "400001"
}

Default Address Rules
Situation
Behaviour
First address saved
Automatically becomes the default
Default address deleted
The next most recent address is automatically made the default
Changing the default manually
Use PATCH /api/addresses/:id/default

Notes
Deletion is a soft delete. The address is hidden from the list but not permanently removed.
GET /api/addresses always returns the default address first.
Only the owner can update or delete an address.
Using Saved Addresses at Checkout
Both checkout flows already accept an address object inline:
Flow
Endpoint
Address field
Product checkout
POST /api/orders/checkout
shipping_address
Service booking
POST /api/service-bookings
customer_address

Recommended frontend flow:
Fetch saved addresses with GET /api/addresses.
Pre-select the default address (the first item in the list).
Let the user pick a different saved address or add a new one.
Pass the selected address object directly as shipping_address or customer_address at checkout.
This way users don't have to retype their address every time.

