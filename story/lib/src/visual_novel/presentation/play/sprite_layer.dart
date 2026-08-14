import 'package:flutter/material.dart';
import 'package:lorescape_story/src/visual_novel/presentation/play/layout.dart';
import 'package:lorescape_story/src/visual_novel/providers.dart';

class SpriteLayer extends StatelessWidget {
  const SpriteLayer({
    required this.stage,
    required this.pathOf,
    required this.layout,
    super.key,
  });

  final List<SpriteOnStage> stage;
  final String? Function(SpriteOnStage sprite) pathOf;
  final VnLayout layout;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        for (var i = 0; i < stage.length; i++)
          _sprite(stage[i], i, stage.length),
      ],
    );
  }

  Widget _sprite(SpriteOnStage sprite, int index, int total) {
    final path = pathOf(sprite);
    if (path == null) return const SizedBox.shrink();
    // 單人置中；雙人左右各偏移 0.18w。實測不存在三人同台。
    final dx = total == 1
        ? 0.0
        : (index == 0 ? -layout.spriteOffset : layout.spriteOffset);
    Widget image = Image.asset(
      path,
      height: layout.spriteHeight,
      fit: BoxFit.fitHeight,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
    if (sprite.filter == 'memory_desaturate') {
      // 劇本在 missingAssets 裡對這個 filter 的註記是「回憶段落用去飽和＋暖色
      // 偏移濾鏡，立繪沿用既有資產不另出圖」——所以不是純灰階，要帶暖色。
      // 三列的權重和分別是 1.06 / 0.94 / 0.76：紅偏亮、藍壓低。
      //
      // ⚠️ `missingAssets['filter']` 含 'memory_desaturate'，但那是「引擎要實作
      // 的效果」而非缺圖，**不要**拿它去做缺件降級把濾鏡跳過。
      image = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.42,
          0.50,
          0.14,
          0,
          12,
          0.36,
          0.46,
          0.12,
          0,
          4,
          0.28,
          0.38,
          0.10,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: image,
      );
    }
    return Positioned(
      key: ValueKey<String>('sprite-${sprite.who}'),
      bottom: layout.spriteBottom,
      left: 0,
      right: 0,
      child: Transform.translate(
        offset: Offset(dx, 0),
        child: Center(child: image),
      ),
    );
  }
}
