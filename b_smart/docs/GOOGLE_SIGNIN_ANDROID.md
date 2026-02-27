# Google Sign-In Android (Api 10 / DEVELOPER_ERROR) Fix

Error `PlatformException(sign_in_failed, com.google.android.gms.common.api.ApiException: 10:, null, null)` means **DEVELOPER_ERROR**: the app's package name or SHA-1 does not match any **Android** OAuth client in Google Cloud.

**You must have an OAuth client of type "Android"** (not just Web). One Web client alone will always give Api 10 on Android.

---

## Do this first: Create the Android OAuth client

1. Open: **[Google Cloud Console → Credentials](https://console.cloud.google.com/apis/credentials)**  
   (Use the same Google Cloud project as your Web client.)

2. Click **"+ CREATE CREDENTIALS"** → **"OAuth client ID"**.

3. If asked, choose **"Application type"** = **Android** (not Web).

4. Fill in **exactly**:
   - **Name:** e.g. `b_smart Android`
   - **Package name:** `com.example.b_smart`
   - **SHA-1 certificate fingerprint:**  
     `AE:B3:4B:02:3E:0F:74:8B:17:5E:8F:58:FC:86:8E:10:08:57:71:3F`

5. Click **Create**.  
   You’ll get an **Android** Client ID (it can be different from your Web client ID).

6. **(Optional)** Add SHA-256 to the same Android client (edit the client, add fingerprint):  
   `F3:D5:9A:83:CF:63:5A:EC:A8:ED:F6:CD:78:91:4D:26:F3:FD:EF:B0:FF:65:59:57:88:09:A6:A1:DA:8D:0E:0A`

7. Wait **5–10 minutes** for Google to propagate, then run the app again.

---

## Your current signing (debug)

- **Package name:** `com.example.b_smart`
- **SHA-1 (debug keystore):** `AE:B3:4B:02:3E:0F:74:8B:17:5E:8F:58:FC:86:8E:10:08:57:71:3F`
- **SHA-256 (debug keystore):** `F3:D5:9A:83:CF:63:5A:EC:A8:ED:F6:CD:78:91:4D:26:F3:FD:EF:B0:FF:65:59:57:88:09:A6:A1:DA:8D:0E:0A`

## You need both clients in the same project

| Client type | Purpose |
|------------|--------|
| **Android** | So the Android app is recognized (package name + SHA-1). **Required to fix Api 10.** |
| **Web** | Used as `serverClientId` in the app and in Supabase Dashboard (with client secret). |

Keep your existing **Web** client for Supabase. Add the **Android** client as above; you don’t need to change the Web client ID in the app.

## Verify SHA-1 on your machine

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

The SHA-1 in the output must match the one in the Android OAuth client in Google Cloud.

## After adding the Android client

- Wait 5–10 minutes.
- Rebuild: `flutter clean && flutter pub get && flutter run`.
