# 🎯 Firebase Composite Indexes - Quick Setup Checklist

## What You Need to Do (3 Simple Steps)

### Step 1: Go to Firebase Console
```
https://console.firebase.google.com/project/barangay-system-d67b0/firestore/indexes
```

### Step 2: Create 3 Composite Indexes

#### Index #1: Requests by Barangay + Timestamp
```
Collection: requests
Field 1: barangay (Ascending ⬆️)
Field 2: timestamp (Descending ⬇️)
```

#### Index #2: Transparency Docs by Barangay + Timestamp
```
Collection: transparency_docs
Field 1: barangay (Ascending ⬆️)
Field 2: timestamp (Descending ⬇️)
```

#### Index #3: Complaints by Barangay + Status + Timestamp
```
Collection: complaints
Field 1: barangay (Ascending ⬆️)
Field 2: status (Ascending ⬆️)
Field 3: timestamp (Descending ⬇️)
```

### Step 3: Wait & Verify
```
⏳ Wait 5-10 minutes for indexes to be built
✅ Check each index shows "Enabled" status
🎉 Run your app again!
```

---

## 🚀 Automatic Index Creation (Even Easier!)

If you see an error in your app logs like:
```
The query requires an index. You can create it here: https://console.firebase.google.com/...
```

Just **click the link** in the error message and Firebase creates it automatically!

---

## ✅ How to Know It's Working

After indexes are created and enabled:
1. App loads without "missing index" errors
2. Requests list shows items
3. Transparency docs load
4. Complaints filter works
5. No more permission/index error messages

---

## 💡 Why These Indexes?

Your app queries data like:
```dart
// Query 1: Get recent requests for a barangay
db.collection('requests')
  .where('barangay', isEqualTo: 'Cabaohan')
  .orderBy('timestamp', descending: true)
  .get();

// Query 2: Get recent transparency docs for barangay
db.collection('transparency_docs')
  .where('barangay', isEqualTo: 'Cabaohan')
  .orderBy('timestamp', descending: true)
  .get();

// Query 3: Get pending complaints for barangay
db.collection('complaints')
  .where('barangay', isEqualTo: 'Cabaohan')
  .where('status', isEqualTo: 'Pending')
  .orderBy('timestamp', descending: true)
  .get();
```

When you have:
- 1 `where` + 1 `orderBy` = composite index needed
- 2 `where` + 1 `orderBy` = composite index needed

---

## 📞 Need Help?

**Index creation taking too long?**
- Indexes usually build in 5-10 minutes
- Check back in Firebase Console → Firestore → Indexes
- They should show "Enabled" when ready

**Still getting "missing index" error after creating index?**
- Wait 2-3 minutes for index to fully enable
- Restart the app
- Clear app cache and restart again

**Getting "permission denied" after fixing indexes?**
- Check [FIRESTORE_SECURITY_RULES_GUIDE.md](FIRESTORE_SECURITY_RULES_GUIDE.md) section "Troubleshooting Permission Errors"
- Verify custom claims are set (role, barangay)
- Verify user is authenticated

---

## Status Tracker

- [ ] Firebase Console open
- [ ] Index #1 (requests) created
- [ ] Index #2 (transparency_docs) created
- [ ] Index #3 (complaints) created
- [ ] All indexes showing "Enabled"
- [ ] App restarted and tested
- [ ] All errors fixed! 🎉
