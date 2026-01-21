import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

class PerformanceMonitor {
  final List<double> _frameTimes = [];
  final List<int> _memoryUsage = [];
  final List<double> _cpuUsage = [];

  DateTime? _lastFrameTime;
  int _totalFrames = 0;
  int _slowFrames = 0;
  int _droppedFrames = 0;

  Timer? _monitoringTimer;
  bool _isMonitoring = false;
  bool _isLowMemoryDevice = false;

  // Performance thresholds
  static const int targetFPS = 60;
  static const int warningFPS = 30;
  static const int criticalFPS = 20;

  static const int warningMemoryMB = 100;
  static const int criticalMemoryMB = 150;

  static const double warningCPU = 70.0;
  static const double criticalCPU = 90.0;

  void startMonitoring() {
    if (_isMonitoring) return;

    _isMonitoring = true;
    _lastFrameTime = DateTime.now();

    // Check device capabilities
    _checkDeviceCapabilities();

    // Start periodic monitoring
    _monitoringTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateMetrics();
    });

    if (kDebugMode) {
      print('Performance monitoring started');
    }
  }

  void _checkDeviceCapabilities() {
    try {
      // Simple device capability check
      final processorCount = Platform.numberOfProcessors;
      final totalMemory = _getTotalMemory();

      _isLowMemoryDevice = totalMemory < 2000 * 1024 * 1024; // Less than 2GB

      if (kDebugMode) {
        print('Device Info:');
        print('  Processors: $processorCount');
        print('  Total Memory: ${totalMemory / 1024 / 1024}MB');
        print('  Is Low Memory Device: $_isLowMemoryDevice');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking device capabilities: $e');
      }
    }
  }

  int _getTotalMemory() {
    if (Platform.isAndroid || Platform.isIOS) {
      // For mobile devices, use conservative estimates
      return 1000 * 1024 * 1024; // Default to 1GB
    }
    return 4000 * 1024 * 1024; // Default to 4GB for other platforms
  }

  void recordFrame() {
    final now = DateTime.now();

    if (_lastFrameTime != null) {
      final frameTime = now.difference(_lastFrameTime!).inMilliseconds;
      _frameTimes.add(frameTime.toDouble());

      if (frameTime > 1000 / targetFPS) {
        _slowFrames++;
      }

      if (frameTime > 1000 / warningFPS) {
        _droppedFrames++;
      }

      // Keep only last 60 frames (1 second at 60 FPS)
      if (_frameTimes.length > 60) {
        _frameTimes.removeAt(0);
      }
    }

    _lastFrameTime = now;
    _totalFrames++;
  }

  void recordSlowFrame(int processingTime) {
    if (kDebugMode) {
      print('Slow frame detected: ${processingTime}ms');
    }
  }

  void recordSlowRender(int renderTime) {
    if (kDebugMode && renderTime > 16) {
      print('Slow render detected: ${renderTime}ms');
    }
  }

  void _updateMetrics() {
    // Record current memory usage (simulated - in real app use proper memory API)
    final memoryUsage = _simulateMemoryUsage();
    _memoryUsage.add(memoryUsage);

    // Record CPU usage (simulated)
    final cpuUsage = _simulateCpuUsage();
    _cpuUsage.add(cpuUsage);

    // Keep only last 60 samples
    if (_memoryUsage.length > 60) {
      _memoryUsage.removeAt(0);
    }
    if (_cpuUsage.length > 60) {
      _cpuUsage.removeAt(0);
    }

    // Check for performance issues
    _checkForIssues();
  }

  int _simulateMemoryUsage() {
    // In a real app, you would use:
    // - dart:developer for memory usage
    // - Platform-specific APIs for more accurate readings
    return 50 * 1024 * 1024 + (_totalFrames % 100000) * 100; // Simulated
  }

  double _simulateCpuUsage() {
    // In a real app, you would use platform-specific APIs
    return 30.0 + (_totalFrames % 100) * 0.1; // Simulated
  }

  void _checkForIssues() {
    final metrics = getMetrics();
    final fps = metrics['fps']!;
    final memory = metrics['memory']! / 1024 / 1024; // Convert to MB
    final cpu = metrics['cpu']!;

    if (fps < criticalFPS) {
      if (kDebugMode) {
        print('CRITICAL: Low FPS: ${fps.toStringAsFixed(1)}');
      }
    } else if (fps < warningFPS) {
      if (kDebugMode) {
        print('WARNING: Moderate FPS: ${fps.toStringAsFixed(1)}');
      }
    }

    if (memory > criticalMemoryMB) {
      if (kDebugMode) {
        print('CRITICAL: High memory usage: ${memory.toStringAsFixed(1)}MB');
      }
    } else if (memory > warningMemoryMB) {
      if (kDebugMode) {
        print('WARNING: Moderate memory usage: ${memory.toStringAsFixed(1)}MB');
      }
    }

    if (cpu > criticalCPU) {
      if (kDebugMode) {
        print('CRITICAL: High CPU usage: ${cpu.toStringAsFixed(1)}%');
      }
    } else if (cpu > warningCPU) {
      if (kDebugMode) {
        print('WARNING: Moderate CPU usage: ${cpu.toStringAsFixed(1)}%');
      }
    }
  }

  Map<String, double> getMetrics() {
    double fps = 0.0;
    if (_frameTimes.isNotEmpty) {
      final avgFrameTime = _frameTimes.reduce((a, b) => a + b) / _frameTimes.length;
      fps = avgFrameTime > 0 ? 1000 / avgFrameTime : 0;
    }

    double memory = 0.0;
    if (_memoryUsage.isNotEmpty) {
      memory = _memoryUsage.reduce((a, b) => a + b) / _memoryUsage.length;
    }

    double cpu = 0.0;
    if (_cpuUsage.isNotEmpty) {
      cpu = _cpuUsage.reduce((a, b) => a + b) / _cpuUsage.length;
    }

    return {
      'fps': fps,
      'memory': memory,
      'cpu': cpu,
      'slow_frames': _slowFrames.toDouble(),
      'dropped_frames': _droppedFrames.toDouble(),
      'total_frames': _totalFrames.toDouble(),
    };
  }

  PerformanceStatus getStatus() {
    final metrics = getMetrics();
    final fps = metrics['fps']!;
    final memory = metrics['memory']! / 1024 / 1024;

    if (fps < criticalFPS || memory > criticalMemoryMB) {
      return PerformanceStatus.critical;
    } else if (fps < warningFPS || memory > warningMemoryMB) {
      return PerformanceStatus.warning;
    } else {
      return PerformanceStatus.good;
    }
  }

  bool get isLowMemoryDevice => _isLowMemoryDevice;
  int get currentMemoryUsage => _memoryUsage.isNotEmpty ? _memoryUsage.last : 0;

  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _isMonitoring = false;

    if (kDebugMode) {
      final metrics = getMetrics();
      print('Performance monitoring stopped');
      print('Final metrics:');
      print('  Average FPS: ${metrics['fps']?.toStringAsFixed(1)}');
      print('  Slow frames: ${metrics['slow_frames']}');
      print('  Dropped frames: ${metrics['dropped_frames']}');
    }
  }
}

enum PerformanceStatus {
  good,
  warning,
  critical,
}