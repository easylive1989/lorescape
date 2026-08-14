import 'package:flutter/material.dart';
import 'package:lorescape_story/src/visual_novel/presentation/play/layout.dart';

class BackgroundLayer extends StatelessWidget {
  const BackgroundLayer({required this.assetPath, super.key});

  final String? assetPath;

  @override
  Widget build(BuildContext context) {
    final path = assetPath;
    if (path == null) return const ColoredBox(color: VnColors.ground);
    return Image.asset(
      path,
      fit: BoxFit.cover,
      // 關鍵構圖都在上半部，螢幕更長時裁下緣（美術風格聖經 §3.1）。
      alignment: Alignment.topCenter,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => const ColoredBox(color: VnColors.ground),
    );
  }
}
