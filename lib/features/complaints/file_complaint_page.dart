part of '../../app/app.dart';

class FileComplaintPage extends StatefulWidget {
  const FileComplaintPage({Key? key}) : super(key: key);

  @override
  State<FileComplaintPage> createState() => _FileComplaintPageState();
}

class _FileComplaintPageState extends State<FileComplaintPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

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
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      // Validate file type
      final ext = image.path.split('.').last.toLowerCase();
      final allowedExtensions = ['jpg', 'jpeg', 'png', 'gif'];
      
      if (!allowedExtensions.contains(ext)) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Invalid File Type'),
              content: const Text('The uploaded file type is not supported. Please upload an image file (JPG, PNG, or GIF).'),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      final imageFile = File(image.path);
      
      // Always compress images for upload to ensure they're under 2MB
      // This prevents upload failures for large images
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Processing image...')),
        );
      }
      
      final compressedFile = await ImageCompressionHelper.compressForUpload(imageFile);
      if (compressedFile != null) {
        setState(() => _selectedImage = compressedFile);
        if (mounted) {
          final finalSize = await compressedFile.length();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Image ready (${(finalSize / 1024).toStringAsFixed(0)}KB)')),
          );
        }
      } else {
        // If compression failed, show error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to process image. Please try a different image.')),
          );
        }
      }
    }
  }

  Future<void> _submitComplaint() async {
    if (_subjectController.text.isEmpty || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    // Enforce per-day complaint limit
    try {
      final uid = AuthService.currentUser!.uid;
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final recent = await FirebaseFirestore.instance.collection('complaints')
        .where('userId', isEqualTo: uid)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .get();
      if (recent.docs.length >= MAX_COMPLAINTS_PER_DAY) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('You have reached the daily complaint limit ($MAX_COMPLAINTS_PER_DAY).')));
        return;
      }
    } catch (e) {
      debugLog('Error checking complaint quota: $e');
    }

    final barangay = await AuthService.waitForBarangay();
    if (barangay == null || barangay.isEmpty) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your barangay is not yet available. Please try again later.')));
      return;
    }

    setState(() => _isLoading = true);

    String? imageUrl;
    if (_selectedImage != null) {
      try {
        // Show uploading indicator
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Uploading image...')),
          );
        }
        
        // Add timeout to prevent hanging
        imageUrl = await AuthService.uploadImage(_selectedImage!, 'complaints/${DateTime.now().millisecondsSinceEpoch}.jpg')
            .timeout(
              const Duration(seconds: 30), // 30 second timeout
              onTimeout: () {
                debugLog('Image upload timed out after 30 seconds');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Image upload timed out. Submitting complaint without image.')),
                  );
                }
                return null;
              },
            );
            
        if (imageUrl == null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload image. Submitting complaint without image.')),
          );
        } else if (imageUrl != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image uploaded successfully!')),
          );
        }
      } catch (e) {
        debugLog('Error uploading complaint image: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error uploading image. Submitting complaint without image.')),
          );
        }
      }
    }

    await FirebaseFirestore.instance.collection('complaints').add({
      'userId': AuthService.currentUser!.uid,
      'subject': _subjectController.text,
      'description': _descriptionController.text,
      'imageUrl': imageUrl,
      'status': 'Pending',
      'barangay': barangay,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await NotificationService.addNotification(
      AuthService.currentUser!.uid,
      'Complaint Received',
      'Your complaint has been submitted and is being reviewed',
    );

    setState(() => _isLoading = false);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: EdgeInsets.zero,
          content: Container(
            width: 320,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.campaign_outlined,
                    size: 64,
                    color: Color(0xFFFF6B35),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Complaint Received!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Your complaint has been submitted and is being reviewed by barangay officials.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.access_time, color: Colors.white70, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'We\'ll notify you of updates',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'DONE',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaints'),
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
            Tab(text: 'File Complaint', icon: Icon(Icons.edit_note_outlined)),
            Tab(text: 'Status', icon: Icon(Icons.query_stats_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFileComplaintTab(),
          _buildComplaintStatusTab(),
        ],
      ),
    );
  }

  Widget _buildFileComplaintTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          TextFormField(
            controller: _subjectController,
            decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
            maxLines: 5,
          ),
          const SizedBox(height: 16),
          if (_selectedImage != null)
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.file(_selectedImage!, fit: BoxFit.cover),
            ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.camera_alt),
            label: Text(_selectedImage == null ? 'Add Photo Evidence' : 'Change Photo'),
          ),
          const SizedBox(height: 24),
          _isLoading
              ? const CircularProgressIndicator()
              : ElevatedButton(
            onPressed: _submitComplaint,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 60)),
            child: const Text('SUBMIT'),
          ),
        ],
      ),
    );
  }

  Widget _buildComplaintStatusTab() {
    final uid = AuthService.currentUser?.uid;
    
    if (uid == null) {
      return const Center(child: Text('Please log in to view your complaints'));
    }

    // Auto-cleanup old resolved complaints when tab is loaded
    _cleanupOldResolvedComplaints(uid);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('complaints')
          .where('userId', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final allComplaints = snapshot.data?.docs ?? [];
        
        // Filter out resolved complaints older than 7 days
        final now = DateTime.now();
        final complaints = allComplaints.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] as String? ?? 'Pending').toLowerCase();
          final timestamp = data['timestamp'] as Timestamp?;
          
          // Keep all non-resolved complaints
          if (status != 'resolved') return true;
          
          // For resolved complaints, check if they're within 7 days
          if (timestamp == null) return true;
          final complaintDate = timestamp.toDate();
          final daysSinceResolved = now.difference(complaintDate).inDays;
          
          // Keep only if less than 7 days old
          return daysSinceResolved < 7;
        }).toList();

        if (complaints.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.report_problem_outlined, size: 64, color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey),
                const SizedBox(height: 16),
                Text('No complaints filed yet', style: TextStyle(fontSize: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: complaints.length,
          itemBuilder: (context, index) {
            final complaint = complaints[index];
            final data = complaint.data() as Map<String, dynamic>;
            final subject = data['subject'] as String? ?? 'N/A';
            final description = data['description'] as String? ?? '';
            final status = data['status'] as String? ?? 'Pending';
            final timestamp = data['timestamp'] as Timestamp?;
            final imageUrl = data['imageUrl'] as String?;
            
            final dateStr = timestamp != null
                ? '${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year}'
                : 'N/A';

            // Determine status color and icon
            Color statusColor;
            IconData statusIcon;
            String statusLabel = status;
            
            switch (status.toLowerCase()) {
              case 'pending':
                statusColor = Colors.orange;
                statusIcon = Icons.hourglass_empty;
                statusLabel = 'Pending Review';
                break;
              case 'under review':
                statusColor = Colors.blue;
                statusIcon = Icons.preview;
                statusLabel = 'Under Review';
                break;
              case 'resolved':
                statusColor = Colors.green;
                statusIcon = Icons.check_circle;
                statusLabel = 'Resolved';
                break;
              case 'rejected':
              case 'invalid':
                statusColor = Colors.red;
                statusIcon = Icons.cancel;
                statusLabel = 'Rejected/Invalid';
                break;
              default:
                statusColor = Colors.grey;
                statusIcon = Icons.info;
                statusLabel = status;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            subject,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: statusColor, width: 1.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 16, color: statusColor),
                              const SizedBox(width: 6),
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Filed: $dateStr',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7) ?? Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    if (description.isNotEmpty) ...[
                      Text(
                        description,
                        style: const TextStyle(fontSize: 13),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (imageUrl != null && imageUrl.isNotEmpty) ...[
                      GestureDetector(
                        onTap: () {
                          // Show full-screen image
                          showDialog(
                            context: context,
                            builder: (context) => Dialog(
                              backgroundColor: Colors.transparent,
                              child: Stack(
                                children: [
                                  Center(
                                    child: InteractiveViewer(
                                      child: buildImageFromUrl(imageUrl),
                                    ),
                                  ),
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            height: 150,
                            width: double.infinity,
                            child: buildImageFromUrl(imageUrl, fit: BoxFit.cover),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ID: ${complaint.id.substring(0, 8)}...',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                        if (status.toLowerCase() == 'pending')
                          TextButton.icon(
                            onPressed: () => _showDeleteConfirmation(context, complaint),
                            icon: const Icon(Icons.delete, size: 18),
                            label: const Text('Delete'),
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
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

  // Auto-cleanup resolved complaints older than 7 days
  Future<void> _cleanupOldResolvedComplaints(String uid) async {
    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final querySnapshot = await FirebaseFirestore.instance
          .collection('complaints')
          .where('userId', isEqualTo: uid)
          .where('status', isEqualTo: 'Resolved')
          .get();

      for (var doc in querySnapshot.docs) {
        final timestamp = doc.data()['timestamp'] as Timestamp?;
        if (timestamp != null) {
          final complaintDate = timestamp.toDate();
          if (complaintDate.isBefore(sevenDaysAgo)) {
            await doc.reference.delete();
            debugLog('[Cleanup] Deleted old resolved complaint: ${doc.id}');
          }
        }
      }
    } catch (e) {
      debugLog('[Cleanup] Error cleaning up old complaints: $e');
    }
  }

  void _showDeleteConfirmation(BuildContext context, QueryDocumentSnapshot complaint) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted = theme.colorScheme.onSurfaceVariant;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text(
          'Delete Complaint?',
          style: TextStyle(color: onSurface, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to delete this complaint? This action cannot be undone.',
          style: TextStyle(color: muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: onSurface),
            child: const Text('Keep'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await complaint.reference.delete();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Complaint deleted')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            icon: const Icon(Icons.delete, size: 18),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}


