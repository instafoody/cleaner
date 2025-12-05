import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/memory_service.dart';

class MemoryBoostScreen extends StatefulWidget {
  const MemoryBoostScreen({super.key});

  @override
  State<MemoryBoostScreen> createState() => _MemoryBoostScreenState();
}

class _MemoryBoostScreenState extends State<MemoryBoostScreen>
    with TickerProviderStateMixin {
  final MemoryService _memoryService = MemoryService();

  MemoryInfo? _memoryInfo;
  bool _isOptimizing = false;
  bool _hasOptimized = false;
  double _freedMemoryMB = 0;

  AnimationController? _progressController;
  AnimationController? _pulseController;
  Animation<double>? _progressAnimation;
  Animation<double>? _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Progress animation controller
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    // Pulse animation controller for optimization
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
    );
    
    _loadMemoryInfo();
  }

  @override
  void dispose() {
    _progressController?.dispose();
    _pulseController?.dispose();
    super.dispose();
  }

  Future<void> _loadMemoryInfo() async {
    final info = await _memoryService.getMemoryInfo();
    if (mounted) {
      setState(() {
        _memoryInfo = info;
      });

      // Animate progress
      final percentage = _memoryService.getMemoryUsagePercentage(info) / 100;
      _progressAnimation = Tween<double>(begin: 0, end: percentage).animate(
        CurvedAnimation(parent: _progressController!, curve: Curves.easeOut),
      );
      _progressController?.reset();
      _progressController?.forward();
    }
  }

  Future<void> _optimizeMemory() async {
    setState(() {
      _isOptimizing = true;
      _hasOptimized = false;
      _freedMemoryMB = 0;
    });

    // Start pulsing animation
    _pulseController?.repeat(reverse: true);

    // Optimize memory
    final freedMB = await _memoryService.optimizeMemory();

    // Stop pulsing animation
    _pulseController?.stop();
    _pulseController?.reset();

    // Reload REAL memory info after optimization
    await _loadMemoryInfo();

    if (mounted) {
      setState(() {
        _isOptimizing = false;
        _hasOptimized = true;
        _freedMemoryMB = freedMB;
        // Set canFreeUpMB to 0 after optimization for this run
        if (_memoryInfo != null) {
          _memoryInfo = MemoryInfo(
            totalMemoryMB: _memoryInfo!.totalMemoryMB,
            availableMemoryMB: _memoryInfo!.availableMemoryMB,
            usedMemoryMB: _memoryInfo!.usedMemoryMB,
            canFreeUpMB: 0, // Set to 0 after optimization
            physicalMemoryMB: _memoryInfo!.physicalMemoryMB,
            virtualMemoryMB: _memoryInfo!.virtualMemoryMB,
          );
        }
      });
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 30),
                    _buildMemoryCircle(),
                    const SizedBox(height: 30),
                    _buildMemoryStats(),
                    const SizedBox(height: 20),
                    if (_hasOptimized) ...[
                      _buildSuccessMessage(),
                      const SizedBox(height: 20),
                    ],
                    _buildInfoCard(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            _buildOptimizeButton(),
            const SizedBox(height: 20),
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
              child: const Icon(Icons.arrow_back, color: Colors.black),
            ),
          ),
          const Text(
            'Memory Boost',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          GestureDetector(
            onTap: _loadMemoryInfo,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.refresh, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryCircle() {
    if (_memoryInfo == null || _progressAnimation == null) {
      return const SizedBox(
        width: 250,
        height: 250,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final percentage = _memoryService.getMemoryUsagePercentage(_memoryInfo!);

    return SizedBox(
      width: 250,
      height: 250,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Animated container with pulse effect during optimization
          if (_isOptimizing && _pulseAnimation != null)
            AnimatedBuilder(
              animation: _pulseAnimation!,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation!.value,
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00D4AA).withValues(alpha: 0.3),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                  ),
                );
              },
            )
          else
            Container(
              width: 250,
              height: 250,
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
          // Progress circle with animation
          AnimatedBuilder(
            animation: _progressAnimation!,
            builder: (context, child) {
              return CustomPaint(
                size: const Size(220, 220),
                painter: MemoryCirclePainter(
                  progress: _progressAnimation!.value,
                  isOptimizing: _isOptimizing,
                  animationValue: _isOptimizing && _pulseController != null
                      ? _pulseController!.value
                      : 0,
                ),
              );
            },
          ),
          // Center text
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isOptimizing ? 'Optimizing...' : 'Memory Used',
                style: TextStyle(
                  fontSize: 14,
                  color: _isOptimizing ? const Color(0xFF00D4AA) : Colors.grey[600],
                  fontWeight: _isOptimizing ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryStats() {
    if (_memoryInfo == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(20),
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
        children: [
          _buildStatRow(
            'Total Memory',
            '${_memoryInfo!.totalMemoryGB.toStringAsFixed(2)} GB',
            Colors.blue,
          ),
          const Divider(height: 20),
          _buildStatRow(
            'Used Memory',
            '${_memoryInfo!.usedMemoryGB.toStringAsFixed(2)} GB',
            Colors.orange,
          ),
          const Divider(height: 20),
          _buildStatRow(
            'Available Memory',
            '${_memoryInfo!.availableMemoryGB.toStringAsFixed(2)} GB',
            Colors.green,
          ),
          const Divider(height: 20),
          _buildStatRow(
            'Can Free Up',
            '${_memoryInfo!.canFreeUpMB.toStringAsFixed(0)} MB',
            Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Memory optimized! Freed ~${_freedMemoryMB.toStringAsFixed(0)} MB',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Android manages memory automatically. This feature requests the system to optimize memory usage.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue[900],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptimizeButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00D4AA), Color(0xFF00B894)],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00D4AA).withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isOptimizing ? null : _optimizeMemory,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isOptimizing)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else
                const Icon(Icons.speed, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text(
                _isOptimizing ? 'Optimizing...' : 'Optimize Memory',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MemoryCirclePainter extends CustomPainter {
  final double progress;
  final bool isOptimizing;
  final double animationValue;

  MemoryCirclePainter({
    required this.progress,
    this.isOptimizing = false,
    this.animationValue = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background circle
    final backgroundPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress arc with gradient
    final sweepAngle = 2 * math.pi * progress;
    
    // Color based on usage (or green when optimizing)
    final colors = isOptimizing
        ? [const Color(0xFF00D4AA), const Color(0xFF00FF88)]
        : progress < 0.5
            ? [const Color(0xFF0066FF), const Color(0xFF00D4AA)]
            : progress < 0.75
                ? [const Color(0xFF00D4AA), const Color(0xFFFFA500)]
                : [const Color(0xFFFFA500), const Color(0xFFFF6584)];

    // Rotate the gradient during optimization
    final startAngle = isOptimizing 
        ? -math.pi / 2 + (animationValue * 2 * math.pi)
        : -math.pi / 2;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradient = SweepGradient(
      colors: colors,
      startAngle: startAngle,
      endAngle: startAngle + sweepAngle,
    );

    final progressPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isOptimizing ? 16 : 14
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );

    // Add animated dots during optimization
    if (isOptimizing) {
      final dotPaint = Paint()
        ..color = const Color(0xFF00D4AA)
        ..style = PaintingStyle.fill;

      for (int i = 0; i < 3; i++) {
        final angle = startAngle + (i * sweepAngle / 3) + (animationValue * math.pi);
        final dotX = center.dx + radius * math.cos(angle);
        final dotY = center.dy + radius * math.sin(angle);
        canvas.drawCircle(Offset(dotX, dotY), 4, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(MemoryCirclePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.isOptimizing != isOptimizing ||
      oldDelegate.animationValue != animationValue;
}
