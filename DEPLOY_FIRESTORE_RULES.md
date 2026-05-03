# Deploy Firestore Security Rules

## Updated Rules for Transparency Docs & Document Requests

The `firestore.rules` file has been updated to:
1. ✅ Allow Barangay Officials to upload transparency documents
2. ✅ Add rules for the new `document_requests` collection
3. ✅ Check user type from Firestore document instead of custom claims

## How to Deploy (Manual Method)

### Option 1: Firebase Console (Easiest)

1. Open [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Go to **Firestore Database** → **Rules** tab
4. Copy the entire content from `firestore.rules` file
5. Paste it into the rules editor
6. Click **Publish**

### Option 2: Firebase CLI

If you have Firebase CLI set up:

```bash
# Make sure you're in the project directory
cd C:\Users\olaiv\barangay_system

# Use your Firebase project
firebase use <your-project-id>

# Deploy rules
firebase deploy --only firestore:rules
```

## What Changed

### Transparency Documents
**Before:**
```javascript
allow create, update, delete: if isAdmin() || 
  (isBarangayOfficial() && effectiveBarangay() != '' && 
   request.resource.data.barangay == effectiveBarangay());
```

**After:**
```javascript
allow create, update, delete: if isAuthenticated() 
  && exists(/databases/$(database)/documents/users/$(request.auth.uid))
  && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.type == 'Barangay Official';
```

**Why:** The app doesn't use custom claims (isBarangayOfficial() function). Instead, it checks the user's `type` field directly from their Firestore document.

### Document Requests (New)
Added complete CRUD rules for `document_requests` collection:
- **Read:** Users can read their own requests, officials can read requests from their barangay
- **Create:** Users can create their own requests
- **Update:** Officials can update (fulfill) requests from their barangay
- **Delete:** Admin only

## Verification

After deploying, test:
1. ✅ Log in as Barangay Official
2. ✅ Go to Transparency page
3. ✅ Click upload button
4. ✅ Select a document (PDF, DOC, etc.)
5. ✅ Should upload successfully
6. ✅ File should appear in the list
7. ✅ Click on file to view it

## Troubleshooting

### Still getting permission denied?
1. Check that your user document has `type: "Barangay Official"`
2. Verify you're logged in with the correct account
3. Clear app data and log in again
4. Check Firebase Console → Authentication to see if user exists

### Rules not taking effect?
- Rules changes are instant in Firebase
- Try force-stopping the app and restarting
- Clear browser cache if using web version

## Security Notes

These rules ensure:
- ✅ Only authenticated users can read transparency docs
- ✅ Only Barangay Officials can upload/edit/delete
- ✅ Users can only create document requests for themselves
- ✅ Officials can only update requests from their barangay
- ✅ All operations require authentication
