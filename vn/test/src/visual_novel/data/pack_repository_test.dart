import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lorescape_vn/src/visual_novel/data/pack_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final repo = BundlePackRepository(rootBundle);

  test('讀得到 pack.json 的 8 篇，且依 order 排序', () async {
    final pack = await repo.loadPack();
    expect(pack.stories, hasLength(8));
    expect(pack.stories.first.title, '港口的外地人');
    expect(pack.stories.map((s) => s.order), List<int>.generate(8, (i) => i + 1));
  });

  test('用 storyId 載入劇本', () async {
    final story = await repo.loadStory('pompeii_01_harbour_stranger');
    expect(story.scenes, hasLength(12));
  });

  test('資產路徑組成景點包共用池的位置', () async {
    final story = await repo.loadStory('pompeii_01_harbour_stranger');
    expect(repo.backgroundPath(story, 'harbour'),
        'assets/content/pompeii-79/assets/backgrounds/bg_harbour.png');
    expect(repo.spritePath(story, 'vibia', 'softened'),
        'assets/content/pompeii-79/assets/sprites/vibia_softened.png');
    expect(repo.cgPath(story, 'cg_column_rising'),
        'assets/content/pompeii-79/assets/backgrounds/cg_column_rising.png');
  });

  test('無立繪角色與未知背景 key 回 null，不丟例外', () async {
    final story = await repo.loadStory('pompeii_01_harbour_stranger');
    expect(repo.spritePath(story, 'zabda', 'neutral'), isNull);
    expect(repo.backgroundPath(story, 'nowhere'), isNull);
  });
}
