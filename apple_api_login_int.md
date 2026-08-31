We now have the actual backend API for Sign in with Apple. Please integrate the existing Apple Sign-In frontend implementation with the real backend.

IMPORTANT: Do not redesign or rewrite the existing Apple authentication implementation. Build on the Apple Sign-In implementation that is already present in this Phase-2 project.

## BACKEND API

For the native iOS app, use ONLY this endpoint:

POST https://api.bebsmart.in/api/auth/apple/token

This is the native iOS Apple authentication endpoint.

Request:

Content-Type: application/json

{
"identity_token": "string",
"full_name": "string",
"email": "string"
}

Responses:

200:
Login/registration successful, returns JWT and user.

400:
Invalid input.

401:
Invalid Apple token.

500:
Server error.

IMPORTANT:

Do NOT use these endpoints for the native Flutter iOS flow:

GET /api/auth/apple

POST /api/auth/apple/callback

Those endpoints are for the web/redirect-based Apple authentication flow.

Our Flutter app is using Apple's native AuthenticationServices flow, so it must use:

POST /api/auth/apple/token

---

# 1. INSPECT THE EXISTING CODE FIRST

Before making changes, inspect:

* lib/services/auth/apple_auth_service.dart
* lib/services/auth/auth_service.dart
* lib/models/auth/apple_auth_models.dart
* lib/screens/auth/apple_sign_in_button.dart
* lib/api/auth_api.dart
* login_screen.dart
* signup_screen.dart
* existing Google authentication implementation
* existing JWT/token storage
* existing user/session model
* existing authentication state management
* existing navigation after login

Understand how Google login currently works from Flutter → API → JWT → authenticated state.

Apple should ultimately follow the same application-level authentication flow.

Do not create a second authentication architecture.

---

# 2. CONNECT THE APPLE RESULT TO THE REAL BACKEND

The existing Apple authentication service already obtains an Apple credential/result.

It currently contains fields such as:

* userIdentifier
* identityToken
* authorizationCode
* email
* givenName
* familyName
* state
* rawNonce
* hashedNonce
* authenticatedAt

The backend API specifically expects:

{
"identity_token": "...",
"full_name": "...",
"email": "..."
}

Map the frontend result to this exact backend request.

### identity_token

Use the actual Apple identity token returned by Apple.

Do NOT send:

* authorizationCode instead of identityToken
* hashedNonce instead of identityToken
* userIdentifier instead of identityToken

The backend documentation explicitly expects:

identity_token

---

# 3. FULL NAME HANDLING

This is extremely important.

The backend documentation states:

"full_name is only ever available from Apple on a user's very first authorization ever — the client must forward it that one time since there is no other way for the backend to receive it."

Therefore construct full_name from:

givenName + familyName

For example:

givenName = "Devang"
familyName = "Sonawane"

Send:

"full_name": "Devang Sonawane"

Handle cases where only one component exists.

For example:

givenName = "Devang"
familyName = null

should produce:

"full_name": "Devang"

Do not produce:

"Devang null"

or unnecessary extra spaces.

If both are unavailable, send an empty string or the value expected by the existing backend contract, but do not fabricate a name.

IMPORTANT:

Do not overwrite a previously stored user name with an empty/null value during subsequent Apple logins.

---

# 4. EMAIL HANDLING

Use the email returned by Apple when available.

The user may select:

"Hide My Email"

In that case Apple can return an address such as:

[example@privaterelay.appleid.com](mailto:example@privaterelay.appleid.com)

This is a valid Apple-provided email.

DO NOT reject it.

DO NOT require Gmail/Outlook/etc.

DO NOT ask the user to provide another email.

For subsequent Apple authentications, Apple may not return the email again. The existing authentication architecture should therefore avoid unnecessarily replacing an existing stored email with null/empty data.

If the backend API accepts an empty email for subsequent authentication, follow the backend contract rather than inventing behavior.

If the backend requires email on every request, clearly identify that requirement rather than silently inventing a workaround.

---

# 5. CREATE THE REAL API METHOD

Implement the real backend call in the existing authentication API/service architecture.

Use:

POST https://api.bebsmart.in/api/auth/apple/token

Headers:

Content-Type: application/json

Body:

{
"identity_token": "<Apple identity token>",
"full_name": "<Apple first + last name>",
"email": "<Apple email>"
}

Do not send unnecessary fields unless the existing backend explicitly requires them.

In particular, do not add:

* authorization_code
* raw_nonce
* hashed_nonce
* state
* user_identifier

to the request body unless the backend documentation changes.

The backend API contract currently specifies only:

identity_token
full_name
email

---

# 6. RESPONSE HANDLING

Inspect the actual response model/schema used by the existing authentication APIs.

The backend documentation says the 200 response returns:

* JWT
* user

Integrate this response into the same authentication/session mechanism used by Google login.

Do NOT create a separate Apple-only token storage system.

After a successful response:

1. Extract the JWT.
2. Store it using the existing secure token/session mechanism.
3. Parse/store the returned user using the existing user model where possible.
4. Update the existing authenticated state.
5. Navigate to the same authenticated destination used by successful Google login.
6. Ensure the user is treated as logged in throughout the application.

Apple login should be indistinguishable from Google login after authentication succeeds.

---

# 7. ERROR HANDLING

Handle the documented backend errors.

### 200

Successful login/registration.

Proceed through the normal authenticated flow.

### 400

Show an appropriate user-facing authentication error.

Do not expose raw backend details unless the existing app does so consistently.

### 401

This means the Apple token is invalid.

Show an appropriate message such as:

"Apple authentication failed. Please try again."

Do not expose the identity token or other sensitive credential information.

### 500

Show a generic server error/retry message.

Do not crash the app.

Also handle:

* no internet connection
* timeout
* malformed response
* missing JWT
* unexpected response format

using the existing API error-handling architecture.

---

# 8. DO NOT LOG SENSITIVE INFORMATION

Never print/log:

* identity_token
* authorization_code
* rawNonce
* hashedNonce
* Apple private credentials

in production logs.

If debugging is necessary, log only safe metadata such as:

"Apple authentication started"
"Apple authentication cancelled"
"Apple backend authentication succeeded"
"Apple backend authentication failed: 401"

Do not log the actual token.

---

# 9. APPLE FIRST LOGIN

Make sure the first Apple login works correctly.

Test this exact flow:

User taps:

Continue with Apple

↓

Apple system authentication appears

↓

User authorizes

↓

Apple returns:

identityToken
givenName
familyName
email

↓

Flutter constructs:

{
"identity_token": "...",
"full_name": "First Last",
"email": "..."
}

↓

POST /api/auth/apple/token

↓

Backend returns JWT + user

↓

Flutter stores JWT

↓

User enters bSmart

---

# 10. HIDE MY EMAIL TEST

Test:

Continue with Apple

↓

Hide My Email

↓

Apple returns private relay email

↓

Flutter sends:

"email": "[xxxxx@privaterelay.appleid.com](mailto:xxxxx@privaterelay.appleid.com)"

↓

Backend accepts it

The app must NOT reject the private relay email.

---

# 11. RETURNING APPLE USER

Test signing in again with the same Apple account.

Apple may not return:

* givenName
* familyName
* email

again.

The implementation must not crash or create a duplicate account.

The Apple identity must ultimately be associated with the same backend user.

The backend is responsible for verifying the Apple identity token and identifying the Apple account.

Do not attempt to identify an Apple account solely by email.

---

# 12. EXISTING AUTH FLOW

Compare the Apple flow with the existing Google flow.

Apple should use the existing:

* authentication state
* JWT storage
* user storage
* navigation
* logout
* session restoration
* error handling

wherever appropriate.

Do not duplicate these systems.

---

# 13. LOGIN AND SIGNUP SCREENS

The existing Apple button has already been added to:

* Login
* Signup

Keep both.

The user should be able to tap:

"Continue with Apple"

from either authentication entry point.

If Apple returns an existing user, log them in.

If the backend creates a new user, continue through the normal authenticated onboarding/session flow.

Do not create a separate Apple signup screen unless the existing backend response requires an additional onboarding step.

---

# 14. IMPORTANT BACKEND CONTRACT RULE

Do not invent fields or endpoints.

The confirmed native endpoint is:

POST /api/auth/apple/token

The confirmed request body is:

{
"identity_token": "string",
"full_name": "string",
"email": "string"
}

If the actual server response differs from the documentation, inspect the response safely and adapt the Flutter model to the real response.

Do not modify the backend.

---

# 15. ENVIRONMENT / BASE URL

Inspect the existing API configuration.

The Apple endpoint should use the same production API base URL architecture if possible.

Do not hard-code a second API configuration if the project already has a centralized base URL.

If the existing API client uses:

https://api.bebsmart.in

then construct:

/api/auth/apple/token

through the existing API client.

Do not create duplicate HTTP client configuration.

---

# 16. SECURITY / NONCE

Keep the existing secure nonce generation in the Apple authentication flow.

Do not remove it simply because the current backend documentation only lists identity_token/full_name/email.

The Apple authentication implementation should continue generating the appropriate nonce and using it correctly with Apple's authentication flow.

Do not send rawNonce/hashedNonce to the backend unless the backend contract later explicitly requires them.

---

# 17. UI

Do not redesign the Apple button at this stage.

The existing polished Apple button implementation should remain.

Make sure the loading state covers the complete operation:

Apple authentication
→ backend API request
→ JWT/session handling

The user should not be able to tap the Apple button repeatedly while the request is in progress.

If Apple authentication succeeds but the backend request fails, return the button to its normal state and show an appropriate error.

---

# 18. TESTING

After implementation, test on a REAL iPhone.

Test:

### Test A

New Apple account → Share My Email

### Test B

New Apple account → Hide My Email

### Test C

Existing Apple account → sign in again

### Test D

Cancel Apple authentication

### Test E

Invalid/expired credential handling

### Test F

No internet/network failure

### Test G

Google login still works

### Test H

Email/password login still works

### Test I

Logout → Apple login again

### Test J

Session restoration after successful Apple login

---

# 19. BUILD VERIFICATION

Run:

flutter pub get
flutter analyze

Then test:

flutter run -d <real-ios-device>

If possible also verify:

flutter build ios --release --no-codesign

Do not make unrelated changes to the project.

---

# 20. FINAL REPORT

After implementation, report:

1. Exact files modified.
2. Exact API method added/changed.
3. Exact endpoint used.
4. Exact request body sent.
5. How full_name is constructed.
6. How Hide My Email is handled.
7. How JWT is stored.
8. How the returned user is stored.
9. How authentication state is updated.
10. Where navigation occurs after successful Apple login.
11. How errors are handled.
12. Any assumptions made because the backend documentation does not specify a response schema.
13. Any backend-side issue discovered during testing.
14. Exact commands used to verify the implementation.

IMPORTANT:

Do not change unrelated features.

Do not modify Google authentication.

Do not modify the existing location/privacy fix.

Do not modify the existing Apple Developer/Xcode capability.

The objective is specifically:

**Connect the already-implemented native Apple Sign-In frontend to the real bSmart backend endpoint `/api/auth/apple/token` and make Apple login behave exactly like the existing authenticated login flow.**
