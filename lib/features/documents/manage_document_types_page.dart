part of '../../app/app.dart';

class ManageDocumentTypesPage extends StatefulWidget {
  const ManageDocumentTypesPage({Key? key}) : super(key: key);

  @override
  State<ManageDocumentTypesPage> createState() => _ManageDocumentTypesPageState();
}

class _ManageDocumentTypesPageState extends State<ManageDocumentTypesPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  String? _editingDocId;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return FutureBuilder<String?>(
      future: AuthService.waitForBarangay(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Manage Document Types'),
              backgroundColor: theme.colorScheme.surface,
              foregroundColor: theme.colorScheme.onSurface,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final barangay = snapshot.data ?? '';
        if (barangay.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Manage Document Types'),
              backgroundColor: theme.colorScheme.surface,
              foregroundColor: theme.colorScheme.onSurface,
            ),
            body: const Center(child: Text('Barangay not loaded')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Manage Document Types'),
            backgroundColor: theme.colorScheme.surface,
            foregroundColor: theme.colorScheme.onSurface,
            elevation: 1,
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: const Color(0xFF228B22),
            foregroundColor: Colors.white,
            onPressed: () => _showAddEditDialog(context, barangay, null),
            child: const Icon(Icons.add),
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('document_types')
                .where('barangay', isEqualTo: barangay)
                .snapshots()
                .timeout(
                  const Duration(seconds: 10),
                  onTimeout: (_) => Stream.error('Query timeout - please check your connection'),
                ),
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '${snapshot.error}',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
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
                              _showAddEditDialog(context, barangay, doc);
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
      },
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
}



