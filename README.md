# BAG-O — Barangay Automated Governance and Operation

A Flutter + Firebase mobile application that digitizes barangay governance, enabling residents and barangay officials to interact seamlessly through a unified platform.

---

## Features

### For Residents
- Register and get approved by barangay officials
- Submit complaints and track their status
- Request barangay documents (clearance, residency, etc.)
- View announcements and events
- Access transparency documents
- Receive in-app notifications

### For Barangay Officials
- Approve or reject resident registrations
- Manage and respond to complaints
- Post announcements and events
- Upload transparency/public documents
- Send notifications to residents
- View analytics dashboard

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (Dart) |
| Backend | Firebase (Firestore, Auth, Storage) |
| Auth | Firebase Authentication |
| Database | Cloud Firestore |
| File Storage | Firebase Storage |
| Notifications | In-app (Firestore-based) |

---

## Getting Started

### Prerequisites
- Flutter SDK (3.x or later)
- Firebase project configured (google-services.json for Android)
- Android Studio / VS Code

### Setup

`ash
flutter pub get
flutter analyze
flutter run -d android
`

### Build Release APK

`ash
flutter build apk --release
`

---

## Project Structure

`
lib/
  app/              # App root, shell, router, theme
  core/             # Services (Auth, Notifications), widgets, utils
  features/
    auth/           # Login and Registration pages
    resident/       # Resident dashboard and features
    official/       # Official dashboard, approval panel
    announcements/  # Announcements page
    notifications/  # Notifications page
    documents/      # Document request page
    profile/        # User profile page
`

---

## Firebase Setup

- Place google-services.json in android/app/
- For iOS, add GoogleService-Info.plist to ios/Runner/
- Deploy Firestore rules via: npx firebase-tools deploy --only firestore:rules --project YOUR_PROJECT_ID

---

## License

Private — All rights reserved.
