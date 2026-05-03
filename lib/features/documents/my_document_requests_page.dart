part of '../../app/app.dart';

class MyDocumentRequestsPage extends StatefulWidget {
  const MyDocumentRequestsPage({Key? key}) : super(key: key);

  @override
  State<MyDocumentRequestsPage> createState() => _MyDocumentRequestsPageState();
}

class _MyDocumentRequestsPageState extends State<MyDocumentRequestsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  String _sortBy = 'date'; // date or subject
  bool _sortAsc = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
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

  String? _contentTypeFromExt(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf': return 'application/pdf';
      case 'doc': case 'docx': return 'application/msword';
      case 'xls': case 'xlsx': return 'application/vnd.ms-excel';
      case 'png': return 'image/png';
      case 'jpg': case 'jpeg': return 'image/jpeg';
      default: return 'application/octet-stream';
    }
  }

  // Create aggregated stream from both document_requests and users/{uid}/requests
  Stream<List<QueryDocumentSnapshot>> _getMyRequestsStream(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('requests')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .asyncMap((subcollectionSnapshot) async {
          final allDocs = <QueryDocumentSnapshot>[...subcollectionSnapshot.docs];
          
          try {
            final topLevelSnapshot = await FirebaseFirestore.instance
                .collection('document_requests')
                .where('userId', isEqualTo: uid)
                .orderBy('timestamp', descending: true)
                .get();
            allDocs.addAll(topLevelSnapshot.docs);
          } catch (e) {
            debugLog('[MyRequests] Could not fetch from document_requests: $e');
          }
          
          final seen = <String>{};
          final deduped = <QueryDocumentSnapshot>[];
          
          for (final doc in allDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final key = '${data['subject'] ?? ''}_${data['timestamp'] ?? ''}';
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
        })
        .handleError((error) {
          debugLog('[MyRequests] Stream error: $error');
          return <QueryDocumentSnapshot>[];
        });
  }

  String _getDefaultWorkflowStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'submitted';
      case 'fulfilled':
        return 'released';
      case 'rejected':
        return 'rejected';
      default:
        return 'submitted';
    }
  }

  String _getDisplayStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'PENDING';
      case 'fulfilled':
        return 'FULFILLED';
      case 'rejected':
        return 'REJECTED';
      default:
        return status.toUpperCase();
    }
  }

  String _getWorkflowStatusDisplay(String workflowStatus) {
    switch (workflowStatus.toLowerCase()) {
      case 'submitted':
        return 'Submitted';
      case 'under review':
        return 'Under Review';
      case 'for releasing':
        return 'For Releasing';
      case 'released':
        return 'Released';
      default:
        return workflowStatus;
    }
  }

  IconData _getWorkflowStatusIcon(String workflowStatus) {
    switch (workflowStatus.toLowerCase()) {
      case 'submitted':
        return Icons.check_circle_outline;
      case 'under review':
        return Icons.schedule;
      case 'for releasing':
        return Icons.local_shipping;
      case 'released':
        return Icons.verified;
      default:
        return Icons.info;
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final next = value.trim().toLowerCase();
    _searchDebounce = Timer(const Duration(milliseconds: 650), () {
      if (mounted && _searchQuery != next) {
        setState(() {
          _searchQuery = next;
        });
      }
    });
  }

  List<QueryDocumentSnapshot> _filterAndSortDocuments(List<QueryDocumentSnapshot> docs, String? filterStatus) {
    var filtered = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final reason = data['reason'] as String? ?? '';
      
      // Exclude requests without reasons - they should never have been submitted
      if (reason.trim().isEmpty) {
        return false;
      }
      
      final status = data['status'] as String? ?? 'Pending';
      final workflowStatus = data['workflowStatus'] as String? ?? _getDefaultWorkflowStatus(status);
      
      // Filter by status with workflow consideration
      if (filterStatus == 'Pending') {
        // Pending: status is 'Pending' and not yet released or rejected
        if (status != 'Pending' || workflowStatus.toLowerCase() == 'released' || workflowStatus.toLowerCase() == 'rejected') {
          return false;
        }
      } else if (filterStatus == 'Fulfilled') {
        // Fulfilled: status is 'Fulfilled' or (status is 'Pending' and released)
        if (status != 'Fulfilled' && !(status == 'Pending' && workflowStatus.toLowerCase() == 'released')) {
          return false;
        }
      } else if (filterStatus == 'Rejected') {
        // Rejected: status is 'Rejected' or (status is 'Pending' and rejected)
        if (status != 'Rejected' && !(status == 'Pending' && workflowStatus.toLowerCase() == 'rejected')) {
          return false;
        }
      }
      
      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final subject = (data['subject'] as String? ?? '').toLowerCase();
        return subject.contains(_searchQuery);
      }
      
      return true;
    }).toList();

    // Sort
    filtered.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      
      int result = 0;
      if (_sortBy == 'date') {
        final aTime = aData['timestamp'] as Timestamp?;
        final bTime = bData['timestamp'] as Timestamp?;
        result = (aTime?.compareTo(bTime ?? Timestamp.now()) ?? 0);
      } else {
        final aSubj = aData['subject'] as String? ?? '';
        final bSubj = bData['subject'] as String? ?? '';
        result = aSubj.compareTo(bSubj);
      }
      
      return _sortAsc ? result : -result;
    });

    return filtered;
  }

  Future<void> _deleteRequest(QueryDocumentSnapshot doc) async {
    try {
      await doc.reference.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request deleted')),
        );
      }
    } catch (e) {
      debugLog('Error deleting request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Widget _buildRequestsList(List<QueryDocumentSnapshot> docs, String filterStatus) {
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey),
            const SizedBox(height: 16),
            Text('No requests found', style: TextStyle(fontSize: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = doc.data() as Map<String, dynamic>;
        final subject = data['subject'] as String? ?? 'N/A';
        final status = data['status'] as String? ?? 'Pending';
        final workflowStatus = data['workflowStatus'] as String? ?? _getDefaultWorkflowStatus(status);
        final timestamp = data['timestamp'] as Timestamp?;
        final dateStr = timestamp != null
            ? '${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year}'
            : 'N/A';
        final base64Data = data['fulfillmentFileData'] as String?;
        final fileName = data['fulfillmentFileName'] as String?;
        final fileType = data['fulfillmentFileType'] as String?;

        // Determine display status based on filter tab
        String effectiveStatus = status;
        if (filterStatus == 'Fulfilled' && status == 'Pending' && workflowStatus.toLowerCase() == 'released') {
          effectiveStatus = 'Fulfilled';
        } else if (filterStatus == 'Rejected' && status == 'Pending' && workflowStatus.toLowerCase() == 'rejected') {
          effectiveStatus = 'Rejected';
        }

        // For rejected documents, show with swipe-to-delete
        if (effectiveStatus == 'Rejected') {
          return Dismissible(
            key: ValueKey(doc.id),
            direction: DismissDirection.endToStart,
            onDismissed: (_) => _deleteRequest(doc),
            background: Container(
              color: const Color(0xFFB91C1C),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            child: _buildRequestCard(doc, data, subject, status, workflowStatus, dateStr, base64Data, fileName, fileType, filterStatus),
          );
        }

        return _buildRequestCard(doc, data, subject, status, workflowStatus, dateStr, base64Data, fileName, fileType, filterStatus);
      },
    );
  }

  Widget _buildRequestCard(
    QueryDocumentSnapshot doc,
    Map<String, dynamic> data,
    String subject,
    String status,
    String workflowStatus,
    String dateStr,
    String? base64Data,
    String? fileName,
    String? fileType,
    String filterStatus,
  ) {
    // Determine display status based on filter tab
    String effectiveStatus = status;
    if (filterStatus == 'Fulfilled' && status == 'Pending' && workflowStatus.toLowerCase() == 'released') {
      effectiveStatus = 'Fulfilled';
    } else if (filterStatus == 'Rejected' && status == 'Pending' && workflowStatus.toLowerCase() == 'rejected') {
      effectiveStatus = 'Rejected';
    }

    Color statusColor = const Color(0xFFF59E0B);
    if (effectiveStatus == 'Fulfilled') statusColor = const Color(0xFF2E7D32);
    if (effectiveStatus == 'Rejected') statusColor = const Color(0xFFB91C1C);

    String displayStatus = _getDisplayStatus(effectiveStatus);
    String workflowDisplay = _getWorkflowStatusDisplay(workflowStatus);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    subject,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                if (effectiveStatus == 'Fulfilled')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Color(0xFF2E7D32)),
                        SizedBox(width: 4),
                        Text(
                          'Ready for Pickup',
                          style: TextStyle(fontSize: 11, color: Color(0xFF2E7D32), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Requested: $dateStr',
              style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7) ?? Colors.grey),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withValues(alpha: 0.5), width: 1),
                  ),
                  child: Text(
                    displayStatus,
                    style: TextStyle(
                      fontSize: 11,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getWorkflowStatusIcon(workflowStatus),
                        size: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7) ?? Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        workflowDisplay,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7) ?? Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (status == 'Fulfilled') ...[
              const SizedBox(height: 8),
              Text(
                'Document has been released and is ready for pickup at the barangay office.',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6) ?? Colors.grey,
                ),
              ),
            ],
            // Cancel button for pending requests
            if (effectiveStatus == 'Pending') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showCancelConfirmation(context, doc),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Cancel Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCancelConfirmation(BuildContext context, QueryDocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Request?'),
        content: const Text('Are you sure you want to cancel this document request? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Request'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteRequest(doc);
            },
            icon: const Icon(Icons.delete, size: 18),
            label: const Text('Cancel Request'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.currentUser?.uid;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Document Requests')),
        body: const Center(child: Text('Please log in to view your requests')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Document Requests'),
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
          labelStyle: const TextStyle(fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontSize: 13),
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Fulfilled'),
            Tab(text: 'Rejected'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search and sort controls
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Search field
                TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: _onSearchChanged,
                  onSubmitted: (val) {
                    _searchDebounce?.cancel();
                    _searchFocusNode.unfocus();
                    setState(() => _searchQuery = val.trim());
                  },
                  decoration: InputDecoration(
                    hintText: 'Search requests',
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
                const SizedBox(height: 8),
                // Sort controls
                PopupMenuButton<String>(
                  tooltip: 'Sort',
                  onSelected: (val) {
                    if (val == 'toggle_order') {
                      setState(() => _sortAsc = !_sortAsc);
                    } else {
                      setState(() => _sortBy = val);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'date', child: Text('Date')),
                    const PopupMenuItem(value: 'subject', child: Text('Subject')),
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
                        Text(_sortBy == 'date' ? 'Date' : 'Subject'),
                        const SizedBox(width: 6),
                        Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Tab content
          Expanded(
            child: StreamBuilder<List<QueryDocumentSnapshot>>(
              stream: _getMyRequestsStream(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final allDocs = snapshot.data ?? [];
                
                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRequestsList(_filterAndSortDocuments(allDocs, 'Pending'), 'Pending'),
                    _buildRequestsList(_filterAndSortDocuments(allDocs, 'Fulfilled'), 'Fulfilled'),
                    _buildRequestsList(_filterAndSortDocuments(allDocs, 'Rejected'), 'Rejected'),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }


}


