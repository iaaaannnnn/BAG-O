part of '../../app/app.dart';

class ResidentsDirectoryPage extends StatefulWidget {
  const ResidentsDirectoryPage({Key? key}) : super(key: key);

  @override
  State<ResidentsDirectoryPage> createState() => _ResidentsDirectoryPageState();
}

class _ResidentsDirectoryPageState extends State<ResidentsDirectoryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // Sort + search state (Material3-style controls)
  String _sortField = 'name'; // name | date
  bool _sortAsc = true;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      animationDuration: const Duration(milliseconds: 380),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _showResidentDetails(BuildContext context, Map<String, dynamic> data) {
    final profileUrl = data['profileImageUrl'] as String?;
    final avatarImage = resolveImageProvider(profileUrl);
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Profile picture with border
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF228B22), width: 3),
                  ),
                  child: CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: avatarImage,
                    child: avatarImage == null
                        ? const Icon(Icons.person, size: 45, color: Colors.grey)
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                // Name
                Text(
                  data['name'] ?? 'Unknown',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                // Role badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF228B22).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    (data['role'] ?? data['type'] ?? 'Resident').toString(),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF228B22), fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 20),
                // Simplified info rows
                _buildCleanInfoRow(Icons.email_outlined, data['email'] ?? 'N/A'),
                const SizedBox(height: 12),
                _buildCleanInfoRow(Icons.phone_outlined, data['mobile'] ?? 'N/A'),
                const SizedBox(height: 12),
                _buildCleanInfoRow(Icons.location_on_outlined, formatBarangayAddress(data)),
                const SizedBox(height: 20),
                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF228B22),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Close', style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCleanInfoRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF228B22)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  // Kept for compatibility but now using _buildCleanInfoRow
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final officialBarangay = AuthService.currentUserData?['barangay'] as String? ?? '';
    
    if (kUseMockData) {
      return Scaffold(
        appBar: AppBar(title: const Text('Residents Directory (Mock)')),
        body: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: kMockResidents.length,
          itemBuilder: (context, index) {
            var user = kMockResidents[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(child: const Icon(Icons.person)),
                title: Text(user['name'] ?? 'Resident'),
                subtitle: Text(user['mobile'] ?? ''),
                onTap: () {
                  showDialog(context: context, builder: (_) => AlertDialog(
                    title: Text(user['name'] ?? 'Resident'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [Text('Email: ${user['email'] ?? 'N/A'}'), Text('Mobile: ${user['mobile'] ?? 'N/A'}'), Text('Address: ${user['address'] ?? 'N/A'}')]),
                    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
                  ));
                },
              ),
            );
          },
        ),
      );
    }

    if (officialBarangay == null || officialBarangay.toString().isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Residents Directory')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return GestureDetector(
      onTap: () => _searchFocusNode.unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Residents Directory'),
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 1,
          bottom: TabBar(
            controller: _tabController,
            isScrollable: false,
            tabAlignment: TabAlignment.fill,
            labelColor: Theme.of(context).colorScheme.onPrimary,
            unselectedLabelColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.72),
            indicatorColor: Theme.of(context).colorScheme.onPrimary,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'Residents', icon: Icon(Icons.groups_outlined)),
              Tab(text: 'Guest Residents', icon: Icon(Icons.badge_outlined)),
            ],
          ),
        ),
        body: Column(
          children: [
            // Search + Sort Controls (Material3; aligned with TransparencyPage)
            _buildSearchSortControls(context),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Regular Residents Tab
                _buildResidentsTab(context, officialBarangay, 'Resident'),
                // Guest Residents Tab
                _buildResidentsTab(context, officialBarangay, 'Guest Resident'),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildSearchSortControls(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search pinned at top with debounce
          TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onChanged: _onSearchChanged,
            onSubmitted: (val) {
              _searchDebounce?.cancel();
              _searchFocusNode.unfocus();
              setState(() => _searchQuery = val.trim().toLowerCase());
            },
            decoration: InputDecoration(
              hintText: 'Search by name, email, or mobile...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchDebounce?.cancel();
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF228B22), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          // Sort controls below search with ascending/descending toggle
          Row(
            children: [
              PopupMenuButton<String>(
                tooltip: 'Sort',
                onSelected: (val) {
                  if (val == 'toggle_order') {
                    setState(() => _sortAsc = !_sortAsc);
                  } else {
                    setState(() => _sortField = val);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'name', child: Text('Name')),
                  const PopupMenuItem(value: 'date', child: Text('Date added')),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'toggle_order',
                    child: Row(
                      children: [
                        Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward, size: 18),
                        const SizedBox(width: 8),
                        Text(_sortAsc ? 'Ascending' : 'Descending'),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_sortField == 'date' ? 'Date' : 'Name'),
                      const SizedBox(width: 6),
                      Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final next = value.trim().toLowerCase();
    _searchDebounce = Timer(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      if (_searchQuery != next) {
        setState(() {
          _searchQuery = next;
        });
      }
    });
  }

  Widget _buildResidentsTab(BuildContext context, String officialBarangay, String residentType) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('type', isEqualTo: residentType)
          .where('barangay', isEqualTo: officialBarangay)
          .snapshots()
          .debounceTime(const Duration(milliseconds: 200)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          debugLog('Error loading $residentType residents: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading residents: ${snapshot.error.toString().replaceFirst('Exception: ', '')}')
              ],
            ),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        
        // Filter residents based on type - both types need approval
        List<QueryDocumentSnapshot> residents;
        residents = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? data['approvalStatus'] ?? data['approval'] ?? 'approved').toString().toLowerCase();
          return status == 'approved';
        }).toList();

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          residents = residents.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['name'] ?? '').toString().toLowerCase();
            final email = (data['email'] ?? '').toString().toLowerCase();
            final mobile = (data['mobile'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery) || email.contains(_searchQuery) || mobile.contains(_searchQuery);
          }).toList();
        }

        // Apply sorting
        residents.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;

          int result;
          if (_sortField == 'name') {
            final aName = (aData['name'] ?? '').toString().toLowerCase();
            final bName = (bData['name'] ?? '').toString().toLowerCase();
            result = aName.compareTo(bName);
          } else {
            final aDate = aData['createdAt'] as Timestamp?;
            final bDate = bData['createdAt'] as Timestamp?;
            if (aDate == null && bDate == null) {
              result = 0;
            } else if (aDate == null) {
              result = -1;
            } else if (bDate == null) {
              result = 1;
            } else {
              result = aDate.compareTo(bDate);
            }
          }

          return _sortAsc ? result : -result;
        });

        if (residents.isEmpty) {
          final emptyMsg = _searchQuery.isEmpty
              ? (residentType == 'Guest Resident'
                  ? 'No guest residents yet'
                  : 'No approved residents yet')
              : 'No matching residents found for "$_searchQuery"';
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 48, color: _searchQuery.isEmpty ? Theme.of(context).colorScheme.primary : Colors.grey),
                const SizedBox(height: 12),
                Text(emptyMsg, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: residents.length,
          itemBuilder: (context, index) {
            final user = residents[index];
            final data = user.data() as Map<String, dynamic>;
            final address = formatBarangayAddress(data);
            
            // Check ALL possible profile image field names for maximum compatibility
            final profileImageUrl = (data['profileImageUrl'] as String?) ?? 
                                    (data['photoURL'] as String?) ?? 
                                    (data['profileImage'] as String?) ??
                                    (data['photoUrl'] as String?);
            final avatarImage = resolveImageProvider(profileImageUrl);
            
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => _showResidentDetails(context, data),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                                backgroundImage: avatarImage,
                                child: avatarImage == null 
                                  ? const Icon(Icons.person, size: 30) 
                                  : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['name'] ?? 'Unknown',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
                                ),
                                const SizedBox(height: 4),
                                Text((data['email'] ?? 'N/A').toString(), style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('Address: $address', style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color)),
                      const SizedBox(height: 8),
                      Text('Contact: ${data['mobile'] ?? 'N/A'}', style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color)),
                      const SizedBox(height: 4),
                      Text('Email: ${data['email'] ?? 'N/A'}', style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}


