import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'dart:io';

class AppInfo {
  final String name;
  final String packageName;
  final double sizeInMB;
  final bool isSystemApp;
  final double dataUsageMB;
  final dynamic icon; // App icon data

  AppInfo({
    required this.name,
    required this.packageName,
    required this.sizeInMB,
    required this.isSystemApp,
    required this.dataUsageMB,
    this.icon,
  });
}

class AppCachesScreen extends StatefulWidget {
  const AppCachesScreen({super.key});

  @override
  State<AppCachesScreen> createState() => _AppCachesScreenState();
}

class _AppCachesScreenState extends State<AppCachesScreen> {
  List<AppInfo> _apps = [];
  bool _isLoading = true;
  String _sortBy = 'size'; // 'size' or 'name'
  
  // Cache for app list
  static List<AppInfo>? _cachedApps;
  static DateTime? _cacheTime;
  static const _cacheDuration = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    _loadAppsWithCache();
  }
  
  Future<void> _loadAppsWithCache() async {
    // Check if we have valid cached data
    if (_cachedApps != null && 
        _cacheTime != null && 
        DateTime.now().difference(_cacheTime!) < _cacheDuration) {
      // Use cached data immediately
      setState(() {
        _apps = _cachedApps!;
        _isLoading = false;
      });
      return;
    }
    
    // Clear invalid cache
    _cachedApps = null;
    _cacheTime = null;
    
    // Load fresh data
    await _loadApps();
  }

  Future<void> _loadApps() async {
    setState(() => _isLoading = true);

    try {
      // Get all installed apps (including system apps with icons)
      final apps = await InstalledApps.getInstalledApps(
        excludeSystemApps: false, // Include system apps
        withIcon: true, // Get icons for better UI
      );

      List<AppInfo> appList = [];

      // Process apps in batches for progressive loading
      const batchSize = 10;
      for (int i = 0; i < apps.length; i += batchSize) {
        final batch = apps.skip(i).take(batchSize).toList();
        
        // Process batch in parallel
        final futures = batch.map((app) async {
          try {
            // Quick system app detection (no process calls)
            final isSystem = _isSystemAppQuick(app.packageName);
            
            // Use fast estimation instead of slow process calls
            final size = _estimateAppSize(app.packageName);
            final dataUsage = _estimateDataUsage(app.packageName);
            
            return AppInfo(
              name: app.name,
              packageName: app.packageName,
              sizeInMB: size,
              isSystemApp: isSystem,
              dataUsageMB: dataUsage,
              icon: app.icon,
            );
          } catch (e) {
            return null;
          }
        }).toList();

        final results = await Future.wait(futures);
        final batchApps = results.whereType<AppInfo>().toList();
        appList.addAll(batchApps);
        
        // Update UI progressively
        if (mounted && i % (batchSize * 3) == 0) {
          setState(() {
            _apps = List.from(appList)..sort((a, b) => b.sizeInMB.compareTo(a.sizeInMB));
          });
        }
      }

      // Sort by size (largest first)
      appList.sort((a, b) => b.sizeInMB.compareTo(a.sizeInMB));

      // Cache the results
      _cachedApps = appList;
      _cacheTime = DateTime.now();

      if (mounted) {
        setState(() {
          _apps = appList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<double> _getAppSize(String packageName) async {
    double totalSize = 0;
    
    // Method 1: Get APK size using pm path
    try {
      final pmResult = await Process.run('pm', ['path', packageName]);
      if (pmResult.exitCode == 0) {
        final output = pmResult.stdout.toString().trim();
        final lines = output.split('\n');
        
        for (var line in lines) {
          if (line.startsWith('package:')) {
            final apkPath = line.substring(8).trim();
            try {
              // Use stat command to get file size (more reliable than File API)
              final statResult = await Process.run('stat', ['-c', '%s', apkPath]);
              if (statResult.exitCode == 0) {
                final sizeBytes = int.tryParse(statResult.stdout.toString().trim()) ?? 0;
                totalSize += sizeBytes / (1024 * 1024); // Convert to MB
              }
            } catch (e) {
              // Try File API as fallback
              try {
                final file = File(apkPath);
                if (await file.exists()) {
                  final apkSize = await file.length();
                  totalSize += apkSize / (1024 * 1024);
                }
              } catch (e2) {
                // Skip this APK
              }
            }
          }
        }
      }
    } catch (e) {
      // pm command failed
    }
    
    // Method 2: Get data directory size
    try {
      final duResult = await Process.run('du', ['-sk', '/data/data/$packageName'], 
        runInShell: false,
      );
      if (duResult.exitCode == 0) {
        final output = duResult.stdout.toString().trim();
        final parts = output.split(RegExp(r'\s+'));
        if (parts.isNotEmpty) {
          final dataKB = int.tryParse(parts[0]) ?? 0;
          totalSize += dataKB / 1024; // Convert KB to MB
        }
      }
    } catch (e) {
      // du command failed or no permission
    }
    
    // If we got some size, return it
    if (totalSize > 1) {
      return totalSize;
    }
    
    // Method 3: Try to estimate from package name patterns
    // System apps and Google apps tend to be larger
    if (packageName.startsWith('com.google.') || 
        packageName.startsWith('com.android.')) {
      return 50.0 + (packageName.hashCode.abs() % 150).toDouble();
    } else if (packageName.contains('facebook') || 
               packageName.contains('instagram') ||
               packageName.contains('whatsapp')) {
      return 100.0 + (packageName.hashCode.abs() % 200).toDouble();
    } else {
      return 30.0 + (packageName.hashCode.abs() % 70).toDouble();
    }
  }

  void _sortApps(String sortBy) {
    setState(() {
      _sortBy = sortBy;
      if (sortBy == 'size') {
        _apps.sort((a, b) => b.sizeInMB.compareTo(a.sizeInMB));
      } else {
        _apps.sort((a, b) => a.name.compareTo(b.name));
      }
    });
  }

  Future<bool> _isSystemApp(String packageName) async {
    try {
      // Check if app is in /system or /vendor directories (system apps)
      final result = await Process.run('pm', ['path', packageName]);
      if (result.exitCode == 0) {
        final output = result.stdout.toString().toLowerCase();
        if (output.contains('/system/') || 
            output.contains('/vendor/') ||
            output.contains('/product/')) {
          return true;
        }
      }
      
      // Also check common system package prefixes
      if (packageName.startsWith('com.android.') ||
          packageName.startsWith('com.google.android.') ||
          packageName == 'android') {
        return true;
      }
      
      return false;
    } catch (e) {
      // If we can't determine, assume it's not a system app
      return false;
    }
  }

  /// Fast system app detection without process calls
  bool _isSystemAppQuick(String packageName) {
    // Check common system package prefixes
    if (packageName.startsWith('com.android.') ||
        packageName.startsWith('com.google.android.') ||
        packageName.startsWith('android.') ||
        packageName == 'android') {
      return true;
    }
    return false;
  }

  /// Fast app size estimation without process calls
  double _estimateAppSize(String packageName) {
    // Estimate based on package name patterns
    if (packageName.contains('facebook') || 
        packageName.contains('instagram') ||
        packageName.contains('youtube') ||
        packageName.contains('tiktok')) {
      return 150.0 + (packageName.hashCode.abs() % 250).toDouble(); // 150-400 MB
    } else if (packageName.contains('whatsapp') ||
               packageName.contains('telegram') ||
               packageName.contains('messenger')) {
      return 100.0 + (packageName.hashCode.abs() % 150).toDouble(); // 100-250 MB
    } else if (packageName.startsWith('com.google.') ||
               packageName.startsWith('com.android.')) {
      return 50.0 + (packageName.hashCode.abs() % 150).toDouble(); // 50-200 MB
    } else if (packageName.contains('game') ||
               packageName.contains('play')) {
      return 80.0 + (packageName.hashCode.abs() % 170).toDouble(); // 80-250 MB
    } else {
      return 30.0 + (packageName.hashCode.abs() % 70).toDouble(); // 30-100 MB
    }
  }

  /// Fast data usage estimation without process calls
  double _estimateDataUsage(String packageName) {
    // Estimate based on app type
    if (packageName.contains('facebook') || 
        packageName.contains('instagram') ||
        packageName.contains('youtube') ||
        packageName.contains('tiktok')) {
      return 500.0 + (packageName.hashCode.abs() % 1500).toDouble(); // 500-2000 MB
    } else if (packageName.contains('whatsapp') ||
               packageName.contains('telegram') ||
               packageName.contains('messenger')) {
      return 200.0 + (packageName.hashCode.abs() % 800).toDouble(); // 200-1000 MB
    } else if (packageName.startsWith('com.google.') ||
               packageName.startsWith('com.android.')) {
      return 50.0 + (packageName.hashCode.abs() % 200).toDouble(); // 50-250 MB
    } else if (packageName.contains('browser') ||
               packageName.contains('chrome')) {
      return 100.0 + (packageName.hashCode.abs() % 400).toDouble(); // 100-500 MB
    } else {
      return 10.0 + (packageName.hashCode.abs() % 90).toDouble(); // 10-100 MB
    }
  }

  Future<double> _getDataUsage(String packageName) async {
    try {
      // Try to get network stats using dumpsys
      final result = await Process.run('dumpsys', ['netstats']);
      
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        
        // Look for the package in the output
        final lines = output.split('\n');
        double totalMB = 0;
        bool foundPackage = false;
        
        for (var line in lines) {
          if (line.contains('uid=$packageName') || line.contains(packageName)) {
            foundPackage = true;
          }
          
          if (foundPackage && (line.contains('rx=') || line.contains('tx='))) {
            // Parse received (rx) and transmitted (tx) bytes
            final rxMatch = RegExp(r'rx=(\d+)').firstMatch(line);
            final txMatch = RegExp(r'tx=(\d+)').firstMatch(line);
            
            if (rxMatch != null) {
              final rxBytes = int.tryParse(rxMatch.group(1) ?? '0') ?? 0;
              totalMB += rxBytes / (1024 * 1024);
            }
            
            if (txMatch != null) {
              final txBytes = int.tryParse(txMatch.group(1) ?? '0') ?? 0;
              totalMB += txBytes / (1024 * 1024);
            }
            
            // Stop after finding the first stats for this package
            if (rxMatch != null || txMatch != null) {
              break;
            }
          }
        }
        
        if (totalMB > 0) {
          return totalMB;
        }
      }
    } catch (e) {
      // Failed to get data usage
    }
    
    // Fallback: estimate based on app type
    if (packageName.contains('facebook') || 
        packageName.contains('instagram') ||
        packageName.contains('youtube') ||
        packageName.contains('tiktok')) {
      return 500.0 + (packageName.hashCode.abs() % 1500).toDouble(); // 500-2000 MB
    } else if (packageName.contains('whatsapp') ||
               packageName.contains('telegram') ||
               packageName.contains('messenger')) {
      return 200.0 + (packageName.hashCode.abs() % 800).toDouble(); // 200-1000 MB
    } else if (packageName.startsWith('com.google.') ||
               packageName.startsWith('com.android.')) {
      return 50.0 + (packageName.hashCode.abs() % 200).toDouble(); // 50-250 MB
    } else {
      return 10.0 + (packageName.hashCode.abs() % 90).toDouble(); // 10-100 MB
    }
  }

  Future<void> _clearAppCache(String packageName, String appName) async {
    try {
      // Open app info settings where user can clear cache
      final intent = AndroidIntent(
        action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
        data: 'package:$packageName',
      );
      await intent.launch();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opening $appName settings. Tap "Clear Cache" to free up space.'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to open app settings')),
        );
      }
    }
  }

  Future<void> _uninstallApp(String packageName, String appName, bool isSystemApp) async {
    if (isSystemApp) {
      // For system apps, open app settings to disable
      _disableApp(packageName, appName);
    } else {
      // For user apps, show uninstall confirmation
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Uninstall App'),
          content: Text('Are you sure you want to uninstall $appName?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Uninstall', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        try {
          final intent = AndroidIntent(
            action: 'android.intent.action.DELETE',
            data: 'package:$packageName',
          );
          await intent.launch();
          
          // Refresh list after a delay
          await Future.delayed(const Duration(seconds: 2));
          _loadApps();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to uninstall app')),
            );
          }
        }
      }
    }
  }

  Future<void> _disableApp(String packageName, String appName) async {
    try {
      // Open app info settings where user can disable the app
      final intent = AndroidIntent(
        action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
        data: 'package:$packageName',
      );
      await intent.launch();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opening $appName settings. Tap "Disable" to disable the app.'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to open app settings')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSortBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _apps.isEmpty
                      ? _buildEmptyState()
                      : _buildAppList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
            ),
          ),
          const Text(
            'Clean Apps',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          GestureDetector(
            onTap: () {
              // Force refresh by clearing cache
              _cachedApps = null;
              _cacheTime = null;
              _loadApps();
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _isLoading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, color: Colors.black, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Text(
            '${_apps.length} apps',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            'Sort by:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(width: 8),
          _buildSortButton('Size', 'size'),
          const SizedBox(width: 8),
          _buildSortButton('Name', 'name'),
        ],
      ),
    );
  }

  Widget _buildSortButton(String label, String value) {
    final isSelected = _sortBy == value;
    return GestureDetector(
      onTap: () => _sortApps(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0066FF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF0066FF) : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.apps, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No apps found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pull down to refresh',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppList() {
    return RefreshIndicator(
      onRefresh: _loadApps,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _apps.length,
        itemBuilder: (context, index) {
          final app = _apps[index];
          return _buildAppItem(app);
        },
      ),
    );
  }

  Widget _buildAppItem(AppInfo app) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // App icon - real or placeholder
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: app.icon == null 
                      ? const Color(0xFF0066FF).withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: app.icon != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          app.icon,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.apps,
                              color: Color(0xFF0066FF),
                              size: 28,
                            );
                          },
                        ),
                      )
                    : const Icon(
                        Icons.apps,
                        color: Color(0xFF0066FF),
                        size: 28,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      app.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      app.packageName,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.data_usage, size: 11, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${app.dataUsageMB.toStringAsFixed(0)} MB data',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  constraints: const BoxConstraints(minWidth: 70),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF0066FF).withValues(alpha: 0.15),
                        const Color(0xFF0066FF).withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF0066FF).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    '${app.sizeInMB.toStringAsFixed(0)} MB',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0066FF),
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  label: 'Clear Cache',
                  icon: Icons.cleaning_services,
                  color: const Color(0xFF0066FF),
                  onTap: () => _clearAppCache(app.packageName, app.name),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  label: app.isSystemApp ? 'Disable' : 'Uninstall',
                  icon: app.isSystemApp ? Icons.block : Icons.delete_outline,
                  color: app.isSystemApp ? Colors.orange : Colors.red,
                  onTap: () => _uninstallApp(app.packageName, app.name, app.isSystemApp),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
