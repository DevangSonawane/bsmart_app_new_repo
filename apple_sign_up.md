We need to implement **Sign in with Apple** in the existing bSmart Flutter iOS app to address Apple's Guideline 4.8 rejection.

### IMPORTANT CONTEXT

I have already completed the Apple-side configuration:

* Sign in with Apple is enabled for the existing bSmart App ID in Apple Developer.
* The **Sign in with Apple capability** has already been added to the existing Xcode project/Runner target.
* Do NOT create a new Xcode project.
* Do NOT create a new Bundle ID/App ID.
* Do NOT modify unrelated authentication or app functionality.

The backend implementation is NOT ready yet.

For this task, implement the **Flutter frontend, Apple authentication logic, state handling, models/services, and clean backend integration interface**, but DO NOT invent or hard-code a final backend API contract.

I will provide the backend API documentation/endpoints later, after which we will integrate the actual backend request.

---

# 1. FIRST: INSPECT THE EXISTING AUTHENTICATION ARCHITECTURE

Before changing code, inspect the existing project carefully.

Understand:

* Current login screen
* Current signup/login flow
* Existing Google Sign-In implementation
* Existing authentication service/provider/repository
* Existing API service
* Existing user model
* Existing authentication state management
* Existing token/session storage
* Existing navigation after successful login
* Existing logout flow
* Existing error handling
* Existing loading states
* Existing UI/theme/design system

Follow the existing project architecture instead of creating a completely separate authentication architecture.

The goal is for Apple Sign-In to behave consistently with the existing Google Sign-In flow.

Do NOT duplicate existing authentication logic unnecessarily.

---

# 2. ADD SIGN IN WITH APPLE TO THE LOGIN/SIGNUP UI

Add a polished **Continue with Apple** button to the existing authentication screen.

The button should feel native, premium, and consistent with Apple's design language while still matching the bSmart UI.

Preferred hierarchy:

* Existing Google login button
* Continue with Apple button
* Existing email/phone/login method if applicable

Do not redesign the entire login screen.

Only make the necessary UI changes.

### Apple button design

Create a high-quality Apple Sign-In button.

Requirements:

* Apple logo on the left
* Text such as:
  **Continue with Apple**
* Proper vertical/horizontal alignment
* Correct touch target
* Rounded corners consistent with the existing bSmart design
* Good typography
* Proper spacing
* Visually premium
* Clean and minimal
* Should look similar in quality to Apple's own authentication UI

Use an appropriate Apple logo asset/icon.

If an SVG is required, use a proper Apple logo SVG asset rather than drawing an inaccurate logo manually.

Do NOT distort, recolor, rotate, or otherwise modify the Apple logo incorrectly.

Do not use a random low-quality Apple logo from an untrusted source.

If the project already has an appropriate Apple icon package or asset system, use that.

Prefer a native/standard Apple logo representation where possible.

---

# 3. APPLE BUTTON STATES

The Apple button must have proper states:

### Default

Display:

Apple logo + "Continue with Apple"

### Loading

When authentication is in progress:

* Prevent multiple taps
* Show an appropriate loading indicator/state
* Keep the layout stable
* Do not allow the user to trigger multiple Apple authentication requests

### Error

If Apple authentication fails:

* Stop loading
* Display an appropriate user-friendly error
* Do not crash the app
* Do not leave the UI permanently disabled

### Cancellation

If the user cancels the Apple authentication sheet:

* Do NOT show this as a serious error
* Simply return the UI to its normal state

---

# 4. IMPLEMENT REAL APPLE AUTHENTICATION ON IOS

Implement the actual native Apple authentication flow in Flutter.

Use a maintained, appropriate Flutter Sign in with Apple implementation/package compatible with the current project and Flutter version.

Do NOT fake the Apple authentication flow.

The Apple system authentication UI must appear when the user taps:

**Continue with Apple**

The implementation should obtain the Apple credential required for backend verification.

At minimum, properly handle the Apple authentication response including the relevant:

* identity token
* authorization code
* user identifier (`sub` / Apple user identifier as applicable)
* email when available
* given name when available
* family name when available
* nonce/state where applicable

Do not trust client-provided identity information as authenticated identity.

The backend will verify the Apple credential later.

---

# 5. NONCE / SECURITY

Implement the Apple authentication flow using a secure nonce.

The nonce should be:

* cryptographically secure/random
* generated for each authentication attempt
* correctly associated with the Apple authentication request
* passed through the authentication flow
* available for the backend integration later

Do not hard-code a nonce.

Do not use a predictable nonce.

Do not hard-code authentication tokens.

Do not put any Apple private key, secret, or server credential into the Flutter app.

---

# 6. IMPORTANT: BACKEND IS NOT READY YET

Do NOT invent the backend API.

Do NOT assume something like:

POST /auth/apple

unless you are creating it only as an internal abstraction/interface and clearly mark it as pending backend integration.

Instead, create a clean abstraction such as:

AppleAuthService
AppleCredential
AppleAuthenticationResult
or whatever naming matches the existing architecture.

The Apple authentication service should produce a structured result that can later be passed to the backend.

For example, conceptually:

Apple authentication
↓
Apple credential/result
↓
Backend authentication service
↓
Existing bSmart session/token handling

The exact API request will be implemented later when I provide the backend developer's documentation/endpoints.

Do not create fake production API calls.

If the existing architecture requires an authentication repository/provider, integrate Apple into that architecture but leave the actual backend request behind a clearly identifiable TODO/interface.

---

# 7. DO NOT BREAK GOOGLE LOGIN

The existing Google login must continue working exactly as before.

After your changes:

Google:

Continue with Google
→ existing Google authentication
→ existing backend
→ existing bSmart session
→ existing home/navigation

Apple:

Continue with Apple
→ Apple system authentication
→ obtain Apple credential
→ pending backend integration layer
→ existing bSmart session/navigation once backend is connected

Do not modify the Google authentication implementation unless absolutely necessary.

---

# 8. HANDLE APPLE FIRST LOGIN CORRECTLY

Apple may provide the user's name/email information during the first authorization.

The implementation must account for:

* givenName
* familyName
* email
* Apple user identifier
* identity token
* authorization code

IMPORTANT:

Apple may not provide the user's name every time.

Therefore:

* Do not assume name is always available.
* Do not overwrite an existing name with null/empty values.
* Preserve first-login information appropriately.
* The backend will ultimately persist the user's Apple identity and first-login information.

---

# 9. SUPPORT HIDE MY EMAIL

The user may choose:

**Hide My Email**

Apple can provide a private relay address such as:

[example@privaterelay.appleid.com](mailto:example@privaterelay.appleid.com)

The Flutter app must NOT reject this email.

Do not add any validation that requires the email to be Gmail, Outlook, etc.

Treat the Apple-provided email as a valid email.

Do not ask the user to reveal their personal email.

---

# 10. ACCOUNT LINKING / EXISTING USERS

Do not implement dangerous automatic account merging based only on email.

Apple's stable Apple user identifier should ultimately be used by the backend to identify an Apple account.

If the existing bSmart authentication architecture has account-linking functionality, inspect it and design the Apple flow so that it can support linking later.

Do not create duplicate client-side user records.

Backend account-linking rules will be finalized once the backend API documentation is provided.

---

# 11. AUTHENTICATION STATE

Integrate Apple Sign-In with the existing authentication state management.

After successful Apple authentication, the app should be capable of transitioning into the same authenticated state used by Google login.

Use the project's existing:

* AuthProvider / Bloc / Cubit / Riverpod / Provider / GetX / repository pattern
* secure token storage
* current-user state
* navigation logic

Do not create a second independent authentication state system.

---

# 12. LOGOUT

Make sure Apple authentication does not break the existing logout flow.

Do not automatically assume that logging out of bSmart means revoking the Apple authorization.

For now, follow the existing bSmart logout/session behavior.

If Apple-specific revocation/deauthorization needs backend support, leave that clearly documented for the backend phase.

---

# 13. IOS-SPECIFIC REQUIREMENTS

Verify the existing iOS project after implementation.

Confirm:

* Sign in with Apple capability remains enabled
* Entitlements are correct
* Bundle ID remains unchanged
* No accidental changes to signing configuration
* No accidental changes to provisioning configuration
* Existing Firebase configuration is untouched unless required
* Existing Google Sign-In continues to work

Do not change signing certificates/profiles unnecessarily.

---

# 14. UI/UX QUALITY

The Apple login experience should feel like a first-class authentication option, not something added at the last minute.

Pay attention to:

* spacing
* typography
* icon sizing
* button height
* corner radius
* shadows/borders if consistent with the existing design
* dark/light appearance if bSmart supports both
* accessibility
* touch target
* loading state
* error state
* disabled state

The Apple button should visually fit into the existing bSmart login screen.

Do not make the Apple button visually inconsistent with the Google button.

---

# 15. ACCESSIBILITY

Make sure the Apple button has an appropriate semantic/accessibility label such as:

"Continue with Apple"

The button must be accessible through VoiceOver.

Do not rely only on the Apple logo for accessibility.

---

# 16. PLATFORM BEHAVIOR

This feature is primarily required for iOS.

Do not break Android.

If the existing authentication architecture is shared between Android and iOS, structure the implementation so that:

* iOS uses Sign in with Apple
* Android behavior remains unchanged unless Apple Sign-In is already intentionally supported there

Do not introduce iOS-specific code that causes Android compilation failures.

Use appropriate platform checks where required.

---

# 17. ERROR HANDLING

Handle common scenarios cleanly:

* User cancels Apple authentication
* Apple authentication fails
* Credential is unavailable
* Identity token unavailable
* Authorization code unavailable
* Network/backend integration unavailable
* Unexpected Apple authentication error
* User already authenticated
* Authentication request already in progress

Never expose raw stack traces or sensitive authentication information to the user.

Log useful debugging information only where appropriate and never log:

* identity tokens
* authorization codes
* private credentials
* secrets

---

# 18. SECURITY

Do not:

* hard-code Apple private keys
* hard-code client secrets
* hard-code tokens
* store sensitive Apple credentials in plain local storage
* log identity tokens
* log authorization codes
* trust email alone as proof of identity

The eventual backend must verify Apple's identity token.

For this frontend phase, securely obtain and hand off the credential required by the backend.

---

# 19. CODE QUALITY

Keep the implementation production-quality.

Follow the project's existing:

* naming conventions
* folder structure
* architecture
* state management
* dependency management
* error handling
* linting/formatting conventions

Do not create unnecessary files.

Do not refactor unrelated parts of the application.

Do not modify unrelated screens.

---

# 20. TESTING

After implementation, test:

### Test 1 — Apple first login

Fresh/new Apple account authorization.

Verify that:

* Apple authentication sheet appears
* authentication succeeds
* name/email information is captured when Apple provides it
* Apple user identifier is captured
* identity token is captured
* authorization code is captured
* no crash occurs

### Test 2 — Hide My Email

Select:

**Hide My Email**

Verify:

* private relay email is accepted
* no email validation error occurs
* email is preserved in the Apple authentication result

### Test 3 — Existing Apple authorization

Authenticate again using the same Apple account.

Verify the flow works even if Apple does not return the user's name again.

### Test 4 — Cancel

Open Apple authentication and cancel it.

Verify:

* no error screen
* no stuck loading state
* user remains on login screen

### Test 5 — Google

Verify existing Google login still works.

### Test 6 — Android

Verify Android still builds successfully and existing authentication is unaffected.

---

# 21. BACKEND INTEGRATION HANDOFF

At the end, provide me with a clear summary containing:

1. Files created
2. Files modified
3. Packages/dependencies added
4. Apple authentication package/version used
5. Apple capability/configuration detected
6. Apple credential fields produced by the Flutter implementation
7. Exact object/model produced for backend integration
8. Where the backend call needs to be inserted
9. Any TODOs left for backend integration
10. Any iOS configuration changes
11. Any Android considerations
12. Exact commands to run for testing/building

Most importantly, clearly identify the code location where the eventual backend endpoint will be integrated.

Do NOT invent the backend endpoint or request format.

I will provide the backend developer's API documentation and endpoints separately, and we will then connect the Apple credential to the real backend authentication API.

---

# FINAL REQUIREMENT

Before finishing, run/analyze the project enough to make sure there are no obvious:

* Dart compilation errors
* dependency conflicts
* iOS build errors
* Android compilation regressions
* null-safety issues
* broken imports
* broken authentication navigation

Do not make unrelated fixes.

The scope of this task is:

**Apple Sign-In frontend + Apple authentication logic + clean backend integration boundary.**

The backend API integration itself will be completed later after I provide the backend documentation.
