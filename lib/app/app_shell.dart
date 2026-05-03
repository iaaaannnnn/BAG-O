part of 'app.dart';

final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.light);
// Flag to track if theme has been initialized from saved preferences
bool _themeInitialized = false;

// ---------------------------------------------------------------------------
// Trial lock screen
// ---------------------------------------------------------------------------
class _TrialLockScreen extends StatelessWidget {
  const _TrialLockScreen();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1A237E),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline, size: 80, color: Colors.white70),
                  const SizedBox(height: 24),
                  const Text(
                    'BAG-O',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Barangay Automated Governance\nand Operation',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.white60),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      children: const [
                        Text(
                          'Access Restricted',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'This application is currently unavailable.\n\nPlease fulfill your payment to restore access.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, color: Colors.white, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Contact your system administrator\nfor assistance.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.white54, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BarangayApp extends StatefulWidget {
  const BarangayApp({Key? key}) : super(key: key);

  @override
  State<BarangayApp> createState() => _BarangayAppState();
}

class _BarangayAppState extends State<BarangayApp> {
  // Cache auth state to prevent loading screen on theme changes
  User? _cachedUser;
  Map<String, dynamic>? _cachedUserData;
  bool _initialAuthCheckDone = false;
  int _nullUserDataRetries = 0;
  String? _lastUserId; // Track last user ID to detect login changes

  // Trial lock
  bool _trialChecked = false;
  bool _trialExpired = false;
  static const String _trialKey = 'trial_start_ms';
  static const int _trialDays = 14;

  @override
  void initState() {
    super.initState();
    _checkTrial();
  }

  Future<void> _checkTrial() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final stored = prefs.getInt(_trialKey);
    if (stored == null) {
      // First launch - record the start date
      await prefs.setInt(_trialKey, now);
    }
    final start = stored ?? now;
    final elapsed = Duration(milliseconds: now - start);
    final expired = elapsed.inDays >= _trialDays;
    if (mounted) {
      setState(() {
        _trialChecked = true;
        _trialExpired = expired;
      });
    }
  }

  void _clearCacheOnLogout() {
    debugLog('[AUTH] Clearing all cached state');
    _cachedUser = null;
    _cachedUserData = null;
    _lastUserId = null;
    _initialAuthCheckDone = false; // Reset to force fresh data on next login
    _themeInitialized = false; // Also reset theme initialization
    // Also clear AuthService static state
    AuthService.userType = null;
    AuthService.currentUserData = null;
  }

  @override
  Widget build(BuildContext context) {
    // Show nothing while we check the trial (very brief)
    if (!_trialChecked) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Color(0xFF1A237E),
          body: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      );
    }

    // Block app entirely if trial has expired
    if (_trialExpired) {
      return const _TrialLockScreen();
    }

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'BAG-O - Barangay Automated Governance and Operation',
          debugShowCheckedModeBanner: false,
          navigatorKey: rootNavigatorKey,
          themeMode: themeMode,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          onGenerateRoute: AppRouter.onGenerateRoute,
      home: ValueListenableBuilder<int>(
        valueListenable: authRefreshNotifier,
        builder: (context, refreshCount, _) {
          return StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              debugLog('[AUTH] Auth state changed: hasData=${snapshot.hasData}, uid=${snapshot.data?.uid}, refreshCount=$refreshCount');
              
              final newUserId = snapshot.data?.uid;
              
              // Detect user change (logout -> login with different user)
              if (newUserId != null && _lastUserId != null && newUserId != _lastUserId) {
                debugLog('[AUTH] [WARN] User changed from $_lastUserId to $newUserId - CLEARING ALL CACHE');
                // Clear ALL cached data to force complete refresh
                _cachedUser = null;
                _cachedUserData = null;
                _initialAuthCheckDone = false; // Force fresh data load
                _themeInitialized = false; // Force theme reload for new user
                // Also clear AuthService static state
                AuthService.currentUserData = null;
                AuthService.userType = null;
              }
              
              // Detect fresh login after logout (when _lastUserId is null)
              if (newUserId != null && _lastUserId == null && _cachedUserData != null) {
                debugLog('[AUTH] [WARN] Fresh login detected after logout - CLEARING STALE CACHE');
                _cachedUser = null;
                _cachedUserData = null;
                _initialAuthCheckDone = false;
                _themeInitialized = false;
                AuthService.currentUserData = null;
                AuthService.userType = null;
              }
              
              // Detect logout
              if (newUserId == null && _lastUserId != null) {
                debugLog('[AUTH] User logged out - clearing cache');
                _cachedUser = null;
                _cachedUserData = null;
                _initialAuthCheckDone = true; // Keep true to prevent loading spinner
                _themeInitialized = false; // Reset theme for next user
              }
              
              // Update last user ID
              _lastUserId = newUserId;
              
              // Only show loading on initial auth check, not on theme changes
              if (snapshot.connectionState == ConnectionState.waiting && !_initialAuthCheckDone) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              
              // Update cached user when we get data
              if (snapshot.hasData) {
                _cachedUser = snapshot.data;
                _initialAuthCheckDone = true;
              } else if (snapshot.connectionState == ConnectionState.active) {
                _cachedUser = null;
                _cachedUserData = null;
                _initialAuthCheckDone = true;
              }
              
              // Use cached user to prevent flicker on theme change
              final currentUser = snapshot.data ?? _cachedUser;
              
              if (currentUser != null) {
                // Use a key based on user UID + refreshCount to force FutureBuilder to refresh on re-login
                final userId = currentUser.uid;
                
                // Check if we need to fetch fresh data (new user, no cache, or user switched)
                final needsFreshData = _cachedUserData == null || 
                    _cachedUserData!['uid'] != userId;
                
                return FutureBuilder<Map<String, dynamic>?>(
                  key: ValueKey('$userId-$refreshCount'),
                  future: needsFreshData
                      ? AuthService.getUserData().timeout(
                          const Duration(seconds: 7),
                          onTimeout: () {
                            debugLog('[AUTH] getUserData() timed out after 7 seconds for user $userId');
                            return null;
                          },
                        )
                      : Future.value(_cachedUserData),
                  builder: (context, userSnapshot) {
                    debugLog('[AUTH] FutureBuilder state: connectionState=${userSnapshot.connectionState}, hasData=${userSnapshot.hasData}, needsFresh=$needsFreshData');
                    
                    // Use cached data during loading if available and valid
                    if (userSnapshot.connectionState == ConnectionState.waiting) {
                      if (_cachedUserData != null && _cachedUserData!['uid'] == userId) {
                        // Use cached data - no loading spinner
                        AuthService.userType = (_cachedUserData!['type']);
                        AuthService.currentUserData = _cachedUserData;
                        return (AuthService.userType == 'Resident' || AuthService.userType == 'Guest Resident')
                          ? const ResidentDashboard()
                          : const OfficialDashboard();
                      }
                      // Show loading only if no cached data
                      return const Scaffold(body: Center(child: CircularProgressIndicator()));
                    }
                    if (userSnapshot.hasData && userSnapshot.data != null) {
                        // Cache the user data with uid for validation
                        _cachedUserData = {...userSnapshot.data!, 'uid': userId};
                        AuthService.userType = (userSnapshot.data!['type']);
                        AuthService.currentUserData = userSnapshot.data;
                        _initialAuthCheckDone = true; // Mark as done only after successful data load
                        _nullUserDataRetries = 0;
                        debugLog('[AUTH] [OK] Resolved userType from Firestore: ${AuthService.userType}');
                        
                        // Load saved theme preference BEFORE building dashboard (only once on initial load)
                        if (!_themeInitialized) {
                          final savedMode = (userSnapshot.data!['themeMode'] as String? ?? 'light').toLowerCase();
                          final desired = savedMode == 'dark' ? ThemeMode.dark : ThemeMode.light;
                          if (themeModeNotifier.value != desired) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              themeModeNotifier.value = desired;
                              _themeInitialized = true;
                            });
                          } else {
                            _themeInitialized = true;
                          }
                        }
                        
                        return (AuthService.userType == 'Resident' || AuthService.userType == 'Guest Resident')
                          ? const ResidentDashboard()
                          : const OfficialDashboard();
                }
                
                // Handle error state - don't get stuck
                if (userSnapshot.hasError) {
                  debugLog('[AUTH] [ERR] Error loading user data: ${userSnapshot.error}');
                  _cachedUser = null;
                  _cachedUserData = null;
                  _initialAuthCheckDone = true;
                  return const LoginPage();
                }
                
                // Handle null data after loading completes
                if (userSnapshot.connectionState == ConnectionState.done && userSnapshot.data == null) {
                  // Retry a couple times before giving up (prevents lock on login page after fresh login)
                  if (_nullUserDataRetries < 2) {
                    _nullUserDataRetries++;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      authRefreshNotifier.value += 1;
                    });
                    return const Scaffold(body: Center(child: CircularProgressIndicator()));
                  }

                  // If login already populated static user data, use it as fallback
                  if (AuthService.currentUserData != null && AuthService.userType != null) {
                    return (AuthService.userType == 'Resident' || AuthService.userType == 'Guest Resident')
                        ? const ResidentDashboard()
                        : const OfficialDashboard();
                  }

                  debugLog('[AUTH] [ERR] User data is null after retries - returning to login');
                  _cachedUser = null;
                  _cachedUserData = null;
                  _initialAuthCheckDone = true;
                  return const LoginPage();
                }
                
                debugLog('[AUTH] No user data found or timeout; returning to LoginPage');
                // Clear cache on logout or error
                _cachedUserData = null;
                _initialAuthCheckDone = false; // Reset flag on error
                return const LoginPage();
                  },
                );
              }
              debugLog('[AUTH] No authenticated user; showing LoginPage');
              return const LoginPage();
            },
          );
        },
      ),
        );
      },
    );
  }
}

// ==================== LOGIN PAGE ====================

