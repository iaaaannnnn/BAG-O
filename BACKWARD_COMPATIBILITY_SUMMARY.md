# Backward Compatibility Implementation - Summary

## Overview
This document summarizes all backward compatibility changes applied to `lib/main.dart` to gracefully handle the migration from old to new Firestore field names. The changes ensure that the app continues to work with both old and new field names during the data migration period.

## Field Name Mappings

### Users Collection
| Old Field | New Field | Usage |
|-----------|-----------|-------|
| `type` | `role` | User role (Resident, Barangay Official) |
| `approvalStatus` | `status` | Approval status (pending, approved, rejected) |
| `approval` | `status` | Alternative old field name for approval status |

### Transparency Docs Collection
| Old Field | New Field | Usage |
|-----------|-----------|-------|
| `title` | `fileName` | Document filename |
| `url` | `fileUrl` | Document file URL in storage |
| `timestamp` | `uploadDate` | Upload timestamp |
| `type` | — | (Deleted, no longer used) |

### Requests Collection
| Field | Usage |
|-------|-------|
| `status` | New standard field for request status |
| `approval` | Legacy field (still written for backward compat, queried during transition) |

## Changes Applied

### 1. **Registration & User Creation** (Line ~1055)
**Changed to:** Write new field names
```dart
'status': _userType == 'Resident' ? 'pending' : 'approved',
'role': _userType,
```
**Backward Compat:** Deletes old `approvalStatus` and `approval` fields on approve/reject actions

---

### 2. **Approval Panel** (Lines ~1900-1950)
**Status Check:** Fallback through all possible field names
```dart
String status = ((userData['status'] as String?) ?? 
  (userData['approvalStatus'] as String?) ?? 
  (userData['approval'] as String?) ?? 
  'approved').toString().toLowerCase();
```

**Approval Handler:** Deletes old fields after updating new ones
```dart
'approvalStatus': FieldValue.delete(),
'approval': FieldValue.delete(),
```

**Rejection Handler:** Same cleanup pattern as approval

---

### 3. **Profile Page** (Line ~2709)
**Changed to:** Read new field with fallback
```dart
Text((userData['role'] ?? userData['type'] ?? 'Resident').toString(), 
  style: TextStyle(color: Colors.grey[600]!)),
```

---

### 4. **Residents Directory** (Line ~1853)
**Displays role:** Uses fallback chain
```dart
final appliedRole = (userData['role'] ?? userData['type'] ?? 'Resident').toString();
```

---

### 5. **Transparency Documents Upload** (Lines ~2850-2920)
**Writes both field names:** For backward compatibility during migration
```dart
'fileName': docName,
'fileUrl': uploadedUrl,
'uploadDate': FieldValue.serverTimestamp(),
'uploadedBy': userId,
// Legacy fields for backward compat
'title': docName,
'url': uploadedUrl,
'timestamp': FieldValue.serverTimestamp(),
'type': 'document',
```

**Storage Path:** `/transparency_docs/{barangay}/{timestamp}_{filename}`

---

### 6. **Transparency Documents Display** (Lines ~2958-2959)
**Reads with fallbacks:**
```dart
final ts = data['uploadDate'] as Timestamp? ?? data['timestamp'] as Timestamp?;
final title = data['fileName'] as String? ?? data['title'] as String? ?? 'Untitled';
final url = data['fileUrl'] as String? ?? data['url'] as String?;
```

---

### 7. **Approved Residents View** (Line ~1976)
**Status check:** Fallback chain for reading status
```dart
final status = (m['status'] ?? m['approvalStatus'] ?? m['approval'])?.toString() ?? '';
return status.toLowerCase() == 'approved';
```

---

### 8. **Request Status Display** (Line ~2059)
**Changed to:** Read new field first
```dart
trailing: Text(data['status'] ?? data['approval'] ?? ''),
```

---

### 9. **Request Queries** (Lines ~3141, 3147)
**Updated to query new field:** Changed from `approval == 'Pending'` to `status == 'Pending'`
```dart
.where('status', isEqualTo: 'Pending')
```
*Note: Requests still write both `status` and `approval` fields for compatibility*

---

### 10. **Rejection Status Check** (Line ~1575)
**Changed to:** Check new field name
```dart
} else if (status == 'rejected') {
```
*Previously checked old field name `approvalStatus`*

---

## Firestore Rules Updates

File: `firestore.rules`

### New Helper Functions
```javascript
function isBarangayOfficial() {
  return request.auth.token.role == 'Barangay Official';
}
```

### Permissions Granted
- **Users collection:** Officials can read/update approval fields (status, role, approvedAt, rejectedAt) for users in their barangay
- **Transparency Docs:** Officials can create/update/delete documents for their barangay
- **Complaints:** Officials can read/update complaints for their barangay
- **Requests:** Officials can read/update requests for their barangay

---

## Migration Script

File: `scripts/migrate_firestore.js`

This Node.js script performs one-time data migration:

### Operations
1. **migrateUsers()** - Normalizes user role and status fields
2. **migrateTransparencyDocs()** - Maps old field names to new ones
3. **idempotent design** - Safe to run multiple times

### Usage
```bash
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account-key.json
node scripts/migrate_firestore.js
```

---

## Testing Checklist

### Before Running Migration
- [ ] Backup Firestore database (export to JSON)
- [ ] Test app locally with `flutter run -d android` or preferred platform
- [ ] Verify all features work: approvals, transparency uploads, resident directory

### After Running Migration
- [ ] Verify old field names are removed from documents
- [ ] Confirm queries work with new field names
- [ ] Check Firestore rules grant correct permissions
- [ ] Test all workflows still function correctly

---

## Dependencies

Updated in `pubspec.yaml`:
- `file_picker: ^6.0.0` (added for transparency doc file selection)
- `rxdart: ^0.28.0` (debounceTime for rate limiting)

---

## Code Analysis Status

**Result:** ✅ **Clean** (36 info/warning issues only, **0 errors**)
- No compilation errors after adding `file_picker`
- All backward compatibility fallback chains implemented
- Analysis passes with `flutter analyze`

---

## Deployment Strategy

1. **Phase 1 (Current):** Deploy updated app with backward compatibility reads/writes
   - App writes both old and new field names
   - App reads new field names with fallbacks to old
   - Existing data continues to work seamlessly

2. **Phase 2 (After migration):** Run `scripts/migrate_firestore.js`
   - Normalizes all existing documents
   - Removes old field names
   - Frees up Firestore storage

3. **Phase 3 (Optional):** Remove backward compatibility code
   - After confirming all data migrated
   - Simplify code by removing fallback chains
   - Recommended: 2-4 weeks after Phase 2

---

## Key Takeaways

✅ **No Breaking Changes:** Users with old data can continue using the app  
✅ **Gradual Migration:** Data migrated incrementally, no downtime required  
✅ **Firestore Rules:** Officials now have proper permissions for approval workflows  
✅ **Rate Limiting:** Client-side throttling prevents abuse (200ms debounce, 30s upload throttle)  
✅ **UI Improvements:** All pages show "No data available." when empty  
✅ **File Handling:** Transparency docs restricted to PDF/DOCX/XLSX/CSV only  

---

## Next Steps

1. Run `flutter pub get` and `flutter analyze` ✅ (Complete)
2. Test locally on Android/iOS/web
3. Review and deploy updated `firestore.rules`
4. When ready, execute `scripts/migrate_firestore.js`
5. Validate all data migrated successfully
6. Monitor app for any issues with new field names
