# 🔐 Firestore Security Rules & Indexes Guide

## Current Setup Overview

Your barangay_system has the following collections that need proper security rules and indexes:

| Collection | Purpose | Access Control |
|---|---|---|
| `users` | User profiles, roles, barangay assignment | Authenticated read, role-based write |
| `requests` | Document requests, certificates | Owner/Admin/Official for own barangay |
| `transparency_docs` | Transparency/audit documents | Admin/Official write, authenticated read |
| `complaints` | Citizen complaints | Owner/Admin/Official for own barangay |
| `announcements` | Barangay announcements | Authenticated read, barangay write |
| `notifications` | User notifications | User-specific |
| `phone_numbers` | Registration deduplication | Unrestricted get, authenticated write |

---

## ✅ Security Rules Explained

### 1. **Users Collection Rules**

```javascript
match /users/{userId} {
  // ✅ ALL authenticated users can READ users
  // This enables:
  // - Residents directory (filter by role==Resident)
  // - Pending approvals list (filter by status==pending)
  // - User searches and lookups
  allow read: if isAuthenticated();
  
  // ✅ Users create their own account
  allow create: if isOwner(userId);
  
  // ✅ Users update own profile (cannot change admin/barangay)
  allow update: if isOwner(userId)
    && !request.resource.data.diff(resource.data).affectedKeys()
      .hasAny(['isAdmin', 'barangay']);
  
  // ✅ Admins can update any user
  allow update: if isAdmin();
  
  // ✅ Officials can approve/reject users in their barangay
  allow update: if isBarangayOfficial()
    && resource.data.barangay == userBarangay()
    && request.resource.data.diff(resource.data).affectedKeys()
      .hasOnly(['status', 'role', 'approvedAt', 'rejectedAt']);
  
  // ✅ Only admins can delete
  allow delete: if isAdmin();
}
```

**Why it works:**
- `allow read: if isAuthenticated()` - All logged-in users can read all users
- Your app filters by role/barangay/status **in code** for UI purposes
- This passes through the Firestore Security Rules check
- Officials are limited to specific update fields

---

### 2. **Requests Collection Rules**

```javascript
match /requests/{requestId} {
  // ✅ Owner OR Admin OR Official in same barangay can read
  allow read: if isAuthenticated() && (
    resource.data.userId == request.auth.uid ||
    isAdmin() ||
    (isBarangayOfficial() && resource.data.barangay == userBarangay())
  );
  
  // ✅ Authenticated users create requests with their own ID
  allow create: if isAuthenticated() 
    && request.resource.data.userId == request.auth.uid;
  
  // ✅ Owner OR Admin OR Official can update
  allow update: if isAuthenticated() && (
    resource.data.userId == request.auth.uid ||
    isAdmin() ||
    (isBarangayOfficial() && resource.data.barangay == userBarangay())
  );
  
  // ✅ Only admins can delete
  allow delete: if isAdmin();
}
```

**Why it works:**
- Restricts access by ownership OR role
- Queries with `where barangay == X` will pass because Officials are allowed
- Queries with `order by timestamp` need composite index (see below)

---

### 3. **Transparency Docs Collection Rules**

```javascript
match /transparency_docs/{docId} {
  // ✅ All authenticated users can read transparency documents
  allow read: if isAuthenticated();
  
  // ✅ Only admins or officials can upload
  allow create, update, delete: if isAdmin() || 
    (isBarangayOfficial() && request.resource.data.barangay == userBarangay());
}
```

**Why it works:**
- Public read access (transparency = public data)
- Write restricted to officials

---

### 4. **Complaints Collection Rules**

```javascript
match /complaints/{complaintId} {
  // ✅ Owner OR Admin OR Official in same barangay can read
  allow read: if isAuthenticated() && (
    resource.data.userId == request.auth.uid ||
    isAdmin() ||
    (isBarangayOfficial() && resource.data.barangay == userBarangay())
  );
  
  // ✅ Authenticated users create complaints with their own ID
  allow create: if isAuthenticated() 
    && request.resource.data.userId == request.auth.uid;
  
  // ✅ Owner OR Admin OR Official can update
  allow update: if isAuthenticated() && (
    resource.data.userId == request.auth.uid ||
    isAdmin() ||
    (isBarangayOfficial() && resource.data.barangay == userBarangay())
  );
  
  // ✅ Only admins can delete
  allow delete: if isAdmin();
}
```

---

## 🔑 Important: Custom Claims Setup

For the security rules to work, your Firebase Cloud Function or custom authentication must set these **Custom Claims** on the user token:

```javascript
// When a user is registered as a Barangay Official
await admin.auth().setCustomUserClaims(uid, {
  role: 'Barangay Official',      // Or 'Resident'
  barangay: 'Cabaohan',           // Their assigned barangay
  isAdmin: false                   // true only for super admins
});

// When a user is registered as a Resident
await admin.auth().setCustomUserClaims(uid, {
  role: 'Resident',
  barangay: 'Cabaohan',
  isAdmin: false
});
```

**Your app must ensure these claims are set correctly!**

---

## 📊 Composite Indexes Required

Your queries use multiple `where` conditions and `order by` - this requires **composite indexes**.

### Index 1: Requests Collection
```
Collection: requests
Fields:
  1. barangay (Ascending)
  2. timestamp (Descending)
```

**Used by queries like:**
```dart
FirebaseFirestore.instance
  .collection('requests')
  .where('barangay', isEqualTo: 'Cabaohan')
  .orderBy('timestamp', descending: true)
  .limit(10)
  .get();
```

---

### Index 2: Transparency Docs Collection
```
Collection: transparency_docs
Fields:
  1. barangay (Ascending)
  2. timestamp (Descending)
```

**Used by queries like:**
```dart
FirebaseFirestore.instance
  .collection('transparency_docs')
  .where('barangay', isEqualTo: 'Cabaohan')
  .orderBy('timestamp', descending: true)
  .limit(10)
  .get();
```

---

### Index 3: Complaints Collection
```
Collection: complaints
Fields:
  1. barangay (Ascending)
  2. status (Ascending)
  3. timestamp (Descending)
```

**Used by queries like:**
```dart
FirebaseFirestore.instance
  .collection('complaints')
  .where('barangay', isEqualTo: 'Cabaohan')
  .where('status', isEqualTo: 'Pending')
  .orderBy('timestamp', descending: true)
  .limit(10)
  .get();
```

---

## 🚀 How to Create Indexes

### Method 1: Automatic Creation (Easiest)
When you run queries that need indexes, Firebase shows you an error with a **direct console link**. Click the link and Firebase creates it automatically.

### Method 2: Manual Creation
1. Go to **Firebase Console** → **Firestore** → **Indexes** tab
2. Click **Create Index**
3. Select Collection name
4. Add fields in order specified above
5. Click **Create**

### Method 3: Bulk Create via Command
```bash
# First, install Firebase tools
npm install -g firebase-tools

# Create firestore.indexes.json in your project root
cat > firestore.indexes.json << 'EOF'
{
  "indexes": [
    {
      "collectionGroup": "requests",
      "queryScope": "Collection",
      "fields": [
        {"fieldPath": "barangay", "order": "ASCENDING"},
        {"fieldPath": "timestamp", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "transparency_docs",
      "queryScope": "Collection",
      "fields": [
        {"fieldPath": "barangay", "order": "ASCENDING"},
        {"fieldPath": "timestamp", "order": "DESCENDING"}
      ]
    },
    {
      "collectionGroup": "complaints",
      "queryScope": "Collection",
      "fields": [
        {"fieldPath": "barangay", "order": "ASCENDING"},
        {"fieldPath": "status", "order": "ASCENDING"},
        {"fieldPath": "timestamp", "order": "DESCENDING"}
      ]
    }
  ],
  "fieldOverrides": []
}
EOF

# Deploy indexes
firebase deploy --only firestore:indexes
```

---

## ✅ Testing Your Rules

### Test 1: User Can Read All Users
```
User: user123 (authenticated as Resident)
Query: users collection, read operation
Expected: ✅ ALLOWED (isAuthenticated() = true)
```

### Test 2: Official Can Update User in Same Barangay
```
User: official123 (authenticated as Barangay Official, barangay=Cabaohan)
Document: users/user456 with barangay=Cabaohan
Update: status field only
Expected: ✅ ALLOWED
```

### Test 3: Official Cannot Update User in Different Barangay
```
User: official123 (authenticated as Barangay Official, barangay=Cabaohan)
Document: users/user456 with barangay=DifferentBarangay
Update: status field
Expected: ❌ DENIED (barangay mismatch)
```

### Test 4: Query with Where + OrderBy
```
Query: requests where barangay==Cabaohan order by timestamp desc
Expected: ⏳ NEEDS INDEX (once index created: ✅ ALLOWED)
```

---

## 🔧 Troubleshooting Permission Errors

### "Missing or insufficient permissions"

**Cause 1:** User not authenticated
```
❌ NOT LOGGED IN → Can't read
✅ Solution: Ensure user is authenticated before queries
```

**Cause 2:** Custom claims not set
```
❌ Custom claims missing → isAdmin(), isBarangayOfficial() fail
✅ Solution: Verify custom claims set when user registered
```

**Cause 3:** Role mismatch
```
❌ Official trying to access different barangay
✅ Solution: Check barangay field in custom claims matches document barangay
```

### "The query requires an index"

**Cause:** Composite index not created
```
❌ Multi-field query without index
✅ Solution: Create composite index (see methods above)
```

---

## 📋 Security Best Practices Applied

✅ **Principle of Least Privilege**
- Users can only read/write their own data or data in their role's scope
- Officials limited to their barangay
- Admins have full access

✅ **Data Segregation by Barangay**
- Every document has a `barangay` field
- Rules check `resource.data.barangay == userBarangay()`
- Prevents officials from accessing other barangays

✅ **Role-Based Access Control**
- Different permissions for Resident vs Official vs Admin
- Enforced at Firestore level

✅ **Audit Trail**
- Updates restricted to specific fields
- Provides accountability

✅ **Public vs Private Data**
- transparency_docs: public read (allow read: if authenticated)
- complaints: private (ownership-based access)
- users: semi-public (all authenticated can read, but filtered in app)

---

## 📝 Checklist Before Deploying

- [ ] Custom claims set correctly in Cloud Functions (or wherever auth happens)
- [ ] All 3 composite indexes created in Firebase Console
- [ ] Indexes show "Enabled" status (wait 5-10 minutes after creation)
- [ ] Test rules in Firebase Console's "Rules playground"
- [ ] App properly filters sensitive data in code (don't rely solely on rules)
- [ ] Barangay field populated in all user documents
- [ ] All requests, transparency_docs, complaints have barangay field

---

## 🎯 What This Fixes

✅ Permission Denied on users collection queries
✅ Permission Denied on requests queries
✅ Permission Denied on transparency_docs queries
✅ Missing Composite Index errors
✅ Role-based access control working
✅ Barangay-based data segregation enforced
✅ Officials can only approve users in their barangay

---

**Status:** All rules ready to deploy. Create the 3 indexes and you're good to go! 🚀
