# Developer onboarding — b_smart (Flutter)

Prerequisites:
- Flutter SDK (see flutter.dev)
- Dart SDK (bundled with Flutter)
- A Supabase project with the same schema used by the React app.

Local setup:
1. Copy `.env.example` to `.env` and fill in `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
2. flutter pub get
3. Start the app:
   - flutter run -d <device>

Important files:
- `lib/config/supabase_config.dart` — runtime override for Supabase keys (loaded from `.env` in main).
- `lib/services/supabase_service.dart` — central Supabase queries and RPC usage.
- `lib/routes.dart` — centralized routes.
- `lib/theme/` — design tokens and theme.
- `lib/screens/` — app screens (home, reels, profile, create post, wallet, notifications).

Testing:
- Run unit/widget tests:
  - flutter test

Notes:
- If backend RPCs like `transfer_coins` or `append_post_id` are missing, create migrations in Supabase or ask backend team to add them. See `b_smart/docs/SECURITY_CHECKS.md` and `b_smart/docs/QA_CHECKLIST.md`.

