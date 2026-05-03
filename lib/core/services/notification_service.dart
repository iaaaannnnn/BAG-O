part of '../../app/app.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> addNotification(String userId, String title, String message) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': title,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      // Log but don't fail the operation if notification creation fails
      debugLog('Warning: Failed to create notification: $e');
    }
  }

  static Stream<QuerySnapshot> getNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}

// Global notifier for theme mode

