part of '../../app/app.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Firebase Storage disabled - using base64 in Firestore instead
  // static final FirebaseStorage _storage = FirebaseStorage.instance;

  static User? get currentUser => _auth.currentUser;
  static String? userType;
  static Map<String, dynamic>? currentUserData;

  static Future<void> saveThemeMode(String mode) async {
    if (currentUser == null) return;
    // Fire-and-forget: save to Firestore in background without blocking UI
    _firestore.collection('users').doc(currentUser!.uid).set(
      {'themeMode': mode},
      SetOptions(merge: true),
    ).catchError((e) {
      debugLog('[AuthService] Failed to save theme mode: $e');
    });
  }

  static Future<bool> deleteAccount() async {
    if (currentUser == null) return false;
    try {
      final uid = currentUser!.uid;
      final userData = await getUserData();
      if (userData == null) return false;

      // Get phone and email to track deletion
      final rawPhone = (userData['mobile'] ?? '').toString();
      String normalizedPhone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
      if (normalizedPhone.startsWith('63')) normalizedPhone = '0' + normalizedPhone.substring(2);
      if (normalizedPhone.length == 10 && normalizedPhone.startsWith('9')) normalizedPhone = '0' + normalizedPhone;
      final email = (userData['email'] ?? '').toString().trim().toLowerCase();

      // Mark account as deleted and store deletion timestamp
      final deletionTimestamp = DateTime.now();
      await _firestore.collection('deleted_accounts').doc(uid).set({
        'uid': uid,
        'email': email,
        'phone': normalizedPhone,
        'deletedAt': Timestamp.fromDate(deletionTimestamp),
        'canReregisterAt': Timestamp.fromDate(deletionTimestamp.add(const Duration(days: 7))),
        'userData': userData,
      });

      // Delete user document
      await _firestore.collection('users').doc(uid).delete();

      // Delete related phone/email reservations
      if (normalizedPhone.isNotEmpty) {
        await _firestore.collection('phone_numbers').doc(normalizedPhone).delete();
      }
      if (email.isNotEmpty) {
        await _firestore.collection('phone_numbers').doc('email_$email').delete();
      }

      // Delete Firebase Auth account
      await currentUser!.delete();
      
      // Clear local state
      userType = null;
      currentUserData = null;
      
      debugLog('[AUTH] Account deleted successfully');
      return true;
    } catch (e) {
      debugLog('[AUTH] Error deleting account: $e');
      return false;
    }
  }

  static Future<bool> cancelRequest() async {
    if (currentUser == null) return false;
    try {
      final uid = currentUser!.uid;
      final userData = await getUserData();
      if (userData == null || userData['status'] != 'pending') return false;

      // Get phone and email to track cancellation
      final rawPhone = (userData['mobile'] ?? '').toString();
      String normalizedPhone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
      if (normalizedPhone.startsWith('63')) normalizedPhone = '0' + normalizedPhone.substring(2);
      if (normalizedPhone.length == 10 && normalizedPhone.startsWith('9')) normalizedPhone = '0' + normalizedPhone;
      final email = (userData['email'] ?? '').toString().trim().toLowerCase();

      // Mark account as cancelled (no re-registration ban for pending accounts)
      final cancellationTimestamp = DateTime.now();
      await _firestore.collection('cancelled_accounts').doc(uid).set({
        'uid': uid,
        'email': email,
        'phone': normalizedPhone,
        'cancelledAt': Timestamp.fromDate(cancellationTimestamp),
        'userData': userData,
      });

      // Delete user document
      await _firestore.collection('users').doc(uid).delete();

      // Delete related phone/email reservations
      if (normalizedPhone.isNotEmpty) {
        await _firestore.collection('phone_numbers').doc(normalizedPhone).delete();
      }
      if (email.isNotEmpty) {
        await _firestore.collection('phone_numbers').doc('email_$email').delete();
      }

      // Delete Firebase Auth account
      await currentUser!.delete();
      
      // Clear local state
      userType = null;
      currentUserData = null;
      
      debugLog('[AUTH] Request cancelled successfully');
      return true;
    } catch (e) {
      debugLog('[AUTH] Error cancelling request: $e');
      return false;
    }
  }

  static Future<bool> register(String email, String password, String type, Map<String, dynamic> userData) async {
    UserCredential? userCredential;
    try {
      debugLog('Attempting to register: $email');

      // Check for recently deleted accounts with same email/phone
      final normalizedEmail = email.trim().toLowerCase();
      final rawPhone = (userData['mobile'] ?? '').toString();
      String normalizedPhone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
      if (normalizedPhone.startsWith('63')) normalizedPhone = '0' + normalizedPhone.substring(2);
      if (normalizedPhone.length == 10 && normalizedPhone.startsWith('9')) normalizedPhone = '0' + normalizedPhone;

      final deletedAccountsQuery = await _firestore.collection('deleted_accounts')
          .where('email', isEqualTo: normalizedEmail)
          .get();
      
      for (var doc in deletedAccountsQuery.docs) {
        final data = doc.data();
        final canReregisterAt = (data['canReregisterAt'] as Timestamp).toDate();
        if (DateTime.now().isBefore(canReregisterAt)) {
          final daysRemaining = canReregisterAt.difference(DateTime.now()).inDays + 1;
          throw FirebaseException(
            plugin: 'cloud_firestore',
            message: 'This email was recently deleted. You can re-register in $daysRemaining day(s).',
          );
        }
      }

      if (normalizedPhone.isNotEmpty) {
        final deletedPhoneQuery = await _firestore.collection('deleted_accounts')
            .where('phone', isEqualTo: normalizedPhone)
            .get();
        
        for (var doc in deletedPhoneQuery.docs) {
          final data = doc.data();
          final canReregisterAt = (data['canReregisterAt'] as Timestamp).toDate();
          if (DateTime.now().isBefore(canReregisterAt)) {
            final daysRemaining = canReregisterAt.difference(DateTime.now()).inDays + 1;
            throw FirebaseException(
              plugin: 'cloud_firestore',
              message: 'This phone number was recently deleted. You can re-register in $daysRemaining day(s).',
            );
          }
        }
      }

      // Create user account (will throw if email already exists)
      debugLog('Creating user account...');
      userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      debugLog('User created with UID: ${userCredential.user!.uid}');
      debugLog('Saving to Firestore...');
      
      try {
        final userDoc = {
          'type': type,
          ...userData,
          'createdAt': FieldValue.serverTimestamp(),
        };
        
        // Add expiration date for guest residents (30 days from now)
        if (type == 'Guest Resident') {
          userDoc['expirationDate'] = Timestamp.fromDate(DateTime.now().add(const Duration(days: 30)));
        }
        
        await _firestore.collection('users').doc(userCredential.user!.uid).set(userDoc);
        debugLog('Firestore write successful!');
      } catch (firestoreError) {
        debugLog('Firestore write error: $firestoreError');
        // Attempt to clean up the auth user since Firestore write failed
        try {
          await userCredential!.user!.delete();
          debugLog('Rolled back created auth user due to Firestore error.');
        } catch (delErr) {
          debugLog('Failed to delete orphaned user: $delErr');
        }
        rethrow;
      }


        debugLog('Registration: attempting to reserve phone/email for duplicate prevention...');

        // Use already normalized phone/email from above for duplicate prevention
        try {
          await _firestore.runTransaction((txn) async {
            final phoneRef = normalizedPhone.isNotEmpty
                ? _firestore.collection('phone_numbers').doc(normalizedPhone)
                : null;
            final emailRef = _firestore.collection('phone_numbers').doc('email_$normalizedEmail');

            if (phoneRef != null) {
              final phoneSnap = await txn.get(phoneRef);
              if (phoneSnap.exists) {
                throw FirebaseException(
                  plugin: 'cloud_firestore',
                  message: 'Phone number already registered',
                );
              }
            }

            final emailSnap = await txn.get(emailRef);
            if (emailSnap.exists) {
              throw FirebaseException(
                plugin: 'cloud_firestore',
                message: 'Email already registered',
              );
            }

            if (phoneRef != null) {
              txn.set(phoneRef, {
                'uid': userCredential!.user!.uid,
                'email': normalizedEmail,
                'createdAt': FieldValue.serverTimestamp(),
              });
            }

            txn.set(emailRef, {
              'uid': userCredential!.user!.uid,
              'phone': normalizedPhone,
              'createdAt': FieldValue.serverTimestamp(),
            });
          });
          debugLog('Reserved phone/email in phone_numbers collection successfully.');
        } catch (reservationError) {
          debugLog('Reservation error: $reservationError');
          // Rollback: delete created auth user and users doc if reservation fails
          try {
            await userCredential!.user!.delete();
            await _firestore.collection('users').doc(userCredential.user!.uid).delete();
            debugLog('Rolled back created auth user and user doc due to reservation failure.');
          } catch (delErr) {
            debugLog('Failed to rollback after reservation failure: $delErr');
          }
          rethrow;
        }

        // Sign out the newly-created user so the app returns to the login flow.
        await _auth.signOut();
        debugLog('Registration successful! New user signed out; please login.');
        return true;
    } on FirebaseAuthException catch (e) {
      // Re-throw to allow UI to present specific messages
      debugLog('FirebaseAuthException during register: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugLog('Registration error (general): $e');
      rethrow;
    }
  }

  static Future<bool> login(String email, String password) async {
    try {
      // CRITICAL: Reset all state before login to prevent stale data from previous session
      userType = null;
      currentUserData = null;
      _themeInitialized = false; // Reset theme to force fresh load for this user
      
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userCredential.user!.uid).get();
      currentUserData = userDoc.data() as Map<String, dynamic>?;
      userType = currentUserData?['type'];

      if (!userDoc.exists || currentUserData == null) {
        await _auth.signOut();
        throw FirebaseAuthException(
          code: 'profile-not-found',
          message: 'Your account profile could not be loaded. Please contact support.',
        );
      }
      
      // Check approval status for residents/guest residents
      if (userType == 'Resident' || userType == 'Guest Resident') {
        // Check status field with multiple fallback checks - get the actual value from Firestore
        String status = (currentUserData?['status'] ?? '').toString().toLowerCase();
        if (status.isEmpty) {
          status = (currentUserData?['approvalStatus'] ?? '').toString().toLowerCase();
        }
        if (status.isEmpty) {
          status = (currentUserData?['approval'] ?? '').toString().toLowerCase();
        }
        
        debugLog('[AUTH] Resident login - checking status: $status (raw status=${currentUserData?['status']}, approvalStatus=${currentUserData?['approvalStatus']}, approval=${currentUserData?['approval']})');
        
        if (status == 'pending') {
          // Clear the auth state since we're not allowing login
          await _auth.signOut();
          throw FirebaseAuthException(
            code: 'account-pending-approval',
            message: 'Your account is pending approval from barangay officials. Please try again later.',
          );
        } else if (status == 'rejected') {
          // Clear the auth state since we're not allowing login
          await _auth.signOut();
          throw FirebaseAuthException(
            code: 'account-rejected',
            message: 'Your account registration has been rejected. Please contact your barangay office.',
          );
        }
        
        // Check if there are any barangay officials for this barangay
        final userBarangay = currentUserData?['barangay'] as String? ?? '';
        if (userBarangay.isNotEmpty) {
          try {
            final officialsSnapshot = await _firestore
                .collection('users')
                .where('type', isEqualTo: 'Barangay Official')
                .where('barangay', isEqualTo: userBarangay)
                .limit(1)
                .get();
            
            if (officialsSnapshot.docs.isEmpty) {
              // No officials found - sign out and show error
              await _auth.signOut();
              throw FirebaseAuthException(
                code: 'no-officials-found',
                message: userType == 'Guest Resident'
                    ? 'There are no registered barangay officials in your selected barangay yet. Guest resident login is currently unavailable. Please try again later when officials have been registered.'
                    : 'There are no registered barangay officials in your barangay yet. Login may take longer than expected. Please contact your barangay office for assistance.',
              );
            }
          } catch (e) {
            debugLog('[AUTH] Error checking for officials: $e');
            // If it's already a FirebaseAuthException, rethrow it
            if (e is FirebaseAuthException) {
              rethrow;
            }
            // Otherwise, continue with login (don't block on this check failing)
          }
        }
      }
      
      // Load and apply user's saved theme preference immediately
      final savedTheme = (currentUserData?['themeMode'] as String? ?? 'light').toLowerCase();
      themeModeNotifier.value = savedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;
      _themeInitialized = true; // Mark theme as initialized
      debugLog('[AUTH] [OK] Applied saved theme: $savedTheme');
      
      debugLog('Login successful. UID=${userCredential.user!.uid}, type=${userType}');
      
      // Force UI refresh by incrementing with large value to ensure rebuild
      // Use a slightly longer delay to ensure Firebase auth state has propagated
      await Future.delayed(const Duration(milliseconds: 200));
      authRefreshNotifier.value += 1000;
      debugLog('[AUTH] [OK] Triggered authRefreshNotifier after login (incremented by 1000)');
      
      return true;
    } on FirebaseAuthException catch (e) {
      debugLog('FirebaseAuthException during login: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugLog('Login error: $e');
      rethrow;
    }
  }

  static Future<void> logout() async {
    debugLog('[AUTH] Starting logout...');
    
    // Clear ALL static state to prevent any stale data
    currentUserData = null;
    userType = null;
    _themeInitialized = false;
    
    // Reset theme to light for unauthenticated screens (login/registration)
    themeModeNotifier.value = ThemeMode.light;
    
    // Sign out from Firebase (this clears currentUser automatically via getter)
    await _auth.signOut();
    
    // Force UI refresh
    await Future.delayed(const Duration(milliseconds: 150));
    authRefreshNotifier.value += 1000;
    debugLog('[AUTH] [OK] Logout complete - all state cleared, authRefreshNotifier incremented');
  }

  static Future<Map<String, dynamic>?> getUserData() async {
    final user = _auth.currentUser;
    if (user == null) {
      debugLog('[getUserData] No current user, returning null');
      return null;
    }
    
    try {
      debugLog('[getUserData] Fetching user data for ${user.uid}');
      DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
      
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>?;
        debugLog('[getUserData] [OK] User document found with ${data?.keys.length ?? 0} fields');
        return data;
      } else {
        debugLog('[getUserData] Document does not exist on first attempt, retrying after 300ms...');
        // Retry after 300ms in case of eventual consistency
        await Future.delayed(const Duration(milliseconds: 300));
        DocumentSnapshot retryDoc = await _firestore.collection('users').doc(currentUser!.uid).get();
        if (retryDoc.exists) {
          debugLog('[getUserData] [OK] User document found on retry');
          return retryDoc.data() as Map<String, dynamic>?;
        } else {
          debugLog('[getUserData] [WARN] Document still does not exist, trying once more after 700ms...');
          // One more retry with longer delay
          await Future.delayed(const Duration(milliseconds: 700));
          DocumentSnapshot finalRetryDoc = await _firestore.collection('users').doc(currentUser!.uid).get();
          if (finalRetryDoc.exists) {
            debugLog('[getUserData] [OK] User document found on second retry');
            return finalRetryDoc.data() as Map<String, dynamic>?;
          } else {
            debugLog('[getUserData] [ERR] Document does not exist after 3 attempts');
            return null;
          }
        }
      }
    } catch (e) {
      debugLog('[getUserData] Error: $e');
      return null;
    }
  }

  // Wait until `currentUserData` contains a non-empty `barangay` field.
  // Returns the barangay string or null if timeout reached.
  static Future<String?> waitForBarangay({int timeoutMs = 7000}) async {
    final end = DateTime.now().add(Duration(milliseconds: timeoutMs));
    while (DateTime.now().isBefore(end)) {
      final b = currentUserData?['barangay'] as String? ?? '';
      if (b.isNotEmpty) return b;
      if (currentUser != null) {
        currentUserData = await getUserData();
        final b2 = currentUserData?['barangay'] as String? ?? '';
        if (b2.isNotEmpty) return b2;
      }
      await Future.delayed(const Duration(milliseconds: 250));
    }
    return null;
  }

  static Future<void> updateUserData(Map<String, dynamic> data) async {
    if (currentUser == null) return;
    await _firestore.collection('users').doc(currentUser!.uid).update(data);
  }

  /// Check if user is a guest resident and get their expiration info
  static Map<String, dynamic>? getGuestExpirationInfo() {
    if (userType != 'Guest Resident') return null;
    if (currentUserData == null) return null;
    
    final expirationDate = currentUserData?['expirationDate'];
    if (expirationDate == null) return null;
    
    final expireTime = (expirationDate as Timestamp).toDate();
    final now = DateTime.now();
    final daysRemaining = expireTime.difference(now).inDays;
    final hoursRemaining = expireTime.difference(now).inHours;
    final isExpired = now.isAfter(expireTime);
    final canRenew = hoursRemaining <= 24 && hoursRemaining > 0 && !isExpired;
    
    return {
      'expirationDate': expireTime,
      'daysRemaining': daysRemaining,
      'hoursRemaining': hoursRemaining,
      'isExpired': isExpired,
      'canRenew': canRenew,
      'renewalMessage': canRenew 
        ? 'Your account is expiring soon! Renew now to keep using the app.'
        : isExpired
          ? 'Your account has expired. Please contact the barangay office.'
          : 'Your account will expire in $daysRemaining day(s).',
    };
  }

  /// Renew guest resident account for another 30 days
  static Future<bool> renewGuestAccount() async {
    try {
      if (currentUser == null || userType != 'Guest Resident') return false;
      
      final newExpirationDate = Timestamp.fromDate(DateTime.now().add(const Duration(days: 30)));
      await _firestore.collection('users').doc(currentUser!.uid).update({
        'expirationDate': newExpirationDate,
        'lastRenewalDate': FieldValue.serverTimestamp(),
      });
      
      // Refresh user data
      currentUserData = await getUserData();
      return true;
    } catch (e) {
      debugLog('Error renewing guest account: $e');
      return false;
    }
  }

  /// Converts an image file to a base64 data URL for storage in Firestore.
  /// This avoids the need for Firebase Storage.
  /// Returns a data URL like "data:image/jpeg;base64,..." or null on error.
  static Future<String?> uploadImage(File file, String path) async {
    try {
      debugLog('[Upload] Starting image upload (base64 to Firestore): $path');
      
      // Verify file exists
      if (!await file.exists()) {
        debugLog('[Upload] ERROR: File does not exist at ${file.path}');
        return null;
      }
      
      final fileSize = await file.length();
      debugLog('[Upload] File size: ${(fileSize / 1024).toStringAsFixed(2)}KB');
      
      if (fileSize == 0) {
        debugLog('[Upload] ERROR: File is empty');
        return null;
      }

      // Max 5MB for base64 in Firestore
      if (fileSize > 5 * 1024 * 1024) {
        debugLog('[Upload] ERROR: File too large (>5MB for Firestore storage)');
        return null;
      }
      
      // Read file as bytes
      debugLog('[Upload] Reading file bytes...');
      final bytes = await file.readAsBytes();
      
      // Convert to base64
      debugLog('[Upload] Converting to base64...');
      final base64String = base64Encode(bytes);
      final dataUrl = 'data:image/jpeg;base64,$base64String';
      
      debugLog('[Upload] SUCCESS! Base64 data created (${base64String.length} chars)');
      return dataUrl;
    } catch (e) {
      debugLog('[Upload] ERROR [$path]: ${e.runtimeType} - $e');
      return null;
    }
  }
}

// Helper function to display base64 or network images

