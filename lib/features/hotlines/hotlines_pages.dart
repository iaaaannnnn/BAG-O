part of '../../app/app.dart';

class EmergencyContactsPage extends StatelessWidget {
  const EmergencyContactsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Check if user is official or resident/guest
    final userType = AuthService.userType ?? '';
    final isOfficial = userType.toLowerCase().contains('official');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Government Hotlines'),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: isOfficial
          ? const ManageHotlinesPage()
          : const ViewHotlinesPage(),
      floatingActionButton: isOfficial
          ? FloatingActionButton(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.addEditHotline);
              },
              backgroundColor: const Color(0xFF228B22),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

// ==================== HOTLINES MANAGEMENT PAGES ====================

class ManageHotlinesPage extends StatefulWidget {
  const ManageHotlinesPage({Key? key}) : super(key: key);

  @override
  State<ManageHotlinesPage> createState() => _ManageHotlinesPageState();
}

class _ManageHotlinesPageState extends State<ManageHotlinesPage> {
  String _barangay = '';
  bool _isLoadingBarangay = true;

  @override
  void initState() {
    super.initState();
    _loadBarangay();
  }

  Future<void> _loadBarangay() async {
    final b = await AuthService.waitForBarangay();
    if (mounted) {
      setState(() {
        _barangay = b ?? '';
        _isLoadingBarangay = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingBarangay) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_barangay.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('hotlines')
          .where('barangay', isEqualTo: _barangay)
          .orderBy('isEmergency', descending: true)
          .orderBy('departmentName')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error loading hotlines: ${snapshot.error}'),
            ),
          );
        }

        final hotlines = snapshot.data?.docs ?? [];

        if (hotlines.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.phone_disabled, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No hotlines added yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: hotlines.length,
          itemBuilder: (context, index) {
            final doc = hotlines[index];
            final data = doc.data() as Map<String, dynamic>;

            return _buildHotlineCard(context, doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildHotlineCard(BuildContext context, String docId, Map<String, dynamic> data) {
    final isEmergency = data['isEmergency'] as bool? ?? false;
    final isActive = data['status'] == 'Active';
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      color: isEmergency ? Colors.red.withOpacity(0.05) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isEmergency)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'EMERGENCY',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              data['departmentName'] ?? 'Unknown',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data['hotlineNumber'] ?? 'N/A',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                      if ((data['description'] ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            data['description'] ?? '',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                            ),
                            softWrap: true,
                          ),
                        ),
                      if ((data['operatingHours'] ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Hours: ${data['operatingHours']}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.addEditHotline,
                        arguments: docId,
                      );
                    } else if (value == 'toggle') {
                      final newStatus = isActive ? 'Inactive' : 'Active';
                      await FirebaseFirestore.instance
                          .collection('hotlines')
                          .doc(docId)
                          .update({'status': newStatus});
                    } else if (value == 'delete') {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Hotline'),
                          content: const Text('Are you sure you want to delete this hotline?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () async {
                                await FirebaseFirestore.instance.collection('hotlines').doc(docId).delete();
                                if (context.mounted) Navigator.pop(ctx);
                              },
                              child: const Text('Delete', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'toggle', child: Text(isActive ? 'Deactivate' : 'Activate')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                  child: const Icon(Icons.more_vert),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? Colors.green[100] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    color: isActive ? Colors.green[700] : Colors.grey[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ViewHotlinesPage extends StatefulWidget {
  const ViewHotlinesPage({Key? key}) : super(key: key);

  @override
  State<ViewHotlinesPage> createState() => _ViewHotlinesPageState();
}

class _ViewHotlinesPageState extends State<ViewHotlinesPage> {
  String _barangay = '';
  bool _isLoadingBarangay = true;

  @override
  void initState() {
    super.initState();
    _loadBarangay();
  }

  Future<void> _loadBarangay() async {
    final b = await AuthService.waitForBarangay();
    if (mounted) {
      setState(() {
        _barangay = b ?? '';
        _isLoadingBarangay = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingBarangay || _barangay.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('hotlines')
          .where('barangay', isEqualTo: _barangay)
          .where('status', isEqualTo: 'Active')
          .orderBy('isEmergency', descending: true)
          .orderBy('departmentName')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error loading hotlines: ${snapshot.error}'),
            ),
          );
        }

        final hotlines = snapshot.data?.docs ?? [];

        if (hotlines.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.phone_disabled, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No active hotlines available', style: TextStyle(color: Colors.grey, fontSize: 16)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: hotlines.length,
          itemBuilder: (context, index) {
            final doc = hotlines[index];
            final data = doc.data() as Map<String, dynamic>;

            return _buildPublicHotlineCard(context, data);
          },
        );
      },
    );
  }

  Widget _buildPublicHotlineCard(BuildContext context, Map<String, dynamic> data) {
    final isEmergency = data['isEmergency'] as bool? ?? false;
    final theme = Theme.of(context);
    final hotlineNumber = data['hotlineNumber'] ?? '';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      color: isEmergency ? Colors.red.withOpacity(0.05) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isEmergency)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'EMERGENCY',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    data['departmentName'] ?? 'Unknown',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hotlineNumber,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                          fontSize: 18,
                        ),
                      ),
                      if ((data['description'] ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            data['description'] ?? '',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                            ),
                            softWrap: true,
                          ),
                        ),
                      if ((data['operatingHours'] ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Hours: ${data['operatingHours']}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: hotlineNumber));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Hotline number copied')),
                        );
                      },
                      icon: const Icon(Icons.content_copy),
                      tooltip: 'Copy number',
                    ),
                    IconButton(
                      onPressed: () => _callHotline(hotlineNumber),
                      icon: const Icon(Icons.call),
                      tooltip: 'Call',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _callHotline(String number) async {
    final cleanNumber = number.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not initiate call')),
        );
      }
    }
  }
}

class AddEditHotlinePage extends StatefulWidget {
  final String? hotlineId;

  const AddEditHotlinePage({Key? key, this.hotlineId}) : super(key: key);

  @override
  State<AddEditHotlinePage> createState() => _AddEditHotlinePageState();
}

class _AddEditHotlinePageState extends State<AddEditHotlinePage> {
  final _formKey = GlobalKey<FormState>();
  final _departmentController = TextEditingController();
  final _numberController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isEmergency = false;
  bool _isLoading = false;
  String _barangay = '';
  bool _isLoadingBarangay = true;

  // Operating hours state
  int _startHour = 8;
  int _endHour = 17;
  bool _is24Hours = false;

  @override
  void initState() {
    super.initState();
    _loadBarangay();
    if (widget.hotlineId != null) {
      _loadHotline();
    }
  }

  Future<void> _loadBarangay() async {
    final b = await AuthService.waitForBarangay();
    if (mounted) {
      setState(() {
        _barangay = b ?? '';
        _isLoadingBarangay = false;
      });
    }
  }

  Future<void> _loadHotline() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('hotlines')
          .doc(widget.hotlineId)
          .get();

      if (doc.exists) {
        final data = doc.data() ?? {};
        _departmentController.text = data['departmentName'] ?? '';
        _numberController.text = data['hotlineNumber'] ?? '';
        _descriptionController.text = data['description'] ?? '';
        
        // Parse operating hours
        final operatingHours = data['operatingHours'] as String?;
        if (operatingHours != null && operatingHours.isNotEmpty) {
          if (operatingHours.toLowerCase().contains('24')) {
            _is24Hours = true;
          } else {
            _is24Hours = false;
            // Try to parse hours from format like "8:00 AM - 5:00 PM"
            final hourRegex = RegExp(r'(\d{1,2}):00\s*(AM|PM)');
            final matches = hourRegex.allMatches(operatingHours);
            if (matches.length >= 2) {
              final startMatch = matches.first;
              final endMatch = matches.last;
              
              int startHour = int.parse(startMatch.group(1)!);
              int endHour = int.parse(endMatch.group(1)!);
              
              // Convert to 24-hour format
              if (startMatch.group(2) == 'PM' && startHour != 12) startHour += 12;
              if (startMatch.group(2) == 'AM' && startHour == 12) startHour = 0;
              if (endMatch.group(2) == 'PM' && endHour != 12) endHour += 12;
              if (endMatch.group(2) == 'AM' && endHour == 12) endHour = 0;
              
              _startHour = startHour;
              _endHour = endHour;
            }
          }
        }
        
        setState(() {
          _isEmergency = data['isEmergency'] ?? false;
        });
      }
    } catch (e) {
      debugLog('Error loading hotline: $e');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoadingBarangay || _barangay.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait while loading...')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final operatingHours = _is24Hours 
          ? '24 Hours' 
          : '${_formatHour(_startHour)} - ${_formatHour(_endHour)}';
      
      final data = {
        'departmentName': _departmentController.text.trim(),
        'hotlineNumber': _numberController.text.trim(),
        'description': _descriptionController.text.trim(),
        'operatingHours': operatingHours,
        'isEmergency': _isEmergency,
        'status': 'Active',
        'barangay': _barangay,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.hotlineId == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('hotlines').add(data);
      } else {
        await FirebaseFirestore.instance
            .collection('hotlines')
            .doc(widget.hotlineId)
            .update(data);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hotline ${widget.hotlineId == null ? 'added' : 'updated'} successfully')),
        );
      }
    } catch (e) {
      debugLog('Error saving hotline: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _departmentController.dispose();
    _numberController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Widget _buildOperatingHoursField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Operating Hours (Optional)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Checkbox(
              value: _is24Hours,
              onChanged: (value) => setState(() => _is24Hours = value ?? false),
            ),
            const Text('24 Hours'),
          ],
        ),
        if (!_is24Hours) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('From: ', style: TextStyle(fontWeight: FontWeight.w500)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<int>(
                  value: _startHour,
                  items: List.generate(24, (index) => index).map((hour) {
                    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
                    final amPm = hour < 12 ? 'AM' : 'PM';
                    return DropdownMenuItem(
                      value: hour,
                      child: Text('${displayHour.toString().padLeft(2, '0')}:00 $amPm'),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _startHour = value ?? 8),
                  underline: const SizedBox(),
                ),
              ),
              const SizedBox(width: 16),
              const Text('To: ', style: TextStyle(fontWeight: FontWeight.w500)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<int>(
                  value: _endHour,
                  items: List.generate(24, (index) => index).map((hour) {
                    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
                    final amPm = hour < 12 ? 'AM' : 'PM';
                    return DropdownMenuItem(
                      value: hour,
                      child: Text('${displayHour.toString().padLeft(2, '0')}:00 $amPm'),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _endHour = value ?? 17),
                  underline: const SizedBox(),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Text(
          _is24Hours ? 'Available 24 hours a day' : 'Available from ${_formatHour(_startHour)} to ${_formatHour(_endHour)}',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
      ],
    );
  }

  String _formatHour(int hour) {
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final amPm = hour < 12 ? 'AM' : 'PM';
    return '${displayHour.toString().padLeft(2, '0')}:00 $amPm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.hotlineId == null ? 'Add Hotline' : 'Edit Hotline'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _departmentController,
                decoration: InputDecoration(
                  labelText: 'Department / Office Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  hintText: 'e.g., Police, Fire, Health',
                ),
                maxLength: 50,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Department name is required';
                  }
                  if (val.trim().length < 2) {
                    return 'Department name must be at least 2 characters';
                  }
                  if (val.length > 50) {
                    return 'Department name cannot exceed 50 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _numberController,
                decoration: InputDecoration(
                  labelText: 'Hotline Number',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  hintText: 'e.g., 911 or +63-2-123-4567',
                ),
                keyboardType: TextInputType.phone,
                maxLength: 20,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Hotline number is required';
                  }
                  // Allow numbers, spaces, hyphens, plus signs, and parentheses
                  final phoneRegex = RegExp(r'^[\d\s\-\+\(\)]+$');
                  if (!phoneRegex.hasMatch(val)) {
                    return 'Please enter a valid phone number';
                  }
                  if (val.length > 20) {
                    return 'Phone number cannot exceed 20 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  hintText: 'e.g., Emergency only, Non-emergency cases',
                ),
                maxLength: 200,
                maxLines: 3,
                validator: (val) {
                  if (val != null && val.length > 200) {
                    return 'Description cannot exceed 200 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildOperatingHoursField(),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Emergency Hotline'),
                subtitle: const Text('Mark as priority emergency contact'),
                value: _isEmergency,
                onChanged: (val) => setState(() => _isEmergency = val ?? false),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF228B22),
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                          )
                        : Text(widget.hotlineId == null ? 'Add' : 'Update'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


