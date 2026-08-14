import 'dart:async';

import 'package:flutter/material.dart';

/// 逐字顯示。`completed` 由外部控制——玩家點一下畫面就把它設 true，
/// 讓這一段立刻補完而不是推進到下一段。
class TypewriterText extends StatefulWidget {
  const TypewriterText({
    required this.text,
    required this.style,
    required this.msPerCharacter,
    required this.completed,
    required this.onCompleted,
    super.key,
  });

  static const ValueKey<String> key_ = ValueKey<String>('typewriter');

  final String text;
  final TextStyle style;
  final double msPerCharacter;
  final bool completed;
  final VoidCallback onCompleted;

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  Timer? _timer;
  int _shown = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _shown = 0;
      _start();
    } else if (widget.completed && !oldWidget.completed) {
      _finish();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    if (widget.completed || widget.msPerCharacter <= 0) {
      _shown = widget.text.length;
      return;
    }
    _timer = Timer.periodic(
      Duration(milliseconds: widget.msPerCharacter.round()),
      (timer) {
        if (_shown >= widget.text.length) {
          _finish();
          return;
        }
        setState(() => _shown++);
        if (_shown >= widget.text.length) _finish();
      },
    );
  }

  void _finish() {
    _timer?.cancel();
    _timer = null;
    if (_shown != widget.text.length) setState(() => _shown = widget.text.length);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onCompleted();
    });
  }

  @override
  Widget build(BuildContext context) =>
      Text(widget.text.substring(0, _shown), style: widget.style);
}
