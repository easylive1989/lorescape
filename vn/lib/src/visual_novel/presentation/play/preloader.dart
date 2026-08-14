import 'package:flutter/material.dart';
import 'package:lorescape_vn/src/visual_novel/providers.dart';

/// Web 上單張 PNG 有 2.2–2.6 MB，AssetImage 是進到那個節點才走 HTTP 抓，
/// 不預載就會看到背景先白一下。把「這一場的背景 ＋ 下一場的背景 ＋ 台上角色的
/// 所有表情」先塞進 image cache。失敗（缺件）不影響畫面，吞掉即可。
Future<void> precacheNode(
  BuildContext context,
  PackRepository repository,
  Story story,
  PlayState state,
) async {
  final paths = <String>{};
  final scene = story.scenes[state.cursor.sceneId];
  if (scene != null) {
    final background = repository.backgroundPath(story, scene.background);
    if (background != null) paths.add(background);
    final next = scene.next == null ? null : story.scenes[scene.next];
    if (next != null) {
      final path = repository.backgroundPath(story, next.background);
      if (path != null) paths.add(path);
    }
  }
  for (final sprite in state.stage) {
    for (final expression in story.characters[sprite.who]?.sprites?.keys ?? const <String>[]) {
      final path = repository.spritePath(story, sprite.who, expression);
      if (path != null) paths.add(path);
    }
  }
  for (final path in paths) {
    if (!context.mounted) return;
    await precacheImage(AssetImage(path), context, onError: (_, _) {});
  }
}
