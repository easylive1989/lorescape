import 'dart:convert';
import 'dart:io';

import 'package:characters/characters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lorescape_vn/src/visual_novel/data/story_json_parser.dart';
import 'package:lorescape_vn/src/visual_novel/domain/play_state.dart';
import 'package:lorescape_vn/src/visual_novel/domain/story.dart';
import 'package:lorescape_vn/src/visual_novel/domain/story_player.dart';

const String packRoot = 'assets/content/pompeii-79';

/// 已確認的死碼——劇本裡在任何路徑上都走不到的 if 分支。
///
/// 這不是測試問題，是內容問題，等作者決定要不要改（見 task-6-report）。
/// 用 allowlist 而不是 `skip:`，是為了讓兩個方向都有訊號：多出新的死碼會紅，
/// 而死碼被修好之後這裡沒刪也會紅。
const Map<String, Set<String>> knownDeadBranches = <String, Set<String>>{
  // awareness 有三個無條件 +1（S02/S05/S07），到 S08 必為 3，else 永不成立
  '01-harbour-stranger': <String>{'S08#6.else.'},
  // 結局 A 的閘門要 conviction>=2，而 conviction 與 standing 在同三個選擇點互斥
  '03-the-well-fell': <String>{'E_A#9.then.'},
  // 結局 A 的閘門要 nerve>=2，nerve 只有兩個來源，兩個都選走 kinship 就上不去
  '06-the-locked-door': <String>{'E_A#12.then.'},
};

/// 逐篇窮舉的基準（路徑數、選項覆蓋數、非空 if 分支數）。存在的理由是補上
/// 「內容被整段刪掉時測試依然全綠」這個洞——`declared.difference(taken)` 與
/// `unreached` 這類集合斷言在集合為空時也會通過，只有跟實測基準比對才擋得住
/// 分歧被誤刪。數字來自 task-6-report.md 記錄的實測結果。
const Map<String, ({int paths, int options, int branches})> walkBaselines =
    <String, ({int paths, int options, int branches})>{
      '01-harbour-stranger': (paths: 128, options: 14, branches: 9),
      '02-the-oven-went-out': (paths: 40, options: 11, branches: 3),
      '03-the-well-fell': (paths: 16, options: 8, branches: 4),
      '04-the-tree-in-the-sky': (paths: 20, options: 9, branches: 2),
      '05-the-tablets': (paths: 80, options: 13, branches: 3),
      '06-the-locked-door': (paths: 32, options: 10, branches: 4),
      '07-cannot-land': (paths: 32, options: 10, branches: 2),
      '08-the-new-house': (paths: 20, options: 9, branches: 3),
    };

List<Map<String, String>> loadPackEntries() {
  final pack =
      jsonDecode(File('$packRoot/pack.json').readAsStringSync())
          as Map<String, dynamic>;
  return (pack['stories'] as List<dynamic>)
      .map((e) => e as Map<String, dynamic>)
      .map(
        (e) => <String, String>{
          'dir': e['dir'] as String,
          'title': e['title'] as String,
        },
      )
      .toList();
}

/// 素材的實際格式，由 `import_pack.py` 寫進 pack.json。
final String packAssetFormat =
    (jsonDecode(File('$packRoot/pack.json').readAsStringSync())
            as Map<String, dynamic>)['assetFormat']
        as String? ??
    'png';

String withPackExtension(String filename) =>
    packAssetFormat == 'png' || !filename.endsWith('.png')
    ? filename
    : '${filename.substring(0, filename.length - 4)}.$packAssetFormat';

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

  /// 走到結局的次數（＝窮舉出的路徑數）。
  int paths = 0;

  /// 劇本結構裡非空 if 分支的數量（見 [countNonEmptyIfBranches]）。
  int branchCount = 0;
}

/// 掃描整篇劇本，數出結構上非空的 if 分支數（`then`／`else` 各自算一個，
/// 只要陣列不是空的就算，跟走訪路徑無關）。用來填 [WalkResult.branchCount]，
/// 也是「走訪規模符合實測基準」那條測試比對的其中一個數字。
int countNonEmptyIfBranches(List<StoryNode> nodes) {
  var count = 0;
  for (final node in nodes) {
    if (node is IfNode) {
      if (node.then.isNotEmpty) count++;
      if (node.orElse.isNotEmpty) count++;
      count += countNonEmptyIfBranches(node.then);
      count += countNonEmptyIfBranches(node.orElse);
    } else if (node is ChoiceNode) {
      for (final option in node.options) {
        count += countNonEmptyIfBranches(option.then);
      }
    }
  }
  return count;
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
      result.paths++;
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
        result.takenOptions.add(
          '${current.cursor.readKey}#opt${visible[i].index}',
        );
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
        for (final scene in story.scenes.values) {
          result.branchCount += countNonEmptyIfBranches(scene.nodes);
        }
      });

      test('三個結局全部可達', () {
        expect(result.endings, story.endings.keys.toSet());
      });

      test('走訪規模符合實測基準', () {
        // 沒有下限斷言的話，內容被刪掉一整段分歧時這組測試依然全綠。
        final baseline = walkBaselines[dir]!;
        expect(result.paths, baseline.paths, reason: '路徑數變了');
        expect(result.takenOptions.length, baseline.options, reason: '選項數變了');
        expect(result.branchCount, baseline.branches, reason: '非空 if 分支數變了');
      });

      test('每個非空 if 分支都至少有一個直接的停頓節點', () {
        // 前綴判定的前提。若有人寫出 `if (x) { show ... }` 這種只有副作用的分支，
        // 判定會誤報成走不到——註解擋不住，這條斷言才擋得住。
        void scan(List<StoryNode> nodes) {
          for (final node in nodes) {
            if (node is IfNode) {
              for (final side in <List<StoryNode>>[node.then, node.orElse]) {
                if (side.isEmpty) continue;
                expect(
                  side.any(
                    (n) =>
                        n is NarrationNode ||
                        n is DialogueNode ||
                        n is CgNode ||
                        n is ChoiceNode,
                  ),
                  isTrue,
                  reason: '這個 if 分支沒有直接的停頓節點，前綴判定會誤報',
                );
                scan(side);
              }
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

      test('每個 if 的 then 與非空 else 都走得到', () {
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
                // 判定「這個分支走到了沒」要看**有沒有任何已讀鍵落在它底下**，
                // 不能只看 `.then.0`。readKeys 只記錄游標停下來的位置，而分支的
                // 第一個節點若是 show／sfx 這種不停頓的型別，游標永遠不會停在
                // `.0` 上——實測 8 篇有 4 個分支正是如此（01/S07、01/E_C、
                // 05/S06、08/S04），用 `.0` 判定會全部誤報成走不到。
                // 前綴比對是可靠的：實測沒有任何分支是純副作用節點，每個分支
                // 內都至少有一個會停頓的節點。
                final prefix =
                    '$sceneId#${<String>[...here, side.$1].join('.')}.';
                if (!result.readKeys.any((key) => key.startsWith(prefix))) {
                  unreached.add(prefix);
                }
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
        final known = knownDeadBranches[dir] ?? const <String>{};
        expect(
          unreached.toSet().difference(known),
          isEmpty,
          reason: '出現新的死碼——這些 if 分支在任何路徑上都進不去',
        );
        expect(
          known.difference(unreached.toSet()),
          isEmpty,
          reason: '這些死碼已經走得到了，請從 knownDeadBranches 刪掉',
        );
      });

      test('變數不超過宣告的上限', () {
        story.variables.forEach((name, spec) {
          final reached = result.maxima[name];
          if (reached == null) return;
          expect(
            reached,
            lessThanOrEqualTo(spec.max),
            reason: '$name 超過宣告的 max',
          );
        });
      });

      test('參照的每個資產檔都存在', () {
        // story.json 一律寫 `.png`，實際輸出可能是 `.webp`——劇本是逐字複製
        // 的、不能改，副檔名的轉換是引擎組路徑時的職責。這條測試因此要跟著
        // pack.json 的 assetFormat 走，直接拿 story.json 的檔名找檔案會誤判。
        for (final filename in story.backgrounds.values) {
          expect(
            File(
              '$packRoot/assets/backgrounds/${withPackExtension(filename)}',
            ).existsSync(),
            isTrue,
            reason: filename,
          );
        }
        for (final character in story.characters.values) {
          for (final filename
              in (character.sprites ?? const <String, String>{}).values) {
            expect(
              File(
                '$packRoot/assets/sprites/${withPackExtension(filename)}',
              ).existsSync(),
              isTrue,
              reason: filename,
            );
          }
        }
        void scanCg(List<StoryNode> nodes) {
          for (final node in nodes) {
            if (node is CgNode) {
              expect(
                File(
                  '$packRoot/assets/backgrounds/'
                  '${withPackExtension('${node.id}.png')}',
                ).existsSync(),
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
              expect(
                text.characters.length,
                lessThanOrEqualTo(60),
                reason: text,
              );
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
