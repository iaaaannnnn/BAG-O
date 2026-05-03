part of '../../app/app.dart';

class TransparencyPage extends StatefulWidget {
  const TransparencyPage({Key? key}) : super(key: key);

  @override
  State<TransparencyPage> createState() => _TransparencyPageState();
}

enum _TransparencyView { list, gridLarge }

class _TransparencyPageState extends State<TransparencyPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  _TransparencyView _view = _TransparencyView.gridLarge;
  String _sortBy = 'date';
  bool _sortAsc = false;
  bool _showSearch = false;
  String _searchQuery = '';
  Timer? _searchDebounce;
  List<QueryDocumentSnapshot> _cachedDocs = const [];

  Future<bool> _launchWithFallback(Uri uri, {String? debugInfo}) async {
    debugLog('[Transparency] Attempting to launch: ${uri.toString().substring(0, uri.toString().length > 100 ? 100 : uri.toString().length)}...');
    
    // Try in-app first, then external, then default.
    for (final mode in const [
      LaunchMode.externalApplication,
      LaunchMode.platformDefault,
      LaunchMode.inAppBrowserView,
    ]) {
      try {
        debugLog('[Transparency] Trying mode: $mode');
        final ok = await launchUrl(uri, mode: mode);
        if (ok) {
          debugLog('[Transparency] Successfully launched with mode: $mode');
          return true;
        }
      } catch (e) {
        debugLog('[Transparency] Failed with mode $mode: $e');
        // Try next mode
      }
    }
    debugLog('[Transparency] All launch attempts failed. ${debugInfo ?? ""}');
    return false;
  }
  String? _barangay;
  bool _loadingBarangay = true;
  String? _barangayError;

  @override
  void initState() {
    super.initState();
    _loadBarangay();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadBarangay() async {
    setState(() {
      _loadingBarangay = true;
      _barangayError = null;
    });

    try {
      final b = await AuthService.waitForBarangay();
      if (!mounted) return;
      setState(() {
        _barangay = b;
        _loadingBarangay = false;
        if (b == null || b.isEmpty) {
          _barangayError = 'Barangay information not available.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingBarangay = false;
        _barangayError = 'Failed to load barangay information.';
      });
    }
  }

  String? _contentTypeFromExt(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'xls':
      case 'xlsx':
        return 'application/vnd.ms-excel';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      default:
        return 'application/octet-stream';
    }
  }

  Future<String?> _uploadFile(BuildContext context) async {
    final userId = AuthService.currentUser?.uid;
    final barangay = _barangay ?? '';

    if (barangay.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Barangay not loaded. Please try again.')),
        );
      }
      return null;
    }
    
    debugLog('[Transparency] Starting upload - userId: $userId, barangay: $barangay');
    
    // Rate limiting: 2 uploads per minute (30 second throttle)
    if (!ThrottleHelper.canExecute('transparency_upload', 30000)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please wait at least 30 seconds before uploading another document')),
          );
        }
        return null;
      }

      try {
        // Use file_picker with custom extensions and enforce document-only uploads
        final allowedExts = ['pdf', 'docx', 'doc', 'xlsx', 'xls', 'csv'];
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: allowedExts,
          withData: true,
        );

        if (result == null || result.files.isEmpty) return null;

        final picked = result.files.first;
        final fileName = picked.name;
        final ext = (fileName.split('.').last).toLowerCase();

        if (!allowedExts.contains(ext)) {
          if (context.mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Unsupported File Type'),
                content: Text('Only documents are allowed.\n\nSupported formats: ${allowedExts.join(", ")}'),
                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
              ),
            );
          }
          return null;
        }

        final fileBytes = picked.bytes;
        if (fileBytes == null) return null;

        // Validate file size using bytes (avoid non-existent file path errors)
        final maxSize = ImageCompressionHelper.maxDocumentSizeBytes; // 10 MB
        if (fileBytes.length > maxSize) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showMaterialBanner(
              MaterialBanner(
                content: const Text(
                  'Document too large: Maximum 10MB allowed\n\nPlease select a smaller file.',
                  style: TextStyle(color: Colors.white),
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
          return null;
        }

        // Convert file to base64 and store directly in Firestore (FREE!)
        final base64Data = base64Encode(fileBytes);
        
        debugLog('[Transparency] Uploading file: $fileName ($ext)');
        
        // Save file data as base64 string in Firestore with userId field
        final docRef = await FirebaseFirestore.instance.collection('transparency_docs').add({
          'fileName': fileName,
          'fileData': base64Data, // Store file as base64
          'fileSize': fileBytes.length,
          'uploadDate': FieldValue.serverTimestamp(),
          'uploadedBy': userId ?? 'unknown',
          'userId': userId ?? 'unknown', // Add explicit userId for permission check
          'barangay': barangay,
          'fileType': ext,
          // Legacy field names for backward compatibility
          'title': fileName,
          'timestamp': FieldValue.serverTimestamp(),
          'type': ext,
        }).timeout(const Duration(seconds: 10));

        debugLog('[Transparency] Upload successful: ${docRef.id}');
        return 'embedded'; // Return indicator that file is embedded
    } catch (e) {
      debugLog('[Transparency] Upload error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: ${e.toString()}')),
        );
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOfficial = AuthService.userType == 'Barangay Official';
    final barangay = _barangay ?? '';

    if (_loadingBarangay) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transparency Documents')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_barangayError != null || barangay.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transparency Documents')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_barangayError ?? 'Barangay not loaded', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadBarangay,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _searchFocusNode.unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Transparency Documents'),
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        floatingActionButton: isOfficial
            ? FloatingActionButton(
              onPressed: () async {
                try {
                  final res = await _uploadFile(context);
                  if (res != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File uploaded')));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: ${e.toString()}')));
                  }
                }
              },
              child: const Icon(Icons.upload_file),
            )
          : null,
      body: barangay.isNotEmpty
        ? StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('transparency_docs')
                .where('barangay', isEqualTo: barangay)
                .orderBy('uploadDate', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                _cachedDocs = snapshot.data!.docs;
              }

              if (snapshot.connectionState == ConnectionState.waiting && _cachedDocs.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                debugLog('Error loading transparency docs: ${snapshot.error}');
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.error_outline, size: 48, color: Colors.red),
                      SizedBox(height: 16),
                      Text('An error occurred while loading documents.')
                    ],
                  ),
                );
              }

              final docs = _cachedDocs;
              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.article, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No transparency documents found.')
                    ],
                  ),
                );
              }

              final filteredDocs = _applySearchAndSort(docs);

              return Column(
                children: [
                  _buildTransparencyControls(),
                  Expanded(
                    child: filteredDocs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.search_off, size: 48, color: Colors.grey),
                                const SizedBox(height: 12),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'No documents match your filters.'
                                      : 'No documents found for "$_searchQuery".',
                                ),
                              ],
                            ),
                          )
                        : _view == _TransparencyView.list
                        ? ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredDocs.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final doc = filteredDocs[index];
                              final data = doc.data() as Map<String, dynamic>;
                              final ts = data['uploadDate'] as Timestamp? ?? data['timestamp'] as Timestamp?;
                              final dateStr = ts != null ? ts.toDate().toString().split(' ').first : 'Unknown';
                              final title = data['fileName'] as String? ?? data['title'] as String? ?? 'Untitled';
                              final fileSize = data['fileSize'] as int?;
                              final fileSizeStr = fileSize != null ? '${(fileSize / 1024).toStringAsFixed(1)} KB' : 'Unknown size';
                              final fileType = (data['fileType'] as String? ?? 'pdf').toLowerCase();
                              final base64Data = data['fileData'] as String?;
                              final url = data['fileUrl'] as String? ?? data['url'] as String?;

                              return Card(
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: _colorForFileType(fileType),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(_iconForFileType(fileType), size: 24, color: _iconForegroundForFileType(fileType)),
                                  ),
                                  title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                                  subtitle: Text('$dateStr | $fileSizeStr', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isOfficial)
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 20),
                                          color: Colors.red,
                                          tooltip: 'Delete',
                                          onPressed: () => _confirmDelete(context, doc, title),
                                        ),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                  onTap: () => _openDocument(context, title, fileType, base64Data, url),
                                ),
                              );
                            },
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 0.75,
                            ),
                            itemCount: filteredDocs.length,
                            itemBuilder: (context, index) {
                              final doc = filteredDocs[index];
                              final data = doc.data() as Map<String, dynamic>;
                              final ts = data['uploadDate'] as Timestamp? ?? data['timestamp'] as Timestamp?;
                              final dateStr = ts != null ? ts.toDate().toString().split(' ').first : 'Unknown';
                              final title = data['fileName'] as String? ?? data['title'] as String? ?? 'Untitled';
                              final fileSize = data['fileSize'] as int?;
                              final fileSizeStr = fileSize != null ? '${(fileSize / 1024).toStringAsFixed(1)} KB' : 'Unknown size';
                              final fileType = (data['fileType'] as String? ?? 'pdf').toLowerCase();
                              final base64Data = data['fileData'] as String?;
                              final url = data['fileUrl'] as String? ?? data['url'] as String?;

                              return Card(
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () => _openDocument(context, title, fileType, base64Data, url),
                                  child: Stack(
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            child: Container(
                                              decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[100]),
                                              child: _buildFileThumbnail(fileType, base64Data),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  title,
                                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(dateStr, style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color)),
                                                Text(fileSizeStr, style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (isOfficial)
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: Material(
                                            color: Colors.white.withOpacity(0.9),
                                            borderRadius: BorderRadius.circular(20),
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(20),
                                              onTap: () => _confirmDelete(context, doc, title),
                                              child: const Padding(
                                                padding: EdgeInsets.all(6),
                                                child: Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          )
        : const Center(child: Text('Barangay information not loaded')),
    ),
    );
  }

  List<QueryDocumentSnapshot> _applySearchAndSort(List<QueryDocumentSnapshot> docs) {
    final query = _searchQuery.toLowerCase();
    final filtered = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final title = (data['fileName'] as String? ?? data['title'] as String? ?? '').toLowerCase();
      final type = (data['fileType'] as String? ?? '').toLowerCase();
      if (query.isEmpty) return true;
      return title.contains(query) || type.contains(query);
    }).toList();

    int compareBy<T extends Comparable>(T? a, T? b) {
      if (a == null && b == null) return 0;
      if (a == null) return -1;
      if (b == null) return 1;
      return a.compareTo(b);
    }

    filtered.sort((aDoc, bDoc) {
      final a = aDoc.data() as Map<String, dynamic>;
      final b = bDoc.data() as Map<String, dynamic>;

      int result;
      switch (_sortBy) {
        case 'name':
          result = compareBy<String>((a['fileName'] ?? a['title'] ?? '') as String?, (b['fileName'] ?? b['title'] ?? '') as String?);
          break;
        case 'type':
          result = compareBy<String>((a['fileType'] ?? '') as String?, (b['fileType'] ?? '') as String?);
          break;
        case 'size':
          result = compareBy<int>(a['fileSize'] as int?, b['fileSize'] as int?);
          break;
        case 'date':
        default:
          final aTs = a['uploadDate'] as Timestamp? ?? a['timestamp'] as Timestamp?;
          final bTs = b['uploadDate'] as Timestamp? ?? b['timestamp'] as Timestamp?;
          result = compareBy<int>(aTs?.millisecondsSinceEpoch, bTs?.millisecondsSinceEpoch);
          break;
      }

      return _sortAsc ? result : -result;
    });

    return filtered;
  }

  Widget _buildTransparencyControls() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search bar pinned at top
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
              hintText: 'Search documents',
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
          // Controls row below search: sort + view toggle
          Row(
            children: [
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
                  const PopupMenuItem(value: 'name', child: Text('Name')),
                  const PopupMenuItem(value: 'date', child: Text('Date modified')),
                  const PopupMenuItem(value: 'size', child: Text('File size')),
                  const PopupMenuItem(value: 'type', child: Text('File type')),
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
                      Text(_sortBy == 'date'
                          ? 'Date'
                          : _sortBy == 'size'
                              ? 'Size'
                              : _sortBy == 'type'
                                  ? 'Type'
                                  : 'Name'),
                      const SizedBox(width: 6),
                      Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward, size: 16),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: _view == _TransparencyView.list ? 'Grid view' : 'List view',
                icon: Icon(_view == _TransparencyView.list ? Icons.grid_view : Icons.view_list),
                onPressed: () => setState(() {
                  _view = _view == _TransparencyView.list ? _TransparencyView.gridLarge : _TransparencyView.list;
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final next = value.trim();
    _searchDebounce = Timer(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      if (_searchQuery != next) {
        setState(() {
          _searchQuery = next;
        });
      }
    });
  }

  Future<void> _confirmDelete(BuildContext context, QueryDocumentSnapshot doc, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        await doc.reference.delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document deleted successfully')),
          );
        }
      } catch (e) {
        debugLog('[Transparency] Error deleting document: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _openDocument(BuildContext context, String title, String fileType, String? base64Data, String? url) async {
    if (base64Data != null) {
      try {
        final bytes = base64Decode(base64Data);
        if (context.mounted) {
          Navigator.pushNamed(
            context,
            AppRoutes.documentViewer,
            arguments: DocumentViewerArgs(
              title: title,
              fileBytes: bytes,
              fileType: fileType,
            ),
          );
        }
      } catch (e) {
        debugLog('[Transparency] Error opening file: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
      }
    } else if (url != null) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        final launched = await _launchWithFallback(uri);
        if (!launched && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot open file')));
        }
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot open file')));
      }
    }
  }

  Widget _buildFileThumbnail(String fileType, String? base64Data) {
    final icon = _iconForFileType(fileType);
    final bgColor = _colorForFileType(fileType);
    final iconColor = _iconForegroundForFileType(fileType);

    return _buildFileIcon(icon, bgColor, iconColor, fileType);
  }

  Widget _buildFileIcon(IconData icon, Color bgColor, Color iconColor, String fileType) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final containerBg = isDark ? Colors.grey[850] : Colors.white;
        final labelColor = isDark ? Colors.grey[300] : Colors.grey[600];
        
        return Container(
          color: containerBg,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 48, color: iconColor),
                ),
                const SizedBox(height: 8),
                Text(
                  fileType.toUpperCase(),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: labelColor),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _iconForFileType(String fileType) {
    switch (fileType) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.grid_on;
      case 'csv':
        return Icons.table_chart;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _colorForFileType(String fileType) {
    switch (fileType) {
      case 'pdf':
        return const Color(0xFFE53935);
      case 'doc':
      case 'docx':
        return const Color(0xFF2196F3);
      case 'xls':
      case 'xlsx':
      case 'csv':
        return const Color(0xFF4CAF50);
      default:
        return Colors.grey[300]!;
    }
  }

  Color _iconForegroundForFileType(String fileType) {
    switch (fileType) {
      case 'pdf':
      case 'doc':
      case 'docx':
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Colors.white;
      default:
        return Colors.grey[700]!;
    }
  }
}


// ==================== OFFICIAL / ADMIN PAGES ====================


