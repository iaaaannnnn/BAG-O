# 🔥 Firebase Composite Indexes Setup

Your app needs 3 composite indexes to be created in Firebase. The error messages provide direct links, but here's what you need to do:

## Quick Steps

### Option 1: Use the Console Links (Easiest)
The error messages show direct links to create indexes. Click each one:

1. **Requests Collection Index**
   ```
   https://console.firebase.google.com/v1/r/project/barangay-system-d67b0/firestore/indexes?create_composite=ClZwcm9qZWN0cy9iYXJhbmdheS1zeXN0ZW0tZDY3YjAvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL3JlcXVlc3RzL2luZGV4ZXMvXxABGgwKCGJhcmFuZ2F5EAEaDQoJdGltZXN0YW1wEAIaDAoIX19uYW1lX18QAg
   ```
   - Fields: `barangay` (Ascending), `timestamp` (Descending)

2. **Transparency Docs Collection Index**
   ```
   https://console.firebase.google.com/v1/r/project/barangay-system-d67b0/firestore/indexes?create_composite=Cl9wcm9qZWN0cy9iYXJhbmdheS1zeXN0ZW0tZDY3YjAvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL3RyYW5zcGFyZW5jeV9kb2NzL2luZGV4ZXMvXxABGgwKCGJhcmFuZ2F5EAEaDQoJdGltZXN0YW1wEAIaDAoIX19uYW1lX18QAg
   ```
   - Fields: `barangay` (Ascending), `timestamp` (Descending)

3. **Complaints Collection Index**
   ```
   https://console.firebase.google.com/v1/r/project/barangay-system-d67b0/firestore/indexes?create_composite=Clhwcm9qZWN0cy9iYXJhbmdheS1zeXN0ZW0tZDY3YjAvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL2NvbXBsYWludHMvaW5kZXhlcy9fEAEaDAoIYmFyYW5nYXkQARoKCgZzdGF0dXMQARoNCgl0aW1lc3RhbXAQAhoMCghfX25hbWVfXxAC
   ```
   - Fields: `barangay` (Ascending), `status` (Ascending), `timestamp` (Descending)

---

## Manual Setup (If links don't work)

### 1. Requests Index
Go to **Firestore → Indexes → Composite** and create:
```
Collection: requests
Fields:
  - barangay (Ascending)
  - timestamp (Descending)
```

### 2. Transparency Docs Index
```
Collection: transparency_docs
Fields:
  - barangay (Ascending)
  - timestamp (Descending)
```

### 3. Complaints Index
```
Collection: complaints
Fields:
  - barangay (Ascending)
  - status (Ascending)
  - timestamp (Descending)
```

---

## Status Tracking

- [ ] Requests index created
- [ ] Transparency docs index created
- [ ] Complaints index created
- [ ] All indexes marked as "Enabled"

Usually takes 5-10 minutes for indexes to be ready.

---

## Verify Indexes Are Ready

1. Go to Firebase Console → Firestore → Indexes
2. Check if all 3 indexes show "Enabled" status
3. Restart the app after indexes are ready

---

## What Will Be Fixed

Once indexes are created:
- ✅ Request queries will work
- ✅ Transparency doc queries will work
- ✅ Complaint filters will work

---

## Fixed Issues

### ✅ Firestore Rules Updated
- Users collection now allows all authenticated users to read
- App filters by role/barangay in code
- This fixes "PERMISSION_DENIED" errors

### ✅ Android Manifest Updated
- Added `android:enableOnBackInvokedCallback="true"`
- This fixes the back gesture warning

### ⏳ Pending: Create Composite Indexes
- See instructions above
- Takes 5-10 minutes in Firebase
