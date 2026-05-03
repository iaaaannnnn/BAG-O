part of '../../app/app.dart';

class ViewComplaintsAdminPage extends StatefulWidget {
  const ViewComplaintsAdminPage({Key? key}) : super(key: key);

  @override
  State<ViewComplaintsAdminPage> createState() => _ViewComplaintsAdminPageState();
}

class _ViewComplaintsAdminPageState extends State<ViewComplaintsAdminPage> with SingleTickerProviderStateMixin {
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
      length: 3,
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
    return FutureBuilder<String?>(
      future: AuthService.waitForBarangay(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Complaints')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final barangay = snapshot.data ?? '';
        if (barangay.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Complaints')),
            body: const Center(child: Text('Barangay not loaded')),
          );
        }

        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return GestureDetector(
          onTap: () => _searchFocusNode.unfocus(),
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Complaints'),
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
                  Tab(icon: Icon(Icons.task_alt_outlined), text: 'Resolved'),
                  Tab(icon: Icon(Icons.list_alt_outlined), text: 'All'),
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
                      _buildComplaintsTab('Pending', barangay),
                      _buildComplaintsTab('Resolved', barangay),
                      _buildComplaintsTab(null, barangay),
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
              hintText: 'Search by resident name, subject, or description...',
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
  
  Widget _buildComplaintsTab(String? status, String barangay) {
    if (barangay.isEmpty) {
      return const Center(child: Text('Barangay not loaded'));
    }

    // Query without status filter - apply status filter client-side
    final stream = FirebaseFirestore.instance
        .collection('complaints')
        .where('barangay', isEqualTo: barangay)
        .limit(100) // Limit to prevent large queries
        .snapshots()
        .timeout(
          const Duration(seconds: 10),
          onTimeout: (_) => Stream.error('Query timeout'),
        )
        .debounceTime(const Duration(milliseconds: 200));

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          debugLog('Error loading complaints: ${snapshot.error}');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Error loading complaints', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(
                    'Please try again later',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7) ?? Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        
        // Client-side filtering and sorting
        var docs = snapshot.data?.docs ?? [];
        if (status != null) {
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return (data['status'] ?? '').toString() == status;
          }).toList();
        }

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final userName = (data['userName'] ?? '').toString().toLowerCase();
            final subject = (data['subject'] ?? '').toString().toLowerCase();
            final description = (data['description'] ?? '').toString().toLowerCase();
            final q = _searchQuery.toLowerCase();
            return userName.contains(q) || subject.contains(q) || description.contains(q);
          }).toList();
        }

        // Apply sort
        docs.sort((a, b) {
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
        
        if (docs.isEmpty) {
          return Center(child: Text(status != null ? 'No $status Complaints' : 'No Complaints'));
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final ts = data['timestamp'] as Timestamp?;
            final dateStr = ts != null ? '${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year}' : 'N/A';
            final hasImage = (data['imageUrl'] ?? '').toString().isNotEmpty;
            final complaintStatus = (data['status'] ?? 'Pending').toString();
            
            Color statusColor = complaintStatus == 'Resolved' ? const Color(0xFF2E7D32) : const Color(0xFFF59E0B);
            
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 2,
              child: InkWell(
                onTap: () => _showComplaintDetails(context, data, doc.id, dateStr),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row with subject and status badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              data['subject'] ?? 'Complaint',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (complaintStatus == 'Resolved')
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
                                    'Resolved',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF2E7D32), fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Submitted info (date only)
                      Text(
                        'Submitted: $dateStr',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7) ?? Colors.grey),
                      ),
                      const SizedBox(height: 10),
                      
                      // Status badge row with small graphic (only show if not in Resolved tab)
                      Row(
                        children: [
                          if (status != 'Resolved')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: statusColor.withValues(alpha: 0.5), width: 1),
                              ),
                              child: Text(
                                complaintStatus,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                        ),
                      if (status != 'Resolved')
                        const SizedBox(height: 10),
                      
                      // Description
                      Text(
                        data['description'] ?? 'N/A',
                        style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8)),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      // Image preview if available
                      if (hasImage) ...[
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => _showFullImage(context, data['imageUrl']),
                          child: Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  buildImageFromUrl(data['imageUrl'], fit: BoxFit.cover),
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.zoom_in, size: 16, color: Colors.white),
                                          SizedBox(width: 4),
                                          Text('View', style: TextStyle(color: Colors.white, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      
                      // Action buttons
                      if (complaintStatus == 'Pending') ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF228B22),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => _updateComplaintStatus(doc.id, 'Resolved'),
                                icon: const Icon(Icons.check_circle, size: 18),
                                label: const Text('Mark as Resolved'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => _updateComplaintStatus(doc.id, 'Invalid'),
                                icon: const Icon(Icons.cancel, size: 18),
                                label: const Text('Invalidate'),
                              ),
                            ),
                          ],
                        ),
                      ] else if (complaintStatus == 'Resolved') ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => _updateComplaintStatus(doc.id, 'Pending'),
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Reopen Complaint'),
                          ),
                        ),
                      ],
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
  
  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: buildImageFromUrl(imageUrl, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showComplaintDetails(BuildContext context, Map<String, dynamic> data, String docId, String dateStr) {
    final hasImage = (data['imageUrl'] ?? '').toString().isNotEmpty;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(data['subject'] ?? 'Complaint', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (data['status'] ?? '').toString().toLowerCase() == 'resolved' ? Colors.green[100] : (data['status'] ?? '').toString().toLowerCase() == 'invalid' ? Colors.red[100] : Colors.orange[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      data['status'] ?? 'Pending',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: (data['status'] ?? '').toString().toLowerCase() == 'resolved' ? Colors.green[700] : (data['status'] ?? '').toString().toLowerCase() == 'invalid' ? Colors.red[700] : Colors.orange[700],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Complainant: ${data['userName'] ?? 'Unknown'}', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              const SizedBox(height: 4),
              Text('Type: ${data['type'] ?? 'General'}', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              const SizedBox(height: 4),
              Text('Filed: $dateStr', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 16),
              const Text('Description:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(data['description'] ?? 'N/A', style: const TextStyle(fontSize: 16)),
              if (hasImage) ...[
                const SizedBox(height: 16),
                const Text('Attached Image:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _showFullImage(context, data['imageUrl']);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: buildImageFromUrl(data['imageUrl'], height: 200, width: double.infinity, fit: BoxFit.cover),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Center(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    if ((data['status'] ?? '').toString() != 'Resolved')
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF228B22), 
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _updateComplaintStatus(docId, 'Resolved');
                        },
                        child: const Text('Mark Resolved'),
                      ),
                    if ((data['status'] ?? '').toString() == 'Invalid')
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          minimumSize: const Size(160, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _updateComplaintStatus(docId, 'Pending');
                        },
                        child: const Text('Reopen'),
                      ),
                    if ((data['status'] ?? '').toString() == 'Resolved')
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          minimumSize: const Size(160, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _updateComplaintStatus(docId, 'Pending');
                        },
                        child: const Text('Reopen'),
                      ),
                    if ((data['status'] ?? '').toString() == 'Pending')
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _updateComplaintStatus(docId, 'Invalid');
                        },
                        child: const Text('Invalidate'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Future<void> _updateComplaintStatus(String docId, String newStatus) async {
    if (!ThrottleHelper.canExecute('complaint_$docId', 500)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please wait before updating again')));
      }
      return;
    }
    
    try {
      await FirebaseFirestore.instance.collection('complaints').doc(docId).update({'status': newStatus});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status updated to $newStatus')));
      }
    } catch (e) {
      debugLog('Error updating complaint: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

// OldViewComplaintsAdminPage removed - replaced by refactored ViewComplaintsAdminPage

