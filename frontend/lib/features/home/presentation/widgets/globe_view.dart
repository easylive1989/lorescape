import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:context_app/app/config/lorescape_tokens.dart';
import 'package:context_app/features/home/domain/globe/globe_rotation.dart';
import 'package:context_app/features/home/domain/globe/orthographic_projection.dart';
import 'package:context_app/features/home/domain/globe/world_outline.dart';
import 'package:context_app/features/home/domain/models/globe_pin.dart';
import 'package:context_app/features/home/presentation/widgets/globe_painter.dart';

/// 首頁那顆可拖曳的地球儀。
///
/// [focus] 換人時會用 950ms 的 easeOutCubic 轉過去；使用者拖曳期間動畫讓位
/// 給手指，放開後停在使用者轉到的角度，直到下一次 [focus] 變動。
class GlobeView extends StatefulWidget {
  const GlobeView({
    super.key,
    required this.outline,
    required this.pins,
    required this.focus,
    this.size = 344,
  });

  final WorldOutline outline;

  /// 帶地名標籤的釘點（最近 7 篇）。
  final List<GlobePin> pins;

  /// 目前選中的故事地點。可能不在 [pins] 內（捲到更舊的卡片時）。
  final GlobePin? focus;

  final double size;

  /// 測試用來抓畫布與拖曳目標。
  static const Key canvasKey = Key('globe-canvas');

  @override
  State<GlobeView> createState() => _GlobeViewState();
}

class _GlobeViewState extends State<GlobeView>
    with SingleTickerProviderStateMixin {
  static const Duration _flightDuration = Duration(milliseconds: 950);

  /// 拖曳位移換算成旋轉度數的比例，取自設計稿。
  static const double _dragGain = 0.32;

  late AnimationController _controller;
  late GlobeRotation _rotation;
  GlobeRotation _flightFrom = const GlobeRotation(0, 0);
  GlobeRotation _flightTo = const GlobeRotation(0, 0);

  @override
  void initState() {
    super.initState();
    _rotation = widget.focus == null
        ? const GlobeRotation(0, 0)
        : GlobeRotation.facing(widget.focus!.coordinate);
    _controller = AnimationController(vsync: this, duration: _flightDuration)
      ..addListener(_onFlightTick);
  }

  @override
  void didUpdateWidget(GlobeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final focus = widget.focus;
    if (focus == null || focus.id == oldWidget.focus?.id) return;
    _flightFrom = _rotation;
    _flightTo = GlobeRotation.facing(focus.coordinate);
    _controller.forward(from: 0);
  }

  void _onFlightTick() {
    final t = Curves.easeOutCubic.transform(_controller.value);
    setState(() => _rotation = _flightFrom.lerpTo(_flightTo, t));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails _) => _controller.stop();

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _rotation = GlobeRotation(
        _rotation.lambda + details.delta.dx * _dragGain,
        _rotation.phi - details.delta.dy * _dragGain,
      ).clampedPhi();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 螢幕比預設的 344pt 窄時（320pt 裝置、或開了「顯示縮放」的
        // iPhone），外層給的是 loose constraints，SizedBox 會被壓小；如果
        // 投影只用 widget.size 算 focus marker 的位置，就會跟畫布實際尺寸
        // 脫鉤——marker 用 344 的基準，painter 卻畫在更小的圓上，選中的
        // pin 會偏離陸地。這裡把投影、CustomPaint、SizedBox 都夾到同一個
        // 有效尺寸，確保三者永遠算的是同一顆球。
        final effectiveSize = constraints.hasBoundedWidth
            ? math.min(widget.size, constraints.maxWidth)
            : widget.size;

        final projection = OrthographicProjection(
          rotation: _rotation,
          center: Offset(effectiveSize / 2, effectiveSize / 2),
          radius: effectiveSize / 2 - 3,
        );
        final focus = widget.focus;
        final focusOffset = focus == null
            ? null
            : projection.project(focus.coordinate);
        final focusVisible =
            focus != null &&
            focusOffset != null &&
            projection.angularDistanceTo(focus.coordinate) < 1.32;

        return SizedBox(
          width: effectiveSize,
          height: effectiveSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onPanStart: _onDragStart,
                onPanUpdate: _onDragUpdate,
                child: CustomPaint(
                  key: GlobeView.canvasKey,
                  size: Size.square(effectiveSize),
                  painter: GlobePainter(
                    outline: widget.outline,
                    pins: widget.pins,
                    rotation: _rotation,
                    focusId: focus?.id,
                  ),
                ),
              ),
              // focusOffset 在焦點剛切換、旋轉還沒轉到那一面時可能是
              // null（該點暫時在地球背面投影不出來）；這種情況先不畫標記，
              // 等飛行動畫轉過去再顯示。
              if (focus != null && focusOffset != null)
                Positioned(
                  left: focusOffset.dx,
                  top: focusOffset.dy,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: focusVisible ? 1 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: _FocusMarker(label: focus.label),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// 選中地點的水滴 pin 與其上方的紙卡 chip。用 widget 而非 canvas，字體與
/// 陰影才會跟 App 其他地方一致。
/// 水滴 pin 的邊長，取自 ls3.css 的 `.gpin .map-pin`。
const double _pinSize = 36;

/// 旋轉 45 度後對角線會撐到 `_pinSize * √2`，外框要留這麼大尖端才不被裁掉。
const double _pinBox = _pinSize * 1.4142135624;

/// 設計稿 `.map-pin` 的描邊與內圈色（乳白，不隨 accent 變動）。
const Color _pinBorder = Color(0xFFFBF1E9);

class _FocusMarker extends StatelessWidget {
  const _FocusMarker({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    // 外層 Positioned 把左上角放在投影點上。這裡水平往左推半個自身寬度做
    // 置中、垂直往上推一整個高度，讓水滴 pin 的尖端剛好落在座標上。寬度
    // 隨地名長短變動，所以用比例位移而不是寫死的 Offset。
    return FractionalTranslation(
      translation: const Offset(-0.5, -1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: tokens.paperRaised,
              border: Border.all(color: tokens.line),
              borderRadius: BorderRadius.circular(999),
              boxShadow: tokens.e2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: tokens.clay,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.96,
                    color: tokens.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // 水滴 pin：設計稿的 `.map-pin` 是 `border-radius: 50% 50% 50% 0`
          // 搭配 `rotate(-45deg)`——方角開在**左下**，逆時針轉 45 度後才會落
          // 到正下方當尖端。方角開在右下的話會轉到正右方（曾經如此）。
          //
          // 尺寸取 ls3.css 的 `.gpin .map-pin`：36×36、內圈 11、2.5px 乳白
          // 描邊。旋轉後對角線比邊長多出 (√2-1)×36/2 ≈ 7.5px，所以外層要留
          // 這段空間，尖端才不會被 Column 的邊界裁掉。
          SizedBox(
            width: _pinBox,
            height: _pinBox,
            child: Center(
              child: Transform.rotate(
                angle: -math.pi / 4,
                child: Container(
                  width: _pinSize,
                  height: _pinSize,
                  decoration: BoxDecoration(
                    color: tokens.clay,
                    border: Border.all(color: _pinBorder, width: 2.5),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(_pinSize / 2),
                      topRight: Radius.circular(_pinSize / 2),
                      bottomRight: Radius.circular(_pinSize / 2),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(28, 20, 10, 0.4),
                        offset: Offset(0, 4),
                        blurRadius: 9,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: const BoxDecoration(
                        color: _pinBorder,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
