
BSMART
Social Media Platform
Push Notification Integration Guide
For Android APK Developers

Version 1.0  |  May 2026
Confidential — Internal Developer Document
1. Overview
This document describes the complete steps required for the Android APK developer to integrate Firebase Cloud Messaging (FCM) push notifications into the Bsmart mobile application.
The Bsmart backend uses AWS SNS (Simple Notification Service) as the push delivery hub. The APK is responsible for obtaining the FCM device token and registering it with the backend API. Once registered, the backend will automatically deliver push notifications to the device whenever events occur (likes, comments, follows, etc.).

Architecture
The notification flow works as follows:
User performs an action (e.g. likes a post)
Backend fires sendNotification() internally
Backend calls AWS SNS with the user's stored endpoint ARN
AWS SNS delivers the push via Firebase Cloud Messaging
FCM delivers the notification to the Android device


2. Prerequisites
Firebase Project
The Firebase project for Bsmart is already created. You will need access to it.
Firebase Project Name: bsmart
Sender ID: 775304408229
Request the google-services.json file from the backend team

Required Dependencies
Add the following to your Android project:
In project-level build.gradle:
buildscript {
  dependencies {
    classpath 'com.google.gms:google-services:4.4.1'
  }
}
In app-level build.gradle:
apply plugin: 'com.google.gms.google-services'
 
dependencies {
  implementation platform('com.google.firebase:firebase-bom:32.7.0')
  implementation 'com.google.firebase:firebase-messaging'
}
⚠️  Place the google-services.json file in the app/ directory of your Android project. Get this file from the backend team.
3. Implementation Steps
Step 1 — Create Firebase Messaging Service
Create a new class that extends FirebaseMessagingService. This class handles two things: receiving the FCM token and showing notifications when the app is in the foreground.
// BsmartFirebaseMessagingService.java
 
public class BsmartFirebaseMessagingService extends FirebaseMessagingService {
 
  @Override
  public void onNewToken(String token) {
    super.onNewToken(token);
    // Token refreshed — register with Bsmart backend
    String authToken = getAuthTokenFromStorage();
    if (authToken != null) {
      registerTokenWithBackend(token, authToken);
    }
  }
 
  @Override
  public void onMessageReceived(RemoteMessage message) {
    super.onMessageReceived(message);
    // App is in FOREGROUND — show notification manually
    String title = message.getNotification() != null
      ? message.getNotification().getTitle() : "Bsmart";
    String body  = message.getNotification() != null
      ? message.getNotification().getBody()  : "";
    showNotification(title, body);
  }
 
  private void showNotification(String title, String body) {
    NotificationCompat.Builder builder =
      new NotificationCompat.Builder(this, "bsmart_channel")
        .setSmallIcon(R.drawable.ic_notification)
        .setContentTitle(title)
        .setContentText(body)
        .setPriority(NotificationCompat.PRIORITY_HIGH)
        .setAutoCancel(true);
    NotificationManagerCompat manager =
      NotificationManagerCompat.from(this);
    manager.notify((int) System.currentTimeMillis(), builder.build());
  }
}

Step 2 — Register Service in AndroidManifest.xml
Declare the service and required permissions inside the <application> tag:
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
 
<application>
  ...
  <service
    android:name=".BsmartFirebaseMessagingService"
    android:exported="false">
    <intent-filter>
      <action android:name="com.google.firebase.MESSAGING_EVENT"/>
    </intent-filter>
  </service>
 
  <!-- Default notification channel -->
  <meta-data
    android:name="com.google.firebase.messaging.default_notification_channel_id"
    android:value="bsmart_channel"/>
</application>
Step 3 — Get FCM Token and Register with Backend
Call this method right after a successful login. Store the token and send it to the Bsmart backend API:
private void registerPushToken(String authToken) {
  FirebaseMessaging.getInstance().getToken()
    .addOnCompleteListener(task -> {
      if (!task.isSuccessful()) {
        Log.e("FCM", "Token fetch failed", task.getException());
        return;
      }
      String fcmToken = task.getResult();
      // Save locally for token refresh use
      saveTokenLocally(fcmToken);
      // Send to Bsmart backend
      sendTokenToBackend(fcmToken, authToken);
    });
}
 
private void sendTokenToBackend(String fcmToken, String authToken) {
  OkHttpClient client = new OkHttpClient();
 
  JSONObject json = new JSONObject();
  json.put("fcm_token", fcmToken);
 
  RequestBody body = RequestBody.create(
    json.toString(),
    MediaType.parse("application/json")
  );
 
  Request request = new Request.Builder()
    .url("https://api.bebsmart.in/api/push/register-fcm")
    .addHeader("Authorization", "Bearer " + authToken)
    .addHeader("Content-Type", "application/json")
    .post(body)
    .build();
 
  client.newCall(request).enqueue(new Callback() {
    @Override public void onResponse(Call call, Response response) {
      Log.d("FCM", "Token registered: " + response.code());
    }
    @Override public void onFailure(Call call, IOException e) {
      Log.e("FCM", "Token registration failed", e);
    }
  });
}

Step 4 — Create Notification Channel (Android 8+)
Create the notification channel in your Application class or MainActivity onCreate(). This is required for Android 8.0 (API 26) and above:
private void createNotificationChannel() {
  if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
    CharSequence name        = "Bsmart Notifications";
    String description       = "Bsmart social notifications";
    int importance           = NotificationManager.IMPORTANCE_HIGH;
    NotificationChannel channel =
      new NotificationChannel("bsmart_channel", name, importance);
    channel.setDescription(description);
    channel.enableVibration(true);
    NotificationManager manager =
      getSystemService(NotificationManager.class);
    manager.createNotificationChannel(channel);
  }
}
 
// Call this in onCreate() of your Application class or MainActivity
createNotificationChannel();
Step 5 — Request Notification Permission (Android 13+)
Android 13 (API 33) and above require explicit runtime permission for notifications:
// In your MainActivity or permission handler
if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
  if (ContextCompat.checkSelfPermission(
      this, Manifest.permission.POST_NOTIFICATIONS)
      != PackageManager.PERMISSION_GRANTED) {
    ActivityCompat.requestPermissions(
      this,
      new String[]{Manifest.permission.POST_NOTIFICATIONS},
      101
    );
  }
}

Step 6 — Clear Token on Logout
When the user logs out, call the unregister API so no further notifications are sent to this device:
private void unregisterPushToken(String authToken) {
  OkHttpClient client = new OkHttpClient();
 
  Request request = new Request.Builder()
    .url("https://api.bebsmart.in/api/push/unregister")
    .addHeader("Authorization", "Bearer " + authToken)
    .delete()
    .build();
 
  client.newCall(request).enqueue(new Callback() {
    @Override public void onResponse(Call call, Response response) {
      Log.d("FCM", "Token unregistered: " + response.code());
    }
    @Override public void onFailure(Call call, IOException e) {
      Log.e("FCM", "Unregister failed", e);
    }
  });
}
 
// Call this BEFORE clearing local auth token on logout
unregisterPushToken(authToken);
4. API Reference
Base URL: https://api.bebsmart.in
All endpoints require a valid JWT Bearer token in the Authorization header.

POST /api/push/register-fcm
Registers the device FCM token with the backend. Call this after login and whenever onNewToken fires.
Request Headers:
Authorization: Bearer <jwt_token>
Content-Type: application/json
Request Body:
{
  "fcm_token": "dGhpcyBpcyBhIHNhbXBsZSBGQ00..."
}
Success Response (200):
{
  "success": true,
  "message": "FCM token registered"
}

DELETE /api/push/unregister
Clears all push tokens for the user. Call this on logout.
Request Headers:
Authorization: Bearer <jwt_token>
Success Response (200):
{
  "success": true,
  "message": "Push tokens cleared"
}

Notification Payload Structure
When a notification is received on the device, the data payload has this structure:
{
  "title": "Bsmart",
  "body":  "john_doe liked your post",
  "link":  "/posts/664f1a2b3c4d5e6f7a8b9c0d",
  "type":  "like"
}


5. Notification Types
The type field in the notification payload identifies the event. Use this to customise the notification icon, sound, or action on tap.


6. Testing
Step 1 — Verify Token Registration
Build and install the APK on a physical Android device
Login with a test account
Check logcat for: D/FCM: Token registered: 200
Ask backend team to verify the fcm_token field is set on the user document in MongoDB

Step 2 — Test Foreground Notification
Keep the app open in foreground
From another account, like a post created by the test account
The onMessageReceived method should fire
Notification should appear in the status bar

Step 3 — Test Background Notification
Press Home to background the app (do NOT force-close it)
From another account, like a post created by the test account
FCM handles display automatically — notification should appear
Tap notification — app should open and navigate to the correct screen

Step 4 — Test Token Refresh
Clear app data (Settings → Apps → Bsmart → Clear Data)
Login again
onNewToken fires automatically with a new token
New token should be registered with backend

Step 5 — Test Logout Cleanup
Login and confirm token is registered
Logout from the app
Check logcat for: D/FCM: Token unregistered: 200
Ask backend team to confirm fcm_token is null on the user document
✅  After logout, no push notifications should be delivered to the device
7. Implementation Checklist
Use this checklist to confirm the integration is complete before releasing:


8. Troubleshooting


Contact
For backend API issues or Firebase project access, contact the Bsmart backend team.
API Docs (Swagger): https://api.bebsmart.in/api-docs
Firebase Console: https://console.firebase.google.com — Project: bsmart-224b2