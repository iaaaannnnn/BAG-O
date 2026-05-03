# Copilot / AI Agent Instructions for `barangay_system`

**Purpose:** Provide concise, actionable guidance so an AI coding agent becomes productive quickly in this Flutter + Firebase monorepo.

**Quick Architecture Snapshot:**
- **Entrypoint:** `lib/main.dart` — a single-file, monolithic Flutter app containing UI pages, service helpers, and app wiring.
- **Services:** `AuthService` and `NotificationService` are implemented as static helper classes inside `lib/main.dart` (search for `class AuthService` / `class NotificationService`).
- **Data Backend:** Firebase (Auth, Firestore, Storage). Firestore collections used by code: `users`, `notifications`, `announcements`, `complaints`, `transparency_docs`.

**Key Patterns & Conventions (code examples):**
- **User model and role:** user documents are stored under `users` and contain a `type` field (`Resident` or `Barangay Official`). See `AuthService.register(...)` in `lib/main.dart`.
- **Realtime UI:** UI relies on `StreamBuilder` for live Firestore streams (e.g., announcements and notifications).
- **Image uploads:** Images are uploaded via `AuthService.uploadImage(file, path)` with path patterns like `complaints/{timestamp}.jpg` and `profiles/{uid}.jpg`.
- **Error/debugging:** The app uses `print(...)` and simple `SnackBar` UI for errors — prefer small, targeted fixes rather than wide structural changes.

**Build / Run / Debug workflows**
- Install deps and analyze:

```
flutter pub get
flutter analyze
```

- Run on a device/emulator (examples):

```
flutter run -d android
flutter run -d windows
flutter run -d chrome
```

- Build release artifacts:

```
flutter build apk
flutter build ios
```

- Gradle (Windows PowerShell) for Android-specific tasks:

```
cd android; .\gradlew assembleDebug
```

**Firebase / Platform notes**
- `Firebase.initializeApp()` is called in `main()` — the project expects platform Firebase config.
- `android/app/google-services.json` is present. For iOS builds you must add `GoogleService-Info.plist` to `ios/Runner` before running on device/simulator.
- If testing without a real Firebase project, consider using the Firebase Emulators or provide environment-specific config (not present in repo).

**Files & places to inspect for related logic**
- `lib/main.dart` — primary app logic, UI pages, and service helpers.
- `pubspec.yaml` — dependency versions (notably `firebase_*` and `image_picker`).
- `android/app/google-services.json` — Android Firebase config.

**What to change carefully / common gotchas**
- The app is monolithic: breaking `lib/main.dart` into many files is OK, but preserve behavior (AuthService static API, collection names, and upload path strings) to avoid subtle bugs.
- Many UI flows assume `AuthService.currentUser` and that `users` Firestore document includes `type`. Keep these contracts when refactoring.
- Image picking uses `image_picker` and `dart:io` File — ensure platform permissions and Android manifest entries are kept when editing.

**If you need to implement a feature**
- Add unit/smoke tests in `test/` and keep changes small and focused. There are currently no tests — prefer adding a small widget or service test for any new logic.

**If you need credentials or environment info**
- Ask the repo owner for: Android `google-services.json` (already present), iOS `GoogleService-Info.plist`, and any Firebase project IDs or emulator instructions.

---
If anything in these instructions is unclear or you want me to include deeper examples (e.g., split-service refactor template or a sample Firestore security rule set), tell me which area to expand.
