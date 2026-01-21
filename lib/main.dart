import 'package:flutter/material.dart';
import 'core/app.dart';
import 'core/lifecycle_observer.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsBinding.instance.addObserver(AppLifecycleObserver());
  runApp(const _AnimatedApp());
}

class _AnimatedApp extends StatefulWidget {
  const _AnimatedApp();

  @override
  State<_AnimatedApp> createState() => _AnimatedAppState();
}

class _AnimatedAppState extends State<_AnimatedApp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220), // fast & smooth
    );

    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.02),
      end: Offset.zero,
    ).animate(_fade);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: const TempScanApp(),
      ),
    );
  }
}
