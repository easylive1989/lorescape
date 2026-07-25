import 'package:context_app/app/config/lorescape_tokens.dart';
import 'package:context_app/features/splash/presentation/mountain_painter.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 全螢幕品牌 splash：深墨底上的山形描線動畫，約 1.8s 後導向 `/`。
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1800),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            context.go('/');
          }
        });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final bg = tokens.inkBg;
    final line = tokens.paper;

    return Semantics(
      label: 'Lorescape',
      child: ColoredBox(
        color: bg,
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final v = _controller.value; // 0..1 over 1.8s
              double interval(double a, double b) =>
                  ((v - a) / (b - a)).clamp(0.0, 1.0);
              final strokeT = interval(0.0, 0.56); // 0–1.0s
              final footT = interval(0.5, 0.78); // 0.9–1.4s
              final wordT = interval(0.67, 0.94); // 1.2–1.7s
              final fadeOut = 1.0 - interval(0.94, 1.0); // 1.7–1.8s

              return Opacity(
                opacity: fadeOut,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RepaintBoundary(
                      child: SizedBox(
                        width: 160,
                        height: 160,
                        child: CustomPaint(
                          painter: MountainPainter(
                            strokeProgress: strokeT,
                            footprintProgress: footT,
                            color: line,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Opacity(
                      opacity: wordT,
                      child: Text(
                        'Lorescape',
                        style: TextStyle(
                          color: line,
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
