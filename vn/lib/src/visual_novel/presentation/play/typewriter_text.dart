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

  /// onCompleted 對同一段文字只能通知一次。
  ///
  /// 沒有這個旗標會被打兩次：timer 自然打完先通知一次 → 父層的 `_typingDone`
  /// 翻 true 觸發 rebuild → 新 widget 的 `completed` 是 true 而舊的是 false
  /// （打字期間父層不會因為逐字動畫本身而重繪）→ `didUpdateWidget` 的
  /// 「外部強制補完」分支再通知一次。目前呼叫端剛好是冪等的所以看不出來，
  /// 但只要有人接一個「打完字播音效」就會聽到兩聲。
  bool _notified = false;

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
    _notified = false;
    if (widget.completed || widget.msPerCharacter <= 0) {
      // 一開始就是完成狀態（已讀節點直接顯示全文）也要通知——否則父層的
      // `_typingDone` 永遠不會翻 true，玩家對已讀節點的第一次點擊會變成
      // 無效的「補完」，每一格都要多點一次。
      _shown = widget.text.length;
      _notify();
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
    if (_shown != widget.text.length) {
      setState(() => _shown = widget.text.length);
    }
    _notify();
  }

  void _notify() {
    if (_notified) return;
    _notified = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onCompleted();
    });
  }

  @override
  Widget build(BuildContext context) =>
      Text(widget.text.substring(0, _shown), style: widget.style);
}
