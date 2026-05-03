part of '../../app/app.dart';

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({Key? key}) : super(key: key);

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  String? _userBarangay;
  bool _loadingBarangay = true;

  @override
  void initState() {
    super.initState();
    _loadBarangay();
  }

  Future<void> _loadBarangay() async {
    try {
      final userData = await AuthService.getUserData();
      if (mounted) {
        setState(() {
          _userBarangay = userData?['barangay'] as String?;
          _loadingBarangay = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingBarangay = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingBarangay) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Announcements'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_userBarangay == null || _userBarangay!.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Announcements'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.info_outline, size: 64, color: Colors.orange),
                const SizedBox(height: 16),
                const Text('Unable to load announcements', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Please ensure your profile is complete and you are approved by the barangay.', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _loadingBarangay = true;
                    });
                    _loadBarangay();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcements'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
          .collection('announcements')
          .where('barangay', isEqualTo: _userBarangay)
          .orderBy('timestamp', descending: true)
          .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) {
            debugLog('Error loading announcements: ${snapshot.error}');
            return Center(child: Text('Error: ${snapshot.error.toString().replaceFirst('Exception: ', '')}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No announcements yet'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var announcement = snapshot.data!.docs[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(announcement['title'], style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : null)),
                      Text(
                        announcement['title'],
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if ((announcement.data() as Map<String, dynamic>?)?.containsKey('attachmentUrls') == true && 
                          (announcement['attachmentUrls'] as List<dynamic>?)?.isNotEmpty == true ||
                          (announcement.data() as Map<String, dynamic>?)?.containsKey('imageUrl') == true && announcement['imageUrl'] != null)
                        Column(
                          children: [
                            buildImageFromUrl(
                              (announcement['attachmentUrls'] as List<dynamic>?)?.isNotEmpty == true 
                                ? announcement['attachmentUrls'][0] 
                                : announcement['imageUrl'], 
                              fit: BoxFit.cover
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      Text(announcement['content'], style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class AnnouncementDetailPage extends StatefulWidget {
  final String announcementId;

  const AnnouncementDetailPage({Key? key, required this.announcementId}) : super(key: key);

  @override
  State<AnnouncementDetailPage> createState() => _AnnouncementDetailPageState();
}

class _AnnouncementDetailPageState extends State<AnnouncementDetailPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcement Details'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('announcements')
            .doc(widget.announcementId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Announcement not found'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final type = data['type'] as String? ?? 'Announcement';
          final isEvent = type == 'Event';
          final attachmentUrls = data['attachmentUrls'] as List<dynamic>? ?? [];
          
          // Handle legacy imageUrl field
          if (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty) {
            attachmentUrls.add(data['imageUrl']);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with icon and type
                Row(
                  children: [
                    Icon(
                      isEvent ? Icons.event : Icons.campaign,
                      color: const Color(0xFF228B22),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        data['title'] ?? 'Untitled',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (isEvent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Event',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Images
                if (attachmentUrls.isNotEmpty)
                  SizedBox(
                    height: 250,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: attachmentUrls.length,
                      itemBuilder: (context, index) {
                        final url = attachmentUrls[index] as String;
                        return Container(
                          width: MediaQuery.of(context).size.width - 32,
                          margin: EdgeInsets.only(right: index < attachmentUrls.length - 1 ? 16 : 0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: buildImageFromUrl(url, fit: BoxFit.cover),
                          ),
                        );
                      },
                    ),
                  ),

                if (attachmentUrls.isNotEmpty)
                  const SizedBox(height: 16),

                // Content
                Text(
                  data['content'] ?? '',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),

                // Event details
                if (isEvent) ...[
                  if (data['eventDate'] != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          _formatEventDate(data['eventDate']),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (data['location'] != null && data['location'].toString().isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            data['location'],
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ],

                // Timestamp
                Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.grey, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      _formatTimestamp(data['timestamp']),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatEventDate(dynamic eventDate) {
    if (eventDate is Timestamp) {
      final dateTime = eventDate.toDate();
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
    return 'Date not available';
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final dateTime = timestamp.toDate();
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      } else {
        return 'Just now';
      }
    }
    return 'Unknown time';
  }
}


