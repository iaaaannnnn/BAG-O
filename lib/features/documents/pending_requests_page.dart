part of '../../app/app.dart';

class PendingRequestsPage extends StatefulWidget {
  const PendingRequestsPage({Key? key}) : super(key: key);

  @override
  State<PendingRequestsPage> createState() => _PendingRequestsPageState();
}

class _PendingRequestsPageState extends State<PendingRequestsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // Search and sort state
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  Timer? _searchDebounce;
  String _sortField = 'date'; // date | name
  bool _sortAsc = false; // false = newest first, true = oldest first for date

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      animationDuration: const Duration(milliseconds: 380),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kUseMockData) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pending Requests (Mock)')),
        body: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: kMockPendingRequests.length,
          itemBuilder: (context, index) {
            var doc = kMockPendingRequests[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(doc['subject'] ?? 'Request'),
                subtitle: Text(doc['description'] ?? ''),
                trailing: Text(doc['status'] ?? 'Pending'),
              ),
            );
          },
        ),
      );
    }

    return FutureBuilder<String?>(
      future: AuthService.waitForBarangay(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Pending Requests')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final officialBarangay = snapshot.data ?? '';
        if (officialBarangay.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Pending Requests')),
            body: const Center(child: Text('Barangay information not loaded')),
          );
        }

        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return GestureDetector(
          onTap: () => _searchFocusNode.unfocus(),
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Document Requests'),
              centerTitle: true,
              elevation: 0,
              scrolledUnderElevation: 1,
              bottom: TabBar(
                controller: _tabController,
                isScrollable: false,
                labelColor: colorScheme.onPrimary,
                unselectedLabelColor: colorScheme.onPrimary.withValues(alpha: 0.72),
                indicatorColor: colorScheme.onPrimary,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                tabAlignment: TabAlignment.fill,
                tabs: const [
                  Tab(icon: Icon(Icons.pending_actions_outlined), text: 'Pending'),
                  Tab(icon: Icon(Icons.task_alt_outlined), text: 'Approved'),
                  Tab(icon: Icon(Icons.upload_file_outlined), text: 'Released'),
                  Tab(icon: Icon(Icons.cancel_outlined), text: 'Rejected'),
                ],
              ),
            ),
            body: Column(
              children: [
                // Search + Sort Controls
                _buildSearchSortControls(context),
                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRequestsTab(officialBarangay, 'Under Review'),
                      _buildRequestsTab(officialBarangay, 'Approved'),
                      _buildRequestsTab(officialBarangay, 'Release'),
                      _buildRequestsTab(officialBarangay, 'Rejected'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
              hintText: 'Search by resident name, subject, or reason...',
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
                  const PopupMenuItem(value: 'name', child: Text('Resident Name')),
                  const PopupMenuItem(value: 'date', child: Text('Date')),
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

  // Helper method to aggregate requests from both user subcollections and top-level collection
  Widget _buildRequestsTab(String officialBarangay, String status) {
    // Map display status to Firestore status values
    String firestoreStatus;
    if (status == 'Under Review') {
      firestoreStatus = 'Pending';
    } else if (status == 'Approved') {
      firestoreStatus = 'Approved';
    } else if (status == 'Release') {
      firestoreStatus = 'Fulfilled';
    } else {
      firestoreStatus = 'Rejected';
    }

    return StreamBuilder<List<QueryDocumentSnapshot>>(
      stream: _getRequestsStreamByStatus(officialBarangay, firestoreStatus),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error loading requests: ${snapshot.error}'),
            ),
          );
        }

        final docs = snapshot.data ?? [];

        // Apply search filter
        var filteredDocs = docs;
        if (_searchQuery.isNotEmpty) {
          filteredDocs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final userName = (data['userName'] ?? '').toString().toLowerCase();
            final subject = (data['subject'] ?? '').toString().toLowerCase();
            final reason = (data['reason'] ?? '').toString().toLowerCase();
            final q = _searchQuery.toLowerCase();
            return userName.contains(q) || subject.contains(q) || reason.contains(q);
          }).toList();
        }

        // Apply sort
        filteredDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          int result;
          if (_sortField == 'name') {
            final aName = (aData['userName'] ?? '').toString().toLowerCase();
            final bName = (bData['userName'] ?? '').toString().toLowerCase();
            result = aName.compareTo(bName);
          } else {
            final aDate = (aData['timestamp'] as Timestamp?) ?? (aData['createdAt'] as Timestamp?);
            final bDate = (bData['timestamp'] as Timestamp?) ?? (bData['createdAt'] as Timestamp?);
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

        if (filteredDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  status == 'Under Review' ? Icons.inbox : 
                  status == 'Approved' ? Icons.check_circle_outline : 
                  status == 'Release' ? Icons.file_upload :
                  Icons.cancel_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  status == 'Under Review' 
                    ? 'No requests under review'
                    : status == 'Approved'
                      ? 'No approved requests'
                      : status == 'Release'
                        ? 'No documents ready for release'
                        : 'No rejected requests',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) => _buildRequestCard(context, filteredDocs[index], firestoreStatus),
        );
      },
    );
  }

  Widget _buildRequestCard(BuildContext context, QueryDocumentSnapshot doc, String currentStatus) {
    final data = doc.data() as Map<String, dynamic>;
    final userName = data['userName'] as String? ?? 'N/A';
    final subject = data['subject'] as String? ?? 'Request';
    final reason = data['reason'] as String? ?? '';
    final timestamp = data['timestamp'] as Timestamp?;
    final formattedDate = timestamp != null 
        ? '${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year}'
        : 'N/A';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  currentStatus == 'Pending' ? Icons.pending_actions : 
                  currentStatus == 'Approved' ? Icons.check_circle_outline :
                  currentStatus == 'Fulfilled' ? Icons.check_circle : Icons.cancel,
                  color: currentStatus == 'Pending' ? Colors.orange : 
                         currentStatus == 'Approved' ? Colors.blue :
                         currentStatus == 'Fulfilled' ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    subject,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Text('Resident: $userName', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            if (reason.isNotEmpty) Text('Reason: $reason', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Text('Date: $formattedDate', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            
            if (currentStatus == 'Pending') ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _handleRejectRequest(context, doc, data),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _handleApproveRequest(context, doc, data),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF228B22),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ] else if (currentStatus == 'Approved') ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showFulfillDialog(context, doc),
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: const Text('Release'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleApproveRequest(BuildContext context, QueryDocumentSnapshot doc, Map<String, dynamic> data) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Request'),
        content: Text('Are you sure you want to approve this ${data['subject']} request? The document will be marked as approved and ready for release.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await doc.reference.update({
          'status': 'Approved',
          'approval': 'Approved',
          'approvedAt': FieldValue.serverTimestamp(),
          'approvedBy': AuthService.currentUser?.uid,
        });

        final userId = data['userId'] as String?;
        if (userId != null) {
          await NotificationService.addNotification(
            userId,
            'Request Approved',
            'Your ${data['subject']} request has been approved and is ready for release.',
          );
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request approved successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to approve request: $e')),
          );
        }
      }
    }
  }

  Future<void> _handleRejectRequest(BuildContext context, QueryDocumentSnapshot doc, Map<String, dynamic> data) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Request'),
        content: Text('Are you sure you want to reject this ${data['subject']} request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await doc.reference.update({
        'status': 'Rejected',
        'approval': 'Rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': AuthService.currentUser?.uid,
      });

      final userId = data['userId'] as String?;
      if (userId != null) {
        await NotificationService.addNotification(
          userId,
          'Request Rejected',
          'Your ${data['subject']} request has been rejected.',
        );
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showMaterialBanner(
          MaterialBanner(
            backgroundColor: Colors.red.shade600,
            content: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Request rejected successfully',
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
        Future.delayed(const Duration(seconds: 2), () {
          if (context.mounted) ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
        });
      }
    } catch (e) {
      debugLog('Error rejecting request: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Stream<List<QueryDocumentSnapshot>> _getRequestsStreamByStatus(String officialBarangay, String status) {
    try {
      if (officialBarangay.isEmpty) {
        return Stream.value([]);
      }

      // Query all requests for the barangay and filter client-side to avoid indexing issues
      return FirebaseFirestore.instance
          .collection('document_requests')
          .where('barangay', isEqualTo: officialBarangay)
          .limit(500) // Reasonable limit to prevent large queries
          .snapshots()
          .map((snap) {
            final docs = snap.docs;
            debugLog('[RequestsStream] Found ${docs.length} total documents for barangay: $officialBarangay');
            // Log all status values for debugging
            if (docs.isNotEmpty) {
              final statusCounts = <String, int>{};
              for (final doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                final docStatus = (data['status'] ?? 'null').toString();
                statusCounts[docStatus] = (statusCounts[docStatus] ?? 0) + 1;
              }
              debugLog('[RequestsStream] Status distribution: $statusCounts');
            }
            // Client-side status filtering
            final filteredDocs = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final docBarangay = (data['barangay'] ?? '').toString();
              final docStatus = (data['status'] ?? '').toString();
              final barangayMatches = docBarangay == officialBarangay;
              final statusMatches = docStatus == status;
              
              if (!barangayMatches && docs.length < 10) {
                debugLog('[RequestsStream] Doc ${doc.id} barangay: "$docBarangay" != "$officialBarangay", skipping');
              }
              if (!statusMatches && docs.length < 10) {
                debugLog('[RequestsStream] Doc ${doc.id} status: "$docStatus" != "$status", skipping');
              }
              
              return barangayMatches && statusMatches;
            }).toList();
            debugLog('[RequestsStream] After filtering for status "$status": ${filteredDocs.length} documents');

            // Sort by timestamp descending (newest first)
            filteredDocs.sort((a, b) {
              final aTime = (a.data()['timestamp'] as Timestamp?);
              final bTime = (b.data()['timestamp'] as Timestamp?);
              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return bTime.compareTo(aTime);
            });
            return filteredDocs;
          }).handleError((e) {
            debugLog('[RequestsStream] Error: $e');
            return <QueryDocumentSnapshot>[];
          });
    } catch (e) {
      debugLog('[RequestsStream] Error creating stream: $e');
      return Stream.value([]);
    }
  }

  Widget _buildAggregatedRequestsStream(String officialBarangay) {
    return StreamBuilder<List<QueryDocumentSnapshot>>(
      stream: _getAggregatedRequestsStream(officialBarangay),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          debugLog('Error loading requests: ${snapshot.error}');
          return Center(child: Text('Error: ${snapshot.error.toString().replaceFirst('Exception: ', '')}'));
        }
        
        final docs = snapshot.data ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No pending requests for your barangay'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final userName = data['userName'] as String? ?? 'N/A';
            final timestamp = data['timestamp'] as Timestamp?;
            final formattedDate = timestamp != null 
              ? '${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year}'
              : 'N/A';
            
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(data['subject'] ?? 'Request'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text('From: $userName', style: const TextStyle(fontSize: 12)),
                    Text('Reason: ${data['reason'] ?? ''}', style: const TextStyle(fontSize: 12)),
                    Text('Submitted: $formattedDate', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    if (data['barangay'] != null && data['barangay'].isNotEmpty)
                      Text('Barangay: ${data['barangay']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (val) async {
                    try {
                      if (val == 'Under Review') {
                        await doc.reference.update({'workflowStatus': 'Under Review'});
                        final userId = data['userId'] as String?;
                        if (userId != null) {
                          await NotificationService.addNotification(userId, 'Request Under Review', 'Your ${data['subject']} request is now under review');
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked under review')));
                        }
                      } else if (val == 'Approve') {
                        await doc.reference.update({'approval': 'Approved', 'status': 'Approved'});
                        await doc.reference.update({'workflowStatus': 'For Releasing'});
                        final userId = data['userId'] as String?;
                        if (userId != null) {
                          await NotificationService.addNotification(userId, 'Request Approved', 'Your ${data['subject']} request has been approved');
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request approved and notification sent')));
                        }
                      } else if (val == 'Release') {
                        _showFulfillDialog(context, doc);
                      } else if (val == 'Reject') {
                        await doc.reference.update({'approval': 'Rejected', 'status': 'Rejected'});
                        final userId = data['userId'] as String?;
                        if (userId != null) {
                          await NotificationService.addNotification(userId, 'Request Rejected', 'Your ${data['subject']} request was rejected');
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request rejected and notification sent')));
                        }
                      }
                    } catch (e) {
                      debugLog('Error updating request: $e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'Under Review', child: Text('Under Review')),
                    PopupMenuItem(value: 'Approve', child: Text('Approve')),
                    PopupMenuItem(value: 'Release', child: Text('Release')),
                    PopupMenuItem(value: 'Reject', child: Text('Reject')),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showFulfillDialog(BuildContext context, QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final userName = data['userName'] as String? ?? 'Unknown';
    final subject = data['subject'] as String? ?? 'N/A';
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Release Document'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resident: $userName', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Requested: $subject'),
            const SizedBox(height: 16),
            Text('Mark this document as released to the resident.', style: TextStyle(fontSize: 13, color: Theme.of(ctx).textTheme.bodyMedium?.color?.withOpacity(0.7) ?? Colors.black54)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _releaseDocument(context, doc);
            },
            icon: const Icon(Icons.check_circle),
            label: const Text('Release'),
          ),
        ],
      ),
    );
  }

  Future<void> _releaseDocument(BuildContext context, QueryDocumentSnapshot doc) async {
    try {
      await doc.reference.update({
        'status': 'Fulfilled',
        'approval': 'Approved',
        'workflowStatus': 'Released',
        'fulfilledAt': FieldValue.serverTimestamp(),
        'fulfilledBy': AuthService.currentUser?.uid,
      });

      final data = doc.data() as Map<String, dynamic>;
      final userId = data['userId'] as String?;
      if (userId != null) {
        await NotificationService.addNotification(
          userId,
          'Document Released',
          'Your requested document "${data['subject']}" has been released and is ready for pickup.',
        );
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document marked as released!')),
        );
      }
    } catch (e) {
      debugLog('Error releasing document: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to release document: $e')),
        );
      }
    }
  }

  // Stream aggregation helper: combines user subcollections and top-level collection
  Stream<List<QueryDocumentSnapshot>> _getAggregatedRequestsStream(String officialBarangay) {
    try {
      // Guard: Cannot query with empty barangay
      if (officialBarangay.isEmpty) {
        return Stream.value([]);
      }

      // NOTE: Collection group reads were hitting permission-denied in some environments.
      // To keep officials unblocked, rely on the top-level collection only.
      final topLevelStream = FirebaseFirestore.instance
          .collection('document_requests')
          .where('barangay', isEqualTo: officialBarangay)
          .where('status', isEqualTo: 'Pending')
          .snapshots();

      return topLevelStream.map((snap) {
        final docs = snap.docs;
        final seen = <String>{};
        final deduped = <QueryDocumentSnapshot>[];

        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final key = '${data['userId'] ?? ''}_${data['subject'] ?? ''}_${data['timestamp'] ?? ''}';
          if (!seen.contains(key)) {
            seen.add(key);
            deduped.add(doc);
          }
        }

        deduped.sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          final bTime = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });

        return deduped;
      }).handleError((e) {
        debugLog('[RequestsStream] top-level stream error: $e');
        return <QueryDocumentSnapshot>[];
      });
    } catch (e) {
      debugLog('[RequestsStream] Error creating aggregated stream: $e');
      return Stream.value([]);
    }
  }
}


