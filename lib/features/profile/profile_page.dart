part of '../../app/app.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    final userData = await AuthService.getUserData();
    if (mounted) {
      setState(() {
        _profileImageUrl = userData?['profileImageUrl'];
      });
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() => _isUploading = true);
      debugLog('[Profile] Starting image upload...');

      final imageFile = File(pickedFile.path);
      
      // Get user ID early
      final uid = AuthService.currentUser?.uid;
      if (uid == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User not authenticated. Please log in again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isUploading = false);
        return;
      }
      
      // Compress image for reliable upload
      File? compressedFile = await ImageCompressionHelper.compressForUpload(imageFile);
      final fileToUse = compressedFile ?? imageFile;
      final finalSize = fileToUse.lengthSync();
      debugLog('[Profile] File size: ${(finalSize / 1024 / 1024).toStringAsFixed(2)}MB');
      
      if (compressedFile == null) {
        debugLog('[Profile] Using original file');
      }
      
      // Upload to Firebase Cloud Storage
      final storagePath = 'profiles/${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      debugLog('[Profile] Uploading to: $storagePath');
      
      final downloadUrl = await AuthService.uploadImage(fileToUse, storagePath);
      
      if (downloadUrl == null || downloadUrl.isEmpty) {
        debugLog('[Profile] Upload returned null/empty URL');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload image. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isUploading = false);
        return;
      }

      debugLog('[Profile] Upload successful: $downloadUrl');

      // Save to Firestore user document
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'profileImageUrl': downloadUrl,
        'profileImageUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Update local state immediately for instant feedback
      if (mounted) {
        setState(() {
          _profileImageUrl = downloadUrl;
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated successfully!')),
        );
      }
    } catch (e) {
      debugLog('[Profile] Error uploading image: $e');
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _removeProfilePicture() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Profile Picture'),
        content: const Text('Are you sure you want to remove your profile picture?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        setState(() => _isUploading = true);
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'profileImageUrl': '',
          'profileImageUpdatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          setState(() {
            _profileImageUrl = null;
            _isUploading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile picture removed')),
          );
        }
      } catch (e) {
        debugLog('[Profile] Error removing picture: $e');
        setState(() => _isUploading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  void _showProfilePictureOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage();
              },
            ),
            if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove picture', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _removeProfilePicture();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.currentUser?.uid;
    
    if (uid == null) {
      // User not logged in, rely on root auth shell to present login
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Unable to load profile'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final currentImageUrl = data['profileImageUrl'] as String?;
          final avatarImage = resolveImageProvider(currentImageUrl);
          
          // Update local state if image changed from Firestore (e.g., from another device)
          if (currentImageUrl != _profileImageUrl && !_isUploading) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _profileImageUrl = currentImageUrl;
                });
              }
            });
          }
          final address = formatBarangayAddress(data);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Profile picture with Facebook-style camera button
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF228B22), width: 3),
                      ),
                      child: CircleAvatar(
                        radius: 65,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: avatarImage,
                        child: avatarImage == null
                          ? const Icon(Icons.person, size: 65, color: Colors.grey)
                          : null,
                      ),
                    ),
                    if (_isUploading)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withOpacity(0.5),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          ),
                        ),
                      ),
                    // Camera button with spacing (Facebook-style)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: _isUploading ? null : _showProfilePictureOptions,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF228B22),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.black87 : Colors.white,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Name and role
                Text(
                  data['name'] ?? 'Unknown',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF228B22).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    (data['role'] ?? data['type'] ?? 'User').toString(),
                    style: const TextStyle(fontSize: 14, color: Color(0xFF228B22), fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 24),
                // Guest account expiration warning
                buildGuestExpirationWarning(context),
                const SizedBox(height: 24),
                // Simplified profile info card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSimpleProfileRow(Icons.person, 'Full Name', data['name'] ?? 'N/A'),
                        const Divider(height: 24),
                        _buildSimpleProfileRow(Icons.email, 'Email', data['email'] ?? 'N/A'),
                        const Divider(height: 24),
                        _buildSimpleProfileRow(Icons.phone, 'Mobile', data['mobile'] ?? 'N/A'),
                        const Divider(height: 24),
                        _buildSimpleProfileRow(Icons.location_on, 'Address', address),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Account Actions
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (dialogContext) {
                              final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
                              return AlertDialog(
                              title: Text('Logout', style: TextStyle(color: isDark ? Colors.white : null)),
                              content: Text('Are you sure you want to logout?', style: TextStyle(color: isDark ? Colors.white : null)),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    Navigator.pop(dialogContext); // Close dialog
                                    
                                    // Show loading dialog
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (context) => const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                    
                                    try {
                                      AuthService.userType = null;
                                      await AuthService.logout();
                                      
                                      if (mounted) {
                                        Navigator.pop(context); // Close loading dialog
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Logout successful'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                        // Return to root auth shell; it will show LoginPage automatically
                                        Navigator.of(context).popUntil((route) => route.isFirst);
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        Navigator.pop(context); // Close loading dialog
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Logout error: ${e.toString()}'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF228B22),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text('Logout'),
                                ),
                              ],
                            );
                            },
                          );
                        },
                        icon: const Icon(Icons.logout),
                        label: const Text('Logout'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF228B22),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final isPending = data['status']?.toString().toLowerCase() == 'pending';
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(isPending ? 'Cancel Request' : 'Delete Account'),
                              content: Text(
                                isPending
                                  ? 'Are you sure you want to cancel your registration request? This will permanently delete your account and you can register again anytime.'
                                  : 'Are you sure you want to delete your account? This action cannot be undone.\n\nYou will not be able to create a new account with the same email or phone number for 7 days.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    // Show loading
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (context) => const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                    
                                    final success = isPending ? await AuthService.cancelRequest() : await AuthService.deleteAccount();
                                    
                                    if (mounted) {
                                      Navigator.pop(context); // Close loading
                                      if (success) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(isPending ? 'Request cancelled successfully' : 'Account deleted successfully'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                        // Return to root auth shell; it will show LoginPage automatically
                                        Navigator.of(context).popUntil((route) => route.isFirst);
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(isPending ? 'Failed to cancel request. Please try again.' : 'Failed to delete account. Please try again.'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text(isPending ? 'Cancel Request' : 'Delete'),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: Icon(data['status']?.toString().toLowerCase() == 'pending' ? Icons.cancel : Icons.delete_forever),
                        label: Text(data['status']?.toString().toLowerCase() == 'pending' ? 'Cancel Request' : 'Delete Account'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSimpleProfileRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Builder(
      builder: (context) {
        final textColor = valueColor ?? Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: const Color(0xFF228B22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

