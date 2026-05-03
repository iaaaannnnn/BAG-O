part of '../../app/app.dart';

class ThrottleHelper {
  static final Map<String, DateTime> _lastActionTime = {};
  
  static bool canExecute(String key, int delayMs) {
    final now = DateTime.now();
    final lastTime = _lastActionTime[key];
    if (lastTime == null) {
      _lastActionTime[key] = now;
      return true;
    }
    if (now.difference(lastTime).inMilliseconds >= delayMs) {
      _lastActionTime[key] = now;
      return true;
    }
    return false;
  }
  
  static void reset(String key) {
    _lastActionTime.remove(key);
  }
}

class ImageCompressionHelper {
  static const int maxImageSizeBytes = 10 * 1024 * 1024; // 10MB
  static const int maxDocumentSizeBytes = 10 * 1024 * 1024; // 10MB
  static const int maxUploadSizeBytes = 2 * 1024 * 1024; // 2MB for uploads

  /// Compresses an image file aggressively to ensure it's under 2MB for reliable uploads
  /// This is the recommended method for user uploads (complaints, profile pics, etc.)
  static Future<File?> compressForUpload(File imageFile, {int quality = 80, int maxWidth = 1200, int maxHeight = 1200}) async {
    try {
      final fileSize = await imageFile.length();
      debugLog('[ImageCompression] Original file size: ${fileSize ~/ 1024}KB');
      
      Uint8List? finalBytes;
      int currentQuality = quality;
      int currentMaxWidth = maxWidth;
      int currentMaxHeight = maxHeight;
      
      // Iteratively compress until under 2MB or limits reached
      while (true) {
        final compressedBytes = await FlutterImageCompress.compressWithFile(
          imageFile.absolute.path,
          quality: currentQuality,
          minWidth: currentMaxWidth,
          minHeight: currentMaxHeight,
          keepExif: false,
        );

        if (compressedBytes == null) {
          debugLog('[ImageCompression] Compression failed');
          return null;
        }

        debugLog('[ImageCompression] Compressed to ${compressedBytes.length ~/ 1024}KB with quality $currentQuality, dimensions ${currentMaxWidth}x$currentMaxHeight');
        
        // Check if size is acceptable
        if (compressedBytes.length <= maxUploadSizeBytes) {
          finalBytes = compressedBytes;
          break;
        }
        
        // Try reducing quality first
        if (currentQuality > 30) {
          currentQuality -= 15;
          debugLog('[ImageCompression] Still too large (${compressedBytes.length ~/ 1024}KB), trying lower quality $currentQuality');
          continue;
        }
        
        // Quality is at minimum, try reducing dimensions
        if (currentMaxWidth > 600) {
          currentMaxWidth -= 300;
          currentMaxHeight -= 300;
          currentQuality = 50; // Reset quality when reducing dimensions
          debugLog('[ImageCompression] Quality at minimum, reducing dimensions to ${currentMaxWidth}x$currentMaxHeight');
          continue;
        }
        
        // Cannot compress further, use best effort
        debugLog('[ImageCompression] Could not compress below 2MB, using best effort');
        finalBytes = compressedBytes;
        break;
      }

      if (finalBytes == null) {
        debugLog('[ImageCompression] No compressed bytes available');
        return null;
      }

      // Create a new file with compressed data in temp directory for reliable access
      final tempDir = await Directory.systemTemp.createTemp('img_upload_');
      final compressedFile = File('${tempDir.path}/upload_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await compressedFile.writeAsBytes(finalBytes);
      
      // Verify the file was written correctly
      if (!await compressedFile.exists()) {
        debugLog('[ImageCompression] Failed to create compressed file');
        return null;
      }
      
      final writtenSize = await compressedFile.length();
      debugLog('[ImageCompression] Final file size: ${writtenSize ~/ 1024}KB (${(writtenSize / (1024 * 1024)).toStringAsFixed(2)}MB)');
      debugLog('[ImageCompression] Compressed file path: ${compressedFile.path}');
      return compressedFile;
    } catch (e) {
      debugLog('[ImageCompression] Error compressing image for upload: $e');
      return null;
    }
  }

  /// Compresses an image file if it exceeds the maximum size
  /// Returns the compressed file or original file if already small enough
  static Future<File?> compressImage(File imageFile, {int quality = 85}) async {
    try {
      final fileSize = await imageFile.length();
      
      // If file is already under 10MB, return as-is
      if (fileSize <= maxImageSizeBytes) {
        return imageFile;
      }

      debugLog('[ImageCompression] Compressing image from ${fileSize ~/ 1024}KB to under 10MB');
      
      // Compress the image
      final compressedBytes = await FlutterImageCompress.compressWithFile(
        imageFile.absolute.path,
        quality: quality,
        minWidth: 512,
        minHeight: 512,
        keepExif: false,
      );

      if (compressedBytes == null) {
        debugLog('[ImageCompression] Compression failed');
        return null;
      }

      // If still too large, try with lower quality
      if (compressedBytes.length > maxImageSizeBytes && quality > 50) {
        debugLog('[ImageCompression] Still too large, trying lower quality');
        return compressImage(imageFile, quality: quality - 20);
      }

      // Create a new file with compressed data
      final compressedFile = File('${imageFile.path}_compressed.jpg');
      await compressedFile.writeAsBytes(compressedBytes);
      
      debugLog('[ImageCompression] Compressed to ${compressedBytes.length ~/ 1024}KB');
      return compressedFile;
    } catch (e) {
      debugLog('[ImageCompression] Error compressing image: $e');
      return null;
    }
  }

  /// Validates file size and shows appropriate warnings
  static Future<bool> validateFileSize(BuildContext context, File file, String fileType, {bool isOfficial = false}) async {
    final fileSize = await file.length();
    final maxSize = fileType.startsWith('image/') ? maxImageSizeBytes : maxDocumentSizeBytes;
    
    if (fileSize > maxSize) {
      final sizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(1);
      final maxSizeMB = (maxSize / (1024 * 1024)).toStringAsFixed(0);
      
      if (isOfficial) {
        // Show banner for officials
        if (context.mounted) {
          ScaffoldMessenger.of(context).showMaterialBanner(
            MaterialBanner(
              content: Text(
                'File too large: ${sizeMB}MB (max ${maxSizeMB}MB)\n\nPlease select a smaller file or compress it before uploading.',
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
      } else {
        // Show dialog for residents/guests
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('File Too Large'),
              content: Text('The selected file is ${sizeMB}MB. Maximum allowed size is ${maxSizeMB}MB.\n\nPlease select a smaller file.'),
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
      return false;
    }
    
    return true;
  }
}


