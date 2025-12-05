import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Service class responsible for scanning and cleaning junk files
/// 
/// Targets major junk directories:
/// - Thumbnails (200MB-3GB)
/// - Old Downloads (100MB-2GB)
/// - Temp Files (50MB-500MB)
/// - WhatsApp/Telegram leftovers (up to several GB)
/// - Residual app folders (left after uninstall)
class JunkCleanerService {
  // List of files found during scan
  final List<FileSystemEntity> _junkFiles = [];
  
  // Total size of junk found in bytes
  int _totalJunkSize = 0;

  // Categorized junk sizes
  int _cacheFilesSize = 0;
  int _tempFilesSize = 0;
  int _bigFilesSize = 0;

  /// Scans the device for junk files and returns total size in bytes
  Future<int> scanJunk() async {
    _junkFiles.clear();
    _totalJunkSize = 0;
    _cacheFilesSize = 0;
    _tempFilesSize = 0;
    _bigFilesSize = 0;

    try {
      // 1. Scan thumbnails
      await _scanThumbnails();

      // 2. Scan temp files
      await _scanTempFiles();

      // 3. Scan old downloads
      await _scanOldDownloads();

      // 4. Scan WhatsApp/Telegram junk
      await _scanSocialMediaJunk();

      // 5. Scan residual app folders
      await _scanResidualAppFolders();

      // 6. Scan app's own directories
      await _scanAppDirectories();

    } catch (e) {
      // Error during scan - silently continue
    }

    return _totalJunkSize;
  }
  
  /// Get categorized sizes in GB
  double get cacheFilesSizeGB => _cacheFilesSize / (1024 * 1024 * 1024);
  double get tempFilesSizeGB => _tempFilesSize / (1024 * 1024 * 1024);
  double get bigFilesSizeGB => _bigFilesSize / (1024 * 1024 * 1024);
  
  /// Get categorized sizes in bytes (for verification)
  int get cacheFilesSizeBytes => _cacheFilesSize;
  int get tempFilesSizeBytes => _tempFilesSize;
  int get bigFilesSizeBytes => _bigFilesSize;
  
  /// Verify that categories add up to total (for debugging)
  bool get categoriesValid => (_cacheFilesSize + _tempFilesSize + _bigFilesSize) == _totalJunkSize;

  /// Deletes all scanned junk files and returns cleaned size in bytes
  Future<int> cleanJunk() async {
    int cleanedSize = 0;

    for (var entity in _junkFiles) {
      try {
        if (await entity.exists()) {
          // Get size before deletion
          int size = 0;
          if (entity is File) {
            size = await entity.length();
          } else if (entity is Directory) {
            size = await _getDirectorySize(entity);
          }

          // Delete the file or directory
          await entity.delete(recursive: true);
          cleanedSize += size;
        }
      } catch (e) {
        // Failed to delete - silently continue
      }
    }

    // Clear the list after cleaning
    _junkFiles.clear();
    _totalJunkSize = 0;
    _cacheFilesSize = 0;
    _tempFilesSize = 0;
    _bigFilesSize = 0;

    return cleanedSize;
  }

  /// Scan thumbnails directory (200MB-3GB)
  Future<void> _scanThumbnails() async {
    final thumbnailPaths = [
      '/storage/emulated/0/DCIM/.thumbnails',
      '/storage/emulated/0/Pictures/.thumbnails',
    ];

    for (var path in thumbnailPaths) {
      final dir = Directory(path);
      if (await dir.exists()) {
        try {
          await for (var entity in dir.list(recursive: true)) {
            if (entity is File) {
              try {
                final size = await entity.length();
                _junkFiles.add(entity);
                _totalJunkSize += size;
                _cacheFilesSize += size;
              } catch (e) {
                // Skip files we can't access
              }
            }
          }
        } catch (e) {
          // Skip directory if we can't access
        }
      }
    }
  }

  /// Scan temp files (50MB-500MB)
  Future<void> _scanTempFiles() async {
    final tempPaths = [
      '/storage/emulated/0/temp',
      '/storage/emulated/0/Download/temp',
      '/storage/emulated/0/Android/media',
    ];

    for (var path in tempPaths) {
      final dir = Directory(path);
      if (await dir.exists()) {
        try {
          await for (var entity in dir.list(recursive: true)) {
            if (entity is File) {
              try {
                // Check if it's a temp file
                if (entity.path.toLowerCase().contains('temp') ||
                    entity.path.endsWith('.tmp') ||
                    entity.path.endsWith('.temp')) {
                  final size = await entity.length();
                  _junkFiles.add(entity);
                  _totalJunkSize += size;
                  _tempFilesSize += size;
                }
              } catch (e) {
                // Skip files we can't access
              }
            }
          }
        } catch (e) {
          // Skip directory if we can't access
        }
      }
    }
  }

  /// Scan old downloads (100MB-2GB) - files older than 30 days
  Future<void> _scanOldDownloads() async {
    final downloadPaths = [
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Downloads',
    ];

    final now = DateTime.now();
    const daysOld = 30;

    for (var path in downloadPaths) {
      final dir = Directory(path);
      if (await dir.exists()) {
        try {
          await for (var entity in dir.list(recursive: false)) {
            if (entity is File) {
              try {
                final stat = await entity.stat();
                final age = now.difference(stat.modified).inDays;
                
                if (age > daysOld) {
                  final size = await entity.length();
                  _junkFiles.add(entity);
                  _totalJunkSize += size;
                  _bigFilesSize += size;
                }
              } catch (e) {
                // Skip files we can't access
              }
            }
          }
        } catch (e) {
          // Skip directory if we can't access
        }
        break; // Use first existing path
      }
    }
  }

  /// Scan WhatsApp and Telegram junk (up to several GB)
  Future<void> _scanSocialMediaJunk() async {
    final socialMediaPaths = [
      // WhatsApp
      '/storage/emulated/0/WhatsApp/Media/.Statuses',
      '/storage/emulated/0/WhatsApp/Media/WhatsApp Animated Gifs',
      '/storage/emulated/0/WhatsApp/Media/WhatsApp Video',
      '/storage/emulated/0/WhatsApp/Media/WhatsApp Images',
      '/storage/emulated/0/WhatsApp/Media/WhatsApp Audio',
      // Telegram
      '/storage/emulated/0/Telegram/Telegram Images',
      '/storage/emulated/0/Telegram/Telegram Video',
      '/storage/emulated/0/Telegram/Telegram Audio',
      '/storage/emulated/0/Telegram/Telegram Documents',
    ];

    for (var path in socialMediaPaths) {
      final dir = Directory(path);
      if (await dir.exists()) {
        try {
          await for (var entity in dir.list(recursive: true)) {
            if (entity is File) {
              try {
                final size = await entity.length();
                _junkFiles.add(entity);
                _totalJunkSize += size;
                _bigFilesSize += size;
              } catch (e) {
                // Skip files we can't access
              }
            }
          }
        } catch (e) {
          // Skip directory if we can't access
        }
      }
    }
  }

  /// Scan residual app folders (left after uninstall)
  /// Note: We scan but don't automatically delete these as they might be from active apps
  /// This is a conservative approach to avoid deleting important data
  Future<void> _scanResidualAppFolders() async {
    // Skip this for now as we can't reliably detect uninstalled apps without root
    // The Android/data and Android/obb folders are protected and require special permissions
    // Users can manually clean these through Android Settings > Storage
    return;
  }

  /// Scan app's own directories
  Future<void> _scanAppDirectories() async {
    try {
      // Scan app's temporary directory
      final tempDir = await getTemporaryDirectory();
      await _scanDirectory(tempDir, isTemp: true);

      // Scan app's application support directory
      final appSupportDir = await getApplicationSupportDirectory();
      await _scanDirectory(appSupportDir, isCache: true);
    } catch (e) {
      // Error scanning app directories
    }
  }

  /// Scans a directory recursively for junk files
  Future<void> _scanDirectory(Directory directory, {bool isTemp = false, bool isCache = false}) async {
    try {
      if (!await directory.exists()) return;

      final entities = directory.listSync(recursive: true, followLinks: false);

      for (var entity in entities) {
        try {
          if (entity is File) {
            final fileSize = await entity.length();
            
            // Check if file has junk extension
            if (_isJunkFile(entity)) {
              _junkFiles.add(entity);
              _totalJunkSize += fileSize;
              
              // Categorize by type
              final pathLower = entity.path.toLowerCase();
              if (isTemp || pathLower.contains('.tmp') || pathLower.contains('temp') || pathLower.contains('/tmp/')) {
                _tempFilesSize += fileSize;
              } else if (isCache || pathLower.contains('.cache') || pathLower.contains('cache') || pathLower.contains('/cache/')) {
                _cacheFilesSize += fileSize;
              } else if (fileSize > 10 * 1024 * 1024) { // Files > 10MB are "big files"
                _bigFilesSize += fileSize;
              } else {
                // Default: smaller misc files go to temp
                _tempFilesSize += fileSize;
              }
            }
          } else if (entity is Directory) {
            // Check if directory is empty
            if (await _isEmptyDirectory(entity)) {
              _junkFiles.add(entity);
            }
          }
        } catch (e) {
          // Skip files we can't access
          continue;
        }
      }
    } catch (e) {
      // Error scanning directory - silently continue
    }
  }



  /// Get directory size recursively
  Future<int> _getDirectorySize(Directory directory) async {
    int totalSize = 0;
    try {
      await for (var entity in directory.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            totalSize += await entity.length();
          } catch (e) {
            // Skip files we can't access
          }
        }
      }
    } catch (e) {
      // Error calculating size
    }
    return totalSize;
  }

  /// Checks if a file is considered junk based on extension
  bool _isJunkFile(File file) {
    final junkExtensions = [
      '.tmp',
      '.log',
      '.bak',
      '.cache',
      '.temp',
      '.old',
      '.dmp',
      '.crdownload',
      '.part',
      '.download',
    ];
    
    final fileName = file.path.toLowerCase();
    return junkExtensions.any((ext) => fileName.endsWith(ext));
  }

  /// Checks if a directory is empty
  Future<bool> _isEmptyDirectory(Directory directory) async {
    try {
      final entities = await directory.list().toList();
      return entities.isEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Formats bytes to human-readable format (MB)
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    const int mb = 1024 * 1024;
    return (bytes / mb).toStringAsFixed(2);
  }

  /// Gets the number of junk files found
  int get junkFileCount => _junkFiles.length;
}
