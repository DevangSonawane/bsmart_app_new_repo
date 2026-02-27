App Name: b Smart - 3
Feature: Wallet / Coins
Purpose
To allow users to view, manage, and track coins earned through watching ads, receiving gifts from other users, and to manage payout or account details.

 
Use Case 1: View Wallet / Coins Balance
Actor: Logged-in User
Precondition: User is logged in
Trigger: User taps the Coins / Wallet icon from the Home header

Steps:
1. User taps the Wallet / Coins icon.
2. System opens the Wallet screen.
3. System displays:
○ Total available coin balance
○ Equivalent value (if applicable)
4. Wallet summary is shown at the top.
Postcondition: User can see their current coin balance.

Example Screens:





 
Use Case 2: Earn Coins by Watching Ads
Actor: User, System
Precondition:

● User is eligible to watch ads
● Ads are available
Steps:
1. User navigates to the “Watch Ads & Earn Coins” section.
2. User selects an Ad to watch.
3. System plays the Ad.
4. User watches the Ad completely.
5. System verifies Ad completion.
6. System credits coins to the user’s Wallet.
7. System shows a success message:
○ “You earned X coins.”
8. Wallet balance updates instantly.
Postcondition: Coins are added to the user’s Wallet.

Example Screen:



 



 
Use Case 3: Receive Coins as a Gift
Actor: User (Sender), User (Receiver), System
Precondition:

● Sender has sufficient coins
● Receiver account exists
Steps:
1. Sender selects a user profile.
2. Sender chooses the “Gift Coins” option.
3. Sender enters the number of coins.
4. Sender confirms the transaction.
5. System deducts coins from the sender’s Wallet.
6. System credits coins to the receiver’s Wallet.
7. System sends a notification to the receiver:
○ “You received X coins from [User Name].”
Postcondition: Coins are transferred successfully.

 
Use Case 4: View Coins History
Actor: Logged-in User

Steps:
1. User opens the Wallet screen.
2. User selects the “Coins History” option.
3. System displays a chronological list of coin transactions.
4. Each entry includes:
○ Transaction type (Ad reward / Gift received / Gift sent)
○ Coin amount (+ / −)
○ Date and time
○ Status (Completed / Pending)
5. User scrolls or filters the history list.
Postcondition: User can review all past coin transactions.

 
Use Case 5: Add Account Details
Actor: Logged-in User
Precondition: User has access to Wallet settings

Steps:
1. User opens Wallet.
2. User navigates to “Account Details”.
3. User selects “Add / Edit Account”.
4. User enters required details (example):
○ Account holder name
○ Bank / UPI / Payment method
○ Account number / UPI ID
5. User submits the details.
6. System validates the information.
7. System securely saves the account details.
8. System shows confirmation message.
Postcondition: User’s account details are saved successfully.

 
Use Case 6: Edit or Update Account Details
Actor: Logged-in User

Steps:
1. User opens Wallet → Account Details.
2. User selects “Edit”.
3. User updates required fields.
4. User saves changes.
5. System validates and updates the data.
Postcondition: Account details are updated.

 
Use Case 7: Wallet Error Handling
Actor: System

Scenarios:
● Ad not completed → Coins not credited
● Network failure → Transaction marked as pending
● Invalid account details → Error message shown
System Actions:

1. Display clear error messages.
2. Prevent incorrect balance updates.
3. Retry or rollback failed transactions.
Postcondition: Wallet data remains consistent and secure.

 
Summary (For Product & Tech Teams)
● Coin sources: Ads, Gifts
● Key screens: Wallet, Coins History, Account Details
● Security: Validation & transaction tracking
● Notifications: Triggered for coin rewards and gifts
 