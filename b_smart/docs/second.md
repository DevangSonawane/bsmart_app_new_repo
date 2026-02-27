App Name: b Smart - 2
Feature: Notifications
Purpose
To inform users about important activities, with primary focus on newly added Ads, along with other relevant updates.

 
Use Case 1: View Notifications List
Actor: Logged-in User
Precondition: User is logged in
Trigger: User taps the Notifications icon from the Home header

Steps:
1. User taps the Notifications icon.
2. System opens the Notifications screen.
3. System displays a chronological list of notifications (latest first).
4. Each notification shows:
○ Notification type (Ad / System / Activity)
○ Short description
○ Timestamp
○ Read / Unread status
5. Unread notifications are highlighted.
Postcondition: User views all available notifications.

 
Use Case 2: Receive Notification for New Ad Added (Primary)
Actor: System
Precondition:

● User has notifications enabled
● A new Ad is added to the platform
Steps:
1. System detects a new Ad added to the platform.
2. System identifies eligible users (based on targeting rules, if any).
3. System generates a notification:
○ Title: “New Ad Available”
○ Message: “A new ad has been added. Check it out now.”
4. System sends:
○ Push notification (if app is in background)
○ In-app notification (if app is open)
5. Notification is stored in the user’s Notifications list as Unread.
Postcondition: User is notified about the new Ad.

 
Use Case 3: Open Notification and View Ad
Actor: User
Precondition: User has at least one notification

Steps:
1. User taps a notification related to a new Ad.
2. System marks the notification as Read.
3. System redirects the user to:
○ Ads screen OR
○ Specific Ad detail page
4. User views the Ad content.
Postcondition: Notification is read and related Ad is displayed.

 
Use Case 4: Notification Badge Update
Actor: System
Precondition: There are unread notifications

Steps:
1. System counts unread notifications.
2. System displays a badge count on the Notifications icon.
3. When the user opens the Notifications screen:
○ Badge count decreases or resets.
4. Badge updates in real time.
Postcondition: Badge accurately reflects unread notifications.

 
Use Case 5: Mark Notification as Read
Actor: User

Steps:
1. User taps a specific notification OR
2. User selects “Mark as Read” option (if available).
3. System updates the notification status to Read.
4. Notification appearance changes (no highlight).
Postcondition: Notification is marked as read.

 
Use Case 6: Clear All Notifications
Actor: User

Steps:
1. User opens Notifications screen.
2. User taps “Clear All” or “Delete All”.
3. System asks for confirmation.
4. User confirms action.
5. System removes all notifications from the list.
Postcondition: Notifications list is cleared.

 
Use Case 7: Notification Settings (Optional / Future)
Actor: User

Steps:
1. User opens Notification Settings.
2. User enables or disables:
○ New Ad notifications
○ Other system notifications
3. System saves preferences.
4. Future notifications follow updated settings.
Postcondition: Notification preferences are updated.

 