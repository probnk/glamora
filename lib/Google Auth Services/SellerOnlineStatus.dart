import 'dart:ui';

import 'package:flutter/material.dart';
class LifecycleEventHandler extends WidgetsBindingObserver {
  final Future<void> Function() resumeCallBack;
  final Future<void> Function() suspendingCallBack;

  LifecycleEventHandler({
    required this.resumeCallBack,
    required this.suspendingCallBack,
  });

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        await resumeCallBack();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        await suspendingCallBack();
        break;
    }
  }
}