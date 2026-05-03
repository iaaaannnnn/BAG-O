part of '../../app/app.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _mobileFocusNode = FocusNode();
  // Region 8 (Eastern Visayas) province -> municipality -> barangay mapping (loaded from asset)
  Map<String, Map<String, List<String>>> _region8Provinces = {};
  List<String> _provinces = [];
  List<String> _municipalities = [];
  List<String> _barangays = [];
  
  // Duplicate checking
  String? _emailError;
  String? _mobileError;
  bool _checkingEmail = false;
  bool _checkingMobile = false;
  
  // Debounce timers
  Timer? _emailDebounce;
  Timer? _mobileDebounce;

  @override
  void initState() {
    super.initState();
    _loadRegion8FromAsset();
    _emailController.addListener(_onEmailChanged);
    _mobileController.addListener(_onMobileChanged);
    _emailFocusNode.addListener(() {
      if (!_emailFocusNode.hasFocus) {
        _checkEmailDuplicate(_emailController.text.trim());
      }
    });
    _mobileFocusNode.addListener(() {
      if (!_mobileFocusNode.hasFocus) {
        _checkMobileDuplicate(_mobileController.text.trim());
      }
    });
  }

  Future<void> _loadRegion8FromAsset() async {
    try {
      // Load index.json which lists available province files (per-province assets)
      final indexStr = await rootBundle.loadString('assets/data/region8/index.json');
      final List<dynamic> indexList = json.decode(indexStr) as List<dynamic>;
      final List<String> provinces = indexList.map((e) => e.toString()).toList()..sort();

      // Initialize province list; municipalities/barangays are lazy-loaded on selection
      if (mounted) {
        setState(() {
          _provinces = provinces;
          _region8Provinces = {}; // will be populated per-province as needed
        });
      } else {
        _provinces = provinces;
        _region8Provinces = {};
      }
      debugLog('[REGION8] [OK] Loaded region8 index with ${_provinces.length} provinces: $_provinces');
    } catch (e) {
      debugLog('[REGION8] [ERR] ERROR loading region8 asset: $e');
      if (mounted) {
        setState(() {
          _region8Provinces = {};
          _provinces = [];
        });
      } else {
        _region8Provinces = {};
        _provinces = [];
      }
    }
  }

  // Lazy-load a single province file into _region8Provinces if not already present.
  Future<void> _ensureProvinceLoaded(String province) async {
    if (_region8Provinces.containsKey(province)) return;
    try {
      // Build a list of filename candidates to try (without extension)
      final sanitized = province.replaceAll(RegExp(r"[^A-Za-z0-9 \-_()]"), '');
      final candidates = <String>{
        province,
        province.replaceAll(' ', '%20'),
        province.replaceAll(' ', '_'),
        province.replaceAll(' ', '-'),
        province.toLowerCase(),
        province.toLowerCase().replaceAll(' ', '_'),
        sanitized,
        sanitized.replaceAll(' ', '_'),
        sanitized.replaceAll(' ', '-'),
      };

      String? jsonStr;
      String? usedCandidate;
      for (final cand in candidates) {
        final path = 'assets/data/region8/$cand.json';
        try {
          jsonStr = await rootBundle.loadString(path);
          usedCandidate = cand;
          break;
        } catch (_) {
          // continue trying other candidates
        }
      }

      if (jsonStr == null) {
        // As a last resort, try the raw province with original spacing (again) to produce clearer error
        try {
          jsonStr = await rootBundle.loadString('assets/data/region8/$province.json');
          usedCandidate = province;
        } catch (e) {
          throw Exception('Could not find asset for province "$province". Tried ${candidates.length} variants.');
        }
      }

      final Map<String, dynamic> parsed = json.decode(jsonStr) as Map<String, dynamic>;
      Map<String, List<String>> muniMap = {};
      if (parsed.containsKey(province) && parsed[province] is Map) {
        final Map<String, dynamic> raw = parsed[province] as Map<String, dynamic>;
        raw.forEach((k, v) {
          muniMap[k] = List<String>.from(v as List);
        });
      } else {
        parsed.forEach((k, v) {
          muniMap[k] = List<String>.from(v as List);
        });
      }

      if (mounted) {
        setState(() {
          _region8Provinces[province] = muniMap;
        });
      } else {
        _region8Provinces[province] = muniMap;
      }
      debugLog('[REGION8] [OK] Loaded province asset for $province (${muniMap.length} municipalities) via "$usedCandidate.json"');
    } catch (e) {
      debugLog('[REGION8] [ERR] ERROR loading province asset for $province: $e');
      if (mounted) {
        setState(() {
          _region8Provinces[province] = {};
        });
      } else {
        _region8Provinces[province] = {};
      }
    }
  }

  String? _selectedProvince;
  String? _selectedMunicipality;
  String? _selectedBarangay;
  String _userType = 'Resident';
  String _suffix = 'None';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _showGuestBanner = true; // For dismissible guest info banner
  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;

  @override
  void dispose() {
    _emailController.removeListener(_onEmailChanged);
    _mobileController.removeListener(_onMobileChanged);
    _emailFocusNode.removeListener(() {});
    _mobileFocusNode.removeListener(() {});
    _emailDebounce?.cancel();
    _mobileDebounce?.cancel();
    _emailController.dispose();
    _mobileController.dispose();
    _emailFocusNode.dispose();
    _mobileFocusNode.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onEmailChanged() {
    // Clear error immediately while typing to show live feedback
    setState(() => _emailError = null);
    
    _emailDebounce?.cancel();
    _emailDebounce = Timer(Duration(milliseconds: 500), () {
      _checkEmailDuplicate(_emailController.text);
    });
  }

  void _onMobileChanged() {
    // Clear error immediately while typing to show live feedback
    setState(() => _mobileError = null);
    
    _mobileDebounce?.cancel();
    _mobileDebounce = Timer(Duration(milliseconds: 500), () {
      _checkMobileDuplicate(_mobileController.text);
    });
  }

  // Normalize email for consistent lookups
  String _normalizeEmailLocal(String email) {
    return email.trim().toLowerCase();
  }

  // Normalize phone numbers to local 11-digit format starting with 0 (e.g. 09123456789)
  String _normalizePhoneLocal(String phone) {
    var d = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.startsWith('63')) {
      // convert +63 or 63... to 0...
      d = '0' + d.substring(2);
    } else if (d.length == 10 && d.startsWith('9')) {
      // missing leading zero
      d = '0' + d;
    }
    return d;
  }

  // Check if email is already registered
  Future<void> _checkEmailDuplicate(String email, {bool updateUI = true}) async {
    final normalized = _normalizeEmailLocal(email);
    if (normalized.isEmpty || !normalized.contains('@')) {
      if (updateUI) setState(() => _emailError = null);
      else _emailError = null;
      return;
    }

    if (updateUI) {
      setState(() => _checkingEmail = true);
    } else {
      _checkingEmail = true;
    }
    try {
      bool exists = false;
      
      // Check users collection for email field (primary check)
      final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: normalized)
          .limit(1)
          .get();
      if (usersSnap.docs.isNotEmpty) exists = true;
      
      // Also check reserved email key in phone_numbers collection
      if (!exists) {
        try {
          final emailDoc = await FirebaseFirestore.instance
              .collection('phone_numbers')
              .doc('email_$normalized')
              .get();
          if (emailDoc.exists && emailDoc.data()?['userId'] != null) {
            exists = true;
          }
        } catch (e) {
          debugLog('[Register] Phone_numbers email check error: $e');
        }
      }

      if (mounted) {
        if (updateUI) {
          setState(() {
            _emailError = exists ? 'This email is already registered' : null;
            _checkingEmail = false;
          });
        } else {
          _emailError = exists ? 'This email is already registered' : null;
          _checkingEmail = false;
        }
      }
    } catch (e) {
      debugLog('[Register] Email check error: $e');
      if (mounted) {
        if (updateUI) {
          setState(() => _checkingEmail = false);
        } else {
          _checkingEmail = false;
        }
      }
    }
  }

  // Check if mobile is already registered
  Future<void> _checkMobileDuplicate(String mobile, {bool updateUI = true}) async {
    final normalized = _normalizePhoneLocal(mobile);
    if (normalized.isEmpty) {
      if (updateUI) setState(() => _mobileError = null);
      else _mobileError = null;
      return;
    }

    if (updateUI) {
      setState(() => _checkingMobile = true);
    } else {
      _checkingMobile = true;
    }
    try {
      bool exists = false;
      
      // Primary check: query users collection for existing phone fields
      final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('mobile', isEqualTo: normalized)
          .limit(1)
          .get();
      if (usersSnap.docs.isNotEmpty) {
        exists = true;
      }
      
      // Check alternative field name 'phoneNumber'
      if (!exists) {
        final usersSnap2 = await FirebaseFirestore.instance
            .collection('users')
            .where('phoneNumber', isEqualTo: normalized)
            .limit(1)
            .get();
        if (usersSnap2.docs.isNotEmpty) {
          exists = true;
        }
      }
      
      // Check phone_numbers collection for this exact phone number (as doc ID)
      if (!exists) {
        try {
          final mobileDoc = await FirebaseFirestore.instance.collection('phone_numbers').doc(normalized).get();
          if (mobileDoc.exists && mobileDoc.data()?['userId'] != null) {
            exists = true;
          }
        } catch (e) {
          debugLog('[Register] Phone_numbers doc check error: $e');
        }
      }
      
      // Comprehensive check: scan all phone_numbers documents to find this phone value
      // Skipping full collection scan for security compliance (list permission restricted)
      // Duplicate checks above using targeted document gets are sufficient.

      if (mounted) {
        if (updateUI) {
          setState(() {
            _mobileError = exists ? 'This phone number is already registered' : null;
            _checkingMobile = false;
          });
        } else {
          _mobileError = exists ? 'This phone number is already registered' : null;
          _checkingMobile = false;
        }
      }
    } catch (e) {
      debugLog('[Register] Mobile check error: $e');
      if (mounted) {
        if (updateUI) {
          setState(() => _checkingMobile = false);
        } else {
          _checkingMobile = false;
        }
      }
    }
  }

  // Check if there are any barangay officials for the selected barangay
  Future<bool> _hasBarangayOfficials(String municipality, String barangay) async {
    try {
      if ((barangay).isEmpty) return true; // avoid blocking if selection missing

      // Officials store barangay and municipality separately; query both when available
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('users')
          .where('type', isEqualTo: 'Barangay Official')
          .where('barangay', isEqualTo: barangay);

      if (municipality.isNotEmpty) {
        query = query.where('municipality', isEqualTo: municipality);
      }

      final snap = await query.limit(1).get();
      return snap.docs.isNotEmpty;
    } catch (e) {
      debugLog('[Register] Error checking officials: $e');
      return true; // Assume there are officials if we can't check
    }
  }

  // Show warning dialog if no barangay officials
  void _showNoOfficialsWarning() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning, color: Color(0xFFFFA500), size: 32),
        title: const Text('No Barangay Officials Yet'),
        content: const Text(
          'There are no registered barangay officials in this barangay yet. '
          'Your approval might take longer than expected. '
          'A barangay official will review your registration when available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match!')));
        return;
      }

      setState(() => _isLoading = true);

      String fullName = '${_firstNameController.text} ';
      if (_middleNameController.text.isNotEmpty) {
        fullName += '${_middleNameController.text} ';
      }
      fullName += _lastNameController.text;
      if (_suffix != 'None') {
        fullName += ' $_suffix';
      }

      try {
        final phone = _mobileController.text.trim();
        final email = _emailController.text.trim();

        // Reset errors and check flags
        _emailError = null;
        _mobileError = null;
        _checkingEmail = true;
        _checkingMobile = true;

        // Run both checks in parallel
        await Future.wait([
          _checkEmailDuplicate(email, updateUI: false),
          _checkMobileDuplicate(phone, updateUI: false),
        ]);

        // Update UI with both results at once
        setState(() {
          _checkingEmail = false;
          _checkingMobile = false;
        });

        // Check if either has an error
        if (_emailError != null || _mobileError != null) {
          setState(() => _isLoading = false);
          return;
        }

        // Register the user first
        bool success = await AuthService.register(
          email,
          _passwordController.text,
          _userType,
          {
            'name': fullName.toUpperCase(),
            'firstName': _firstNameController.text.toUpperCase(),
            'lastName': _lastNameController.text.toUpperCase(),
            'middleName': _middleNameController.text.toUpperCase(),
            'suffix': _suffix.toUpperCase(),
            'mobile': phone,
            'email': email,
            'address': _addressController.text.toUpperCase(),
            'municipality': _selectedMunicipality ?? '',
            'barangay': _selectedBarangay ?? '',
            'status': (_userType == 'Resident' || _userType == 'Guest Resident') ? 'pending' : 'approved',
            'role': _userType,
          },
        );

        setState(() => _isLoading = false);

        if (success && mounted) {
          // Check if there are barangay officials for this barangay (only for Resident/Guest)
          bool hasOfficials = true;
          if (_userType == 'Resident' || _userType == 'Guest Resident') {
            hasOfficials = await _hasBarangayOfficials(_selectedMunicipality ?? '', _selectedBarangay ?? '');
          }
          
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
                    colors: [Color(0xFF6B46C1), Color(0xFF9F7AEA)],
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
                        Icons.how_to_reg_outlined,
                        size: 64,
                        color: Color(0xFF6B46C1),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Registration Successful!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        hasOfficials 
                          ? 'Your account has been created successfully. You can now login.'
                          : 'Your account has been created. Please note: There are no registered barangay officials yet, so approval may take longer.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            hasOfficials ? Icons.pending_actions : Icons.schedule, 
                            color: Colors.white70, 
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              (_userType == 'Resident' || _userType == 'Guest Resident')
                                ? (hasOfficials ? 'Awaiting official approval' : 'Awaiting officials to register')
                                : 'Account ready to use',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
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
                          backgroundColor: const Color(0xFF6B46C1),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'GO TO LOGIN',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      } on FirebaseAuthException catch (e) {
        setState(() => _isLoading = false);
        // Show inline validation for known auth errors instead of a dialog/banner
        if (e.code == 'email-already-in-use') {
          setState(() => _emailError = 'That email is already registered.');
          return;
        } else if (e.code == 'weak-password') {
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Registration Error'),
                content: const Text('Password is too weak. Choose a stronger password.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
                ],
              ),
            );
          }
          return;
        } else if (e.code == 'invalid-email') {
          setState(() => _emailError = 'Invalid email format.');
          return;
        } else {
          setState(() => _isLoading = false);
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Registration Error'),
                content: Text('Registration error: ${e.message}'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
                ],
              ),
            );
          }
          return;
        }
      } catch (e) {
        setState(() => _isLoading = false);
        debugLog('[Register] Unexpected error: $e');
        
        // Handle duplicate phone/email errors with inline validation instead of dialog
        final errorMsg = e.toString().toLowerCase();
        if (errorMsg.contains('phone number already registered')) {
          setState(() => _mobileError = 'This phone number is already registered');
          return;
        } else if (errorMsg.contains('email already registered')) {
          setState(() => _emailError = 'This email is already registered');
          return;
        } else if (errorMsg.contains('recently deleted') || errorMsg.contains('can re-register in')) {
          // Show banner for deleted account restriction
          if (mounted) {
            ScaffoldMessenger.of(context).showMaterialBanner(
              MaterialBanner(
                backgroundColor: Colors.orange.shade100,
                content: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        e.toString().contains('FirebaseException') 
                          ? e.toString().split('] ').last
                          : e.toString(),
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                    },
                    child: const Text('DISMISS'),
                  ),
                ],
              ),
            );
          }
          return;
        }
        
        // Show dialog for other unexpected errors
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Error'),
              content: Text('An unexpected error occurred: ${e.toString()}'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Register As', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _userType,
                    isExpanded: true,
                    items: ['Resident', 'Guest Resident', 'Barangay Official'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (val) => setState(() => _userType = val!),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_userType == 'Guest Resident' && _showGuestBanner)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    border: Border.all(color: Colors.blue[200]!),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue[600]),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Guest accounts last 30 days.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF1976D2)),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _firstNameController,
                textCapitalization: TextCapitalization.characters,
                onChanged: (val) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'First Name',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
                ),
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _lastNameController,
                textCapitalization: TextCapitalization.characters,
                onChanged: (val) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Last Name',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
                ),
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _middleNameController,
                textCapitalization: TextCapitalization.characters,
                onChanged: (val) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Middle Name (Optional)',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
                ),
              ),
              const SizedBox(height: 16),

              const Text('Suffix', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _suffix,
                    isExpanded: true,
                    items: ['None', 'Jr.', 'Sr.', 'II', 'III', 'IV', 'V'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (val) => setState(() => _suffix = val!),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _emailController,
                focusNode: _emailFocusNode,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email *',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: _emailError != null ? Colors.red : Colors.grey[300]!,
                      width: _emailError != null ? 2 : 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: _emailError != null ? Colors.red : Colors.grey[300]!,
                      width: _emailError != null ? 2 : 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: _emailError != null ? Colors.red : const Color(0xFF228B22),
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                  errorText: _emailError,
                  errorStyle: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                  suffixIcon: _checkingEmail
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _emailError != null
                          ? const Icon(Icons.error, color: Colors.red)
                          : null,
                ),
                validator: (val) {
                  if (val!.isEmpty) return 'Required';
                  if (!val.contains('@')) return 'Enter valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _mobileController,
                focusNode: _mobileFocusNode,
                keyboardType: TextInputType.phone,
                maxLength: 11,
                decoration: InputDecoration(
                  labelText: 'Mobile Number *',
                  filled: true,
                  fillColor: Colors.white,
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: _mobileError != null ? Colors.red : Colors.grey[300]!,
                      width: _mobileError != null ? 2 : 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: _mobileError != null ? Colors.red : Colors.grey[300]!,
                      width: _mobileError != null ? 2 : 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: _mobileError != null ? Colors.red : const Color(0xFF228B22),
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                  errorText: _mobileError,
                  errorStyle: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                  suffixIcon: _checkingMobile
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _mobileError != null
                          ? const Icon(Icons.error, color: Colors.red)
                          : null,
                ),
                validator: (val) {
                  if (val!.isEmpty) return 'Required';
                  if (val.length != 11) return 'Must be 11 digits';
                  if (!val.startsWith('09')) return 'Must start with 09';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Province selector (Region 8)
              const Text('Province', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: (_provinces.isNotEmpty && _selectedProvince != null && _provinces.contains(_selectedProvince)) ? _selectedProvince : null,
                    isExpanded: true,
                    hint: const Text('Select Province'),
                    items: _provinces.isEmpty
                        ? [const DropdownMenuItem<String>(value: null, child: Text('Loading provinces...'))]
                        : _provinces.map((p) => DropdownMenuItem<String>(value: p, child: Text(p))).toList(),
                    onChanged: _provinces.isEmpty
                        ? null
                        : (val) async {
                      debugLog('[REGION8] Province selected: $val');
                      debugLog('[REGION8] Available provinces: $_provinces');
                      // ensure the province data is loaded from assets
                      if (val != null) await _ensureProvinceLoaded(val);
                      if (!mounted) return;
                      setState(() {
                        _selectedProvince = val;
                        _selectedMunicipality = null;
                        _selectedBarangay = null;
                        if (val != null) {
                          final munis = _region8Provinces[val];
                          debugLog('[REGION8] Region8Provinces keys: ${_region8Provinces.keys}');
                          debugLog('[REGION8] Data for $val: $munis');
                          _municipalities = (munis?.keys.toList() ?? [])..sort();
                          debugLog('[REGION8] Municipalities for $val: ${_municipalities.toString()}');
                        } else {
                          _municipalities = [];
                        }
                        _barangays = [];
                        _addressController.clear();
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Municipality selector (Region 8)
              const Text('Municipality / City', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: (_municipalities.isNotEmpty && _selectedMunicipality != null && _municipalities.contains(_selectedMunicipality)) ? _selectedMunicipality : null,
                    isExpanded: true,
                    hint: const Text('Select Municipality / City'),
                    items: _municipalities.isEmpty
                        ? [const DropdownMenuItem<String>(value: null, child: Text('Select a province first'))]
                        : _municipalities.map((m) => DropdownMenuItem<String>(value: m, child: Text(m))).toList(),
                    onChanged: _municipalities.isEmpty ? null : (val) {
                      debugLog('[REGION8] Municipality selected: $val');
                      setState(() {
                        _selectedMunicipality = val;
                        _selectedBarangay = null;
                        if (val != null && _selectedProvince != null) {
                          final barangays = _region8Provinces[_selectedProvince]?[val];
                          debugLog('[REGION8] Barangays for $val: $barangays');
                          _barangays = (barangays ?? [])..sort();
                          _addressController.clear();
                        }
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),

              const Text('Barangay', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: (_barangays.isNotEmpty && _selectedBarangay != null && _barangays.contains(_selectedBarangay)) ? _selectedBarangay : null,
                    isExpanded: true,
                    hint: const Text('Select Barangay'),
                    items: _barangays.isEmpty
                        ? [const DropdownMenuItem<String>(value: null, child: Text('Select a municipality first'))]
                        : _barangays.map((b) => DropdownMenuItem<String>(value: b, child: Text(b))).toList(),
                    onChanged: _barangays.isEmpty ? null : (val) {
                      debugLog('[REGION8] Barangay selected: $val');
                      setState(() {
                        _selectedBarangay = val;
                        if (val != null && _selectedMunicipality != null && _selectedProvince != null) {
                          _addressController.text = '$val, $_selectedMunicipality, $_selectedProvince';
                          debugLog('[REGION8] Address set to: ${_addressController.text}');
                        }
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'Full Address (auto-filled from selections)',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
                ),
                maxLines: 2,
                readOnly: true,
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (val) => val!.length < 6 ? 'Min 6 characters' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Terms and Conditions Checkbox
              CheckboxListTile(
                value: _acceptedTerms,
                onChanged: (val) => setState(() => _acceptedTerms = val ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                title: GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Terms and Conditions'),
                        content: const SingleChildScrollView(
                          child: Text(
                            'TERMS AND CONDITIONS\n\n'
                            '1. ACCEPTANCE OF TERMS\n'
                            'By registering and using BAG-O (Barangay Automated Governance and Operation), you agree to be bound by these terms and conditions.\n\n'
                            '2. USER ACCOUNTS\n'
                            'You are responsible for maintaining the confidentiality of your account credentials. You must provide accurate and complete information during registration.\n\n'
                            '3. USE OF SERVICE\n'
                            'BAG-O is intended for legitimate barangay governance and community purposes only. You agree not to misuse the platform or engage in fraudulent activities.\n\n'
                            '4. DATA ACCURACY\n'
                            'You agree to provide truthful and accurate information when submitting requests, complaints, or any documentation through the system.\n\n'
                            '5. PROHIBITED CONDUCT\n'
                            'Users must not use offensive language, submit false information, or harass other users or officials through the platform.\n\n'
                            '6. SERVICE MODIFICATIONS\n'
                            'We reserve the right to modify, suspend, or discontinue any aspect of BAG-O at any time without prior notice.\n\n'
                            '7. LIMITATION OF LIABILITY\n'
                            'BAG-O is provided "as is" and we make no warranties regarding the accuracy, reliability, or availability of the service.',
                            style: TextStyle(fontSize: 13, height: 1.5),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('CLOSE'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text.rich(
                    TextSpan(
                      text: 'I agree to the ',
                      style: TextStyle(fontSize: 13),
                      children: [
                        TextSpan(
                          text: 'Terms and Conditions',
                          style: TextStyle(color: Color(0xFF228B22), decoration: TextDecoration.underline, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Data Privacy Agreement Checkbox
              CheckboxListTile(
                value: _acceptedPrivacy,
                onChanged: (val) => setState(() => _acceptedPrivacy = val ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                title: GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Data Privacy Agreement'),
                        content: const SingleChildScrollView(
                          child: Text(
                            'DATA PRIVACY AGREEMENT\n\n'
                            '1. INFORMATION COLLECTION\n'
                            'BAG-O collects personal information including but not limited to: name, address, contact details, email, and barangay-related documents necessary for service delivery.\n\n'
                            '2. USE OF INFORMATION\n'
                            'Your information will be used solely for:\n'
                            '- Processing barangay service requests\n'
                            '- Facilitating communication between residents and officials\n'
                            '- Managing complaints and feedback\n'
                            '- Maintaining barangay records and statistics\n\n'
                            '3. DATA SECURITY\n'
                            'We implement appropriate technical and organizational measures to protect your personal data against unauthorized access, alteration, disclosure, or destruction.\n\n'
                            '4. DATA SHARING\n'
                            'Your personal information will only be shared with authorized barangay officials for legitimate governance purposes. We will not sell or share your data with third parties without your consent.\n\n'
                            '5. YOUR RIGHTS\n'
                            'You have the right to access, correct, or request deletion of your personal data. You may contact your barangay office to exercise these rights.\n\n'
                            '6. DATA RETENTION\n'
                            'We retain your personal information for as long as necessary to fulfill the purposes outlined in this agreement or as required by law.\n\n'
                            '7. COMPLIANCE\n'
                            'This agreement complies with the Data Privacy Act of 2012 (Republic Act No. 10173) of the Philippines.',
                            style: TextStyle(fontSize: 13, height: 1.5),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('CLOSE'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text.rich(
                    TextSpan(
                      text: 'I agree to the ',
                      style: TextStyle(fontSize: 13),
                      children: [
                        TextSpan(
                          text: 'Data Privacy Agreement',
                          style: TextStyle(color: Color(0xFF228B22), decoration: TextDecoration.underline, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Center(
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: (_acceptedTerms && _acceptedPrivacy) ? _handleRegister : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 60),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: (_acceptedTerms && _acceptedPrivacy) ? null : Colors.grey,
                  ),
                  child: const Text('REGISTER', style: TextStyle(fontSize: 15)),
                ),
              ),
              if (!_acceptedTerms || !_acceptedPrivacy)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Please accept both agreements to register',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== RESIDENT DASHBOARD ====================

