import 'package:context_app/app/config/lorescape_tokens.dart';
import 'package:context_app/features/splash/presentation/splash_mark_painter.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// 依 Claude Design 稿重製的品牌 splash：紙感米白底上，山形 mark（輪廓接續
/// 原生 splash）→ 山體填色與雪頂淡入 → 5 枚足跡逐一彈入 → serif 字標、分隔線、
/// 副標、頁尾依序登場，約 2.4s 後導向 `/`。
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // 設計稿的 splash 專用色（非主題色）。
  static const _brand = Color(0xFF12558C);
  static const _slope = Color(0xFFF1EEE8);
  static const _snow = Color(0xFFFFFFFF);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 2400),
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
    final paper = tokens.paper;
    final ink = tokens.ink;
    final ink3 = tokens.ink3;
    final lineStrong = tokens.lineStrong;

    return Semantics(
      label: 'Lorescape',
      child: Material(
        color: paper,
        child: DecoratedBox(
          // 極淡暈影（呼應設計稿 radial vignette）。
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.16),
              radius: 1.1,
              colors: [Colors.transparent, Color(0x175E5341)],
              stops: [0.4, 1.0],
            ),
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final v = _controller.value;
              double iv(double a, double b) =>
                  ((v - a) / (b - a)).clamp(0.0, 1.0);

              final strokeT = iv(0.08, 0.5); // 山形描線畫出
              final fillOpacity = iv(0.42, 0.68); // 填色 + 雪頂淡入
              final dashPops = <double>[
                for (var i = 0; i < 5; i++) iv(0.5 + i * 0.05, 0.72 + i * 0.05),
              ];
              final wordT = iv(0.64, 0.82);
              final ruleT = iv(0.72, 0.9);
              final subT = iv(0.76, 0.94);
              final footT = iv(0.85, 1.0);

              Widget rise(double t, Widget child) => Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * 14),
                  child: child,
                ),
              );

              return Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 196,
                          height: 196,
                          child: CustomPaint(
                            painter: SplashMarkPainter(
                              strokeProgress: strokeT,
                              fillOpacity: fillOpacity,
                              dashPops: dashPops,
                              brand: _brand,
                              slope: _slope,
                              snow: _snow,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        rise(
                          wordT,
                          Text(
                            'Lorescape',
                            style: GoogleFonts.notoSerifTc(
                              fontSize: 32,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 6,
                              color: ink,
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        Transform.scale(
                          scaleX: ruleT,
                          child: Container(
                            width: 52,
                            height: 1,
                            color: lineStrong,
                          ),
                        ),
                        const SizedBox(height: 13),
                        rise(
                          subT,
                          Text(
                            '口袋裡的旅行說書人',
                            style: GoogleFonts.notoSansTc(
                              fontSize: 12.5,
                              letterSpacing: 3.5,
                              color: ink3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 46,
                    child: rise(
                      footT,
                      Text(
                        'FIELD JOURNAL EDITION',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.notoSansTc(
                          fontSize: 10.5,
                          letterSpacing: 2.7,
                          color: ink3,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
