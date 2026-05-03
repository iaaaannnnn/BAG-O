part of '../../app/app.dart';

class PostAnnouncementPage extends StatefulWidget {
  const PostAnnouncementPage({Key? key}) : super(key: key);

  @override
  State<PostAnnouncementPage> createState() => _PostAnnouncementPageState();
}

class _PostAnnouncementPageState extends State<PostAnnouncementPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _locationController = TextEditingController();
  bool _isLoading = false;
  List<PlatformFile> _pickedFiles = [];
  final FilePicker _filePicker = FilePicker.platform;
  String _type = 'Announcement'; // 'Announcement' or 'Event'
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

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
    _titleController.dispose();
    _contentController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  String _formatEventDate(dynamic eventDate) {
    if (eventDate is Timestamp) {
      final dateTime = eventDate.toDate();
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
    return 'Date not available';
  }

  Future<void> _archiveAnnouncement(String docId, Map<String, dynamic> data) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Archive Announcement'),
        content: const Text('Are you sure you want to archive this announcement? It will be hidden from public view but can be restored later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Theme.of(context).colorScheme.onSecondary,
            ),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        debugLog('Archiving announcement: $docId');
        await FirebaseFirestore.instance.collection('announcements').doc(docId).update({
          'archived': true,
          'archivedAt': FieldValue.serverTimestamp(),
        });
        debugLog('Announcement archived successfully: $docId');

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Announcement archived successfully')),
          );
        }
      } catch (e) {
        debugLog('Error archiving announcement: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to archive announcement')),
          );
        }
      }
    }
  }

  Future<void> _restoreAnnouncement(String docId, Map<String, dynamic> data) async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Restore Announcement'),
        content: const Text('Are you sure you want to restore this announcement? It will be visible to the public again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('announcements').doc(docId).update({
          'archived': false,
          'restoredAt': FieldValue.serverTimestamp(),
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Announcement restored successfully')),
          );
        }
      } catch (e) {
        debugLog('Error restoring announcement: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to restore announcement')),
          );
        }
      }
    }
  }

  Future<void> _deleteAnnouncement(String docId, Map<String, dynamic> data) async {
    final colorScheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Announcement'),
        content: const Text('Are you sure you want to delete this announcement? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        debugLog('Deleting announcement: $docId');
        await FirebaseFirestore.instance.collection('announcements').doc(docId).delete();
        debugLog('Announcement deleted successfully: $docId');

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Announcement deleted successfully')),
          );
        }
      } catch (e) {
        debugLog('Error deleting announcement: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete announcement')),
          );
        }
      }
    }
  }

  Future<void> _deleteAllAnnouncements() async {
    final barangay = await AuthService.waitForBarangay();
    if (barangay == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete All Announcements'),
        content: const Text('Are you sure you want to delete ALL announcements and events? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('announcements')
            .where('barangay', isEqualTo: barangay)
            .get();

        for (var doc in snapshot.docs) {
          final data = doc.data();
          final attachmentUrls = data['attachmentUrls'] as List<dynamic>? ?? [];
          if (data['imageUrl'] != null) {
            attachmentUrls.add(data['imageUrl']);
          }

          for (var url in attachmentUrls) {
            try {
              final ref = FirebaseStorage.instance.refFromURL(url as String);
              await ref.delete();
            } catch (e) {
              debugLog('Error deleting attachment: $e');
            }
          }

          await doc.reference.delete();
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All announcements deleted successfully')),
          );
        }
      } catch (e) {
        debugLog('Error deleting all announcements: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete announcements')),
          );
        }
      }
    }
  }

  Future<void> _post() async {
    if (_titleController.text.trim().isEmpty || _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and content are required')),
      );
      return;
    }

    if (_type == 'Event' && (_selectedDate == null || _selectedTime == null || _locationController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Date, time, and location are required for events')),
      );
      return;
    }

    final barangay = await AuthService.waitForBarangay();
    if (barangay == null || barangay.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your barangay is not yet available. Please try again later.')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    List<String> attachmentUrls = [];
    if (_pickedFiles.isNotEmpty) {
      for (var file in _pickedFiles) {
        try {
          // Validate file size for officials
          final fileSize = file.size;
          if (fileSize > ImageCompressionHelper.maxDocumentSizeBytes) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showMaterialBanner(
                MaterialBanner(
                  content: Text(
                    'File "${file.name}" is too large: ${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB (max 10MB)\n\nPlease select smaller files.',
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.red.shade700,
                  actions: [
                    TextButton(
                      onPressed: () => ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
                      child: const Text('OK', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
              
              // Auto-hide after 5 seconds
              Future.delayed(const Duration(seconds: 5), () {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                }
              });
            }
            setState(() => _isLoading = false);
            return;
          }

          if (file.bytes != null) {
            // For web platform
            final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
            final ref = FirebaseStorage.instance.ref().child('announcements/$fileName');
            await ref.putData(file.bytes!);
            final url = await ref.getDownloadURL();
            attachmentUrls.add(url);
          } else if (file.path != null) {
            // For mobile/desktop platforms
            final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
            
            // Check if it's an image file and compress if needed
            final ext = file.name.split('.').last.toLowerCase();
            final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
            
            File fileToUpload = File(file.path!);
            if (isImage) {
              // Compress image for reliable upload
              final compressedFile = await ImageCompressionHelper.compressForUpload(fileToUpload);
              if (compressedFile != null) {
                fileToUpload = compressedFile;
              }
            }
            
            final url = await AuthService.uploadImage(
              fileToUpload,
              'announcements/$fileName',
            );
            if (url != null) {
              attachmentUrls.add(url);
            }
          }
        } catch (e) {
          debugLog('Error processing attachment ${file.name}: $e');
        }
      }
    }

    final data = {
      'title': _titleController.text.trim(),
      'content': _contentController.text.trim(),
      'attachmentUrls': attachmentUrls,
      'barangay': barangay,
      'type': _type,
      'timestamp': FieldValue.serverTimestamp(),
    };

    if (_type == 'Event') {
      final eventDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );
      data['eventDate'] = Timestamp.fromDate(eventDateTime);
      data['location'] = _locationController.text.trim();
    }

    await FirebaseFirestore.instance.collection('announcements').add(data);
    setState(() => _isLoading = false);
    if (context.mounted) {
      final colorScheme = Theme.of(context).colorScheme;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: Icon(
            _type == 'Event' ? Icons.event_available : Icons.campaign,
            size: 48,
            color: colorScheme.primary,
          ),
          title: Text(
            '$_type Posted!',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          content: Text(
            'Your $_type has been successfully posted and is now visible to all residents.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    // Dynamic surface color based on theme
    final surfaceColor = isDark 
        ? colorScheme.surfaceContainerHighest 
        : colorScheme.surfaceContainerLowest;
    final cardColor = isDark 
        ? colorScheme.surfaceContainer 
        : colorScheme.surface;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Events and Announcements'),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          if (_tabController.index == 1) // Show trash icon only on Manage tab
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Tooltip(
                message: 'Delete all announcements and events',
                child: IconButton(
                  onPressed: _deleteAllAnnouncements,
                  icon: const Icon(Icons.delete_sweep),
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          tabAlignment: TabAlignment.fill,
          tabs: const [
            Tab(text: 'Create', icon: Icon(Icons.add_box_outlined)),
            Tab(text: 'Manage', icon: Icon(Icons.tune_outlined)),
            Tab(text: 'Archived', icon: Icon(Icons.inventory_2_outlined)),
          ],
          indicatorColor: colorScheme.onPrimary,
          labelColor: colorScheme.onPrimary,
          unselectedLabelColor: colorScheme.onPrimary.withValues(alpha: 0.72),
          dividerColor: Colors.transparent,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Create Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Type selector using SegmentedButton (Material3)
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'Announcement',
                      label: Text('Announcement'),
                      icon: Icon(Icons.campaign_outlined),
                    ),
                    ButtonSegment(
                      value: 'Event',
                      label: Text('Event'),
                      icon: Icon(Icons.event_outlined),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() => _type = newSelection.first);
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.comfortable,
                    backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.selected)) {
                        return colorScheme.primary;
                      }
                      return Colors.white;
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.white;
                      }
                      return Colors.black87;
                    }),
                  ),
                ),
                const SizedBox(height: 24),

            // Title field
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                hintText: 'Enter a title for your ${_type.toLowerCase()}',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF228B22), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
            const SizedBox(height: 16),

            // Content field
            TextField(
              controller: _contentController,
              decoration: InputDecoration(
                labelText: 'Content',
                hintText: 'Write the details here...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF228B22), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              maxLines: 6,
              minLines: 4,
            ),
            const SizedBox(height: 16),

            // Event-specific fields
            if (_type == 'Event') ...[
              // Date and Time in a Card
              Card(
                elevation: 0,
                color: cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    // Date picker
                    ListTile(
                      leading: Icon(Icons.calendar_today_outlined, color: colorScheme.primary),
                      title: Text(
                        _selectedDate == null
                            ? 'Select Date'
                            : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                        style: TextStyle(
                          color: _selectedDate == null 
                              ? colorScheme.onSurfaceVariant 
                              : colorScheme.onSurface,
                        ),
                      ),
                      trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
                      onTap: _selectDate,
                      shape: RoundedRectangleBorder(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                    ),
                    Divider(height: 1, indent: 16, endIndent: 16, color: colorScheme.outline.withOpacity(0.2)),
                    // Time picker
                    ListTile(
                      leading: Icon(Icons.access_time_outlined, color: colorScheme.primary),
                      title: Text(
                        _selectedTime == null
                            ? 'Select Time'
                            : '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: _selectedTime == null 
                              ? colorScheme.onSurfaceVariant 
                              : colorScheme.onSurface,
                        ),
                      ),
                      trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
                      onTap: _selectTime,
                      shape: RoundedRectangleBorder(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Location field
              TextField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'Location',
                  hintText: 'Where will the event take place?',
                  prefixIcon: Icon(Icons.location_on_outlined, color: colorScheme.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF228B22), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Attachments section
            Card(
              elevation: 0,
              color: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Attachment previews
                  if (_pickedFiles.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _pickedFiles.map((file) {
                          final isImage = file.extension?.toLowerCase() == 'jpg' || 
                                        file.extension?.toLowerCase() == 'jpeg' || 
                                        file.extension?.toLowerCase() == 'png' ||
                                        file.extension?.toLowerCase() == 'gif';
                          
                          return Chip(
                            label: Text(
                              file.name,
                              style: const TextStyle(fontSize: 12),
                            ),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () {
                              setState(() {
                                _pickedFiles.remove(file);
                              });
                            },
                            backgroundColor: colorScheme.surfaceContainerHighest,
                          );
                        }).toList(),
                      ),
                    ),
                    Divider(height: 1, color: colorScheme.outline.withOpacity(0.2)),
                  ],
                  // Attachment button
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final result = await _filePicker.pickFiles(
                                allowMultiple: true,
                                type: FileType.custom,
                                allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'pdf', 'doc', 'docx', 'xls', 'xlsx'],
                              );
                              if (result != null) {
                                setState(() {
                                  _pickedFiles.addAll(result.files);
                                });
                              }
                            },
                            icon: Icon(
                              _pickedFiles.isEmpty ? Icons.attach_file : Icons.add,
                            ),
                            label: Text(_pickedFiles.isEmpty ? 'Add Attachments' : 'Add More Files'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primaryContainer,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        if (_pickedFiles.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: () => setState(() => _pickedFiles.clear()),
                            icon: const Icon(Icons.clear_all),
                            style: IconButton.styleFrom(
                              backgroundColor: colorScheme.error,
                              foregroundColor: colorScheme.onError,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submit button - Tonal style (no bright fill)
            SizedBox(
              height: 48,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _post,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.send_outlined),
                          const SizedBox(width: 8),
                          Text(
                            'Post ${_type}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),

          // Manage Tab
          FutureBuilder<String?>(
            future: AuthService.waitForBarangay(),
            builder: (context, barangaySnapshot) {
              if (barangaySnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final barangay = barangaySnapshot.data;
              if (barangay == null) {
                return const Center(
                  child: Text('Unable to load barangay information'),
                );
              }

              return Column(
                children: [
                  // Announcements List
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('announcements')
                          .where('barangay', isEqualTo: barangay)
                          .orderBy('timestamp', descending: true)
                          .snapshots()
                          .map((snapshot) {
                            // Filter out archived announcements client-side
                            final filteredDocs = snapshot.docs.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return data['archived'] != true;
                            }).toList();
                            // Create a new QuerySnapshot-like object with filtered docs
                            return snapshot;
                          }),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        // Filter archived items client-side
                        final allDocs = snapshot.data?.docs ?? [];
                        final filteredDocs = allDocs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return data['archived'] != true;
                        }).toList();
                        
                        if (filteredDocs.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('No announcements or events yet'),
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredDocs.length,
                          itemBuilder: (context, index) {
                            final doc = filteredDocs[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final type = (data['type'] as String?) ?? 'Announcement';
                            final isEvent = type == 'Event';
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Dismissible(
                                key: Key(doc.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.only(left: 20),
                                  color: const Color(0xFF228B22),
                                  child: Icon(
                                    Icons.archive,
                                    color: colorScheme.onPrimary,
                                  ),
                                ),
                                secondaryBackground: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  color: colorScheme.error,
                                  child: Icon(
                                    Icons.delete,
                                    color: colorScheme.onError,
                                  ),
                                ),
                                confirmDismiss: (direction) async {
                                  if (direction == DismissDirection.endToStart) {
                                    // Delete action
                                    await _deleteAnnouncement(doc.id, data);
                                    return false;
                                  }
                                  return false;
                                },
                                onResize: () {
                                  // Called when the widget is swiped
                                  // We can use this to distinguish between archive (left) and delete (right)
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
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
                                                              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : null,
                                                            ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Tooltip(
                                                message: 'Archive',
                                                child: IconButton(
                                                  onPressed: () => _archiveAnnouncement(doc.id, data),
                                                  icon: const Icon(Icons.archive),
                                                  color: const Color(0xFF228B22),
                                                  iconSize: 20,
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                                ),
                                              ),
                                              Tooltip(
                                                message: 'Delete',
                                                child: IconButton(
                                                  onPressed: () => _deleteAnnouncement(doc.id, data),
                                                  icon: const Icon(Icons.delete),
                                                  color: colorScheme.error,
                                                  iconSize: 20,
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      if (isEvent && data['eventDate'] != null) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                            const SizedBox(width: 6),
                                            Text(
                                              _formatEventDate(data['eventDate']),
                                              style: Theme.of(context).textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                        if (data['location'] != null) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  data['location'],
                                                  style: Theme.of(context).textTheme.bodySmall,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                      const SizedBox(height: 8),
                                      Text(
                                        data['content'] ?? '',
                                        style: Theme.of(context).textTheme.bodySmall,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if ((data['attachmentUrls'] as List<dynamic>?)?.isNotEmpty == true || data['imageUrl'] != null) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(Icons.attach_file, size: 14, color: Colors.grey),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${((data['attachmentUrls'] as List<dynamic>?)?.length ?? 0) + (data['imageUrl'] != null ? 1 : 0)} attachment(s)',
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: colorScheme.primary,
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
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          // Archived Tab
          FutureBuilder<String?>(
            future: AuthService.waitForBarangay(),
            builder: (context, barangaySnapshot) {
              if (barangaySnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final barangay = barangaySnapshot.data;
              if (barangay == null) {
                return const Center(
                  child: Text('Unable to load barangay information'),
                );
              }

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('announcements')
                    .where('barangay', isEqualTo: barangay)
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data?.docs ?? [];
                  // Filter archived client-side to also catch records missing the field in queries
                  final archivedDocs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['archived'] == true;
                  }).toList();
                  debugLog('Archived announcements snapshot (filtered): ${archivedDocs.length} docs');

                  if (archivedDocs.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No archived announcements'),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: archivedDocs.length,
                    itemBuilder: (context, index) {
                      final doc = archivedDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final type = (data['type'] as String?) ?? 'Announcement';
                      final isEvent = type == 'Event';
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
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
                                                              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : null,
                                                            ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _restoreAnnouncement(doc.id, data),
                                    icon: const Icon(Icons.restore),
                                    color: colorScheme.primary,
                                  ),
                                ],
                              ),
                              if (isEvent && data['eventDate'] != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Text(
                                      _formatEventDate(data['eventDate']),
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                data['content'] ?? '',
                                style: Theme.of(context).textTheme.bodyMedium,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.access_time, size: 14, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatTimestamp(data['timestamp']),
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey,
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
            },
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      final ts = timestamp as Timestamp;
      final date = ts.toDate();
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return 'Unknown';
    }
  }
}


