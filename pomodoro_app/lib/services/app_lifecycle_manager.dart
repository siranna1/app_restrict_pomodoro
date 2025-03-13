// app_lifecycle_manager.dart
import 'package:flutter/material.dart';

class AppLifecycleManager extends StatefulWidget {
  final Widget child;
  final Function onAppResume;
  final Function onAppPause;

  AppLifecycleManager({
    required this.child,
    required this.onAppResume,
    required this.onAppPause,
  });

  @override
  _AppLifecycleManagerState createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends State<AppLifecycleManager>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.onAppResume();
    } else if (state == AppLifecycleState.paused) {
      widget.onAppPause();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
