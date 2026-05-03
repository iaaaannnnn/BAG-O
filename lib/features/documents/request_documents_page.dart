part of '../../app/app.dart';

class RequestDocumentsPage extends StatefulWidget {
  const RequestDocumentsPage({Key? key}) : super(key: key);

  @override
  State<RequestDocumentsPage> createState() => _RequestDocumentsPageState();
}

class _RequestDocumentsPageState extends State<RequestDocumentsPage> with SingleTickerProviderStateMixin {
  String? _userBarangay;
  bool _loadingBarangay = true;
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  String? _editingDocId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      animationDuration: const Duration(milliseconds: 380),
    );
      
    _loadBarangay();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isOfficial = AuthService.userType == 'Barangay Official';
    
    // Default documents as fallback for residents/guests
    final defaultDocuments = [
      'Barangay Clearance',
      'Certificate of Residency',
      'Certificate of Indigency',
      'Business Clearance',
      'Certificate of Good Moral Character',
      'General Barangay Certificate',
      'Blotter / Incident Certification',
    ];
    
    if (_loadingBarangay) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Request Documents'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_userBarangay == null || _userBarangay!.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Request Documents'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.info_outline, size: 64, color: Colors.orange),
                const SizedBox(height: 16),
                const Text('Unable to load barangay information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
        title: const Text('Request Documents'),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
        bottom: isOfficial
            ? TabBar(
                controller: _tabController,
                isScrollable: false,
                tabAlignment: TabAlignment.fill,
                labelColor: theme.colorScheme.onPrimary,
                unselectedLabelColor: theme.colorScheme.onPrimary.withValues(alpha: 0.72),
                indicatorColor: theme.colorScheme.onPrimary,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Request', icon: Icon(Icons.description_outlined)),
                  Tab(text: 'Manage Types', icon: Icon(Icons.tune_outlined)),
                ],
              )
            : null,
      ),
      body: isOfficial
          ? TabBarView(
              controller: _tabController,
              children: [
                _buildRequestDocumentsTab(defaultDocuments),
                _buildManageDocTypesTab(),
              ],
            )
          : _buildRequestDocumentsTab(defaultDocuments),
      
    );
  }

  

  Widget _buildRequestDocumentsTab(List<String> defaultDocuments) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isOfficialView = AuthService.userType == 'Barangay Official';

    // For residents/guests: always show the hardcoded default documents
    if (!isOfficialView) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: defaultDocuments.length,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description, color: Color(0xFF228B22)),
                title: Text(defaultDocuments[index]),
                subtitle: null,
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? theme.colorScheme.surface : const Color(0xFF228B22),
                    foregroundColor: isDark ? theme.colorScheme.onSurface : Colors.white,
                    side: isDark ? BorderSide(color: theme.colorScheme.outline) : null,
                  ),
                  onPressed: () => _submitRequest(context, defaultDocuments[index]),
                  child: const Text('Request'),
                ),
              ),
            ),
          );
        },
      );
    }

    // For officials: use Firestore stream
    final Stream<QuerySnapshot> docTypesStream = FirebaseFirestore.instance.collection('document_types').where('barangay', isEqualTo: _userBarangay).snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: docTypesStream,
      builder: (context, snapshot) {
        // Use Firestore document types only - no fallback to default documents
        // This avoids conflicts between hardcoded defaults and Firestore data
        List<QueryDocumentSnapshot> docSnapshots = [];
        List<String> documents = [];
        List<String> documentDescriptions = [];

        if (snapshot.hasError) {
          // Only use defaults if query fails (network error, timeout, etc.)
          debugLog('[RequestDocuments] Query error: ${snapshot.error}. Using defaults.');
          documents = defaultDocuments;
          documentDescriptions = List.filled(defaultDocuments.length, '');
        } else if (snapshot.hasData) {
          var docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            // No document types configured for this barangay
            // For officials: show empty state prompting configuration
            // For residents/guests: fall back to the defaultDocuments list
            if (isOfficialView) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.description_outlined, size: 64, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No document types available',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your barangay has not set up any document types yet.\nPlease contact your barangay officials.',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[500] : Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            } else {
              documents = defaultDocuments;
              documentDescriptions = List.filled(defaultDocuments.length, '');
            }
          }
          
          // Sort by name client-side
          docs.sort((a, b) {
            final nameA = (a.data() as Map<String, dynamic>)['name'] as String? ?? '';
            final nameB = (b.data() as Map<String, dynamic>)['name'] as String? ?? '';
            return nameA.compareTo(nameB);
          });

          docSnapshots = docs;
          documents = docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['name'] as String? ?? 'Unknown';
          }).toList();
          documentDescriptions = docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['description'] as String? ?? '';
          }).toList();
        } else {
          // Still loading
          return const Center(child: CircularProgressIndicator());
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: documents.length,
          itemBuilder: (context, index) {
            final docId = docSnapshots.isNotEmpty ? docSnapshots[index].id : null;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.description, color: Color(0xFF228B22)),
                      title: Text(documents[index]),
                      subtitle: documentDescriptions[index].isNotEmpty
                          ? Text(documentDescriptions[index], maxLines: 2, overflow: TextOverflow.ellipsis)
                          : null,
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? theme.colorScheme.surface : const Color(0xFF228B22),
                          foregroundColor: isDark ? theme.colorScheme.onSurface : Colors.white,
                          side: isDark ? BorderSide(color: theme.colorScheme.outline) : null,
                        ),
                        onPressed: () => _submitRequest(context, documents[index]),
                        child: const Text('Request'),
                      ),
                    ),
                    
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildManageDocTypesTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF228B22),
        foregroundColor: Colors.white,
        onPressed: () => _showAddEditDialog(context, _userBarangay ?? '', null),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('document_types')
            .where('barangay', isEqualTo: _userBarangay)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            debugLog('Document Types Error: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                  const SizedBox(height: 16),
                  Text('Error loading document types', style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          var docs = snapshot.data?.docs ?? [];
          
          // Sort by name client-side
          docs.sort((a, b) {
            final nameA = (a.data() as Map<String, dynamic>)['name'] as String? ?? '';
            final nameB = (b.data() as Map<String, dynamic>)['name'] as String? ?? '';
            return nameA.compareTo(nameB);
          });

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.description_outlined, size: 64, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No document types yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to add document types that residents can request',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
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
              final name = data['name'] ?? 'Untitled';
              final description = data['description'] ?? '';
              final isActive = data['isActive'] ?? true;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: isActive ? const Color(0xFF228B22).withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                    child: Icon(
                      Icons.description,
                      color: isActive ? const Color(0xFF228B22) : Colors.grey,
                    ),
                  ),
                  title: Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isActive ? theme.textTheme.bodyLarge?.color : Colors.grey,
                      decoration: isActive ? null : TextDecoration.lineThrough,
                    ),
                  ),
                  subtitle: description.isNotEmpty
                      ? Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7)),
                        )
                      : null,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _showAddEditDialog(context, _userBarangay ?? '', doc);
                          break;
                        
                        case 'toggle':
                          _toggleActive(doc.id, !isActive);
                          break;
                        case 'delete':
                          _confirmDelete(context, doc.id, name);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text('Edit')])),
                      
                      PopupMenuItem(
                        value: 'toggle',
                        child: Row(children: [
                          Icon(isActive ? Icons.visibility_off : Icons.visibility, size: 20),
                          const SizedBox(width: 8),
                          Text(isActive ? 'Disable' : 'Enable'),
                        ]),
                      ),
                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 20, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
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

  void _showAddEditDialog(BuildContext context, String barangay, DocumentSnapshot? doc) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    if (doc != null) {
      final data = doc.data() as Map<String, dynamic>;
      _nameController.text = data['name'] ?? '';
      _descriptionController.text = data['description'] ?? '';
      _editingDocId = doc.id;
    } else {
      _nameController.clear();
      _descriptionController.clear();
      _editingDocId = null;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: theme.colorScheme.surface,
        title: Row(
          children: [
            Icon(doc != null ? Icons.edit : Icons.add_circle, color: const Color(0xFF228B22)),
            const SizedBox(width: 8),
            Text(doc != null ? 'Edit Document Type' : 'Add Document Type'),
          ],
        ),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Document Name',
                  hintText: 'e.g., Barangay Clearance',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.description),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a document name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Brief description of this document',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.info_outline),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF228B22),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isLoading ? null : () => _saveDocumentType(ctx, barangay),
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(doc != null ? 'Update' : 'Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveDocumentType(BuildContext dialogContext, String barangay) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final data = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'barangay': barangay,
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_editingDocId != null) {
        await FirebaseFirestore.instance.collection('document_types').doc(_editingDocId).update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('document_types').add(data);
      }

      if (dialogContext.mounted) {
        Navigator.pop(dialogContext);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_editingDocId != null ? 'Document type updated' : 'Document type added')),
        );
      }
    } catch (e) {
      debugLog('Error saving document type: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleActive(String docId, bool newValue) async {
    try {
      await FirebaseFirestore.instance.collection('document_types').doc(docId).update({'isActive': newValue});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(newValue ? 'Document type enabled' : 'Document type disabled')),
        );
      }
    } catch (e) {
      debugLog('Error toggling document type: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _confirmDelete(BuildContext context, String docId, String name) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: theme.colorScheme.surface,
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Document Type'),
          ],
        ),
        content: Text('Are you sure you want to delete "$name"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await FirebaseFirestore.instance.collection('document_types').doc(docId).delete();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Document type deleted')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _submitRequest(BuildContext context, String documentName) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    try {
      // Ask for reason before submitting
      String? reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          final reasonController = TextEditingController();
          return AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            title: Text('Reason for request', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            content: TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'Enter reason',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              maxLines: 3,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('Cancel', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF228B22),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(dialogContext, reasonController.text.trim()),
                child: const Text('Submit'),
              ),
            ],
          );
        },
      );

      if (reason == null || reason.isEmpty) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request cancelled (reason required)')));
        return;
      }

      // Get user's barangay for filtering
      final uid = AuthService.currentUser!.uid;
      final userData = await AuthService.getUserData();
      final userBarangay = userData?['barangay'] as String? ?? '';
      final userName = userData?['name'] as String? ?? 'Unknown';

      // Enforce per-document per-day limit
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      try {
        final q = await FirebaseFirestore.instance.collection('requests')
          .where('userId', isEqualTo: uid)
          .where('subject', isEqualTo: documentName)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();
        if (q.docs.length >= MAX_REQUESTS_PER_DOC_PER_DAY) {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('You have reached the daily limit for $documentName ($MAX_REQUESTS_PER_DOC_PER_DAY).')));
          return;
        }
      } catch (quotaError) {
        debugLog('[Request] Warning: Could not check daily quota: $quotaError. Proceeding with submission.');
      }

      // Save request to Firestore - try user subcollection first, then top-level collection
      try {
        debugLog('[Request] Attempting to save request to users/$uid/requests...');
        await FirebaseFirestore.instance.collection('users').doc(uid).collection('requests').add({
          'subject': documentName,
          'reason': reason,
          'status': 'Pending',
          'approval': 'Pending',
          'barangay': userBarangay,
          'timestamp': FieldValue.serverTimestamp(),
        });
        debugLog('[Request] [OK] Saved to user subcollection');
      } catch (subcollectionError) {
        debugLog('[Request] Subcollection write failed: $subcollectionError. Proceeding with top-level save...');
      }

        // Always save to top-level collection so officials can see it in dashboard
        try {
          debugLog('[Request] Saving to top-level document_requests collection...');
          await FirebaseFirestore.instance.collection('document_requests').add({
            'userId': uid,
            'userName': userName,
            'subject': documentName,
            'reason': reason,
            'status': 'Pending',
            'approval': 'Pending',
            'barangay': userBarangay,
            'timestamp': FieldValue.serverTimestamp(),
          });
          debugLog('[Request] [OK] Saved to top-level document_requests collection');
        } catch (topLevelError) {
          debugLog('[Request] Error saving to top-level collection: $topLevelError');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Warning: Request may not be visible to officials: $topLevelError')));
          }
        }

      try {
        await NotificationService.addNotification(
          uid,
          'Request Submitted',
          'Your $documentName request has been submitted',
        );
      } catch (notifError) {
        debugLog('[Request] Warning: Failed to add notification: $notifError');
      }

      if (context.mounted) {
        _showSuccessDialog(context, documentName);
      }
    } catch (e) {
      debugLog('Error submitting request: $e');
      if (context.mounted) {
        final errorMsg = e.toString();
        final isPermissionDenied = errorMsg.contains('permission-denied') || 
                                   errorMsg.contains('PERMISSION_DENIED');
        
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            title: const Text('Request Submission Failed'),
            content: Text(
              isPermissionDenied
                ? 'Your request could not be submitted because you have not been approved by the barangay official yet. Please contact your barangay official to get approved before submitting requests.'
                : 'Failed to submit request: ${errorMsg.replaceFirst('Exception: ', '')}',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }
  
  void _showSuccessDialog(BuildContext context, String documentName) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final muted = theme.colorScheme.onSurfaceVariant;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        backgroundColor: isDark ? theme.colorScheme.surface : Colors.white,
        content: Container(
          width: 320,
          decoration: BoxDecoration(
            color: isDark ? theme.colorScheme.surface : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with icon
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 30),
                decoration: BoxDecoration(
                  color: isDark ? theme.colorScheme.surfaceContainerHighest : theme.colorScheme.surfaceVariant,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF228B22).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        size: 64,
                        color: Color(0xFF228B22),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Request Submitted!',
                      style: TextStyle(
                        color: onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'Your $documentName request has been successfully submitted.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: onSurface,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.hourglass_empty, color: muted, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Waiting for official review',
                          style: TextStyle(
                            color: muted,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF228B22),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'GOT IT',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
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
}


