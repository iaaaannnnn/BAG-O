# Guest Resident Account Expiration Feature

## Overview
Guest resident accounts now automatically expire after **30 days** from creation. They have the same UI and features as regular residents, but with a deadline tracking system and renewal capability.

## Features Implemented

### 1. **30-Day Account Lifespan**
- When a guest resident registers, an `expirationDate` field is set to 30 days from the current date
- This date is stored in Firestore as a Timestamp

### 2. **Expiration Warning System**
The app displays different warnings based on account status:

#### **Show Always (If Not Expired)**
- **More than 7 days remaining**: No warning displayed
- **Within 7 days**: Orange warning with countdown (e.g., "Your account will expire in 5 day(s)")
- **Within 24 hours**: Red urgent warning with "RENEW ACCOUNT NOW" button
- **Expired**: Red banner saying account has expired with disabled renewal button

#### **Warning Display Locations**
1. **Guest Resident Dashboard** - Below the guest access info banner
2. **Profile Page** - Below the user's role/type badge
3. Shows only for guest residents; regular residents don't see these warnings

### 3. **Account Renewal**
- Guest residents can renew their account **within 24 hours before expiration**
- Renewal adds another 30 days to the account lifetime
- Renewal date is tracked with `lastRenewalDate` field
- When renewed, a success message confirms: "✓ Account renewed for 30 more days!"

### 4. **Firestore Security Rules Update**
The Firestore rules now allow guest residents to update their:
- `expirationDate`
- `lastRenewalDate`

This is restricted to guest residents only during renewal operations.

## Code Implementation

### Modified Files

#### **lib/main.dart**

**AuthService Updates:**
```dart
// Registration - adds expirationDate for guest residents
if (type == 'Guest Resident') {
  userDoc['expirationDate'] = Timestamp.fromDate(DateTime.now().add(const Duration(days: 30)));
}

// New method: getGuestExpirationInfo()
// Returns expiration status including:
// - daysRemaining
// - hoursRemaining  
// - isExpired
// - canRenew
// - renewalMessage

// New method: renewGuestAccount()
// Renews the account for another 30 days
```

**New Widget: buildGuestExpirationWarning()**
- Color-coded warning display (orange → red based on urgency)
- Shows renewal button when eligible (24 hours before expiration)
- Disabled button when account is expired
- Auto-hides when more than 7 days remaining

**Integration Points:**
- `ResidentDashboard._buildGuestDashboard()` - Added warning after guest info banner
- `ProfilePage.build()` - Added warning after user's role badge

#### **firestore.rules**

Updated users collection update rules:
```javascript
allow update: if isOwner(userId)
  && !request.resource.data.diff(resource.data).affectedKeys()
    .hasAny(['isAdmin', 'barangay', 'status', 'role', 'type', 'email', 'mobile'])
  && (
    // Allow expirationDate updates for guest residents (renewal)
    (resource.data.type == 'Guest Resident' && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['expirationDate', 'lastRenewalDate']))
    // Or regular profile updates for non-guests
    || resource.data.type != 'Guest Resident'
  );
```

## User Experience

### Timeline Example: Guest Resident with 30-Day Account

**Day 1-23**: Account active, no warnings displayed
**Day 24**: Orange warning appears - "Your account will expire in 7 day(s)"
**Day 29-29.96 (< 24 hours)**: Red urgent warning with "RENEW ACCOUNT NOW" button appears
**Day 30 00:00**: Account expires - red "Account Expired" message
**After Day 30**: Cannot use app until contacting barangay office to reactivate

### Renewal Example

Guest resident on Day 29 (< 24 hours before expiration):
1. Sees red warning: "🚨 Renew Account Now"
2. Taps "RENEW ACCOUNT" button
3. Confirmation dialog appears
4. Confirms renewal
5. Gets success message: "✓ Account renewed for 30 more days!"
6. Account is now active for another 30 days (Day 59)

## Data Model

### User Document Fields (Guest Resident)

```json
{
  "type": "Guest Resident",
  "createdAt": Timestamp,
  "expirationDate": Timestamp,
  "lastRenewalDate": Timestamp (optional, set on renewal)
  // ... other fields (same as regular residents)
}
```

## API Reference

### AuthService.getGuestExpirationInfo()
Returns `null` for non-guest residents or `Map<String, dynamic>`:
```dart
{
  'expirationDate': DateTime,
  'daysRemaining': int,
  'hoursRemaining': int,
  'isExpired': bool,
  'canRenew': bool,  // true if within 24 hours and not expired
  'renewalMessage': String,  // human-readable message
}
```

### AuthService.renewGuestAccount()
Renews account for 30 more days. Returns `bool`:
- `true` if renewal successful
- `false` if user is not guest resident or renewal failed

## Testing Checklist

- [ ] Guest resident registration sets expirationDate correctly
- [ ] Dashboard shows warning within 7 days
- [ ] Red warning appears within 24 hours
- [ ] Renewal button is disabled when account is expired
- [ ] Renewal extends account for 30 more days
- [ ] Profile page also shows expiration warning
- [ ] Warning auto-hides when more than 7 days remain
- [ ] Regular residents don't see expiration warnings
- [ ] Firestore rules allow guest renewal updates
- [ ] Expired accounts prevent login or app access

## Future Enhancements

- Add automatic account deletion after 7 days of expiration
- Send push notification 1 day before expiration
- Add renewal history in profile
- Admin dashboard showing guest resident expiration dates
- Bulk renewal option for barangay officials
