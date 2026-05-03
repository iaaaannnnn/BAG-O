part of '../../app/app.dart';

class OfficialDashboard extends StatelessWidget {
  const OfficialDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use cached user data from AuthService (set by parent _BarangayAppState)
    // This avoids FutureBuilder re-fetching on every theme change
    final userData = AuthService.currentUserData;
    
    // Guard: Show loading if user data not ready (should be rare - only on cold start)
    if (userData == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    final barangayAddr = formatBarangayAddress(userData);
    final officialBarangay = userData['barangay'] as String? ?? '';
        
        // Guard: Show error if barangay is empty
        if (officialBarangay.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('Barangay assignment not found. Please contact your administrator.')),
          );
        }
        
        return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF228B22),
        iconTheme: const IconThemeData(size: 22),
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('BAG-O', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: 0)),
                      Text('Barangay Automated Governance and Operation', style: TextStyle(color: Colors.white70, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
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
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
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
          
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? theme.colorScheme.surfaceContainerHighest : theme.colorScheme.surfaceContainerLow,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, color: const Color(0xFF228B22), size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          barangayAddr,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color),
                        ),
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
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final itemWidth = (constraints.maxWidth - 12) / 2;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: itemWidth,
                            child: _buildDashboardCard(context, 'Approval\nPanel', Icons.fact_check_outlined, () => Navigator.pushNamed(context, AppRoutes.approvalPanel, arguments: officialBarangay)),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _buildDashboardCard(context, 'Document\nRequests', Icons.folder_copy_outlined, () => Navigator.pushNamed(context, AppRoutes.pendingRequests)),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _buildDashboardCard(context, 'Residents\nDirectory', Icons.groups_outlined, () => Navigator.pushNamed(context, AppRoutes.residentsDirectory)),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _buildDashboardCard(context, 'Announcements', Icons.campaign_outlined, () => Navigator.pushNamed(context, AppRoutes.postAnnouncement)),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _buildDashboardCard(context, 'View\nComplaints', Icons.flag_outlined, () => Navigator.pushNamed(context, AppRoutes.viewComplaintsAdmin)),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _buildDashboardCard(context, 'Transparency\nDocs', Icons.article_outlined, () => Navigator.pushNamed(context, AppRoutes.transparency)),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: StatisticsSection(embedInCard: true),
                ),
                const SizedBox(height: 16),
                // Barangay Officials in card container
                Padding(
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
                                .where('barangay', isEqualTo: officialBarangay)
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
              ],
            ),
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

// SIMPLIFIED PLACEHOLDER PAGES


