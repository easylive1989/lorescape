import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lorescape_story/src/visual_novel/data/story_json_parser.dart';
import 'package:lorescape_story/src/visual_novel/domain/story.dart';

Story loadFixture(String dir) {
  final file = File('assets/content/pompeii-79/stories/$dir/story.json');
  return parseStory(
    jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
  );
}

/// 遞迴走訪節點，含 if 的 then／orElse 與選項的 then——
/// 08-the-new-house 的 filter 節點就是巢狀在 if.then 底下，不遞迴找不到。
Iterable<StoryNode> flattenNodes(List<StoryNode> nodes) sync* {
  for (final node in nodes) {
    yield node;
    switch (node) {
      case IfNode():
        yield* flattenNodes(node.then);
        yield* flattenNodes(node.orElse);
      case ChoiceNode():
        for (final option in node.options) {
          yield* flattenNodes(option.then);
        }
      default:
        break;
    }
  }
}

void main() {
  group('parseStory', () {
    test('讀出線性故事的 meta 與單一結局', () {
      final story = loadFixture('01-harbour-stranger');
      expect(story.meta.id, 'pompeii_01_harbour_stranger');
      expect(story.meta.order, 1);
      expect(story.meta.subtitle, '爆發前一日');
      expect(story.variables, isEmpty);
      expect(story.start, 'S01');
      expect(story.scenes.length, 10);
      expect(story.endings.keys, <String>['A']);
    });

    test('主角是無立繪角色', () {
      final story = loadFixture('01-harbour-stranger');
      expect(story.characters['zabda']!.isPlayer, isTrue);
      expect(story.characters['zabda']!.sprites, isNull);
      expect(
        story.characters['vibia']!.sprites!['softened'],
        'vibia_softened.png',
      );
    });

    test('結局場帶 isEnding 與 endingId，且沒有 next', () {
      final scene = loadFixture('01-harbour-stranger').scenes['E_A']!;
      expect(scene.isEnding, isTrue);
      expect(scene.endingId, 'A');
      expect(scene.next, isNull);
      expect(scene.nodes.whereType<CgNode>().single.hideDialogue, isTrue);
    });

    test('八篇均無選項、條件分支與狀態變數', () {
      for (final dir in const <String>[
        '01-harbour-stranger',
        '02-the-oven-went-out',
        '03-the-well-fell',
        '04-the-tree-in-the-sky',
        '05-the-tablets',
        '06-the-locked-door',
        '07-cannot-land',
        '08-the-new-house',
      ]) {
        final story = loadFixture(dir);
        final nodes = story.scenes.values.expand(
          (scene) => flattenNodes(scene.nodes),
        );
        expect(story.variables, isEmpty, reason: dir);
        expect(story.endings, hasLength(1), reason: dir);
        expect(nodes.whereType<ChoiceNode>(), isEmpty, reason: dir);
        expect(nodes.whereType<IfNode>(), isEmpty, reason: dir);
      }
    });

    test('八篇都解得出來，且沒有未知節點型別', () {
      const dirs = <String>[
        '01-harbour-stranger',
        '02-the-oven-went-out',
        '03-the-well-fell',
        '04-the-tree-in-the-sky',
        '05-the-tablets',
        '06-the-locked-door',
        '07-cannot-land',
        '08-the-new-house',
      ];
      for (final dir in dirs) {
        expect(() => loadFixture(dir), returnsNormally, reason: dir);
      }
    });

    test('未知的節點型別要報明確錯誤，不得靜默忽略', () {
      expect(
        () => parseStory(<String, dynamic>{
          'meta': <String, dynamic>{
            'id': 'x',
            'pack': 'p',
            'order': 1,
            'title': 't',
            'subtitle': '',
            'estimatedMinutes': 1,
            'locale': 'zh-Hant',
          },
          'variables': <String, dynamic>{},
          'characters': <String, dynamic>{},
          'backgrounds': <String, dynamic>{},
          'missingAssets': <dynamic>[],
          'start': 'S01',
          'scenes': <String, dynamic>{
            'S01': <String, dynamic>{
              'title': 't',
              'background': 'b',
              'nodes': <dynamic>[
                <String, dynamic>{'t': 'wat'},
              ],
              'isEnding': true,
              'endingId': 'A',
            },
          },
          'endings': <String, dynamic>{
            'A': <String, dynamic>{'title': 'x', 'note': 'y'},
          },
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
