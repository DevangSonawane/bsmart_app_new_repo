  # B-Smart Frontend — Go-Live Plan (bsmart.social)

  Scope: **frontend only**. The backend is already deployed on EC2 (via the existing GitHub Actions → PM2 pipeline) and its address is not changing. This document covers what's needed to launch the b-smart React app on the new domain, plus the handful of backend confirmations that move depends on.

  **At a glance**
  | | |
  |---|---|
  | Scope | Frontend only |
  | Domain | `bsmart.social` (root domain, no `app.` subdomain) |
  | Hosting | Hostinger |
  | API (unchanged) | `https://api.bebsmart.in` |
  | DNS / SSL | Already provisioned |

  ---

  ## 0. Already settled

  - **Domain & SSL** — `bsmart.social` is registered and pointed at Hostinger; the certificate is issued. Everything lives at the root domain.
  - **API stays put** — the backend keeps `https://api.bebsmart.in`. Only the frontend is moving, which means the app becomes **cross-origin** (bsmart.social calling bebsmart.in) instead of same-origin.
  - **Backend deploy** — already live; out of scope here.

  ---

  ## 1. Backend coordination (needs backend access, not frontend changes)

  These live in the backend's `.env` / dashboard configs, not this repo — flag them to whoever manages the EC2 box.

  - [ ] CORS allow-list (Express `cors` middleware **and** Socket.io's `cors` option) includes `https://bsmart.social`
  - [ ] Backend's `CLIENT_URL` env var is updated to `https://bsmart.social` — it drives the post-Google-login redirect and links in emails
  - [ ] Razorpay is running on **live** keys on the backend, not `rzp_test_…`
  - [ ] VAPID key pair on the backend matches the frontend's `VITE_VAPID_PUBLIC_KEY`

  ---

  ## 2. Build configuration

  Set the production env file before building — this is what gets baked into the static bundle:

  ```
  VITE_API_URL=https://api.bebsmart.in/api
  VITE_WS_URL=wss://api.bebsmart.in
  VITE_VAPID_PUBLIC_KEY=BOAfUTKo-HOQfMShB9SayCcLzpIbG6X1GAIP5Hv3s1TmaH9g0NtONCgvpxTmlTVKk3B3Xi4CE5RFAe0tnC6DI_M
  ```

  > **Note:** ~30 files call `https://api.bebsmart.in` directly instead of reading `VITE_API_URL`. Since the API address isn't changing, the build works fine as-is — it's cleanup for later, not a launch blocker.

  - [ ] `npm ci` for a clean, lockfile-exact install
  - [ ] `npm run build` — verify the `dist/` output has no build warnings worth chasing
  - [ ] `npm run preview` locally and click through login, feed, and post creation before uploading anywhere

  ---

  ## 3. Branding cleanup (recommended, not blocking)

  - [ ] Open Graph / Twitter share previews in `index.html` still point to `bebsmart.in` — update to `bsmart.social` so shared links preview correctly
  - [ ] Help & About settings pages link to `bebsmart.in/tutorials`, `/guide`, and `support@bebsmart.in` — decide whether these move to the new domain or stay as-is

  ---

  ## 4. Deploy to Hostinger

  This is a Vite single-page app using client-side routing (`BrowserRouter`), so the server needs a rewrite rule or every direct link/refresh 404s.

  - [ ] Zip the current live `public_html` before overwriting — this is the rollback copy
  - [ ] Upload the *contents* of `dist/` (not the folder itself) into `public_html/` via File Manager, FTP, or Hostinger's Git deploy
  - [ ] Add a SPA-fallback `.htaccess` (below)
  - [ ] Confirm http→https redirect is active (SSL is provisioned — verify it's enforced, not just available)

  ```apache
  # public_html/.htaccess
  RewriteEngine On
  RewriteCond %{HTTPS} off
  RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]

  RewriteCond %{REQUEST_FILENAME} !-f
  RewriteCond %{REQUEST_FILENAME} !-d
  RewriteRule ^ index.html [L]

  <IfModule mod_expires.c>
    ExpiresActive On
    ExpiresByType text/html "access plus 0 seconds"
    ExpiresByType application/javascript "access plus 1 year"
    ExpiresByType text/css "access plus 1 year"
  </IfModule>
  ```

  ---

  ## 5. Razorpay verification

  The frontend never holds a Razorpay key itself — `key_id` comes back from the backend's create-order call, so there's **no frontend code change** for payments. What needs verifying is that live payments actually clear end to end on the new domain.

  - [ ] Backend is issuing live order IDs, not test-mode orders
  - [ ] Run one real low-value recharge (₹1–10) on `https://bsmart.social`: create order → checkout modal opens → payment completes → wallet is credited
  - [ ] Test the cancel path — closing the checkout modal shouldn't leave the recharge button stuck loading
  - [ ] `checkout.razorpay.com` loads without being blocked by any CSP header set on Hostinger
  - [ ] If a webhook is configured in the Razorpay dashboard, it targets the production backend — not a stale dev URL

  ---

  ## 6. Cross-origin smoke test

  bsmart.social and api.bebsmart.in are now different domains — this is the first time the app runs cross-origin, so re-test everything that talks to the backend.

  - [ ] Email login and Google OAuth both complete and land back on bsmart.social
  - [ ] Chat sends and receives live over the Socket.io connection
  - [ ] Push notification opt-in works and a test push arrives
  - [ ] Media upload and reel playback work end to end
  - [ ] PDF export (invoices/reports) generates correctly

  ---

  ## 7. Rollback

  If something critical surfaces after launch, restore rather than patch live: restore the `public_html` zip from step 4 to instantly revert to the last known-good build, then debug the new build offline.

  ---

  ## 8. First 48 hours

  - [ ] Spot-check browser console for errors on key pages (feed, chat, wallet)
  - [ ] Watch for CORS or unexpected-logout reports from early users
  - [ ] Confirm bsmart.social stays reachable over the first day

  > No error-tracking tool (e.g. Sentry) is wired into the frontend today. Not needed for launch, but it would replace the two checks above with something that doesn't rely on someone happening to look.

  ---

  *Scope note: b-smart frontend only. Backend, dashboard, and infrastructure changes outside the four items in Section 1 are not covered here.*
