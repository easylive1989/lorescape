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
    final projection = OrthographicProjection(
      rotation: _rotation,
      center: Offset(widget.size / 2, widget.size / 2),
      radius: widget.size / 2 - 3,
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
      width: widget.size,
      height: widget.size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onPanStart: _onDragStart,
            onPanUpdate: _onDragUpdate,
            child: CustomPaint(
              key: GlobeView.canvasKey,
              size: Size.square(widget.size),
              painter: GlobePainter(
                outline: widget.outline,
                pins: widget.pins,
                rotation: _rotation,
                focusId: focus?.id,
              ),
            ),
          ),
          // focusOffset 在焦點剛切換、旋轉還沒轉到那一面時可能是 null（該點暫時
          // 在地球背面投影不出來）；這種情況先不畫標記，等飛行動畫轉過去再顯示。
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
  }
}

/// 選中地點的水滴 pin 與其上方的紙卡 chip。用 widget 而非 canvas，字體與
/// 陰影才會跟 App 其他地方一致。
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
          Transform.rotate(
            angle: -0.7853981634, // -45 度，讓方角朝下當作水滴尖端
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: tokens.clay,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(13),
                  topRight: Radius.circular(13),
                  bottomLeft: Radius.circular(13),
                ),
                boxShadow: tokens.e1,
              ),
              child: Center(
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: tokens.paperRaised,
                    shape: BoxShape.circle,
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
