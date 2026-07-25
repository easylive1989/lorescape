import 'package:context_app/app/config/lorescape_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 全螢幕品牌 splash：深墨底上的 Lorescape 山形 mark，約 1.8s 後導向 `/`。
///
/// mark 直接用品牌線稿資源 `assets/images/splash_mark.png`（與原生系統
/// splash 的靜態 mark 為同一張），首幀即完整顯示、無縫交棒、logo 不跳動；
/// 只有字標淡入與整體淡出會動。
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _markAsset = 'assets/images/splash_mark.png';

  late final AnimationController _controller;
  bool _precached = false;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Decode the mark ahead of the first paint so it shows immediately and
    // the native → Flutter handoff stays seamless.
    if (!_precached) {
      _precached = true;
      precacheImage(const AssetImage(_markAsset), context);
    }
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
              final wordT = interval(0.35, 0.68); // 字標淡入
              final fadeOut = 1.0 - interval(0.85, 1.0); // 整體淡出→導向

              return Opacity(
                opacity: fadeOut,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 160,
                      height: 160,
                      child: Image(
                        image: AssetImage(_markAsset),
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
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
