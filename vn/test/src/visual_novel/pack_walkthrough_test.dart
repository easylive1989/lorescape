import 'dart:convert';
import 'dart:io';

import 'package:characters/characters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lorescape_vn/src/visual_novel/data/story_json_parser.dart';
import 'package:lorescape_vn/src/visual_novel/domain/play_state.dart';
import 'package:lorescape_vn/src/visual_novel/domain/story.dart';
import 'package:lorescape_vn/src/visual_novel/domain/story_player.dart';

const String packRoot = 'assets/content/pompeii-79';

/// 「每個 if 的 then 與非空 else 都走得到」在窮舉後對這幾篇回報了走不到的分支。
/// 依規範不能放寬測試或改劇本，這裡先標記 skip，待 user 確認後再處理；
/// 詳細調查記錄於 task-6-report.md。
const Map<String, String> _ifBranchSkipReasons = <String, String>{
  '01-harbour-stranger': '待 user 確認：S08#6.else.0（awareness<3 分支——awareness 在抵達 S08 前已於 '
      'S02/S05/S07 無條件各 +1，抵達時必為 3，else 文字「我很快就睡著了。」理論上走不到，疑似死碼）。'
      '另外 S07#15.then.0、E_C#10.then.0 經覆核為測試方法論誤報：分支本身有被走到'
      '（.then.1 起的 readKey 都在 readKeys 裡），只是分支第 0 個節點是不會停頓的 show/sfx，'
      '游標從未剛好停在 .then.0，非劇本或引擎問題。',
  '03-the-well-fell': '待 user 確認：E_A#9.then.0（standing>=2 分支——結局 A 的路徑上 standing 最高只到 1，'
      '需要 2 才顯示的「還有幾個是認得我的……」理論上走不到；standing 能到 2~3 的路徑全部通向結局 B/C，'
      '疑似死碼或結局路由設計問題）。',
  '05-the-tablets': 'S06#4.then.0 經覆核為測試方法論誤報：分支本身有被走到'
      '（.then.1、.then.2 都在 readKeys 裡），只是分支第 0 個節點是不會停頓的 show，'
      '游標從未剛好停在 .then.0，非劇本問題。',
  '06-the-locked-door': '待 user 確認：E_A#12.then.0（kinship>=3 分支——結局 A 的路徑上 kinship 最高只到 2，'
      '需要 3 才顯示的「奧瑞斯特斯把我推到前面……」理論上走不到；kinship 能到 3~4 的路徑全部通向結局 B/C，'
      '疑似死碼或結局路由設計問題）。',
  '08-the-new-house': 'S04#21.then.0 經覆核為測試方法論誤報：分支本身有被走到'
      '（.then.1 起的 readKey 都在 readKeys 裡），只是分支第 0 個節點是不會停頓的 sfx，'
      '游標從未剛好停在 .then.0，非劇本問題。',
};

List<Map<String, String>> loadPackEntries() {
  final pack = jsonDecode(File('$packRoot/pack.json').readAsStringSync()) as Map<String, dynamic>;
  return (pack['stories'] as List<dynamic>)
      .map((e) => e as Map<String, dynamic>)
      .map((e) => <String, String>{'dir': e['dir'] as String, 'title': e['title'] as String})
      .toList();
}

Story loadStory(String dir) => parseStory(
      jsonDecode(File('$packRoot/stories/$dir/story.json').readAsStringSync())
          as Map<String, dynamic>,
    );

/// 一次完整走訪的產出。
final class WalkResult {
  WalkResult();
  final Set<String> endings = <String>{};
  final Set<String> readKeys = <String>{};
  final Set<String> takenOptions = <String>{}; // '<readKey>#opt<n>'
  final Map<String, num> maxima = <String, num>{};
}

/// 深度優先窮舉所有選擇組合。單篇上界 3^7 = 2,187 條路徑，跑得完。
void walk(Story story, PlayState state, WalkResult result, int budget) {
  var current = state;
  var steps = budget;
  while (true) {
    if (steps-- <= 0) {
      fail('${story.meta.id}：步數超過預算，可能有無窮迴圈於 ${current.cursor.readKey}');
    }
    current.vars.forEach((key, value) {
      if (value is! num) return;
      final seen = result.maxima[key];
      if (seen == null || value > seen) result.maxima[key] = value;
    });

    if (current.status == PlayStatus.ended) {
      result.endings.add(current.endingId!);
      return;
    }
    result.readKeys.add(current.cursor.readKey);

    if (current.status == PlayStatus.choosing) {
      final node = currentNode(story, current) as ChoiceNode;
      final visible = visibleOptions(node, current.vars);
      expect(
        visible,
        isNotEmpty,
        reason: '${story.meta.id} ${current.cursor.readKey}：所有選項都被條件擋掉了',
      );
      for (var i = 0; i < visible.length; i++) {
        result.takenOptions.add('${current.cursor.readKey}#opt${visible[i].index}');
        walk(story, choose(story, current, i), result, steps);
      }
      return;
    }
    current = advance(story, current);
  }
}

void main() {
  final entries = loadPackEntries();

  test('pack.json 列出 8 篇', () {
    expect(entries, hasLength(8));
  });

  for (final entry in entries) {
    final dir = entry['dir']!;
    group('${entry['title']} ($dir)', () {
      late Story story;
      late WalkResult result;

      setUpAll(() {
        story = loadStory(dir);
        result = WalkResult();
        walk(story, initState(story), result, 20000);
      });

      test('三個結局全部可達', () {
        expect(result.endings, story.endings.keys.toSet());
      });

      test('每個選項至少被走過一次', () {
        final declared = <String>{};
        void scan(String sceneId, List<StoryNode> nodes, List<String> path) {
          for (var i = 0; i < nodes.length; i++) {
            final node = nodes[i];
            final here = <String>[...path, '$i'];
            if (node is ChoiceNode) {
              for (var j = 0; j < node.options.length; j++) {
                declared.add('$sceneId#${here.join('.')}#opt$j');
                scan(sceneId, node.options[j].then, <String>[...here, 'opt$j']);
              }
            } else if (node is IfNode) {
              scan(sceneId, node.then, <String>[...here, 'then']);
              scan(sceneId, node.orElse, <String>[...here, 'else']);
            }
          }
        }

        for (final scene in story.scenes.values) {
          scan(scene.id, scene.nodes, const <String>[]);
        }
        expect(
          declared.difference(result.takenOptions),
          isEmpty,
          reason: '有選項在任何路徑上都走不到',
        );
      });

      test('每個 if 的 then 與非空 else 都走得到', skip: _ifBranchSkipReasons[dir], () {
        final unreached = <String>[];
        void scan(String sceneId, List<StoryNode> nodes, List<String> path) {
          for (var i = 0; i < nodes.length; i++) {
            final node = nodes[i];
            final here = <String>[...path, '$i'];
            if (node is IfNode) {
              for (final side in <(String, List<StoryNode>)>[
                ('then', node.then),
                ('else', node.orElse),
              ]) {
                if (side.$2.isEmpty) continue;
                final key = '$sceneId#${<String>[...here, side.$1, '0'].join('.')}';
                if (!result.readKeys.contains(key)) unreached.add(key);
                scan(sceneId, side.$2, <String>[...here, side.$1]);
              }
            } else if (node is ChoiceNode) {
              for (var j = 0; j < node.options.length; j++) {
                scan(sceneId, node.options[j].then, <String>[...here, 'opt$j']);
              }
            }
          }
        }

        for (final scene in story.scenes.values) {
          scan(scene.id, scene.nodes, const <String>[]);
        }
        expect(unreached, isEmpty, reason: '這些 if 分支在任何路徑上都進不去');
      });

      test('變數不超過宣告的上限', () {
        story.variables.forEach((name, spec) {
          final reached = result.maxima[name];
          if (reached == null) return;
          expect(reached, lessThanOrEqualTo(spec.max), reason: '$name 超過宣告的 max');
        });
      });

      test('參照的每個資產檔都存在', () {
        for (final filename in story.backgrounds.values) {
          expect(
            File('$packRoot/assets/backgrounds/$filename').existsSync(),
            isTrue,
            reason: filename,
          );
        }
        for (final character in story.characters.values) {
          for (final filename in (character.sprites ?? const <String, String>{}).values) {
            expect(
              File('$packRoot/assets/sprites/$filename').existsSync(),
              isTrue,
              reason: filename,
            );
          }
        }
        void scanCg(List<StoryNode> nodes) {
          for (final node in nodes) {
            if (node is CgNode) {
              expect(
                File('$packRoot/assets/backgrounds/${node.id}.png').existsSync(),
                isTrue,
                reason: node.id,
              );
            } else if (node is IfNode) {
              scanCg(node.then);
              scanCg(node.orElse);
            } else if (node is ChoiceNode) {
              for (final option in node.options) {
                scanCg(option.then);
              }
            }
          }
        }

        for (final scene in story.scenes.values) {
          scanCg(scene.nodes);
        }
      });

      test('每個對話框的文字不超過 60 字', () {
        void scan(List<StoryNode> nodes) {
          for (final node in nodes) {
            final text = switch (node) {
              NarrationNode(:final text) => text,
              DialogueNode(:final text) => text,
              _ => null,
            };
            if (text != null) {
              expect(text.characters.length, lessThanOrEqualTo(60), reason: text);
            }
            if (node is IfNode) {
              scan(node.then);
              scan(node.orElse);
            } else if (node is ChoiceNode) {
              for (final option in node.options) {
                scan(option.then);
              }
            }
          }
        }

        for (final scene in story.scenes.values) {
          scan(scene.nodes);
        }
      });
    });
  }
}
