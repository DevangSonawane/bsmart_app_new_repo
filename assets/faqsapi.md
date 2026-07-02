Public Endpoints (No Auth — For Website)
List all FAQs

GET /api/faq

Query params (all optional):
  app_source  – member | vendor
  category    – general | account | payment | vendor | member | ads | other

Response 200:
{
  "success": true,
  "total": 5,
  "data": [
    {
      "_id": "665f...",
      "question": "How do I recharge my wallet?",
      "answer": "Go to Wallet → Recharge → Enter amount → Pay via Razorpay.",
      "category": "payment",
      "app_source": "vendor",
      "order": 1,
      "is_active": true,
      "createdAt": "2026-07-01T..."
    }
  ]
}
Filter examples:


GET /api/faq                          → all active FAQs
GET /api/faq?app_source=vendor        → vendor FAQs + both
GET /api/faq?app_source=member        → member FAQs + both
GET /api/faq?category=payment         → payment FAQs only
GET /api/faq?app_source=vendor&category=payment
Get single FAQ

GET /api/faq/:id

Response 200:
{
  "success": true,
  "data": { ...faq object }
}

Response 404:
{ "success": false, "message": "FAQ not found" }