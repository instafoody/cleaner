import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math' as math;
import 'package:android_intent_plus/android_intent.dart';
import 'services/junk_cleaner_service.dart';
import 'services/storage_service.dart';
import 'services/memory_service.dart';
import 'screens/memory_boost_screen.dart';
import 'screens/app_caches_screen.dart';

void main() {
  runApp(const CleanLiteProApp());
}

class CleanLiteProApp extends StatelessWidget {
  const CleanLiteProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cleaning Ninja',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0066FF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  final JunkCleanerService _cleanerService = JunkCleanerService();
  final StorageService _storageService = StorageService();
  final MemoryService _memoryService = MemoryService();

  bool _isScanning = false;
  bool _hasScanned = false;
  double _junkSizeGB = 0.0;
  int _junkFileCount = 0;

  // Storage info for cards
  StorageInfo? _systemStorageInfo;
  StorageInfo? _downloadsInfo;
  MemoryInfo? _memoryInfo;
  double _appCachesGB = 0.0;

  AnimationController? _scanController;
  Animation<double>? _scanAnimation;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _scanAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scanController!, curve: Curves.easeInOut),
    );
    _loadStorageInfo();
    _scanPhone();
  }

  Future<void> _loadStorageInfo() async {
    final systemInfo = await _storageService.getSystemStorageInfo();
    final downloadsInfo = await _storageService.getDownloadsInfo();
    final memoryInfo = await _memoryService.getMemoryInfo();
    final appCaches = await _storageService.getAppCachesSize();

    if (mounted) {
      setState(() {
        _systemStorageInfo = systemInfo;
        _downloadsInfo = downloadsInfo;
        _memoryInfo = memoryInfo;
        _appCachesGB = appCaches;
      });
    }
  }

  @override
  void dispose() {
    _scanController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: Column(
                    children: [
                      _buildHeader(),
                      SizedBox(height: constraints.maxHeight * 0.04),
                      _buildCircularProgress(constraints),
                      SizedBox(height: constraints.maxHeight * 0.04),
                      _buildSmartCleaningButton(),
                      SizedBox(height: constraints.maxHeight * 0.03),
                      _buildFeatureGrid(constraints),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.menu, color: Color(0xFF0066FF), size: 20),
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey[300],
            child: const Icon(Icons.person, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildCircularProgress(BoxConstraints constraints) {
    final size = constraints.maxWidth * 0.7 > 280 ? 280.0 : constraints.maxWidth * 0.7;
    
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),
          if (_scanAnimation != null)
            AnimatedBuilder(
              animation: _scanAnimation!,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(size * 0.85, size * 0.85),
                  painter: CircularProgressPainter(
                    progress: _isScanning
                        ? _scanAnimation!.value
                        : (_hasScanned ? 1.0 : 0.0),
                    color: const Color(0xFF0066FF),
                  ),
                );
              },
            ),
          if (_isScanning && _scanController != null) _buildAnimatedDots(size),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _junkSizeGB >= 1.0 
                    ? '${_junkSizeGB.toStringAsFixed(2)} GB'
                    : '${(_junkSizeGB * 1024).toStringAsFixed(0)} MB',
                style: TextStyle(
                  fontSize: size * 0.18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: size * 0.02),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _isScanning
                      ? 'Scanning...'
                      : _junkFileCount == 0
                          ? 'No junk found'
                          : '$_junkFileCount junk file${_junkFileCount != 1 ? 's' : ''}\n to be cleaned.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: size * 0.05,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedDots(double size) {
    final dotSize = size * 0.93;
    final dotRadius = size * 0.39;
    
    return SizedBox(
      width: dotSize,
      height: dotSize,
      child: Stack(
        children: List.generate(6, (index) {
          return AnimatedBuilder(
            animation: _scanController!,
            builder: (context, child) {
              final angle =
                  (index * math.pi / 3) + (_scanController!.value * 2 * math.pi);
              final x = dotSize / 2 + dotRadius * math.cos(angle);
              final y = dotSize / 2 + dotRadius * math.sin(angle);
              return Positioned(
                left: x - 6,
                top: y - 6,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0066FF),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  Widget _buildSmartCleaningButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0066FF), Color(0xFF0052CC)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0066FF).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: (_isScanning || _junkFileCount == 0) ? null : _openCleaningScreen,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_fix_high, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                _isScanning ? 'Scanning...' : (_junkFileCount == 0 ? 'No Junk Found' : 'Clean Now'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureGrid(BoxConstraints constraints) {
    // Prepare real data for each card with better formatting
    String memorySubtitle = 'Free up RAM';
    if (_memoryInfo != null) {
      try {
        final usagePercent = _memoryService.getMemoryUsagePercentage(_memoryInfo!);
        if (_memoryInfo!.hasVirtualRAM) {
          // Show physical + virtual RAM separately
          memorySubtitle = '${usagePercent.toStringAsFixed(0)}% used\n${_memoryInfo!.physicalMemoryGB.toStringAsFixed(1)}GB+${_memoryInfo!.virtualMemoryGB.toStringAsFixed(1)}GB virtual';
        } else {
          // Show only physical RAM
          memorySubtitle = '${usagePercent.toStringAsFixed(0)}% used\n${_memoryInfo!.usedMemoryGB.toStringAsFixed(1)}/${_memoryInfo!.physicalMemoryGB.toStringAsFixed(1)}GB';
        }
      } catch (e) {
        memorySubtitle = 'Free up RAM';
      }
    }

    String appCachesSubtitle = 'Clear app data';
    if (_appCachesGB > 0) {
      appCachesSubtitle = '~${_appCachesGB.toStringAsFixed(1)}GB\ncached';
    }

    String systemStorageSubtitle = 'Android Settings';
    if (_systemStorageInfo != null) {
      final usagePercent = _systemStorageInfo!.usagePercentage;
      final marketed = _systemStorageInfo!.marketedGB ?? _systemStorageInfo!.totalGB.toInt();
      systemStorageSubtitle = '${usagePercent.toStringAsFixed(0)}% used\n${_systemStorageInfo!.usedGB.toStringAsFixed(1)}/${marketed}GB';
    }

    String downloadsSubtitle = 'Clean downloads';
    if (_downloadsInfo != null && _downloadsInfo!.usedGB > 0) {
      downloadsSubtitle = '${_downloadsInfo!.usedGB.toStringAsFixed(1)}GB\nfiles';
    }

    // Responsive grid sizing with better aspect ratios
    final screenWidth = constraints.maxWidth;
    final crossAxisCount = screenWidth < 320 ? 1 : 2;
    // Increased aspect ratio to give more height and prevent overflow
    final aspectRatio = screenWidth < 320 ? 2.5 : (screenWidth < 360 ? 1.0 : 1.1);
    
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: aspectRatio,
      children: [
        _buildFeatureCard(
          icon: Icons.memory,
          title: 'Memory Boost',
          subtitle: memorySubtitle,
          onTap: _openMemoryBoost,
          accentColor: const Color(0xFF00D4AA), // Teal/Green for memory
        ),
        _buildFeatureCard(
          icon: Icons.apps,
          title: 'Clean Apps',
          subtitle: appCachesSubtitle,
          onTap: _openAppSettings,
          accentColor: const Color(0xFF9C27B0), // Purple for apps
        ),
        _buildFeatureCard(
          icon: Icons.storage,
          title: 'System Storage',
          subtitle: systemStorageSubtitle,
          onTap: _openStorageSettings,
          accentColor: const Color(0xFF0066FF), // Blue for storage
        ),
        _buildFeatureCard(
          icon: Icons.folder,
          title: 'Downloads',
          subtitle: downloadsSubtitle,
          onTap: _openDownloadsSettings,
          accentColor: const Color(0xFFFF9800), // Orange for downloads
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? accentColor,
  }) {
    // Default accent color if not provided
    final cardAccentColor = accentColor ?? const Color(0xFF0066FF);

    return GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive sizing based on card dimensions
          final cardWidth = constraints.maxWidth;
          final cardHeight = constraints.maxHeight;
          final iconSize = (cardWidth * 0.14).clamp(18.0, 26.0);
          final titleSize = (cardWidth * 0.10).clamp(14.0, 18.0);
          final subtitleSize = (cardWidth * 0.075).clamp(10.0, 13.0);
          final padding = (cardWidth * 0.075).clamp(10.0, 16.0);

          return Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon container - fixed size
                Container(
                  padding: EdgeInsets.all((cardWidth * 0.055).clamp(8.0, 12.0)),
                  decoration: BoxDecoration(
                    color: cardAccentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: cardAccentColor,
                    size: iconSize,
                  ),
                ),
                // Flexible spacer that shrinks if needed
                Expanded(
                  flex: 1,
                  child: SizedBox(height: (cardHeight * 0.02).clamp(2.0, 6.0)),
                ),
                // Title - fixed
                Text(
                  title,
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: (cardHeight * 0.015).clamp(2.0, 4.0)),
                // Subtitle with colored background - takes remaining space
                Expanded(
                  flex: 2,
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: (cardWidth * 0.035).clamp(6.0, 10.0),
                      vertical: (cardHeight * 0.015).clamp(4.0, 7.0),
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          cardAccentColor.withValues(alpha: 0.15),
                          cardAccentColor.withValues(alpha: 0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: cardAccentColor.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: subtitleSize,
                          color: cardAccentColor.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _scanPhone() async {
    setState(() {
      _isScanning = true;
      _hasScanned = false;
      _junkFileCount = 0;
      _junkSizeGB = 0.0;
    });

    _scanController?.repeat();

    bool hasPermission = await _requestPermissions();
    if (!hasPermission) {
      _scanController?.stop();
      _scanController?.reset();
      setState(() => _isScanning = false);
      if (mounted) _showPermissionDialog();
      return;
    }

    try {
      int junkSizeBytes = await _cleanerService.scanJunk();
      _scanController?.stop();
      _scanController?.reset();

      setState(() {
        _junkSizeGB = junkSizeBytes / (1024 * 1024 * 1024);
        _junkFileCount = _cleanerService.junkFileCount;
        _hasScanned = true;
        _isScanning = false;
      });
    } catch (e) {
      _scanController?.stop();
      _scanController?.reset();
      setState(() => _isScanning = false);
    }
  }

  Future<bool> _requestPermissions() async {
    if (await Permission.manageExternalStorage.isGranted) return true;
    if (await Permission.manageExternalStorage.request().isGranted) return true;
    Map<Permission, PermissionStatus> statuses =
        await [Permission.storage].request();
    return statuses[Permission.storage]?.isGranted ?? false;
  }

  void _openCleaningScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CleaningScreen(
          junkSizeGB: _junkSizeGB,
          junkFileCount: _junkFileCount,
          cleanerService: _cleanerService,
        ),
      ),
    );
    // Rescan when returning from cleaning screen
    _scanPhone();
  }

  void _openMemoryBoost() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MemoryBoostScreen()),
    );
    // Refresh data when returning
    _loadStorageInfo();
  }

  void _openStorageSettings() async {
    const intent = AndroidIntent(
      action: 'android.settings.INTERNAL_STORAGE_SETTINGS',
    );
    await intent.launch();
    // Refresh data when returning
    await Future.delayed(const Duration(milliseconds: 500));
    _loadStorageInfo();
  }

  void _openAppSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AppCachesScreen()),
    );
    // Refresh data when returning
    _loadStorageInfo();
  }

  void _openDownloadsSettings() async {
    try {
      // Try to open Downloads folder with file manager
      const intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        type: 'resource/folder',
        data: 'content://com.android.externalstorage.documents/document/primary:Download',
      );
      await intent.launch();
    } catch (e) {
      // Fallback: Try alternative method to open Downloads
      try {
        const fallbackIntent = AndroidIntent(
          action: 'android.intent.action.VIEW',
          data: 'file:///storage/emulated/0/Download',
          type: 'resource/folder',
        );
        await fallbackIntent.launch();
      } catch (e2) {
        // Last resort: Open file manager at root
        try {
          const lastResortIntent = AndroidIntent(
            action: 'android.intent.action.VIEW',
            type: 'vnd.android.document/directory',
          );
          await lastResortIntent.launch();
        } catch (e3) {
          // Show error message if all methods fail
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Unable to open Downloads folder. Please open your file manager manually.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      }
    }
    
    // Refresh data when returning (after a delay to allow user to delete files)
    await Future.delayed(const Duration(milliseconds: 500));
    _loadStorageInfo();
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content:
            const Text('Storage access is needed to scan and clean junk files.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}

class CleaningScreen extends StatefulWidget {
  final double junkSizeGB;
  final int junkFileCount;
  final JunkCleanerService cleanerService;

  const CleaningScreen({
    super.key,
    required this.junkSizeGB,
    required this.junkFileCount,
    required this.cleanerService,
  });

  @override
  State<CleaningScreen> createState() => _CleaningScreenState();
}

class _CleaningScreenState extends State<CleaningScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _cleanController;
  bool _isCleaning = false;
  double _currentJunkSizeGB = 0;
  
  // Selection state for each category
  bool _bigFilesSelected = true;
  bool _tempFilesSelected = true;
  bool _cacheFilesSelected = true;

  @override
  void initState() {
    super.initState();
    _currentJunkSizeGB = widget.junkSizeGB;
    _cleanController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _cleanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F1FF),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight - 140),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 20),
                            _buildConcentricCircles(constraints),
                            const SizedBox(height: 30),
                            _buildCleaningList(),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                _buildCleanNowButton(),
                const SizedBox(height: 20),
              ],
            );
          },
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
            'Cleaner',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          GestureDetector(
            onTap: () => openAppSettings(),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.settings, color: Colors.black, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConcentricCircles(BoxConstraints constraints) {
    final size = constraints.maxWidth * 0.7 > 300 ? 300.0 : constraints.maxWidth * 0.7;
    
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _cleanController,
        builder: (context, child) {
          return CustomPaint(
            size: Size(size, size),
            painter: ConcentricCirclesPainter(
              progress: _cleanController.value,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_currentJunkSizeGB.toStringAsFixed(2)}GB',
                    style: TextStyle(
                      fontSize: size * 0.16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: size * 0.02),
                  Text(
                    'System Cleaning',
                    style: TextStyle(
                      fontSize: size * 0.053,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCleaningList() {
    // Get REAL categorized sizes from the cleaner service
    // These are actual file sizes scanned from the device:
    // - bigFilesSize: Files > 10MB or in Downloads folder
    // - tempFilesSize: Temporary files (.tmp, .temp extensions)
    // - cacheSize: Cache files (.cache extension or in cache folders)
    final bigFilesSize = widget.cleanerService.bigFilesSizeGB;
    final tempFilesSize = widget.cleanerService.tempFilesSizeGB;
    final cacheSize = widget.cleanerService.cacheFilesSizeGB;

    // Dynamic completion status based on actual cleaning state
    final isCompleted = _isCleaning ? false : (_currentJunkSizeGB == 0.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCleaningItem(
            'Big Files',
            '${bigFilesSize.toStringAsFixed(2)} GB',
            Colors.orange,
            Icons.description,
            isCompleted,
            _bigFilesSelected,
            () {
              if (!_isCleaning && !isCompleted) {
                setState(() => _bigFilesSelected = !_bigFilesSelected);
              }
            },
          ),
          const Divider(height: 24),
          _buildCleaningItem(
            'Temp Files',
            '${tempFilesSize.toStringAsFixed(2)} GB',
            Colors.blue,
            Icons.file_copy,
            isCompleted,
            _tempFilesSelected,
            () {
              if (!_isCleaning && !isCompleted) {
                setState(() => _tempFilesSelected = !_tempFilesSelected);
              }
            },
          ),
          const Divider(height: 24),
          _buildCleaningItem(
            'Cache Files',
            '${cacheSize.toStringAsFixed(2)} GB',
            Colors.purple,
            Icons.folder,
            isCompleted,
            _cacheFilesSelected,
            () {
              if (!_isCleaning && !isCompleted) {
                setState(() => _cacheFilesSelected = !_cacheFilesSelected);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCleaningItem(
    String title,
    String size,
    Color color,
    IconData icon,
    bool completed,
    bool selected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected ? color : color.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.black : Colors.grey[400],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    completed ? 'Completed' : (selected ? 'Ready to clean' : 'Tap to select'),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Text(
              size,
              style: TextStyle(
                fontSize: 13,
                color: selected ? Colors.grey[600] : Colors.grey[400],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              completed ? Icons.check_circle : (selected ? Icons.check_box : Icons.check_box_outline_blank),
              color: completed ? const Color(0xFF0066FF) : (selected ? color : Colors.grey[400]),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCleanNowButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0066FF), Color(0xFF0052CC)],
          ),
          borderRadius: BorderRadius.circular(28),
        ),
        child: ElevatedButton(
          onPressed: _isCleaning ? null : _cleanNow,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: Text(
            _isCleaning ? 'Cleaning...' : 'Clean Now',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _cleanNow() async {
    setState(() => _isCleaning = true);

    try {
      int cleanedBytes = await widget.cleanerService.cleanJunk();
      double cleanedGB = cleanedBytes / (1024 * 1024 * 1024);

      // Animate the size going to zero
      setState(() {
        _currentJunkSizeGB = 0.0;
      });

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Success!'),
            content: Text('Cleaned ${cleanedGB.toStringAsFixed(2)} GB'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _isCleaning = false);
    }
  }
}

class CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;

  CircularProgressPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final backgroundPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(CircularProgressPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class ConcentricCirclesPainter extends CustomPainter {
  final double progress;

  ConcentricCirclesPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < 5; i++) {
      final radius = (size.width / 2) * (0.3 + i * 0.15);
      final opacity = 0.15 - (i * 0.02);
      final paint = Paint()
        ..color = const Color(0xFF0066FF).withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(ConcentricCirclesPainter oldDelegate) => true;
}
