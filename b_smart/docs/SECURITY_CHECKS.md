# Security & RLS Checklist

Follow these steps to validate that the mobile app works safely with Supabase row-level security (RLS) and auth tokens.

1. Environment & Secrets
   - [ ] Confirm `SUPABASE_URL` and `SUPABASE_ANON_KEY` are set in environment (.env) for local testing and not committed.
2. Auth Tokens
   - [ ] Verify Supabase client uses session tokens for requests: authenticated requests should include Authorization header with Bearer token.
   - [ ] Test auth state changes (login/logout) and ensure client.auth.currentUser updates accordingly.
3. RLS Policies
   - [ ] Review RLS policies for tables: `posts`, `users`, `wallets`, `transactions`, `follows`, `comments`.
   - [ ] Run queries from unauthenticated context to confirm policies block access.
   - [ ] Run queries as authenticated user and confirm policies allow only permitted rows (e.g., wallet read only by owner).
4. RPC & Edge Functions
   - [ ] RPCs that mutate wallet or perform transfers must be implemented server-side and guarded with SECURITY DEFINER or proper permission checks.
   - [ ] Test RPCs with valid and invalid inputs to confirm authorization checks.
5. Storage
   - [ ] Ensure storage buckets intended for user uploads have proper public/private settings and rules (e.g., `post_images` may be public or use signed URLs).
6. Logging & Monitoring
   - [ ] Add server-side logging for transfer RPCs and critical actions.
7. CI / Staging
   - [ ] Run the above checks against a staging Supabase instance before production.

