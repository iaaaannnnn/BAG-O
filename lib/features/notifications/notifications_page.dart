part of '../../app/app.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  Future<void> _markNotificationAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      debugLog('[Notifications] Error marking as read: $e');
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      debugLog('[Notifications] Error deleting notification: $e');
    }
  }

  Future<void> _markAllNotificationsAsRead(String userId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();
      
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snap.docs) {
        batch.update(doc.reference, {'read': true});
      }
      
      await batch.commit();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications marked as read')),
        );
      }
    } catch (e) {
      debugLog('[Notifications] Error marking all as read: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to mark notifications as read')),
        );
      }
    }
  }

  Future<void> _clearAllNotifications(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text('Are you sure you want to delete all notifications? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: userId)
            .get();
        for (var doc in snap.docs) {
          await doc.reference.delete();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All notifications cleared')),
          );
        }
      } catch (e) {
        debugLog('[Notifications] Error clearing all: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark All as Read',
            onPressed: () => _markAllNotificationsAsRead(AuthService.currentUser!.uid),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear All',
            onPressed: () => _clearAllNotifications(AuthService.currentUser!.uid),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: NotificationService.getNotifications(AuthService.currentUser!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No notifications'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var notif = snapshot.data!.docs[index];
              final isRead = notif['read'] as bool? ?? false;
              final notifId = notif.id;
              
              return Dismissible(
                key: Key(notifId),
                direction: DismissDirection.endToStart,
                onDismissed: (direction) => _deleteNotification(notifId),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                child: Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isRead ? null : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  child: ListTile(
                    leading: Icon(
                      Icons.notifications_active,
                      color: isRead ? Colors.grey : const Color(0xFF2E7D32),
                    ),
                    title: Text(
                      notif['title'] ?? 'Notification',
                      style: TextStyle(
                        fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      notif['message'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      // Mark as read
                      if (!isRead) {
                        _markNotificationAsRead(notifId);
                      }
                      
                      // Show full message in dialog
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(notif['title'] ?? 'Notification'),
                          content: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(notif['message'] ?? ''),
                                if (notif['timestamp'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: Text(
                                      'Received: ${_formatTimestamp(notif['timestamp'])}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      final ts = timestamp as Timestamp;
      final date = ts.toDate();
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return 'Unknown';
    }
  }
}


