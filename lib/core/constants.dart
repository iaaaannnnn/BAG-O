part of '../app/app.dart';


// Debug logger helper (stripped in production builds)
void debugLog(String message) {
  if (kDebugLogging) {
    debugPrint(message);
  }
}

const bool kDebugLogging = !bool.fromEnvironment('dart.vm.product') && !bool.fromEnvironment('dart.vm.profile');


// Global notifier to force UI rebuild on login/logout when authStateChanges() doesn't fire
final ValueNotifier<int> authRefreshNotifier = ValueNotifier(0);

// Global navigator key to allow safe navigation from service code (e.g., logout)
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

// Helper function to format barangay address
String formatBarangayAddress(Map<String, dynamic>? userData) {
  if (userData == null) return 'Unknown Location';
  final brgy = userData['barangay'] as String? ?? '';
  final muni = userData['municipality'] as String? ?? '';
  final prov = userData['province'] as String? ?? '';
  final parts = <String>[];
  if (brgy.isNotEmpty) parts.add(brgy.startsWith('Brgy. ') || brgy.startsWith('Barangay ') ? brgy : 'Brgy. $brgy');
  if (muni.isNotEmpty) parts.add(muni);
  if (prov.isNotEmpty) parts.add(prov.length > 4 ? prov.substring(0, 3).toUpperCase() : prov);
  return parts.isEmpty ? 'Unknown Location' : parts.join(', ');
}

enum ProfileAction { viewProfile, settings, logout }

// Note: For uppercase input, use textCapitalization: TextCapitalization.characters
// instead of a TextInputFormatter, as formatters can interrupt mobile keyboard IME.

const String _bagoAboutText =
    'BAG-O stands for Barangay Automated Governance and Operation. It modernizes barangay transactions, information management, resident services, announcements, transparency documents, complaints, and emergency contact access in one organized system.';


