import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const SplashScreen({super.key, required this.nextScreen});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late VideoPlayerController _controller;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool _hasFaded = false;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);

    _controller = VideoPlayerController.asset('assets/splash.mp4')
      ..setPlaybackSpeed(1.5) // or 2.0 for faster playback
      ..initialize().then((_) {
        setState(() {});
        _controller.play();

        _controller.addListener(() {
          if (!_hasFaded &&
              _controller.value.duration.inMilliseconds - _controller.value.position.inMilliseconds < 500) {
            _hasFaded = true;
            _fadeController.forward();

            Future.delayed(const Duration(milliseconds: 500), () {
              Navigator.of(context).pushReplacement(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => widget.nextScreen,
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  transitionDuration: const Duration(milliseconds: 300),
                ),
              );
            });
          }
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _controller.value.isInitialized
          ? FadeTransition(
              opacity: _fadeAnimation.drive(Tween(begin: 1.0, end: 0.0)),
              child: Center(
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
              ),
            )
          : const SizedBox(),
    );
  }
}
