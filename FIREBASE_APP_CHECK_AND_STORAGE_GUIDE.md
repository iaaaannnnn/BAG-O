Quick App Check, Storage, and Indexing Guide

1) App Check warning: "No AppCheckProvider installed"
- For local development, you can either:
  - Use the Firebase Emulator Suite (recommended) which bypasses App Check during local testing, or
  - Register App Check provider (e.g., Play Integrity / DeviceCheck / Debug provider) in Firebase Console and enable it in your app.
- To use a debug provider locally (Android/iOS) add App Check debug tokens and follow Firebase docs.

2) Storage 404 (object-not-found) causes
- Firebase Storage is object-based; folders don't need explicit creation. A 404 during upload usually means the app tried to download or update metadata of an object that doesn't exist.
- Check the exact Storage path your code uploads to. Common patterns in this repo:
  - `transparency_docs/{barangay}/{timestamp}_{filename}` or similar.
- Verify the filename and that you call `putFile()` or `putData()` (create) before trying to `getDownloadURL()` or update metadata.
- Use emulator to test uploads:
  - Start emulators: `firebase emulators:start --only storage,firestore,auth`
  - Configure your app to use the emulator endpoints when running locally.

3) Storage security rules notes
- Storage rules in this repo (`storage.rules`) rely on a custom claim `barangay` in `request.auth.token`.
- If you don't set custom claims, writes for barangay-protected paths will fail. Set claims using Admin SDK (`auth.setCustomUserClaims(uid, { barangay: 'Cabaohan' })`).

4) Firestore composite indexes
- I added `firestore.indexes.json` with the required indexes for `requests`, `transparency_docs`, and `complaints`.
- Deploy indexes with Firebase CLI:

```bash
firebase deploy --only firestore:indexes
```

- Or create indexes via the Firebase Console → Firestore → Indexes → Add Index using the fields shown in `firestore.indexes.json`.

5) Setting custom claims (Admin SDK example - Node.js)

```js
const admin = require('firebase-admin');
admin.initializeApp({ credential: admin.credential.applicationDefault() });

// set barangay claim
admin.auth().setCustomUserClaims(uid, { barangay: 'Cabaohan', role: 'Barangay Official' }).then(() => console.log('done'));
```

6) Quick local checks
- Ensure `AuthService.currentUserData` is populated before navigating to pages that run queries by barangay.
- Use the emulator for Storage/Firestore to reproduce errors locally and avoid App Check restrictions.

7) Next steps I can take for you (pick any):
- Patch remaining pages to guard empty `barangay` usages (I found many occurrences and patched the most common ones).
- Deploy `firestore.indexes.json` for you (requires Firebase CLI access).
- Add runtime checks to `AuthService` to delay navigation until user data / effective barangay is ready.

