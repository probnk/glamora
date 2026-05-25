// lib/widgets/connectivity_wrapper.dart
import 'package:flutter/material.dart';
import '../../Services/connectivity_service.dart';
import 'no_internet_screen.dart';

class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  final bool enabled; // Yeh add kar
  const ConnectivityWrapper({super.key, required this.child,this.enabled = true,
  });

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  final _service = ConnectivityService();
  late bool _isConnected;

  @override
  void initState() {
    super.initState();
    _isConnected = _service.isConnected;
    _service.onConnectivityChanged.listen((connected) {
      if (mounted) setState(() => _isConnected = connected);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child; // Early return
    return Stack(
      children: [
        widget.child,
        if (!_isConnected)
          const Positioned.fill(
            child: NoInternetScreen(),
          ),
      ],
    );
  }
}