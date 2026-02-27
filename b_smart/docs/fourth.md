App Name: b Smart - 4
Feature: Watch Ads & Earn Coins
Purpose
To reward users with coins for watching ads, while ensuring fair usage, fraud prevention, and accurate transaction tracking using a ledger-based system.

 
Use Case: Earn Coins by Watching Ads
Actor
User

System (Ad Engine, Fraud Engine, Wallet Ledger)

 
1. Eligibility Validation (Before Ad Playback)
Trigger: User taps “Watch Ads & Earn Coins”

Step-by-Step:
System checks user authentication.

System validates user eligibility rules:

Eligibility Rules:
Minimum Watch Time %

User must watch at least X% of the ad (e.g., 90%).

Daily Earning Cap

Maximum coins per day (e.g., 500 coins/day).

Ad View Limit

Maximum number of ads per day.

Cooldown Period

Mandatory wait time between ads (e.g., 30–60 seconds).

Unique View Rule

Same ad cannot be rewarded more than once per user.

Device Validation
​Device ID must be valid and not blocked.

Account Status

Account must not be suspended or flagged.

If any rule fails:

System blocks ad playback.

Displays reason (e.g., “Daily limit reached”).

Postcondition: Only eligible users proceed to ad playback.

 
2. Ad Playback & Watch Tracking
Step-by-Step:
System loads an eligible ad.

Ad starts playing.

System tracks:

Watch duration

Foreground activity

App focus (no background play)

Skip, mute, or minimize behavior is monitored.

User must meet the minimum watch threshold.

Failure Scenarios:

Ad skipped early

App moved to background

Network interruption

➡️ Result: No reward granted

 
3. Reward Qualification Check (After Ad Completion)
Step-by-Step:
Ad finishes playing.

System revalidates:

Watch percentage

Cooldown compliance

Daily cap not exceeded

Fraud detection checks are triggered.

 
4. Fraud Prevention & Abuse Detection
Fraud Prevention Rules:
Rate Limiting

Max ads watched per hour/day.

Re-watch Prevention

Same ad ID cannot generate rewards twice.

Duplicate Device Detection

Multiple accounts using same device fingerprint.

Suspicious Pattern Detection

Unnatural watch speed

Repetitive behavior patterns

Account Linking Checks

Multiple accounts funneling rewards.

IP & Location Consistency

Sudden abnormal changes flagged.

System Actions:
Flag suspicious transactions.

Temporarily pause rewards.

Mark account for manual or automated review.

 
5. Ledger-Based Reward Credit (Critical Rule)
⚠️ Coins are NEVER directly added to balance

Step-by-Step:
System creates a ledger transaction entry:

Transaction ID

User ID

Ad ID

Reward amount

Transaction type: AD_REWARD

Status: COMPLETED / PENDING / FAILED

Timestamp

Ledger entry is immutably stored.

Wallet balance is recalculated as:

SUM(all completed ledger transactions)

Benefits:

Full audit trail

No manual balance tampering

Easy rollback & dispute handling

 
6. Wallet Balance Update
Step-by-Step:
Ledger confirms transaction status = COMPLETED.

Wallet service recalculates total balance.

Updated balance is reflected in:

Wallet screen

Header coin count

UI shows success message:

“You earned X coins for watching this ad.”

 
7. Coins History Update
Step-by-Step:
Ledger transaction appears in Coins History.

Entry displays:

Source: Ad Reward

Coins earned (+X)

Date & time

Status

 
8. Notification Trigger (Optional but Recommended)
Step-by-Step:
System sends in-app notification:

“You earned X coins by watching an ad.”

Notification stored in Notifications list.

 
9. Failure & Edge Case Handling
Scenarios:
Network failure → Transaction marked PENDING

Fraud flag → Transaction marked BLOCKED

Ad provider error → Transaction FAILED

System Rules:
No balance update without ledger success

Retry mechanism for pending transactions

Admin review support via ledger logs

10. Ad Targeting & Personalization Rules
Purpose
To ensure users see relevant ads and advertisers receive better engagement, while maintaining reward fairness.

Step-by-Step:
System builds a user ad profile using:

Selected Languages

Selected User Preferences / Interests

Search History (keywords, categories)

Location data (country, state, city-level)

System filters available ads based on:

Advertiser targeting rules

Ad availability & budget

System prioritizes ads with:

High relevance score

Eligible reward value

Only ads matching user profile + eligibility rules are shown.

Result: User sees personalized ads instead of random ads.

 
11. Language-Based Ad Matching
Steps:
System checks user’s selected language(s).

Ads are filtered to match:

Primary language first

Secondary language (if allowed)

Ads without language compatibility are excluded.

Rule: User should never be forced to watch ads in an unsupported language.

 
12. Preference & Search History Matching
Steps:
System analyzes:

Followed categories

Recently searched topics

Ads related to:

Products

Services

Content types
are prioritized.

Repetitive ads in the same category are rate-limited to avoid fatigue.

 
13. Location-Based Ad Delivery
Steps:
System determines user location via:

Device GPS (if permitted)

IP-based location fallback

Ads are matched based on:

Country-specific campaigns

Regional or local advertisers

Location-restricted ads are blocked outside allowed regions.

 
14. Ad-Specific Coin Reward Rules
Purpose
To allow flexible rewards per ad, controlled by advertisers.

Step-by-Step:
Each ad is configured with:

Coin reward value (e.g., 5, 10, 50 coins)

Watch duration requirement

Maximum rewardable views

User watches the ad successfully.

System credits exactly the coins specified for that ad.

Ledger entry records:

Ad ID

Coin value

Reward source

Rule:
➡️ Coins received are strictly based on the ad’s configured reward, not a fixed system value.

 
15. Ad Exhaustion & Rotation Logic
Steps:
Once an ad reaches:

Maximum views OR

Budget limit

System removes it from eligible ads.

Next best-matching ad is shown.

Prevents showing expired or unpaid ads.

 
16. Transparency for Users (Recommended)
UI Indicators:
Show coin reward value before watching the ad

Example: “Watch & Earn 10 Coins”

Show remaining daily ads or coins

Display eligibility messages clearly

17. User Actions During Ad Playback
Purpose
To give users control and engagement options without compromising reward integrity.

Allowed User Actions:
● Like the Ad
● Comment on the Ad
● Share the Ad
● Mute / Unmute audio
● Pause / Resume the Ad (within allowed limits)
 
18. Action Handling & Reward Impact Rules
Step-by-Step:
1. User starts watching the ad.
2. User may perform any allowed action during playback.
3. System behavior rules:
○ Like / Comment / Share
■ Does NOT affect reward eligibility
■ Logged as engagement metrics
○ Mute
■ Allowed without penalty
○ Pause
■ Allowed up to a maximum duration (e.g., X seconds)
■ Excessive pausing may disqualify reward
4. System continues tracking:
○ Active watch time
○ Foreground presence
○ Playback completion %
Rule:
➡️ Reward eligibility depends on watch completion rules, not engagement actions.

 
19. Share Flow (Optional Reward-Neutral)
Step-by-Step:
1. User taps Share.
2. System opens native share options.
3. User selects sharing destination.
4. Share action is logged.
Rule:

● Sharing does not grant extra coins (unless explicitly configured later).
 
20. Comment & Like Flow
Step-by-Step:
1. User taps Like or Comment.
2. System submits engagement data.
3. Comment is moderated (auto/manual if required).
4. Engagement is associated with the Ad ID.
 
21. Mute & Pause Constraints
Rules:
● Mute is always allowed.
● Pause:
○ Limited number of pauses
○ Limited total pause duration
● If pause limits are exceeded:
○ Ad resumes automatically OR
○ Reward eligibility is cancelled
 
22. View Ad Company Detail Page
Purpose
To provide transparency and trust about advertisers.

Step-by-Step:
1. User taps on:
○ Advertiser name OR
○ Company logo OR
○ “View Advertiser” option
2. System opens Ad Company Detail Page.
3. Page displays:
○ Company name & logo
○ Business description
○ Website / app links
○ Verified badge (if applicable)
○ Active ads from the company
4. User can return to ad playback without losing progress (if allowed).
 
23. Company Page Access Rules
Rules:
● Viewing company details:
○ Does NOT cancel ad watch
○ Does NOT reset watch progress
● Excessive navigation away from ad:
○ May pause playback
○ Still subject to pause limits
 
24. Engagement Data Logging (Backend)
Logged Events:
● Ad Viewed
● Like / Comment / Share
● Mute / Pause events
● Company Page View
Usage:
● Analytics & reporting
● Advertiser insights
● Fraud pattern detection
 

 
Final Add-On Summary
Ads are personalized by language, interests, history, and location

Reward value is ad-specific

Users earn exact coins defined by each ad

Ledger maintains full transparency & auditability

Fraud rules still apply regardless of targeting



Final Consolidated Rules Add-On

● Users can like, comment, share, mute, pause ads
● Engagement actions do not affect coin rewards
● Pause is controlled to prevent abuse
● Users can view Ad Company details safely
● All interactions are logged for analytics & fraud detection
 

 

 