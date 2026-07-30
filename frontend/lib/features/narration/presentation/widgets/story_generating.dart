import 'dart:async';
import 'dart:math' as math;

import 'package:context_app/app/config/lorescape_tokens.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 故事生成中的整頁動畫，對應設計稿的 `.gen`（screens_story.jsx 的
/// StoryGenerating）：
///
/// - 88px 勳章：虛線外環 9s 順轉、實線內環（頂端 clay 弧）6s 逆轉、
///   兩個交錯的脈衝光暈、中央紙色圓章彈跳進場。
/// - 襯線標題與說明小字。
/// - 步驟清單：進行中的 dot 帶漣漪、完成打勾、未到的半透明。
/// - 底部「手稿卡」：四行文字逐行填入，一支羽毛筆沿著行掃過去，
///   寫完稍停後換頁重寫（真實生成時間比設計稿的 3.6s 長，凍住會像當機）。
/// - 最底 2px 進度條。
///
/// 步驟只是「感覺有進度」的舞台效果：固定間隔逐步推進，最後一步保持
/// 進行中直到外層把這個 widget 換掉（API 回來）。切換階段（挖掘 → 寫作）
/// 時請換 [Key]，讓步驟與筆跡從頭開始。
class StoryGenerating extends StatefulWidget {
  const StoryGenerating({
    super.key,
    required this.title,
    required this.subtitle,
    required this.steps,
    this.icon = Icons.menu_book_outlined,
  });

  final String title;
  final String subtitle;
  final List<String> steps;

  /// 勳章中央的圖示（挖掘用書本、寫作用筆）。
  final IconData icon;

  /// 每隔多久推進一個步驟。
  static const Duration stepInterval = Duration(milliseconds: 2600);

  @override
  State<StoryGenerating> createState() => _StoryGeneratingState();
}

class _StoryGeneratingState extends State<StoryGenerating>
    with TickerProviderStateMixin {
  late final AnimationController _outerRing = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  )..repeat();
  late final AnimationController _innerRing = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();
  late final AnimationController _blip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();
  late final AnimationController _write = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4600),
  )..repeat();

  /// 進度條慢慢逼近 95% 後停住：真實生成時間未知，跑滿會像「完成了卻
  /// 沒反應」，比停在九成五更糟。
  late final AnimationController _bar = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..forward();

  int _activeStep = 0;
  Timer? _stepTimer;

  @override
  void initState() {
    super.initState();
    _stepTimer = Timer.periodic(StoryGenerating.stepInterval, (timer) {
      if (_activeStep >= widget.steps.length - 1) {
        timer.cancel();
        return;
      }
      setState(() => _activeStep += 1);
    });
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _outerRing.dispose();
    _innerRing.dispose();
    _pulse.dispose();
    _blip.dispose();
    _write.dispose();
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              // 小螢幕（或測試的 600px 視窗）擠不下時捲動，而不是 overflow。
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Medal(
                      outerTurns: _outerRing,
                      innerTurns: _innerRing,
                      pulse: _pulse,
                      icon: widget.icon,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.notoSerifTc(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                        color: tokens.ink,
                      ),
                    ),
                    const SizedBox(height: 7),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 250),
                      child: Text(
                        widget.subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.55,
                          color: tokens.ink3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    for (final (index, step) in widget.steps.indexed)
                      Padding(
                        padding: EdgeInsets.only(top: index == 0 ? 0 : 10),
                        child: _StepRow(
                          label: step,
                          isDone: index < _activeStep,
                          isActive: index == _activeStep,
                          blip: _blip,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _WritingPage(progress: _write),
          const SizedBox(height: 14),
          _ProgressBar(progress: _bar),
        ],
      ),
    );
  }
}

/// `.gen__medal`：雙環＋脈衝＋中央圓章。
class _Medal extends StatelessWidget {
  const _Medal({
    required this.outerTurns,
    required this.innerTurns,
    required this.pulse,
    required this.icon,
  });

  final Animation<double> outerTurns;
  final Animation<double> innerTurns;
  final Animation<double> pulse;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 兩個交錯的脈衝光暈（`.gen__pulse` / `--b`，錯開半個週期）。
          AnimatedBuilder(
            animation: pulse,
            builder: (context, _) => Stack(
              alignment: Alignment.center,
              children: [
                for (final phase in [pulse.value, (pulse.value + 0.5) % 1])
                  Opacity(
                    opacity: 0.22 * (1 - phase),
                    child: Transform.scale(
                      scale: 0.7 + 0.85 * phase,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: tokens.clay,
                          shape: BoxShape.circle,
                        ),
                        child: const SizedBox(width: 52, height: 52),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          RotationTransition(
            turns: outerTurns,
            child: CustomPaint(
              size: const Size(88, 88),
              painter: _DashedRingPainter(
                color: tokens.clay.withValues(alpha: 0.55),
              ),
            ),
          ),
          RotationTransition(
            turns: ReverseAnimation(innerTurns),
            child: CustomPaint(
              size: const Size(60, 60),
              painter: _InnerRingPainter(
                base: tokens.claySoft,
                accent: tokens.clay,
              ),
            ),
          ),
          // `.gen__ic`：彈跳進場的中央圓章。
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutBack,
            builder: (context, t, child) => Opacity(
              opacity: t.clamp(0, 1),
              child: Transform.rotate(
                angle: (1 - t) * -12 * math.pi / 180,
                child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
              ),
            ),
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.paperRaised,
                shape: BoxShape.circle,
                boxShadow: tokens.e2,
              ),
              child: Icon(icon, size: 22, color: tokens.clay),
            ),
          ),
        ],
      ),
    );
  }
}

/// 1.5px 虛線圓環（`.gen__ring`）。
class _DashedRingPainter extends CustomPainter {
  const _DashedRingPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color;
    final radius = size.width / 2 - 0.75;
    final center = size.center(Offset.zero);
    const dashCount = 26;
    const sweep = 2 * math.pi / dashCount;
    for (var i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * sweep,
        sweep * 0.55,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedRingPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 內環（`.gen__ring--in`）：整圈 clay-soft，頂端四分之一圈 clay。
class _InnerRingPainter extends CustomPainter {
  const _InnerRingPainter({required this.base, required this.accent});

  final Color base;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.width / 2 - 0.75,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = base;
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint);
    // CSS 圓形只上 border-top-color 時，上色的是頂端四分之一圈。
    canvas.drawArc(
      rect,
      -3 * math.pi / 4,
      math.pi / 2,
      false,
      paint..color = accent,
    );
  }

  @override
  bool shouldRepaint(_InnerRingPainter oldDelegate) =>
      oldDelegate.base != base || oldDelegate.accent != accent;
}

/// `.gen__step`：一列步驟（dot ＋ 文字）。
class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.label,
    required this.isDone,
    required this.isActive,
    required this.blip,
  });

  final String label;
  final bool isDone;
  final bool isActive;
  final Animation<double> blip;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AnimatedOpacity(
      opacity: isDone || isActive ? 1 : 0.42,
      duration: const Duration(milliseconds: 350),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: isDone
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      color: tokens.clay,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 13,
                      color: Color(0xFFFBF1E9),
                    ),
                  )
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      if (isActive)
                        AnimatedBuilder(
                          animation: blip,
                          builder: (context, _) => CustomPaint(
                            size: const Size(20, 20),
                            painter: _BlipPainter(
                              color: tokens.clay,
                              t: blip.value,
                            ),
                          ),
                        ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isActive ? tokens.clay : tokens.lineStrong,
                            width: 1.5,
                          ),
                        ),
                        child: const SizedBox(width: 20, height: 20),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                fontSize: 15,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? tokens.ink : tokens.ink2,
              ),
              child: Text(label),
            ),
          ),
        ],
      ),
    );
  }
}

/// 進行中步驟的漣漪（`gen-blip` 的 box-shadow 外擴）。
class _BlipPainter extends CustomPainter {
  const _BlipPainter({required this.color, required this.t});

  final Color color;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = color.withValues(alpha: 0.45 * (1 - t));
    canvas.drawCircle(size.center(Offset.zero), 10 + 9 * t, paint);
  }

  @override
  bool shouldRepaint(_BlipPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.color != color;
}

/// `.gen__page`：底部手稿卡——四行文字逐行填入＋羽毛筆掃行。
///
/// 時間軸照設計稿的 `gen-quill` keyframes：每行掃約 22%，行距間 3% 快速
/// 回行；controller 的最後 8% 是整頁寫滿的停頓，之後換頁重寫。
class _WritingPage extends StatelessWidget {
  const _WritingPage({required this.progress});

  final Animation<double> progress;

  /// 每行的 (開始, 結束, 行末位置)；行末位置同時是該行文字的目標寬度。
  static const List<(double, double, double)> _lines = [
    (0.00, 0.22, 0.88),
    (0.25, 0.47, 0.82),
    (0.50, 0.72, 0.86),
    (0.75, 0.92, 0.68),
  ];

  static const double _rowHeight = 11;
  static const double _rowGap = 11;

  /// 寫字段落佔整個週期的比例，其餘是寫滿後的停頓。
  static const double _writeSpan = 0.92;

  double _fillFor(int index, double t) {
    final (start, end, width) = _lines[index];
    return (((t - start) / (end - start)).clamp(0.0, 1.0)) * width;
  }

  /// 羽毛筆現在的（行進度 x、行 index y），沿設計稿 keyframes 折線走。
  (double, double) _quillAt(double t) {
    for (var i = 0; i < _lines.length; i++) {
      final (start, end, width) = _lines[i];
      if (t < start) {
        // 行距間的快速回行：從上一行行末拉回本行起點。
        final (_, prevEnd, prevWidth) = _lines[i - 1];
        final q = (t - prevEnd) / (start - prevEnd);
        return (prevWidth + (0.02 - prevWidth) * q, (i - 1) + q);
      }
      if (t <= end) {
        final q = (t - start) / (end - start);
        return (0.02 + (width - 0.02) * q, i.toDouble());
      }
    }
    final (_, _, lastWidth) = _lines.last;
    return (lastWidth, (_lines.length - 1).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final inkFill = tokens.ink.withValues(alpha: 0.27);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      decoration: BoxDecoration(
        color: tokens.paperRaised,
        border: Border.all(color: tokens.line),
        borderRadius: BorderRadius.circular(tokens.rLg),
        boxShadow: tokens.e1,
      ),
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, _) {
          final t = (progress.value / _writeSpan).clamp(0.0, 1.0);
          final (quillX, quillLine) = _quillAt(t);
          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    children: [
                      for (var i = 0; i < _lines.length; i++)
                        Padding(
                          padding: EdgeInsets.only(top: i == 0 ? 0 : _rowGap),
                          child: _WritingRow(
                            fill: _fillFor(i, t),
                            fillColor: inkFill,
                            background: tokens.paperSunk,
                          ),
                        ),
                    ],
                  ),
                  Positioned(
                    left: quillX * width - 3,
                    top: quillLine * (_rowHeight + _rowGap) - 22,
                    child: Opacity(
                      opacity: (t / 0.04).clamp(0.0, 1.0),
                      child: _Quill(color: tokens.clayDeep),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _WritingRow extends StatelessWidget {
  const _WritingRow({
    required this.fill,
    required this.fillColor,
    required this.background,
  });

  final double fill;
  final Color fillColor;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _WritingPage._rowHeight,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(5),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: fill,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(5),
          ),
          child: const SizedBox(height: _WritingPage._rowHeight),
        ),
      ),
    );
  }
}

/// 微微擺動的羽毛筆（`.gen__quill` ＋ `gen-bob`）。
class _Quill extends StatefulWidget {
  const _Quill({required this.color});

  final Color color;

  @override
  State<_Quill> createState() => _QuillState();
}

class _QuillState extends State<_Quill> with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bob,
      builder: (context, child) => Transform.rotate(
        // gen-bob：-2.5° ↔ +1.5° 的小幅擺動，筆尖為軸心。
        angle: (-2.5 + 4 * _bob.value) * math.pi / 180,
        alignment: Alignment.bottomLeft,
        child: child,
      ),
      child: CustomPaint(
        size: const Size(20, 26),
        painter: _QuillPainter(color: widget.color),
      ),
    );
  }
}

/// 手繪羽毛筆：葉形羽身＋筆桿＋筆尖墨點。
class _QuillPainter extends CustomPainter {
  const _QuillPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final feather = Path()
      ..moveTo(4.5, 21)
      ..quadraticBezierTo(2.5, 9, 15, 2)
      ..quadraticBezierTo(19.5, 8.5, 8, 19)
      ..close();
    canvas.drawShadow(feather, const Color(0x383C2819), 3, false);
    canvas.drawPath(feather, Paint()..color = color);
    // 筆桿。
    canvas.drawLine(
      const Offset(4.5, 21),
      const Offset(1.5, 25.5),
      Paint()
        ..color = color
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
    // 筆尖墨點（`.gen__nib`）。
    canvas.drawCircle(
      const Offset(1.5, 25.5),
      2.2,
      Paint()..color = color.withValues(alpha: 0.75),
    );
  }

  @override
  bool shouldRepaint(_QuillPainter oldDelegate) => oldDelegate.color != color;
}

/// `.gen__bar`：2px 進度條。
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});

  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final eased = Curves.easeOutCubic.transform(progress.value);
        return Container(
          height: 2,
          decoration: BoxDecoration(
            color: tokens.line,
            borderRadius: BorderRadius.circular(2),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: 0.95 * eased,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.clay,
                borderRadius: BorderRadius.circular(2),
              ),
              child: const SizedBox(height: 2),
            ),
          ),
        );
      },
    );
  }
}
