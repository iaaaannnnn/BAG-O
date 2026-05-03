part of '../../app/app.dart';

class ApprovalPanelPage extends StatefulWidget {
  final String officialBarangay;
  const ApprovalPanelPage({Key? key, required this.officialBarangay}) : super(key: key);

  @override
  State<ApprovalPanelPage> createState() => _ApprovalPanelPageState();
}

class _ApprovalPanelPageState extends State<ApprovalPanelPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // Per-tab search/sort state
  // Pending
  final TextEditingController _pendingSearchController = TextEditingController();
  final FocusNode _pendingSearchFocusNode = FocusNode();
  String _pendingSearchQuery = '';
  Timer? _pendingSearchDebounce;
  String _pendingSortField = 'name'; // name | date
  bool _pendingSortAsc = true;
  // Approved
  final TextEditingController _approvedSearchController = TextEditingController();
  final FocusNode _approvedSearchFocusNode = FocusNode();
  String _approvedSearchQuery = '';
  Timer? _approvedSearchDebounce;
  String _approvedSortField = 'name';
  bool _approvedSortAsc = true;
  // Rejected
  final TextEditingController _rejectedSearchController = TextEditingController();
  final FocusNode _rejectedSearchFocusNode = FocusNode();
  String _rejectedSearchQuery = '';
  Timer? _rejectedSearchDebounce;
  String _rejectedSortField = 'name';
  bool _rejectedSortAsc = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      animationDuration: const Duration(milliseconds: 380),
    );
    _cleanupOldRejectedUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pendingSearchDebounce?.cancel();
    _approvedSearchDebounce?.cancel();
    _rejectedSearchDebounce?.cancel();
    _pendingSearchController.dispose();
    _approvedSearchController.dispose();
    _rejectedSearchController.dispose();
    _pendingSearchFocusNode.dispose();
    _approvedSearchFocusNode.dispose();
    _rejectedSearchFocusNode.dispose();
    super.dispose();
  }

  void _unfocusAll() {
    _pendingSearchFocusNode.unfocus();
    _approvedSearchFocusNode.unfocus();
    _rejectedSearchFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return GestureDetector(
      onTap: _unfocusAll,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Approval Panel'),
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 1,
          bottom: TabBar(
            controller: _tabController,
            isScrollable: false,
            tabAlignment: TabAlignment.fill,
            labelColor: colorScheme.onPrimary,
            unselectedLabelColor: colorScheme.onPrimary.withValues(alpha: 0.72),
            indicatorColor: colorScheme.onPrimary,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(icon: Icon(Icons.pending_actions_outlined), text: 'Pending'),
              Tab(icon: Icon(Icons.task_alt_outlined), text: 'Approved'),
              Tab(icon: Icon(Icons.cancel_outlined), text: 'Rejected'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPendingResidentsTab(),
            _buildApprovedResidentsTab(),
            _buildAllRequestsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingResidentsTab() {
    // Real-time stream: all users for this barangay, filter client-side by status
    // Guard: Only run query if barangay is not empty
    if (widget.officialBarangay.isEmpty) {
      return const Center(child: Text('Barangay not loaded. Please try again.'));
    }
    
    final stream = FirebaseFirestore.instance
        .collection('users')
        .where('barangay', isEqualTo: widget.officialBarangay)
        .snapshots()
        // Client-side throttling: max 5 reads/sec (200ms)
        .debounceTime(const Duration(milliseconds: 200));

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          debugLog('Error loading pending users: ${snapshot.error}');
          return const Center(child: Text('Error loading pending users'));
        }

        final docs = snapshot.data?.docs ?? [];
        // Client-side filter: only show pending users who have successfully registered (have required fields)
        List<QueryDocumentSnapshot> pendingDocs = docs.where((doc) {
          final userData = doc.data() as Map<String, dynamic>;
          final status = (userData['status'] ?? userData['approvalStatus'] ?? userData['approval'] ?? 'approved').toString().toLowerCase();
          // Only show if pending AND has required registration fields
          final hasRequiredFields = (userData['name'] as String?)?.trim().isNotEmpty == true &&
                                    (userData['email'] as String?)?.trim().isNotEmpty == true &&
                                    ((userData['mobile'] as String?)?.trim().isNotEmpty == true || (userData['phone'] as String?)?.trim().isNotEmpty == true);
          return status == 'pending' && hasRequiredFields;
        }).toList();
        
        // Apply search filter
        if (_pendingSearchQuery.isNotEmpty) {
          pendingDocs = pendingDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['name'] ?? '').toString().toLowerCase();
            final email = (data['email'] ?? '').toString().toLowerCase();
            final mobile = (data['mobile'] ?? data['phone'] ?? '').toString().toLowerCase();
            final q = _pendingSearchQuery.toLowerCase();
            return name.contains(q) || email.contains(q) || mobile.contains(q);
          }).toList();
        }

        // Apply sort
        pendingDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          int result;
          if (_pendingSortField == 'name') {
            final aName = (aData['name'] ?? '').toString().toLowerCase();
            final bName = (bData['name'] ?? '').toString().toLowerCase();
            result = aName.compareTo(bName);
          } else {
            final aDate = (aData['createdAt'] as Timestamp?) ?? (aData['timestamp'] as Timestamp?);
            final bDate = (bData['createdAt'] as Timestamp?) ?? (bData['timestamp'] as Timestamp?);
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
          return _pendingSortAsc ? result : -result;
        });

        return Column(
          children: [
            _buildSearchAndSortControls(
              context,
              controller: _pendingSearchController,
              focusNode: _pendingSearchFocusNode,
              hintText: 'Search by name, email, or mobile...',
              sortField: _pendingSortField,
              sortAsc: _pendingSortAsc,
              onSearchChanged: (val) {
                _pendingSearchDebounce?.cancel();
                final next = val.trim().toLowerCase();
                _pendingSearchDebounce = Timer(const Duration(milliseconds: 650), () {
                  if (!mounted) return;
                  setState(() => _pendingSearchQuery = next);
                });
              },
              onSearchSubmitted: (val) {
                _pendingSearchDebounce?.cancel();
                _pendingSearchFocusNode.unfocus();
                setState(() => _pendingSearchQuery = val.trim().toLowerCase());
              },
              onSearchCleared: () {
                _pendingSearchDebounce?.cancel();
                _pendingSearchController.clear();
                setState(() => _pendingSearchQuery = '');
              },
              onSortFieldChanged: (val) => setState(() => _pendingSortField = val),
              onSortOrderToggled: () => setState(() => _pendingSortAsc = !_pendingSortAsc),
            ),
            Expanded(
              child: pendingDocs.isEmpty
                  ? _buildEmptyState(
                      context,
                      icon: Icons.pending_actions_outlined,
                      message: _pendingSearchQuery.isEmpty
                          ? 'No pending requests'
                          : 'No matching users found',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: pendingDocs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final doc = pendingDocs[index];
                        return _buildPendingUserCard(context, doc);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPendingUserCard(BuildContext context, QueryDocumentSnapshot doc) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    final userData = doc.data() as Map<String, dynamic>;
    final uid = doc.id;
    final fullName = (userData['name'] as String?) ?? 'Unknown';
    final appliedRole = (userData['role'] ?? userData['type'] ?? 'Resident').toString();
    final email = (userData['email'] ?? 'No email').toString();
    final phone = (userData['mobile'] ?? userData['phone'] ?? 'No mobile').toString();
    final addedAt = _extractAddedAt(userData);
    final addedAtText = addedAt != null ? _formatAddedAt(addedAt) : 'Unknown';
    
    // Check ALL possible profile image field names for maximum compatibility
    final profileImage = (userData['profileImageUrl'] as String?) ?? 
              (userData['photoURL'] as String?) ?? 
              (userData['profileImage'] as String?) ??
              (userData['photoUrl'] as String?);
    final avatarImage = resolveImageProvider(profileImage);
    
    final isGuest = appliedRole.toLowerCase().contains('guest');

    return Card(
      elevation: 0,
      color: isDark ? colorScheme.surfaceContainer : colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with avatar and name
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: colorScheme.primaryContainer,
                  backgroundImage: avatarImage,
                  child: avatarImage == null
                      ? Icon(Icons.person_outline, size: 24, color: colorScheme.onPrimaryContainer) 
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        appliedRole,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge for guest
                if (isGuest)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Guest',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Contact info
            _buildContactRow(context, Icons.email_outlined, email),
            const SizedBox(height: 4),
            _buildContactRow(context, Icons.phone_outlined, phone),
            const SizedBox(height: 4),
            _buildContactRow(context, Icons.schedule_outlined, 'Added: $addedAtText'),
            const SizedBox(height: 16),
            // Action buttons - filled style with consistent radius
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleReject(uid),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleApprove(uid),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check, size: 18),
                        const SizedBox(width: 6),
                        const Text('Approve', style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactRow(BuildContext context, IconData icon, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  DateTime? _extractAddedAt(Map<String, dynamic> userData) {
    final raw = userData['createdAt'] ??
        userData['timestamp'] ??
        userData['registeredAt'] ??
        userData['dateCreated'];

    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    if (raw is String) return DateTime.tryParse(raw);

    return null;
  }

  String _formatAddedAt(DateTime dateTime) {
    final local = dateTime.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = (local.hour % 12 == 0 ? 12 : local.hour % 12).toString();
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$month/$day/$year $hour:$minute $period';
  }

  Widget _buildSearchAndSortControls(
    BuildContext context, {
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required String sortField,
    required bool sortAsc,
    required Function(String) onSearchChanged,
    required Function(String) onSearchSubmitted,
    required VoidCallback onSearchCleared,
    required Function(String) onSortFieldChanged,
    required VoidCallback onSortOrderToggled,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search field
          TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onSearchChanged,
            onSubmitted: onSearchSubmitted,
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(Icons.clear, color: colorScheme.onSurfaceVariant),
                      onPressed: onSearchCleared,
                    ),
              filled: true,
              fillColor: isDark ? colorScheme.surfaceContainerHighest : colorScheme.surfaceContainerLowest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    onSortOrderToggled();
                  } else {
                    onSortFieldChanged(val);
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
                        Icon(sortAsc ? Icons.arrow_upward : Icons.arrow_downward, size: 18),
                        const SizedBox(width: 8),
                        Text(sortAsc ? 'Ascending' : 'Descending'),
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
                      Text(sortField == 'date' ? 'Date' : 'Name'),
                      const SizedBox(width: 6),
                      Icon(sortAsc ? Icons.arrow_upward : Icons.arrow_downward, size: 16),
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

  Widget _buildEmptyState(BuildContext context, {required IconData icon, required String message}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _handleApprove(String uid) async {
    // Rate limit: max 3 approval actions per minute -> min interval 20s
    if (!ThrottleHelper.canExecute('approval_action', 20000)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please wait before performing more approval actions')));
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'status': 'approved',
        'role': 'Resident',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvalStatus': FieldValue.delete(),
        'approval': FieldValue.delete(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showMaterialBanner(
          MaterialBanner(
            backgroundColor: const Color(0xFF10B981),
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Color(0xFF10B981), size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'User approved successfully!',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                },
                child: const Text('DISMISS', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
        });
      }
    } catch (e) {
      debugLog('Error approving user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showMaterialBanner(
          MaterialBanner(
            backgroundColor: Colors.red.shade600,
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error: $e',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                },
                child: const Text('DISMISS', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _handleReject(String uid) async {
    if (!ThrottleHelper.canExecute('approval_action', 20000)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please wait before performing more approval actions')));
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'approvalStatus': FieldValue.delete(),
        'approval': FieldValue.delete(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showMaterialBanner(
          MaterialBanner(
            backgroundColor: const Color(0xFFEF4444),
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Color(0xFFEF4444), size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'User application rejected',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                },
                child: const Text('DISMISS', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
        });
      }
    } catch (e) {
      debugLog('Error rejecting user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showMaterialBanner(
          MaterialBanner(
            backgroundColor: Colors.red.shade600,
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error: $e',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                },
                child: const Text('DISMISS', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    }
  }

  Widget _buildApprovedResidentsTab() {
    if (widget.officialBarangay == null || widget.officialBarangay.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('type', isEqualTo: 'Resident')
          .where('barangay', isEqualTo: widget.officialBarangay)
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          debugLog('Error loading approved residents: ${snapshot.error}');
          return const Center(child: Text('Error loading approved residents'));
        }

        final allDocs = snapshot.data?.docs ?? [];
        List<QueryDocumentSnapshot> approvedResidents = allDocs.where((d) {
          final m = d.data() as Map<String, dynamic>;
          final status = (m['status'] ?? m['approvalStatus'] ?? m['approval'])?.toString() ?? '';
          return status.toLowerCase() == 'approved';
        }).toList();

        // Apply search filter
        if (_approvedSearchQuery.isNotEmpty) {
          approvedResidents = approvedResidents.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['name'] ?? '').toString().toLowerCase();
            final email = (data['email'] ?? '').toString().toLowerCase();
            final mobile = (data['mobile'] ?? data['phone'] ?? '').toString().toLowerCase();
            final q = _approvedSearchQuery.toLowerCase();
            return name.contains(q) || email.contains(q) || mobile.contains(q);
          }).toList();
        }

        // Apply sort
        approvedResidents.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          int result;
          if (_approvedSortField == 'name') {
            final aName = (aData['name'] ?? '').toString().toLowerCase();
            final bName = (bData['name'] ?? '').toString().toLowerCase();
            result = aName.compareTo(bName);
          } else {
            final aDate = (aData['approvedAt'] as Timestamp?) ?? (aData['createdAt'] as Timestamp?) ?? (aData['timestamp'] as Timestamp?);
            final bDate = (bData['approvedAt'] as Timestamp?) ?? (bData['createdAt'] as Timestamp?) ?? (bData['timestamp'] as Timestamp?);
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
          return _approvedSortAsc ? result : -result;
        });

        return Column(
          children: [
            _buildSearchAndSortControls(
              context,
              controller: _approvedSearchController,
              focusNode: _approvedSearchFocusNode,
              hintText: 'Search approved residents...',
              sortField: _approvedSortField,
              sortAsc: _approvedSortAsc,
              onSearchChanged: (val) {
                _approvedSearchDebounce?.cancel();
                final next = val.trim().toLowerCase();
                _approvedSearchDebounce = Timer(const Duration(milliseconds: 650), () {
                  if (!mounted) return;
                  setState(() => _approvedSearchQuery = next);
                });
              },
              onSearchSubmitted: (val) {
                _approvedSearchDebounce?.cancel();
                _approvedSearchFocusNode.unfocus();
                setState(() => _approvedSearchQuery = val.trim().toLowerCase());
              },
              onSearchCleared: () {
                _approvedSearchDebounce?.cancel();
                _approvedSearchController.clear();
                setState(() => _approvedSearchQuery = '');
              },
              onSortFieldChanged: (val) => setState(() => _approvedSortField = val),
              onSortOrderToggled: () => setState(() => _approvedSortAsc = !_approvedSortAsc),
            ),
            Expanded(
              child: approvedResidents.isEmpty
                  ? _buildEmptyState(
                      context,
                      icon: Icons.check_circle_outline,
                      message: _approvedSearchQuery.isEmpty
                          ? 'No approved residents yet'
                          : 'No matching residents found',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: approvedResidents.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final doc = approvedResidents[index];
                        return _buildApprovedUserCard(context, doc);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildApprovedUserCard(BuildContext context, QueryDocumentSnapshot doc) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    final userData = doc.data() as Map<String, dynamic>;
    final uid = doc.id;
    final name = userData['name'] ?? 'Unknown';
    final email = (userData['email'] ?? 'No email').toString();
    final contact = userData['mobile'] ?? userData['contact'] ?? 'No contact';
    
    // Check ALL possible profile image field names for maximum compatibility
    final profileImage = (userData['profileImageUrl'] as String?) ?? 
              (userData['photoURL'] as String?) ?? 
              (userData['profileImage'] as String?) ??
              (userData['photoUrl'] as String?);
    final avatarImage = resolveImageProvider(profileImage);

    return Card(
      elevation: 0,
      color: isDark ? colorScheme.surfaceContainer : colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: colorScheme.primaryContainer,
              backgroundImage: avatarImage,
              child: avatarImage == null
                  ? Icon(Icons.person_outline, size: 24, color: colorScheme.onPrimaryContainer) 
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  _buildContactRow(context, Icons.email_outlined, email),
                  const SizedBox(height: 2),
                  _buildContactRow(context, Icons.phone_outlined, contact),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _updateApprovalStatus(uid, 'Rejected'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Revoke'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllRequestsTab() {
    if (widget.officialBarangay == null || widget.officialBarangay.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Show only rejected users (status == 'rejected')
    final q = FirebaseFirestore.instance
        .collection('users')
        .where('barangay', isEqualTo: widget.officialBarangay)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: q,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) {
          debugLog('Error loading rejected residents: ${snapshot.error}');
          return Center(child: Text('An error occurred while loading rejected residents.'));
        }
        final allDocs = snapshot.data?.docs ?? [];
        // Filter client-side for rejected status
        List<QueryDocumentSnapshot> rejectedDocs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? data['approvalStatus'] ?? data['approval'] ?? '').toString().toLowerCase();
          return status == 'rejected';
        }).toList();
        
        // Apply search filter
        if (_rejectedSearchQuery.isNotEmpty) {
          rejectedDocs = rejectedDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['name'] ?? '').toString().toLowerCase();
            final email = (data['email'] ?? '').toString().toLowerCase();
            final mobile = (data['mobile'] ?? data['phone'] ?? '').toString().toLowerCase();
            final q = _rejectedSearchQuery.toLowerCase();
            return name.contains(q) || email.contains(q) || mobile.contains(q);
          }).toList();
        }

        // Apply sort
        rejectedDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          int result;
          if (_rejectedSortField == 'name') {
            final aName = (aData['name'] ?? '').toString().toLowerCase();
            final bName = (bData['name'] ?? '').toString().toLowerCase();
            result = aName.compareTo(bName);
          } else {
            final aDate = (aData['rejectedAt'] as Timestamp?) ?? (aData['createdAt'] as Timestamp?) ?? (aData['timestamp'] as Timestamp?);
            final bDate = (bData['rejectedAt'] as Timestamp?) ?? (bData['createdAt'] as Timestamp?) ?? (bData['timestamp'] as Timestamp?);
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
          return _rejectedSortAsc ? result : -result;
        });

        return Column(
          children: [
            _buildSearchAndSortControls(
              context,
              controller: _rejectedSearchController,
              focusNode: _rejectedSearchFocusNode,
              hintText: 'Search rejected users...',
              sortField: _rejectedSortField,
              sortAsc: _rejectedSortAsc,
              onSearchChanged: (val) {
                _rejectedSearchDebounce?.cancel();
                final next = val.trim().toLowerCase();
                _rejectedSearchDebounce = Timer(const Duration(milliseconds: 650), () {
                  if (!mounted) return;
                  setState(() => _rejectedSearchQuery = next);
                });
              },
              onSearchSubmitted: (val) {
                _rejectedSearchDebounce?.cancel();
                _rejectedSearchFocusNode.unfocus();
                setState(() => _rejectedSearchQuery = val.trim().toLowerCase());
              },
              onSearchCleared: () {
                _rejectedSearchDebounce?.cancel();
                _rejectedSearchController.clear();
                setState(() => _rejectedSearchQuery = '');
              },
              onSortFieldChanged: (val) => setState(() => _rejectedSortField = val),
              onSortOrderToggled: () => setState(() => _rejectedSortAsc = !_rejectedSortAsc),
            ),
            Expanded(
              child: rejectedDocs.isEmpty
                  ? _buildEmptyState(
                      context,
                      icon: Icons.cancel_outlined,
                      message: _rejectedSearchQuery.isEmpty
                          ? 'No rejected users'
                          : 'No matching users found',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: rejectedDocs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final doc = rejectedDocs[index];
                        return _buildRejectedUserCard(context, doc);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRejectedUserCard(BuildContext context, QueryDocumentSnapshot doc) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Unknown';
    final email = data['email'] ?? 'No email';
    final phone = data['mobile'] ?? data['phone'] ?? 'No phone';
    
    // Check ALL possible profile image field names for maximum compatibility
    final profileImage = (data['profileImageUrl'] as String?) ?? 
              (data['photoURL'] as String?) ?? 
              (data['profileImage'] as String?) ??
              (data['photoUrl'] as String?);
    final avatarImage = resolveImageProvider(profileImage);

    return Card(
      elevation: 0,
      color: isDark ? colorScheme.surfaceContainer : colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: colorScheme.errorContainer,
              backgroundImage: avatarImage,
              child: avatarImage == null
                  ? Icon(Icons.person_outline, size: 24, color: colorScheme.onErrorContainer) 
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  _buildContactRow(context, Icons.email_outlined, email),
                  const SizedBox(height: 2),
                  _buildContactRow(context, Icons.phone_outlined, phone),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateApprovalStatus(String uid, String status) async {
    if (!ThrottleHelper.canExecute('approval_$uid', 333)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please wait before updating this resident again')),
        );
      }
      return;
    }
    
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'approvalStatus': status,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Resident $status')),
        );
      }
    } catch (e) {
      debugLog('Error updating approval status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  /// Clean up rejected users older than 7 days
  /// Deletes the user document but keeps the rejection count (via rejectedAt timestamp)
  Future<void> _cleanupOldRejectedUsers() async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 7));
      final cutoffTimestamp = Timestamp.fromDate(cutoffDate);
      
      // Query rejected users older than 7 days
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('barangay', isEqualTo: widget.officialBarangay)
          .where('rejectedAt', isLessThan: cutoffTimestamp)
          .get();
      
      // Batch delete old rejected users
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snap.docs) {
        batch.delete(doc.reference);
      }
      
      if (snap.docs.isNotEmpty) {
        await batch.commit();
        debugLog('[ApprovalPanel] Cleaned up ${snap.docs.length} rejected users older than 7 days');
      }
    } catch (e) {
      debugLog('[ApprovalPanel] Error during cleanup: $e');
    }
  }
}

// ==================== BARANGAY OFFICIAL DASHBOARD ====================

