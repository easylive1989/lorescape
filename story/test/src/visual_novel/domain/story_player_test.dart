import 'package:flutter_test/flutter_test.dart';
import 'package:lorescape_story/src/visual_novel/data/story_json_parser.dart';
import 'package:lorescape_story/src/visual_novel/domain/cursor.dart';
import 'package:lorescape_story/src/visual_novel/domain/play_state.dart';
import 'package:lorescape_story/src/visual_novel/domain/story.dart';
import 'package:lorescape_story/src/visual_novel/domain/story_player.dart';

Story build(
  Map<String, dynamic> scenes, {
  Map<String, dynamic>? variables,
  Map<String, dynamic>? characters,
}) {
  return parseStory(<String, dynamic>{
    'meta': <String, dynamic>{
      'id': 'test',
      'pack': 'p',
      'order': 1,
      'title': 't',
      'subtitle': '',
      'estimatedMinutes': 1,
      'locale': 'zh-Hant',
    },
    'variables': variables ?? <String, dynamic>{},
    'characters':
        characters ??
        <String, dynamic>{
          'a': <String, dynamic>{'name': '甲', 'sprites': null},
        },
    'backgrounds': <String, dynamic>{'bg': 'bg.png'},
    'missingAssets': <dynamic>[],
    'start': 'S01',
    'scenes': scenes,
    'endings': <String, dynamic>{
      'A': <String, dynamic>{'title': '結局 A', 'note': ''},
    },
  });
}

Map<String, dynamic> scene(
  List<dynamic> nodes, {
  String? next,
  bool isEnding = false,
  String? endingId,
}) => <String, dynamic>{
  'title': '場',
  'background': 'bg',
  'nodes': nodes,
  if (next != null) 'next': next,
  if (isEnding) 'isEnding': true,
  if (endingId != null) 'endingId': endingId,
};

void main() {
  group('advance', () {
    test('副作用節點不停頓，直接走到下一個會停的節點', () {
      final story = build(<String, dynamic>{
        'S01': scene(
          <dynamic>[
            <String, dynamic>{'t': 'sfx', 'id': 'footsteps'},
            <String, dynamic>{'t': 'show', 'who': 'a', 'sprite': 'neutral'},
            <String, dynamic>{'t': 'n', 'text': '第一句'},
          ],
          isEnding: true,
          endingId: 'A',
        ),
      });
      final state = initState(story);
      expect(currentNode(story, state), isA<NarrationNode>());
      expect((currentNode(story, state) as NarrationNode).text, '第一句');
      expect(state.stage.single.who, 'a', reason: 'show 的副作用要套用');
    });

    test('hide 收掉台上所有立繪', () {
      final story = build(<String, dynamic>{
        'S01': scene(
          <dynamic>[
            <String, dynamic>{'t': 'show', 'who': 'a', 'sprite': 'neutral'},
            <String, dynamic>{'t': 'n', 'text': '一'},
            <String, dynamic>{'t': 'hide'},
            <String, dynamic>{'t': 'n', 'text': '二'},
          ],
          isEnding: true,
          endingId: 'A',
        ),
      });
      var state = initState(story);
      expect(state.stage, hasLength(1));
      state = advance(story, state);
      expect(state.stage, isEmpty);
    });

    test('if 成立時走 then，並在走完後回到上一層繼續', () {
      final story = build(
        <String, dynamic>{
          'S01': scene(
            <dynamic>[
              <String, dynamic>{'t': 'n', 'text': '前'},
              <String, dynamic>{
                't': 'if',
                'cond': <String, dynamic>{'var': 'v', 'op': '>=', 'value': 1},
                'then': <dynamic>[
                  <String, dynamic>{'t': 'n', 'text': '裡面'},
                ],
                'else': <dynamic>[
                  <String, dynamic>{'t': 'n', 'text': '另一邊'},
                ],
              },
              <String, dynamic>{'t': 'n', 'text': '後'},
            ],
            isEnding: true,
            endingId: 'A',
          ),
        },
        variables: <String, dynamic>{
          'v': <String, dynamic>{
            'label': 'v',
            'initial': 1,
            'min': 0,
            'max': 4,
          },
        },
      );
      var state = initState(story);
      state = advance(story, state);
      expect((currentNode(story, state) as NarrationNode).text, '裡面');
      expect(state.cursor.toTokens(), <String>['1', 'then', '0']);
      state = advance(story, state);
      expect((currentNode(story, state) as NarrationNode).text, '後');
      expect(state.cursor.toTokens(), <String>['2']);
    });

    test('if 不成立時走 else', () {
      final story = build(
        <String, dynamic>{
          'S01': scene(
            <dynamic>[
              <String, dynamic>{
                't': 'if',
                'cond': <String, dynamic>{'var': 'v', 'op': '>=', 'value': 9},
                'then': <dynamic>[
                  <String, dynamic>{'t': 'n', 'text': '裡面'},
                ],
                'else': <dynamic>[
                  <String, dynamic>{'t': 'n', 'text': '另一邊'},
                ],
              },
            ],
            isEnding: true,
            endingId: 'A',
          ),
        },
        variables: <String, dynamic>{
          'v': <String, dynamic>{
            'label': 'v',
            'initial': 0,
            'min': 0,
            'max': 4,
          },
        },
      );
      final state = initState(story);
      expect((currentNode(story, state) as NarrationNode).text, '另一邊');
    });

    test('走完場的根陣列後依 next 跳下一場', () {
      final story = build(<String, dynamic>{
        'S01': scene(<dynamic>[
          <String, dynamic>{'t': 'n', 'text': '一'},
        ], next: 'S02'),
        'S02': scene(
          <dynamic>[
            <String, dynamic>{'t': 'n', 'text': '二'},
          ],
          isEnding: true,
          endingId: 'A',
        ),
      });
      var state = initState(story);
      state = advance(story, state);
      expect(state.cursor.sceneId, 'S02');
      expect((currentNode(story, state) as NarrationNode).text, '二');
    });

    test('結局場走完後 status 變 ended 並帶出 endingId', () {
      final story = build(<String, dynamic>{
        'S01': scene(
          <dynamic>[
            <String, dynamic>{'t': 'n', 'text': '一'},
          ],
          isEnding: true,
          endingId: 'A',
        ),
      });
      final state = advance(story, initState(story));
      expect(state.status, PlayStatus.ended);
      expect(state.endingId, 'A');
    });

    test('沒有 next 也不是結局的場走完 → StateError', () {
      final story = build(<String, dynamic>{
        'S01': scene(<dynamic>[
          <String, dynamic>{'t': 'n', 'text': '一'},
        ]),
      });
      expect(() => advance(story, initState(story)), throwsStateError);
    });

    test('choice 讓 status 變 choosing', () {
      final story = build(<String, dynamic>{
        'S01': scene(<dynamic>[
          <String, dynamic>{
            't': 'choice',
            'options': <dynamic>[
              <String, dynamic>{'text': '甲', 'goto': 'S02'},
              <String, dynamic>{'text': '乙', 'goto': 'S02'},
            ],
          },
        ]),
        'S02': scene(
          <dynamic>[
            <String, dynamic>{'t': 'n', 'text': '二'},
          ],
          isEnding: true,
          endingId: 'A',
        ),
      });
      expect(initState(story).status, PlayStatus.choosing);
    });
  });

  group('規格明列、但最容易無聲壞掉的邊界', () {
    test('if 不成立且沒有 else 時，往下一個節點走（22/26 個 if 屬此類）', () {
      final story = build(
        <String, dynamic>{
          'S01': scene(
            <dynamic>[
              <String, dynamic>{
                't': 'if',
                'cond': <String, dynamic>{'var': 'v', 'op': '>=', 'value': 9},
                'then': <dynamic>[
                  <String, dynamic>{'t': 'n', 'text': '不該出現'},
                ],
              },
              <String, dynamic>{'t': 'n', 'text': '後面'},
            ],
            isEnding: true,
            endingId: 'A',
          ),
        },
        variables: <String, dynamic>{
          'v': <String, dynamic>{
            'label': 'v',
            'initial': 0,
            'min': 0,
            'max': 4,
          },
        },
      );
      final state = initState(story);
      expect((currentNode(story, state) as NarrationNode).text, '後面');
      expect(
        state.cursor.toTokens(),
        <String>['1'],
        reason: '空分支不得 push，否則 _listAt 拿到空陣列會誤觸「整場走完」而提前跳場',
      );
    });

    test('show 的 sprite 為 null 是 stage no-op', () {
      final story = build(<String, dynamic>{
        'S01': scene(
          <dynamic>[
            <String, dynamic>{'t': 'show', 'who': 'a', 'sprite': null},
            <String, dynamic>{'t': 'n', 'text': '一'},
          ],
          isEnding: true,
          endingId: 'A',
        ),
      });
      expect(initState(story).stage, isEmpty);
    });

    test('bgm 節點帶 id: null 會把 bgmId 清成 null', () {
      final story = build(<String, dynamic>{
        'S01': <String, dynamic>{
          'title': '場',
          'background': 'bg',
          'bgm': 'sea',
          'isEnding': true,
          'endingId': 'A',
          'nodes': <dynamic>[
            <String, dynamic>{'t': 'n', 'text': '一'},
            <String, dynamic>{'t': 'bgm', 'id': null},
            <String, dynamic>{'t': 'n', 'text': '二'},
          ],
        },
      });
      var state = initState(story);
      expect(state.bgmId, 'sea');
      state = advance(story, state);
      expect(state.bgmId, isNull);
    });

    test('連續 pop 兩層之後，外層的 index 正確 +1', () {
      final story = build(
        <String, dynamic>{
          'S01': scene(
            <dynamic>[
              <String, dynamic>{
                't': 'choice',
                'options': <dynamic>[
                  <String, dynamic>{
                    'text': '甲',
                    'then': <dynamic>[
                      <String, dynamic>{
                        't': 'if',
                        'cond': <String, dynamic>{
                          'var': 'v',
                          'op': '>=',
                          'value': 0,
                        },
                        'then': <dynamic>[
                          <String, dynamic>{'t': 'n', 'text': '最內層'},
                        ],
                      },
                    ],
                  },
                  <String, dynamic>{'text': '乙', 'goto': 'S01'},
                ],
              },
              <String, dynamic>{'t': 'n', 'text': '匯流'},
            ],
            isEnding: true,
            endingId: 'A',
          ),
        },
        variables: <String, dynamic>{
          'v': <String, dynamic>{
            'label': 'v',
            'initial': 0,
            'min': 0,
            'max': 4,
          },
        },
      );
      var state = choose(story, initState(story), 0);
      expect((currentNode(story, state) as NarrationNode).text, '最內層');
      expect(state.cursor.toTokens(), <String>['0', 'opt0', '0', 'then', '0']);
      state = advance(story, state);
      expect((currentNode(story, state) as NarrationNode).text, '匯流');
      expect(state.cursor.toTokens(), <String>['1']);
    });

    test('d 切表情保留該角色的濾鏡與台上位置', () {
      final story = build(
        <String, dynamic>{
          'S01': scene(
            <dynamic>[
              <String, dynamic>{
                't': 'show',
                'who': 'a',
                'sprite': 'neutral',
                'filter': 'memory_desaturate',
              },
              <String, dynamic>{'t': 'show', 'who': 'b', 'sprite': 'neutral'},
              <String, dynamic>{'t': 'n', 'text': '一'},
              <String, dynamic>{
                't': 'd',
                'who': 'a',
                'sprite': 'wry',
                'text': '二',
              },
            ],
            isEnding: true,
            endingId: 'A',
          ),
        },
        characters: <String, dynamic>{
          'a': <String, dynamic>{
            'name': '甲',
            'sprites': <String, dynamic>{'neutral': 'a.png', 'wry': 'aw.png'},
          },
          'b': <String, dynamic>{
            'name': '乙',
            'sprites': <String, dynamic>{'neutral': 'b.png'},
          },
        },
      );
      final state = advance(story, initState(story));
      expect(state.stage.map((s) => s.who), <String>[
        'a',
        'b',
      ], reason: '換表情不得改變左右站位');
      expect(state.stage.first.sprite, 'wry');
      expect(
        state.stage.first.filter,
        'memory_desaturate',
        reason: '換表情不得把 show 設定的濾鏡洗掉',
      );
    });

    test('advance 在 choosing 時不動作', () {
      final story = build(<String, dynamic>{
        'S01': scene(<dynamic>[
          <String, dynamic>{
            't': 'choice',
            'options': <dynamic>[
              <String, dynamic>{'text': '甲', 'goto': 'S02'},
              <String, dynamic>{'text': '乙', 'goto': 'S02'},
            ],
          },
        ]),
        'S02': scene(
          <dynamic>[
            <String, dynamic>{'t': 'n', 'text': '二'},
          ],
          isEnding: true,
          endingId: 'A',
        ),
      });
      final state = initState(story);
      expect(advance(story, state).cursor.toTokens(), state.cursor.toTokens());
      expect(advance(story, state).status, PlayStatus.choosing);
    });
  });

  group('resume', () {
    test('存檔停在選項上時，讀回來要是 choosing 而不是 playing', () {
      final story = build(<String, dynamic>{
        'S01': scene(<dynamic>[
          <String, dynamic>{
            't': 'choice',
            'options': <dynamic>[
              <String, dynamic>{'text': '甲', 'goto': 'S02'},
              <String, dynamic>{'text': '乙', 'goto': 'S02'},
            ],
          },
        ]),
        'S02': scene(
          <dynamic>[
            <String, dynamic>{'t': 'n', 'text': '二'},
          ],
          isEnding: true,
          endingId: 'A',
        ),
      });
      // 模擬讀檔：SaveData.toPlayState() 一律回 playing
      final fromSave = initState(story).copyWith(status: PlayStatus.playing);
      expect(resume(story, fromSave)!.status, PlayStatus.choosing);
    });

    test('存檔停在旁白上時維持 playing', () {
      final story = build(<String, dynamic>{
        'S01': scene(
          <dynamic>[
            <String, dynamic>{'t': 'n', 'text': '一'},
          ],
          isEnding: true,
          endingId: 'A',
        ),
      });
      expect(resume(story, initState(story))!.status, PlayStatus.playing);
    });

    test('結局場的越界游標還原成 ended 並帶回 endingId，不得 RangeError', () {
      final story = build(<String, dynamic>{
        'S01': scene(
          <dynamic>[
            <String, dynamic>{'t': 'n', 'text': '一'},
          ],
          isEnding: true,
          endingId: 'A',
        ),
      });
      // 結局狀態的游標必然越界——_settle 只在越界時才回傳 ended。
      final atEnd = initState(story).copyWith(
        cursor: Cursor.atSceneStart('S01').withLastIndex(1),
        status: PlayStatus.playing,
      );
      final restored = resume(story, atEnd)!;
      expect(restored.status, PlayStatus.ended);
      expect(restored.endingId, 'A');
    });

    test('路徑對不上現在的劇本時回 null，讓呼叫端退回開頭', () {
      final story = build(<String, dynamic>{
        'S01': scene(
          <dynamic>[
            <String, dynamic>{'t': 'n', 'text': '一'},
          ],
          isEnding: true,
          endingId: 'A',
        ),
      });
      final stale = initState(
        story,
      ).copyWith(cursor: Cursor.fromTokens('S01', <String>['0', 'then', '0']));
      expect(resume(story, stale), isNull, reason: 'S01[0] 是旁白，沒有 then 分支');
      expect(
        resume(
          story,
          initState(story).copyWith(cursor: Cursor.atSceneStart('S99')),
        ),
        isNull,
        reason: '場不存在',
      );
    });

    test('巢狀層越界回 null——不得被當成「整場走完」而傳送到結局', () {
      final story = build(<String, dynamic>{
        'S01': scene(
          <dynamic>[
            <String, dynamic>{
              't': 'choice',
              'options': <dynamic>[
                <String, dynamic>{
                  'text': '甲',
                  'then': <dynamic>[
                    <String, dynamic>{'t': 'n', 'text': '裡面'},
                  ],
                },
                <String, dynamic>{'text': '乙', 'goto': 'S01'},
              ],
            },
          ],
          isEnding: true,
          endingId: 'A',
        ),
      });
      // 模擬劇本改版：舊存檔停在 opt0.then 的 index 4，新版那串只剩 1 個節點。
      final stale = initState(story).copyWith(
        cursor: Cursor.fromTokens('S01', <String>['0', 'opt0', '4']),
        status: PlayStatus.playing,
      );
      expect(resume(story, stale), isNull);
    });

    test('竄改成負的選項索引也要回 null，不得 RangeError', () {
      final story = build(<String, dynamic>{
        'S01': scene(
          <dynamic>[
            <String, dynamic>{
              't': 'choice',
              'options': <dynamic>[
                <String, dynamic>{
                  'text': '甲',
                  'then': <dynamic>[
                    <String, dynamic>{'t': 'n', 'text': '裡面'},
                  ],
                },
                <String, dynamic>{'text': '乙', 'goto': 'S01'},
              ],
            },
          ],
          isEnding: true,
          endingId: 'A',
        ),
      });
      final tampered = initState(story).copyWith(
        cursor: Cursor.fromTokens('S01', <String>['0', 'opt-1', '0']),
        status: PlayStatus.playing,
      );
      expect(resume(story, tampered), isNull);
    });
  });

  group('visibleOptions', () {
    test('cond 不成立的選項不顯示，且可見索引對得回原始索引', () {
      final story = build(
        <String, dynamic>{
          'S01': scene(<dynamic>[
            <String, dynamic>{
              't': 'choice',
              'options': <dynamic>[
                <String, dynamic>{'text': '甲', 'goto': 'S02'},
                <String, dynamic>{
                  'text': '乙（要條件）',
                  'goto': 'S02',
                  'cond': <String, dynamic>{'var': 'v', 'op': '>=', 'value': 2},
                },
                <String, dynamic>{'text': '丙', 'goto': 'S02'},
              ],
            },
          ]),
          'S02': scene(
            <dynamic>[
              <String, dynamic>{'t': 'n', 'text': '二'},
            ],
            isEnding: true,
            endingId: 'A',
          ),
        },
        variables: <String, dynamic>{
          'v': <String, dynamic>{
            'label': 'v',
            'initial': 0,
            'min': 0,
            'max': 4,
          },
        },
      );
      final state = initState(story);
      final node = currentNode(story, state) as ChoiceNode;
      final visible = visibleOptions(node, state.vars);
      expect(visible.map((v) => v.option.text), <String>['甲', '丙']);
      expect(visible.map((v) => v.index), <int>[
        0,
        2,
      ], reason: '游標的分支標記要用原始索引，否則存檔會指錯選項');
    });
  });

  group('choose', () {
    test('套用 add 並夾在宣告的上限', () {
      final story = build(
        <String, dynamic>{
          'S01': scene(<dynamic>[
            <String, dynamic>{
              't': 'choice',
              'options': <dynamic>[
                <String, dynamic>{
                  'text': '甲',
                  'add': <String, dynamic>{'v': 3},
                  'goto': 'S02',
                },
                <String, dynamic>{'text': '乙', 'goto': 'S02'},
              ],
            },
          ]),
          'S02': scene(
            <dynamic>[
              <String, dynamic>{'t': 'n', 'text': '二'},
            ],
            isEnding: true,
            endingId: 'A',
          ),
        },
        variables: <String, dynamic>{
          'v': <String, dynamic>{
            'label': 'v',
            'initial': 0,
            'min': 0,
            'max': 2,
          },
        },
      );
      final state = choose(story, initState(story), 0);
      expect(state.vars['v'], 2, reason: '0 + 3 夾到 max 2');
    });

    test('未宣告的變數用 set 寫入且不夾', () {
      final story = build(<String, dynamic>{
        'S01': scene(<dynamic>[
          <String, dynamic>{
            't': 'choice',
            'options': <dynamic>[
              <String, dynamic>{
                'text': '甲',
                'set': <String, dynamic>{'deal': 'wait'},
                'goto': 'S02',
              },
              <String, dynamic>{'text': '乙', 'goto': 'S02'},
            ],
          },
        ]),
        'S02': scene(
          <dynamic>[
            <String, dynamic>{'t': 'n', 'text': '二'},
          ],
          isEnding: true,
          endingId: 'A',
        ),
      });
      expect(choose(story, initState(story), 0).vars['deal'], 'wait');
    });

    test('選項的 then 走完後回到選項之後繼續', () {
      final story = build(<String, dynamic>{
        'S01': scene(
          <dynamic>[
            <String, dynamic>{
              't': 'choice',
              'options': <dynamic>[
                <String, dynamic>{
                  'text': '甲',
                  'then': <dynamic>[
                    <String, dynamic>{'t': 'n', 'text': '選甲之後'},
                  ],
                },
                <String, dynamic>{'text': '乙', 'goto': 'S02'},
              ],
            },
            <String, dynamic>{'t': 'n', 'text': '匯流'},
          ],
          isEnding: true,
          endingId: 'A',
        ),
        'S02': scene(
          <dynamic>[
            <String, dynamic>{'t': 'n', 'text': '二'},
          ],
          isEnding: true,
          endingId: 'A',
        ),
      });
      var state = choose(story, initState(story), 0);
      expect((currentNode(story, state) as NarrationNode).text, '選甲之後');
      expect(state.cursor.toTokens(), <String>['0', 'opt0', '0']);
      state = advance(story, state);
      expect((currentNode(story, state) as NarrationNode).text, '匯流');
    });

    test('branch 依序求值，第一個成立者生效', () {
      Story storyWith(num affection) => build(
        <String, dynamic>{
          'S01': scene(<dynamic>[
            <String, dynamic>{
              't': 'choice',
              'options': <dynamic>[
                <String, dynamic>{
                  'text': '留下',
                  'branch': <dynamic>[
                    <String, dynamic>{
                      'cond': <String, dynamic>{
                        'var': 'v',
                        'op': '>=',
                        'value': 2,
                      },
                      'goto': 'E_C',
                    },
                    <String, dynamic>{'default': true, 'goto': 'E_B'},
                  ],
                },
                <String, dynamic>{'text': '上船', 'goto': 'E_B'},
              ],
            },
          ]),
          'E_B': scene(
            <dynamic>[
              <String, dynamic>{'t': 'n', 'text': 'B'},
            ],
            isEnding: true,
            endingId: 'A',
          ),
          'E_C': scene(
            <dynamic>[
              <String, dynamic>{'t': 'n', 'text': 'C'},
            ],
            isEnding: true,
            endingId: 'A',
          ),
        },
        variables: <String, dynamic>{
          'v': <String, dynamic>{
            'label': 'v',
            'initial': affection,
            'min': 0,
            'max': 4,
          },
        },
      );
      expect(
        choose(storyWith(2), initState(storyWith(2)), 0).cursor.sceneId,
        'E_C',
      );
      expect(
        choose(storyWith(0), initState(storyWith(0)), 0).cursor.sceneId,
        'E_B',
      );
    });
  });
}
