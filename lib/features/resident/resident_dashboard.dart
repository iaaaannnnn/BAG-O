part of '../../app/app.dart';

class ResidentDashboard extends StatefulWidget {
  const ResidentDashboard({Key? key}) : super(key: key);

  @override
  State<ResidentDashboard> createState() => _ResidentDashboardState();
}

class _ResidentDashboardState extends State<ResidentDashboard> {
  @override
  Widget build(BuildContext context) {
    // Use cached user data from AuthService (set by parent _BarangayAppState)
    // This avoids FutureBuilder re-fetching on every theme change
    final userData = AuthService.currentUserData;
    
    // If no cached data available, show loading (should be rare - only on cold start)
    if (userData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
        
        final barangayAddr = formatBarangayAddress(userData);
        
        return Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF228B22),
            iconTheme: const IconThemeData(color: Colors.white),
            toolbarHeight: 72,
            title: GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(
                      'About BAG-O',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    contentPadding: EdgeInsets.zero,
                    content: SizedBox(
                      width: double.maxFinite,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Opacity(
                              opacity: 0.15,
                              child: Image.asset(
                                'assets/images/FINAL_LOGO_NAT_-removebg-preview.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _bagoAboutText,
                              textAlign: TextAlign.justify,
                              textHeightBehavior: const TextHeightBehavior(
                                applyHeightToFirstAscent: false,
                                applyHeightToLastDescent: false,
                              ),
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.22,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('CLOSE'),
                      ),
                    ],
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Image.asset('assets/images/FINAL_LOGO_NAT_-removebg-preview.png', width: 52, height: 52, fit: BoxFit.contain),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('BAG-O', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 0)),
                          const Text(
                            'Barangay Automated Governance and Operation',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              // Profile icon in top right corner
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: AuthService.currentUser == null
                    ? const Stream.empty()
                    : FirebaseFirestore.instance
                        .collection('users')
                        .doc(AuthService.currentUser!.uid)
                        .snapshots(),
                builder: (context, snap) {
                  final data = snap.data?.data() ?? <String, dynamic>{};
                  final userName = (data['name'] as String?)?.trim();
                  final rawPhoto = data['photoURL'] as String?;
                  final photoUrl = (rawPhoto != null && rawPhoto.trim().isNotEmpty)
                      ? rawPhoto.trim()
                      : (data['profileImageUrl'] as String?);
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: CircularProfileIcon(
                      radius: 20,
                      userName: userName,
                      photoUrl: photoUrl,
                      tooltip: 'Profile',
                      onTap: () {
                        Navigator.pushNamed(context, AppRoutes.profile);
                      },
                    ),
                  );
                },
              ),
            ],
          ),
          body: Builder(
            builder: (context) {
              final theme = Theme.of(context);
              final isDark = theme.brightness == Brightness.dark;
              
              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? theme.colorScheme.surfaceContainerHighest : theme.colorScheme.surfaceContainerLow,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.home, color: Color(0xFF228B22), size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            barangayAddr,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Notification bell aligned with address
                        StreamBuilder<QuerySnapshot>(
                          stream: NotificationService.getNotifications(AuthService.currentUser!.uid),
                          builder: (context, snapshot) {
                            int count = 0;
                            if (snapshot.hasData) {
                              count = snapshot.data!.docs.where((doc) => (doc['read'] as bool?) == false).length;
                            }
                            return IconButton(
                              icon: Stack(
                                children: [
                                  const Icon(Icons.notifications, color: Color(0xFF228B22)),
                                  if (count > 0)
                                    Positioned(
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                        child: Text('$count', style: const TextStyle(fontSize: 10, color: Colors.white), textAlign: TextAlign.center),
                                      ),
                                    ),
                                ],
                              ),
                              onPressed: () => Navigator.pushNamed(context, AppRoutes.notifications),
                            );
                          },
                        ),
                        // Dark mode toggle aligned with address
                        ValueListenableBuilder<ThemeMode>(
                          valueListenable: themeModeNotifier,
                          builder: (context, mode, _) {
                            final isDarkMode = mode == ThemeMode.dark;
                            return InkWell(
                              onTap: () {
                                final newMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
                                themeModeNotifier.value = newMode;
                                AuthService.saveThemeMode(newMode == ThemeMode.dark ? 'dark' : 'light');
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                width: 48,
                                height: 24,
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: isDarkMode ? const Color(0xFF1F2937) : const Color(0xFFD1D5DB),
                                  border: Border.all(color: isDarkMode ? const Color(0xFF374151) : const Color(0xFF9CA3AF)),
                                ),
                                child: AnimatedAlign(
                                  alignment: isDarkMode ? Alignment.centerRight : Alignment.centerLeft,
                                  duration: const Duration(milliseconds: 150),
                                  curve: Curves.easeOut,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(0x33000000),
                                          blurRadius: 4,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      isDarkMode ? Icons.nightlight_round : Icons.wb_sunny,
                                      size: 12,
                                      color: isDarkMode ? const Color(0xFF2E7D32) : const Color(0xFFF59E0B),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: CustomScrollView(
                        slivers: [
                      // Guest account expiration warning (only shows for guest residents)
                      SliverToBoxAdapter(
                        child: buildGuestExpirationWarning(context),
                      ),
                      SliverToBoxAdapter(
                        child: GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.1,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildDashboardCard(context, 'Request\nDocuments', Icons.description_outlined, () => Navigator.pushNamed(context, AppRoutes.requestDocuments)),
                            _buildDashboardCard(context, 'My Document\nRequests', Icons.folder_copy_outlined, () => Navigator.pushNamed(context, AppRoutes.myDocumentRequests)),
                            _buildDashboardCard(context, 'File\nComplaint', Icons.report_problem_outlined, () => Navigator.pushNamed(context, AppRoutes.fileComplaint)),
                            _buildDashboardCard(context, 'Transparency', Icons.article_outlined, () => Navigator.pushNamed(context, AppRoutes.transparency)),
                          ],
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      // Officials section - compact single column in card
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Barangay Officials',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF228B22),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('users')
                                        .where('type', isEqualTo: 'Barangay Official')
                                        .where('barangay', isEqualTo: _getBarangay(userData))
                                        .snapshots(),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState == ConnectionState.waiting) {
                                        return const Center(child: CircularProgressIndicator());
                                      }

                                      final docs = snapshot.data?.docs ?? [];
                                      bool isActiveDoc(QueryDocumentSnapshot d) {
                                        final data = d.data() as Map<String, dynamic>;
                                        final isOnline = (data['isOnline'] as bool?) == true;
                                        final status = (data['status'] as String?)?.toLowerCase();
                                        return isOnline || status == 'active';
                                      }

                                      final active = docs.where(isActiveDoc).toList();
                                      final offline = docs.where((d) => !isActiveDoc(d)).toList();

                                      if (docs.isEmpty) {
                                        return const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('No officials listed')));
                                      }

                                      Widget buildOfficialRow(QueryDocumentSnapshot doc) {
                                        final data = doc.data() as Map<String, dynamic>;
                                        final name = (data['name'] as String?) ?? 'Official';
                                        final email = (data['email'] as String?) ?? '';
                                        final mobile = (data['mobile'] as String?) ?? (data['phone'] as String?) ?? '';
                                        final photoUrl = (data['photoURL'] as String?) ?? (data['profileImageUrl'] as String?);
                                        final isOnline = (data['isOnline'] as bool?) == true;
                                        final avatarImage = resolveImageProvider(photoUrl);

                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          child: Row(
                                            children: [
                                              Stack(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 24,
                                                    backgroundColor: const Color(0xFF228B22).withOpacity(0.2),
                                                    backgroundImage: avatarImage,
                                                    child: avatarImage == null
                                                        ? const Icon(Icons.person, color: Color(0xFF228B22), size: 24)
                                                        : null,
                                                  ),
                                                  if (isOnline)
                                                    Positioned(
                                                      bottom: 0,
                                                      right: 0,
                                                      child: Container(
                                                        width: 12,
                                                        height: 12,
                                                        decoration: BoxDecoration(
                                                          color: Colors.green,
                                                          border: Border.all(color: Colors.white, width: 2),
                                                          shape: BoxShape.circle,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      name,
                                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    if (email.isNotEmpty)
                                                      Text(email, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                    if (mobile.isNotEmpty)
                                                      Text(mobile, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }

                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          ...active.map(buildOfficialRow),
                                          if (offline.isNotEmpty) ...[
                                            Divider(height: 16, color: Colors.grey[300]),
                                            ...offline.map(buildOfficialRow),
                                          ],
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      SliverToBoxAdapter(
                        child: Text(
                          'Latest Announcements & Events',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('announcements')
                            .where('barangay', isEqualTo: _getBarangay(userData))
                            .orderBy('timestamp', descending: true)
                            .limit(10)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const SliverToBoxAdapter(
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return const SliverToBoxAdapter(
                              child: Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text('No announcements or events yet'),
                                ),
                              ),
                            );
                          }

                          return SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final doc = snapshot.data!.docs[index];
                                final data = doc.data() as Map<String, dynamic>;
                                final type = (data['type'] as String?) ?? 'Announcement';
                                final isEvent = type == 'Event';
                                
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: InkWell(
                                    onTap: () {
                                      // Navigate to announcement details
                                      Navigator.pushNamed(
                                        context,
                                        AppRoutes.announcementDetail,
                                        arguments: doc.id,
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              if ((data['attachmentUrls'] as List<dynamic>?)?.isNotEmpty == true || data['imageUrl'] != null)
                                                Container(
                                                  width: 60,
                                                  height: 60,
                                                  margin: const EdgeInsets.only(right: 12),
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: buildImageFromUrl(
                                                      (data['attachmentUrls'] as List<dynamic>?)?.isNotEmpty == true 
                                                        ? data['attachmentUrls'][0] 
                                                        : data['imageUrl'], 
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                ),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          isEvent ? Icons.event : Icons.campaign,
                                                          color: const Color(0xFF228B22),
                                                          size: 20,
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Expanded(
                                                          child: Text(
                                                            data['title'] ?? 'Untitled',
                                                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                              fontWeight: FontWeight.bold,
                                                              color: Theme.of(context).colorScheme.onSurface,
                                                            ),
                                                            maxLines: 2,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                        if (isEvent)
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                            decoration: BoxDecoration(
                                                              color: Colors.blue.shade100,
                                                              borderRadius: BorderRadius.circular(12),
                                                            ),
                                                            child: Text(
                                                              'Event',
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                fontWeight: FontWeight.bold,
                                                                color: Colors.blue.shade700,
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            data['content'] ?? '',
                                            style: Theme.of(context).textTheme.bodySmall,
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (isEvent && data['eventDate'] != null) ...[
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _formatEventDate(data['eventDate']),
                                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                ),
                                              ],
                                            ),
                                          ],
                                          if (isEvent && data['location'] != null) ...[
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    data['location'] ?? '',
                                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                              childCount: snapshot.data!.docs.length,
                            ),
                          );
                        },
                      ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        floatingActionButton: FloatingActionButton(
      onPressed: () {
        Navigator.pushNamed(context, AppRoutes.emergencyContacts);
      },
      backgroundColor: const Color(0xFF228B22),
      tooltip: 'Emergency Hotlines',
      child: const Icon(Icons.phone_in_talk, color: Colors.white),
    ),
  );
  }

  String? _getBarangay(Map<String, dynamic>? userData) {
    return userData?['barangay'] as String?;
  }

  String _formatEventDate(dynamic eventDate) {
    if (eventDate == null) return '';
    try {
      final ts = eventDate as Timestamp;
      final date = ts.toDate();
      return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  // Build dashboard for guest residents - same as regular resident but with expiration warning
  Widget _buildGuestDashboard(BuildContext context, Map<String, dynamic> userData) {
    final barangayAddr = formatBarangayAddress(userData);
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF228B22),
        iconTheme: const IconThemeData(color: Colors.white),
        toolbarHeight: 72,
        title: GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('About BAG-O', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)),
                contentPadding: EdgeInsets.zero,
                content: SizedBox(
                  width: double.maxFinite,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.15,
                          child: Image.asset(
                            'assets/images/FINAL_LOGO_NAT_-removebg-preview.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _bagoAboutText,
                              textAlign: TextAlign.justify,
                              textHeightBehavior: const TextHeightBehavior(
                                applyHeightToFirstAscent: false,
                                applyHeightToLastDescent: false,
                              ),
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.22,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CLOSE'),
                  ),
                ],
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Image.asset('assets/images/FINAL_LOGO_NAT_-removebg-preview.png', width: 52, height: 52, fit: BoxFit.contain),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('BAG-O', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 0)),
                      const Text(
                        'Barangay Automated Governance and Operation',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          // Profile icon in top right corner
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: AuthService.currentUser == null
                ? const Stream.empty()
                : FirebaseFirestore.instance
                    .collection('users')
                    .doc(AuthService.currentUser!.uid)
                    .snapshots(),
            builder: (context, snap) {
              final data = snap.data?.data() ?? <String, dynamic>{};
              final userName = (data['name'] as String?)?.trim();
              final rawPhoto = data['photoURL'] as String?;
              final photoUrl = (rawPhoto != null && rawPhoto.trim().isNotEmpty)
                  ? rawPhoto.trim()
                  : (data['profileImageUrl'] as String?);
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: CircularProfileIcon(
                  radius: 20,
                  userName: userName,
                  photoUrl: photoUrl,
                  tooltip: 'Profile',
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.profile);
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;
          
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? theme.colorScheme.surfaceContainerHighest : theme.colorScheme.surfaceContainerLow,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Color(0xFF228B22), size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        barangayAddr,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Notification bell aligned with address
                    StreamBuilder<QuerySnapshot>(
                      stream: NotificationService.getNotifications(AuthService.currentUser!.uid),
                      builder: (context, snapshot) {
                        int count = 0;
                        if (snapshot.hasData) {
                          count = snapshot.data!.docs.where((doc) => (doc['read'] as bool?) == false).length;
                        }
                        return IconButton(
                          icon: Stack(
                            children: [
                              const Icon(Icons.notifications, color: Color(0xFF228B22)),
                              if (count > 0)
                                Positioned(
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                    child: Text('$count', style: const TextStyle(fontSize: 10, color: Colors.white), textAlign: TextAlign.center),
                                  ),
                                ),
                            ],
                          ),
                          onPressed: () => Navigator.pushNamed(context, AppRoutes.notifications),
                        );
                      },
                    ),
                    // Dark mode toggle aligned with address
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: themeModeNotifier,
                      builder: (context, mode, _) {
                        final isDarkMode = mode == ThemeMode.dark;
                        return InkWell(
                          onTap: () {
                            final newMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
                            themeModeNotifier.value = newMode;
                            AuthService.saveThemeMode(newMode == ThemeMode.dark ? 'dark' : 'light');
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 48,
                            height: 24,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: isDarkMode ? const Color(0xFF1F2937) : const Color(0xFFD1D5DB),
                              border: Border.all(color: isDarkMode ? const Color(0xFF374151) : const Color(0xFF9CA3AF)),
                            ),
                            child: AnimatedAlign(
                              alignment: isDarkMode ? Alignment.centerRight : Alignment.centerLeft,
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.easeOut,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x33000000),
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isDarkMode ? Icons.nightlight_round : Icons.wb_sunny,
                                  size: 12,
                                  color: isDarkMode ? const Color(0xFF2E7D32) : const Color(0xFFF59E0B),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: CustomScrollView(
                    slivers: [
                      // Guest account expiration warning (only shows for guest residents)
                      SliverToBoxAdapter(
                        child: buildGuestExpirationWarning(context),
                      ),
                      SliverToBoxAdapter(
                        child: GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.1,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildDashboardCard(context, 'Request\nDocuments', Icons.description_outlined, () => Navigator.pushNamed(context, AppRoutes.requestDocuments)),
                            _buildDashboardCard(context, 'My Document\nRequests', Icons.folder_copy_outlined, () => Navigator.pushNamed(context, AppRoutes.myDocumentRequests)),
                            _buildDashboardCard(context, 'File\nComplaint', Icons.report_problem_outlined, () => Navigator.pushNamed(context, AppRoutes.fileComplaint)),
                            _buildDashboardCard(context, 'Transparency', Icons.article_outlined, () => Navigator.pushNamed(context, AppRoutes.transparency)),
                          ],
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      SliverToBoxAdapter(
                        child: Text(
                          'Latest Announcements & Events',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('announcements')
                            .where('barangay', isEqualTo: _getBarangay(userData))
                            .orderBy('timestamp', descending: true)
                            .limit(10)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const SliverToBoxAdapter(
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return const SliverToBoxAdapter(
                              child: Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text('No announcements or events yet'),
                                ),
                              ),
                            );
                          }

                          return SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final doc = snapshot.data!.docs[index];
                                final data = doc.data() as Map<String, dynamic>;
                                final type = (data['type'] as String?) ?? 'Announcement';
                                final isEvent = type == 'Event';
                                
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: InkWell(
                                    onTap: () {
                                      // Navigate to announcement details
                                      Navigator.pushNamed(
                                        context,
                                        AppRoutes.announcementDetail,
                                        arguments: doc.id,
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              if ((data['attachmentUrls'] as List<dynamic>?)?.isNotEmpty == true || data['imageUrl'] != null)
                                                Container(
                                                  width: 60,
                                                  height: 60,
                                                  margin: const EdgeInsets.only(right: 12),
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: buildImageFromUrl(
                                                      (data['attachmentUrls'] as List<dynamic>?)?.isNotEmpty == true 
                                                        ? data['attachmentUrls'][0] 
                                                        : data['imageUrl'], 
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),
                                                ),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          isEvent ? Icons.event : Icons.campaign,
                                                          color: const Color(0xFF228B22),
                                                          size: 20,
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Expanded(
                                                          child: Text(
                                                            data['title'] ?? 'Untitled',
                                                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                              fontWeight: FontWeight.bold,
                                                              color: Theme.of(context).colorScheme.onSurface,
                                                            ),
                                                            maxLines: 2,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                        if (isEvent)
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                            decoration: BoxDecoration(
                                                              color: Colors.blue.shade100,
                                                              borderRadius: BorderRadius.circular(12),
                                                            ),
                                                            child: Text(
                                                              'Event',
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                fontWeight: FontWeight.bold,
                                                                color: Colors.blue.shade700,
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            data['content'] ?? '',
                                            style: Theme.of(context).textTheme.bodySmall,
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (isEvent && data['eventDate'] != null) ...[
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _formatEventDate(data['eventDate']),
                                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                ),
                                              ],
                                            ),
                                          ],
                                          if (isEvent && data['location'] != null) ...[
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    data['location'] ?? '',
                                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                              childCount: snapshot.data!.docs.length,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.emergencyContacts);
        },
        backgroundColor: const Color(0xFF228B22),
        tooltip: 'Emergency Hotlines',
        child: const Icon(Icons.phone_in_talk, color: Colors.white),
      ),
    );
  }

  Widget _buildDashboardCard(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return DashboardActionTile(title: title, icon: icon, onTap: onTap);
  }
}

// ==================== APPROVAL PANEL PAGE ====================


