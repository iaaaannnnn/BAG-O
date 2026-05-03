part of '../../app/app.dart';

Widget buildImageFromUrl(String imageUrl, {double? height, double? width, BoxFit fit = BoxFit.cover}) {
  Widget placeholder() => Container(
        height: height,
        width: width,
        color: Colors.grey[300],
        child: const Icon(Icons.image_not_supported),
      );

  try {
    final trimmed = imageUrl.trim();
    if (trimmed.isEmpty) return placeholder();

    if (trimmed.startsWith('data:image')) {
      // Base64 data URI
      final parts = trimmed.split(',');
      if (parts.length == 2) {
        final base64String = parts[1];
        final decodedBytes = base64Decode(base64String);
        return Image.memory(
          decodedBytes,
          height: height,
          width: width,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => placeholder(),
        );
      }
    } else {
      // Network URL
      return Image.network(
        trimmed,
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => placeholder(),
      );
    }
  } catch (e) {
    debugLog('Error displaying image: $e');
  }
  return placeholder();
}

// Resolve image providers for profile avatars (supports base64 data URIs and network URLs)
ImageProvider? resolveImageProvider(String? imageUrl) {
  if (imageUrl == null) return null;
  final trimmed = imageUrl.trim();
  if (trimmed.isEmpty) return null;

  if (trimmed.startsWith('data:image')) {
    try {
      final base64String = trimmed.split(',').last;
      final decodedBytes = base64Decode(base64String);
      return MemoryImage(decodedBytes);
    } catch (e) {
      debugLog('Error decoding base64 image: $e');
      return null;
    }
  }

  return NetworkImage(trimmed);
}

// Guest Resident Account Expiration Warning Widget
Widget buildGuestExpirationWarning(BuildContext context) {
  final expirationInfo = AuthService.getGuestExpirationInfo();
  
  if (expirationInfo == null) return const SizedBox.shrink();
  
  final isExpired = expirationInfo['isExpired'] as bool;
  final canRenew = expirationInfo['canRenew'] as bool;
  final daysRemaining = expirationInfo['daysRemaining'] as int;
  final message = expirationInfo['renewalMessage'] as String;
  
  // Don't show if more than 7 days remaining
  if (daysRemaining > 7 && !canRenew && !isExpired) {
    return const SizedBox.shrink();
  }
  
  final theme = Theme.of(context);
  Color warningColor = const Color(0xFFFFA726); // Orange for warning
  IconData warningIcon = Icons.warning_amber;
  
  if (canRenew) {
    warningColor = const Color(0xFFFF7043); // Red-orange for urgent
    warningIcon = Icons.error;
  } else if (isExpired) {
    warningColor = const Color(0xFFEF5350); // Red for expired
    warningIcon = Icons.cancel;
  }
  
  return Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: warningColor.withOpacity(0.1),
      border: Border.all(color: warningColor, width: 2),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(warningIcon, color: warningColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isExpired ? 'Account Expired' : canRenew ? 'Renew Account Now' : 'Account Expiring',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: warningColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(color: warningColor),
        ),
        const SizedBox(height: 12),
        if (canRenew)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showRenewDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: warningColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('RENEW ACCOUNT'),
            ),
          )
        else if (isExpired)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('CONTACT BARANGAY OFFICE TO REACTIVATE'),
            ),
          ),
      ],
    ),
  );
}

void _showRenewDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Renew Account'),
      content: const Text('Renew your guest resident account for another 30 days?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(ctx);
            final success = await AuthService.renewGuestAccount();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success 
                      ? 'Account renewed for 30 more days!' 
                      : 'Failed to renew account. Please try again.',
                  ),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF7043),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('RENEW'),
        ),
      ],
    ),
  );
}

// Notification Service

