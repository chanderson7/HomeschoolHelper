# EZHomeschool — App Store Submission Guide

This document records the behavior of the current iOS source and the metadata intended for App Store Connect. Production services, reviewer credentials, in-app purchases, support contact delivery, and the final signed archive still require verification before submission.

---

## 1. App Store Presence & Metadata

### General App Information
- **App Name**: `EZHomeschool` *(12 / 30 characters)*
- **Subtitle**: `Homeschool & Lesson Planner` *(27 / 30 characters)*
- **Primary Category**: Education
- **Secondary Category**: Productivity
- **Age Rating**: 4+ (No violence, realistic gambling, profanity, or mature content)
- **Bundle ID**: `com.andersonsites.ezhomeschool`
- **SKU**: `HEZ-IOS-001`
- **Copyright**: `© 2026 Anderson Sites LLC. All rights reserved.`
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
EZHomeschool is a homeschool management app built for parents, cooperative educators, and families. A parent or guardian account is required. After sign-in, each account's records are saved locally on the device for responsive day-to-day use and backed up to private cloud storage when automatic sync is enabled.

Whether you're managing multiple children across different grade levels, tracking state compliance hours, or building personalized lesson sequences, EZHomeschool simplifies your day so you can focus on teaching.

CORE HIGHLIGHTS:

◆ TODAY DASHBOARD & DAILY ORBIT
• Visual daily progress ring showing lesson completion at a glance
• Quick-switch between all learners or focus on an individual child
• Undated flexible sequence — reschedule missed lessons or leap ahead without guilt or calendar clutter
• Fast grade selection from Preschool through 12th Grade when creating learner profiles

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
• Keep student work organized in a device-local portfolio

◆ ACCOUNT DATA & CLOUD BACKUPS
• A parent or guardian account is required to access the app
• Structured homeschool records are saved in an account-specific file on the device
• Automatic private cloud snapshots are enabled by default and can be paused in Account & Backups
• Cloud restore includes structured records; portfolio image files remain on the device where they were added
• No third-party ad networks, no tracking, and no data selling — ever.

EZHomeschool is crafted to make homeschool planning and recordkeeping calmer and more organized. Families remain responsible for reviewing their records and applicable homeschool requirements.
```

---

## 2. In-App Purchases (StoreKit 2)

Configure and verify the following auto-renewable subscription group in App Store Connect. The current source gates creation of a second or later learner and sharing/saving an Academic Report Card export. Cloud sync, portfolio photos, course creation, ISBN scanning, and transcript exports are not currently gated by Pro and must not be advertised as paid benefits unless the app is changed first.

### Subscription Group: `EZHomeschool Pro`
- **Group Reference Name**: `EZHomeschool Pro Subscriptions`

#### Tier 1: Annual Membership (Recommended)
- **Reference Name**: `EZHomeschool Pro Annual`
- **Product ID**: `com.andersonsites.ezhomeschool.pro.annual`
- **Duration**: 1 Year
- **Price**: $39.99 USD
- **Introductory Offer**: 7-Day Free Trial *(planned; verify in App Store Connect)*
- **Subscription Display Name**: `Annual Pro Membership`
- **Subscription Description**: `Add multiple learner profiles and unlock sharing or saving Academic Report Card exports.`

#### Tier 2: Monthly Membership
- **Reference Name**: `EZHomeschool Pro Monthly`
- **Product ID**: `com.andersonsites.ezhomeschool.pro.monthly`
- **Duration**: 1 Month
- **Price**: $4.99 USD
- **Subscription Display Name**: `Monthly Pro Membership`
- **Subscription Description**: `Add multiple learner profiles and unlock sharing or saving Academic Report Card exports with monthly billing.`

---

## 3. App Review Information (Notes for Reviewer)

Provide this in the **App Review Information** section of App Store Connect:

```text
ACCOUNT REQUIRED:
EZHomeschool requires a parent or guardian account. The application opens to its sign-in and account-creation screen when there is no verified session. A network connection is required to create an account, sign in, reset a password, and verify a saved session.

QUICK START / SAMPLE DATA:
After signing in, the reviewer can populate a household with sample data (2 students, 3 courses with 18 lessons, attendance records, grades, reading logs, and portfolio metadata):
1. Option A (First signed-in launch): On the welcome screen, tap "Load Sample Household (Quick Demo)".
2. Option B (Anytime while signed in): In Settings -> Data & Storage, tap "Load Sample Household Data".
The app will immediately load our curated sample household (Emma & Lucas).

APP REVIEW ACCOUNT:
Verify this account and its credentials against the production Supabase project immediately before submission:
- Email: demo@homeschoolhelper.app
- Password: HomeschoolHelper2026!

CLOUD BACKUP BEHAVIOR:
- Automatic cloud snapshots of structured homeschool records are enabled by default for signed-in accounts and can be paused in Settings -> Manage Backups & Restore.
- Restore replaces the current local structured record snapshot; it does not merge records.
- Portfolio image files are stored locally and are not included in cloud backup or restore. Only their structured metadata and local filenames are present in the snapshot.

HARDWARE & PERMISSIONS JUSTIFICATION:
- Camera (NSCameraUsageDescription): Used via Apple's VisionKit to scan book ISBN barcodes and to capture student work for the Portfolio. The scanned ISBN can be sent to Open Library to retrieve book metadata. Portfolio images remain in the app's local storage.
- Photo Library (NSPhotoLibraryUsageDescription): Allows users to select student work images for the device-local portfolio. Portfolio image files are not uploaded by the current cloud-backup implementation.

IN-APP PURCHASES:
StoreKit 2 auto-renewable subscriptions must be tested with Sandbox accounts after the production products and annual introductory offer are configured in App Store Connect. Active subscribers can manage their subscription through StoreKit's native subscription-management sheet in Settings or the paywall.

ACCOUNT DELETION & DATA ERASURE (Guideline 5.1.1(v)):
- In-App Deletion: When signed in, navigate to Settings -> Manage Backups & Restore -> "Delete Account".
- Two user-choice deletion modes are provided:
  1. "Delete Cloud Account & Keep Device Data": Requests permanent deletion of the remote account and cloud backups, preserves the account-specific local data file, and signs the user out. The current build does not provide offline access to that retained file after account deletion.
  2. "Delete Cloud Account & Erase All Device Data": Requests permanent deletion of the remote account and cloud backups, erases the current account's local records, and signs the user out.
- While signed in, Settings -> Data & Storage -> "Erase All Device Data" clears the current local household records without deleting the account.
- The deletion RPC migration and both result paths must be verified against the production Supabase project before submission.
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
  - `NSPrivacyCollectedDataTypeEmailAddress` (App Functionality, linked to the required account).
  - `NSPrivacyCollectedDataTypeUserID` (App Functionality, linked to the required account).
  - `NSPrivacyCollectedDataTypeOtherUserContent` (App Functionality, linked to the account when structured records are backed up).

---

## 6. App Privacy Nutrition Labels (Data Safety)

Answer the App Store Connect Privacy Questionnaire as follows:

### "Do you or your third-party partners collect data from this app?"
**YES**. An account is required, and automatic cloud backup of structured homeschool records is enabled by default. Users can pause automatic sync. Portfolio image files remain local in the current implementation.

### "Do you track users?"
> **NO**. EZHomeschool does not track users across apps and websites owned by other companies, does not integrate advertising SDKs, and does not sell or share data with data brokers.

---

### Data Types Breakdown

| Data Type | Collected? | Linked to User? | Used for Tracking? | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **Contact Info: Email Address** | **Yes** | **Yes** | **No** | **App Functionality**: Required account authentication, password recovery, and cloud-backup access. |
| **Identifiers: User ID** | **Yes** | **Yes** | **No** | **App Functionality**: Scopes local account files and private cloud records to the authenticated parent account. |
| **User Content: Other User Content** | **Yes** | **Yes** | **No** | **App Functionality**: Structured homeschool records, including learner, course, attendance, grade, reading-log, and portfolio metadata, are backed up automatically by default. Portfolio image files are not uploaded. |
| **Purchases: Purchase History** | **No developer collection in current source** | N/A | **No** | StoreKit evaluates verified entitlements on device; the app does not send purchase history to a developer-controlled server. Confirm the final App Store privacy answer against Apple's current questionnaire. |
| **Diagnostics / Crash Data** | **No** | N/A | **No** | None collected. |
| **Location Data** | **No** | N/A | **No** | None collected. |
| **Financial Info** | **No** | N/A | **No** | Handled entirely by Apple Pay / In-App Purchase. |

---

## 7. Build & Archive Instructions

For the uploadable release archive, use Xcode with the Anderson Sites LLC account and automatic signing:

```bash
# 1. Run core unit tests
bash scripts/test-core.sh
```

1. In Xcode, select the `HomeSchoolHelper` scheme and `Any iOS Device (arm64)`.
2. Choose **Product -> Archive**.
3. In **Window -> Organizer -> Archives**, select the new signed archive.
4. Generate and review the privacy report, then choose **Distribute App -> App Store Connect -> Upload**.

`scripts/archive-ios.sh` defaults to `CODE_SIGNING_ALLOWED=NO` and is suitable for build verification. Its default archive is not an uploadable App Store build.
