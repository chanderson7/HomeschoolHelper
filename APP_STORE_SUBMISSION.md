# HomeSchool Helper — App Store Submission Guide

This document contains all verified metadata, store copy, in-app purchase configurations, reviewer instructions, and privacy nutrition label responses required for App Store Connect submission.

---

## 1. App Store Presence & Metadata

### General App Information
- **App Name**: `HomeSchool Helper` *(17 / 30 characters)*
- **Subtitle**: `Homeschool & Lesson Planner` *(27 / 30 characters)*
- **Primary Category**: Education
- **Secondary Category**: Productivity
- **Age Rating**: 4+ (No violence, realistic gambling, profanity, or mature content)
- **Bundle ID**: `com.andersonsites.homeschoolhelper`
- **SKU**: `HSH-IOS-001`
- **Copyright**: `© 2026 HomeSchool Helper. All rights reserved.`
- **Primary Language**: English (U.S.)

---

### Links & URLs
- **Marketing URL**: `https://homeschoohelp.netlify.app/`
- **Support URL**: `https://homeschoohelp.netlify.app/support/`
- **Privacy Policy URL**: `https://homeschoohelp.netlify.app/privacy/`
- **Terms of Service (EULA) URL**: `https://homeschoohelp.netlify.app/terms/`
- **Standard Apple EULA URL**: `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`

---

### Promotional Text *(148 / 170 characters)*
> Effortless homeschooling. Plan curriculum, track 180-day state attendance, scan book barcodes, and generate official academic report cards with GPA.

---

### Search Keywords *(83 / 100 characters)*
> `homeschool,lesson planner,homeschool tracker,attendance,report card,gpa,reading log,curriculum`

---

### App Store Description

```markdown
HomeSchool Helper is the all-in-one homeschool management app built for homeschooling parents, cooperative educators, and modern families. Designed with a local-first architecture, HomeSchool Helper keeps your family's records private, responsive, and completely under your control — online or offline.

Whether you're managing multiple children across different grade levels, tracking state compliance hours, or building personalized lesson sequences, HomeSchool Helper simplifies your day so you can focus on teaching.

CORE HIGHLIGHTS:

◆ TODAY DASHBOARD & DAILY ORBIT
• Visual daily progress ring showing lesson completion at a glance
• Quick-switch between all learners or focus on an individual child
• Undated flexible sequence — reschedule missed lessons or leap ahead without guilt or calendar clutter
• Quick-launch Student Mode for focused, distraction-free independent learner work

◆ CURRICULUM & SUBJECT ROADMAPS
• Build structured sequences for Math, Science, Language Arts, History, and Electives
• Reorder lessons with intuitive drag-and-drop
• Attach external learning links, textbooks, and notes directly to lessons
• Visual completion roadmaps celebrate your child's milestone progress

◆ 180-DAY STATE COMPLIANCE & ATTENDANCE
• Track instruction days and hours against mandatory state requirements
• Separate core academic vs non-core elective hours automatically
• Retrospective activity logging for field trips, nature walks, museum visits, and co-ops
• One-tap annual attendance ledger export

◆ OFFICIAL ACADEMIC REPORT CARDS & GPA
• Weight grade categories (Tests 40%, Homework 30%, Projects 30%) with automatic validation
• Letter grade calculations (A+, A, B, C...) with unweighted and weighted GPA summaries
• Export official, printable Letter PDF Report Cards featuring parent/educator legal attestation
• Export RFC 4180 CSV spreadsheets for district submission, umbrella schools, or records

◆ READING LOG & ISBN BARCODE SCANNER
• Point your camera at any book barcode to automatically populate title, author, and page count via VisionKit
• Active bookshelf with reading progress bars, star ratings, and review notes
• Cumulative reading statistics (books finished, total reading hours)

◆ STUDENT WORK PORTFOLIO
• Snap photos of worksheets, artwork, science experiments, and certificates
• Tag samples by student and subject
• Preserve your student's growth portfolio year over year

◆ DATA SOVEREIGNTY & OPTIONAL CLOUD SYNC
• 100% functional offline without an account — your data lives securely on your device
• Optional encrypted Supabase cloud backup keeps records synced across all your family devices
• No third-party ad networks, no tracking, and no data selling — ever.

HomeSchool Helper is crafted with care to make your homeschool journey joyful, organized, and legally compliant.
```

---

## 2. In-App Purchases (StoreKit 2)

Configure the following auto-renewable subscription group in App Store Connect:

### Subscription Group: `HomeSchool Helper Pro`
- **Group Reference Name**: `HomeSchool Helper Pro Subscriptions`

#### Tier 1: Annual Membership (Recommended)
- **Reference Name**: `HomeSchool Helper Pro Annual`
- **Product ID**: `com.andersonsites.homeschoolhelper.pro.annual`
- **Duration**: 1 Year
- **Price**: $39.99 USD
- **Introductory Offer**: 7-Day Free Trial
- **Subscription Display Name**: `Annual Pro Membership`
- **Subscription Description**: `Full unlimited access to multi-child profiles, official report cards, unlimited portfolio photos, and automatic cloud backup.`

#### Tier 2: Monthly Membership
- **Reference Name**: `HomeSchool Helper Pro Monthly`
- **Product ID**: `com.andersonsites.homeschoolhelper.pro.monthly`
- **Duration**: 1 Month
- **Price**: $4.99 USD
- **Subscription Display Name**: `Monthly Pro Membership`
- **Subscription Description**: `Full access to multi-child profiles, official report cards, unlimited portfolio photos, and automatic cloud backup billed monthly.`

---

## 3. App Review Information (Notes for Reviewer)

Provide this in the **App Review Information** section of App Store Connect:

```text
SIGN-IN & AUTHENTICATION:
HomeSchool Helper operates on a privacy-first, local-first architecture. A user account is completely OPTIONAL. The reviewer may explore the entire application without logging in.

QUICK START / SAMPLE DATA:
To immediately review the app with a populated household (2 students, 3 courses with 18 lessons, attendance records, grades, reading logs, and portfolio items):
1. Option A (First Launch): On the initial welcome screen, tap the prominent button: "Load Sample Household (Quick Demo)".
2. Option B (Anytime): In Settings -> Data & Storage, tap "Load Sample Household Data".
The app will immediately load our curated sample household (Emma & Lucas).

OPTIONAL CLOUD SYNC DEMO ACCOUNT:
If you wish to test Supabase cloud authentication and cross-device sync:
- Email: demo@homeschoolhelper.app
- Password: HomeschoolHelper2026!

HARDWARE & PERMISSIONS JUSTIFICATION:
- Camera (NSCameraUsageDescription): Used exclusively on-device via Apple's VisionKit to scan book ISBN barcodes in the Reading Log (Add Book -> Barcode icon) and to take photos of student physical work for the Portfolio. No video or biometric data is collected or transmitted.
- Photo Library (NSPhotoLibraryUsageDescription): Allows users to pick photos of student work/art to add to their student portfolio.

IN-APP PURCHASES:
StoreKit 2 auto-renewable subscriptions can be tested via standard Sandbox accounts. In addition, the app responds to the environment flag HSH_PRO_OVERRIDE=1 during automated UI testing. Active subscribers can manage their subscription natively via StoreKit's manageSubscriptionsSheet in Settings or the Paywall.

ACCOUNT DELETION & DATA ERASURE (Guideline 5.1.1(v)):
- In-App Deletion: When signed in, navigate to Settings -> Manage Backups & Restore -> "Delete Account".
- Two user-choice deletion modes are provided:
  1. "Delete Cloud Account & Keep Device Data": Permanently removes the remote account and deletes all cloud backup records from our database while preserving the parent's records locally on the device as an offline household.
  2. "Delete Cloud Account & Erase All Device Data": Permanently removes the remote account, cloud backup records, and completely resets all device storage back to a blank state.
- Local-Only Device Reset: For offline users, Settings -> Data & Storage -> "Erase All Device Data" allows completely wiping local device data.
```

---

## 4. Export Compliance & Encryption
- **Uses Non-Exempt Encryption**: `NO` (`<key>ITSAppUsesNonExemptEncryption</key><false/>` in `Config/Info.plist`).
- The application only uses standard system HTTPS/TLS connections for Supabase Auth/storage and StoreKit 2 APIs. No custom encryption or non-exempt algorithms are implemented.

---

## 5. Apple Privacy Manifest (`PrivacyInfo.xcprivacy`)
In compliance with Apple's Spring 2024 Privacy Manifest mandate:
- **Location**: `iOS/HomeSchoolHelper/PrivacyInfo.xcprivacy` (bundled into app root).
- **Tracking**: `NSPrivacyTracking` = `false`.
- **Required Reason APIs Declared**:
  - `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1` (reading and writing user preferences and local flags).
  - `NSPrivacyAccessedAPICategoryFileTimestamp` with reason `C617.1` (accessing timestamps within the app's sandboxed container).
- **Data Types Declared**:
  - `NSPrivacyCollectedDataTypeEmailAddress` (App Functionality, linked to user when signed in).
  - `NSPrivacyCollectedDataTypeUserID` (App Functionality, linked to user when signed in).
  - `NSPrivacyCollectedDataTypeOtherUserContent` (App Functionality, linked to user when signed in).

---

## 6. App Privacy Nutrition Labels (Data Safety)

Answer the App Store Connect Privacy Questionnaire as follows:

### "Do you or your third-party partners collect data from this app?"
**YES** (If the user voluntarily signs in for Cloud Sync; otherwise local only).

### "Do you track users?"
> **NO**. HomeSchool Helper does not track users across apps and websites owned by other companies, does not integrate advertising SDKs, and does not sell or share data with data brokers.

---

### Data Types Breakdown

| Data Type | Collected? | Linked to User? | Used for Tracking? | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **Contact Info: Email Address** | Yes (Optional) | Yes (If signed in) | **No** | **App Functionality**: User account authentication & optional cloud backup retrieval. |
| **Identifiers: User ID** | Yes (Optional) | Yes (If signed in) | **No** | **App Functionality**: Scopes cloud database records to the authenticated parent account. |
| **User Content: Other User Content** | Yes (Optional) | Yes (If signed in) | **No** | **App Functionality**: Homeschool records, courses, attendance, and reading logs backed up to private cloud database. |
| **Purchases: Purchase History** | Yes | No | **No** | **App Functionality**: StoreKit 2 receipt and entitlement verification. |
| **Diagnostics / Crash Data** | **No** | N/A | **No** | None collected. |
| **Location Data** | **No** | N/A | **No** | None collected. |
| **Financial Info** | **No** | N/A | **No** | Handled entirely by Apple Pay / In-App Purchase. |

---

## 7. Build & Archive Instructions

To generate the release archive locally or in CI:

```bash
# 1. Run core unit tests
bash scripts/test-core.sh

# 2. Build Release .xcarchive
bash scripts/archive-ios.sh

# 3. Open in Xcode Organizer to validate and submit
open .build/archives/HomeSchoolHelper.xcarchive
```
