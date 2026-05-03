# Document Fulfillment System Guide

## Overview
A complete system for Barangay Officials to fulfill document requests from residents by uploading files directly through the app.

## Features Implemented

### For Barangay Officials:
1. **Enhanced PendingRequestsPage**
   - View all pending document requests from residents
   - Upload button on each request card
   - Dialog to select and upload document files
   - Supports: PDF, DOCX, DOC, XLSX, XLS, JPG, JPEG, PNG
   - Max file size: 2MB (stored as base64 in Firestore)
   - Automatically notifies resident when document is ready

### For Residents:
1. **New MyDocumentRequestsPage**
   - View all document requests (Pending, Fulfilled, Rejected)
   - Color-coded status badges (Orange=Pending, Green=Fulfilled, Red=Rejected)
   - Download button for fulfilled documents
   - Opens documents in browser using HTML iframe wrapper
   
2. **Dashboard Integration**
   - Added "My Document Requests" card in resident dashboard
   - Easy access to check request status and download documents

## How It Works

### Official Workflow:
1. Official navigates to "Pending Requests"
2. Sees list of document requests from residents
3. Clicks upload icon on a request
4. Selects document file from device
5. File is converted to base64 and stored in Firestore
6. Request status changes to "Fulfilled"
7. Resident receives notification

### Resident Workflow:
1. Resident requests document (via existing Request Documents page)
2. Checks "My Document Requests" to track status
3. When status shows "Fulfilled", download icon appears
4. Clicks download to view document in browser
5. Document opens in new tab/window

## Data Structure

### Request Document Fields:
```dart
{
  'userId': String,           // Resident's UID
  'userName': String,          // Resident's name
  'subject': String,           // Document type requested
  'status': String,            // 'Pending', 'Fulfilled', 'Rejected'
  'barangay': String,          // Barangay name
  'timestamp': Timestamp,      // Request date
  
  // Added for fulfillment:
  'fulfilledAt': Timestamp?,              // When fulfilled
  'fulfilledBy': String?,                 // Official's UID
  'fulfillmentFileName': String?,         // Original filename
  'fulfillmentFileData': String?,         // Base64 encoded file
  'fulfillmentFileType': String?,         // File extension (pdf, docx, etc)
  'fulfillmentFileSize': int?,            // Size in bytes
}
```

## Firestore Indexes Required

### 1. For MyDocumentRequestsPage (Residents viewing their requests):
**Collection:** `document_requests`
**Query:** `.where('userId', isEqualTo: uid).orderBy('timestamp', descending: true)`

**Index needed:**
- Collection: `document_requests`
- Fields:
  - `userId` (Ascending)
  - `timestamp` (Descending)

**Create in Firebase Console:**
```
https://console.firebase.google.com/project/YOUR_PROJECT/firestore/indexes
```

**Or add to firestore.indexes.json:**
```json
{
  "indexes": [
    {
      "collectionGroup": "document_requests",
      "queryScope": "COLLECTION",
      "fields": [
        {
          "fieldPath": "userId",
          "order": "ASCENDING"
        },
        {
          "fieldPath": "timestamp",
          "order": "DESCENDING"
        }
      ]
    }
  ]
}
```

### 2. For PendingRequestsPage (Officials viewing pending requests):
**Collection:** `document_requests`
**Query:** `.where('barangay', isEqualTo: X).where('status', isEqualTo: 'Pending')`

**Index needed:**
- Collection: `document_requests`
- Fields:
  - `barangay` (Ascending)
  - `status` (Ascending)

**Add to firestore.indexes.json:**
```json
{
  "collectionGroup": "document_requests",
  "queryScope": "COLLECTION",
  "fields": [
    {
      "fieldPath": "barangay",
      "order": "ASCENDING"
    },
    {
      "fieldPath": "status",
      "order": "ASCENDING"
    }
  ]
}
```

## File Handling

### Storage Method:
- Files are stored as **base64 strings** directly in Firestore documents
- This is FREE (no Firebase Storage costs)
- Max file size limited to 2MB to stay within Firestore document limits

### Viewing Method:
- Creates HTML iframe wrapper around data URL
- Opens in external browser
- Works on web, Android, Windows, iOS

### Supported File Types:
- **Documents:** PDF, DOC, DOCX, XLS, XLSX
- **Images:** JPG, JPEG, PNG
- Max size: 2MB per file

## Rules & Constraints

1. **File Size Limit:** 2MB maximum (enforced in UI)
2. **Rate Limiting:** Uses existing throttle helpers
3. **Security:** Only officials can upload, only request owner can view
4. **Notifications:** Automatic notification when document is fulfilled
5. **Status Flow:** Pending → Fulfilled (or Rejected)

## Testing Checklist

- [ ] Official can see pending requests
- [ ] Official can upload document to fulfill request
- [ ] File picker shows only allowed file types
- [ ] Files larger than 2MB are rejected
- [ ] Request status updates to "Fulfilled"
- [ ] Resident receives notification
- [ ] Resident can see fulfilled request in "My Document Requests"
- [ ] Resident can download/view the document
- [ ] Document opens correctly in browser
- [ ] Status badges show correct colors

## Security Considerations

### Firestore Rules Needed:
```javascript
// Allow residents to read their own document requests
match /document_requests/{requestId} {
  allow read: if request.auth != null && 
                 resource.data.userId == request.auth.uid;
  
  // Allow residents to create document requests
  allow create: if request.auth != null && 
                   request.resource.data.userId == request.auth.uid;
  
  // Allow officials to update document requests for their barangay
  allow update: if request.auth != null && 
                   get(/databases/$(database)/documents/users/$(request.auth.uid)).data.type == 'Barangay Official' &&
                   get(/databases/$(database)/documents/users/$(request.auth.uid)).data.barangay == resource.data.barangay;
}
```

## Troubleshooting

### Issue: "Cannot open file viewer"
- **Cause:** Browser doesn't support data URLs
- **Solution:** Try different browser or device

### Issue: Index error on MyDocumentRequestsPage
- **Cause:** Missing composite index for userId + timestamp
- **Solution:** Create index in Firebase Console or deploy firestore.indexes.json

### Issue: File upload fails
- **Cause:** File too large or wrong type
- **Solution:** Check file size (<2MB) and extension (PDF, DOC, XLS, JPG, PNG)

### Issue: Resident doesn't see fulfilled document
- **Cause:** Request saved to old collection or user subcollection
- **Solution:** All new document requests are saved to `/document_requests` collection. Check that requests are being created in the correct collection.

## Future Enhancements

- [ ] Add file preview before upload
- [ ] Support larger files with chunking
- [ ] Add digital signature verification
- [ ] Track download history
- [ ] Add expiration dates for fulfilled documents
- [ ] Support multiple file attachments per request
- [ ] Add admin dashboard for analytics

## Notes

- All files stored as base64 to avoid Firebase Storage costs
- HTML iframe wrapper provides better cross-platform compatibility
- Status color coding provides clear visual feedback
- Notification system keeps residents informed
- 2MB limit ensures Firestore document size compliance
