# 龐貝景點包 Flutter 視覺小說引擎 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新開獨立 Flutter 專案 `vn/`，在 Flutter Web 上播放 `writer/創作/龐貝/` 已完成的 8 篇視覺小說（73 場、2,380 節點、24 結局、60 張美術），並移除舊的 `story/` React SPA。

**Architecture:** 純 Dart 執行器（節點指標 ＝ 呼叫堆疊的投影）＋ Flutter 直式版面。所有程式碼收在 `lib/src/visual_novel/`，`domain/` 零 Flutter 依賴，`providers.dart` 是唯一對外介面——這一包日後整包搬進 `frontend/lib/features/visual_novel/`。素材由 `tool/import_pack.py` 從 writer vault 匯入（去背、對齊、去重）。

**Tech Stack:** Flutter 3.38.5 (fvm) / Dart 3.10.4、flutter_riverpod ^2.6.1、go_router ^17.0.0、shared_preferences ^2.3.4、Python 3 + PIL + numpy（匯入腳本）

**設計文件：** `docs/superpowers/specs/2026-08-13-pompeii-vn-flutter-design.md`

## Global Constraints

- **Flutter 版本**：`vn/.fvmrc` 必須是 `{ "flutter": "3.38.5" }`，與 `frontend/` 一致。一律用 `fvm flutter` / `fvm dart` 執行指令。
- **每個 task 結束前**必須跑 `cd vn && fvm flutter analyze --fatal-infos`，零問題才算完成。
- **`lib/src/visual_novel/domain/` 零 Flutter 依賴**：只可 import `dart:*`。不得 import `package:flutter/*`。這條是搬進 `frontend/` 的前提。
- **跨層引用只能經 `providers.dart`**：`presentation/` 不得直接 import `data/` 的實作類別。
- **lint**：`vn/analysis_options.yaml` 直接複製 `frontend/analysis_options.yaml`（含 `always_declare_return_types`、`prefer_final_locals`、`always_use_package_imports`、`prefer_single_quotes`、`avoid_print`）。
- **劇本逐字複製**：`story.json` 的內容一個字都不改。任何「修劇本」的念頭都要回報而不是動手。
- **文件用繁體中文**（技術名詞除外）。
- **內容來源路徑**：`writer/創作/龐貝/stories/<NN>_<中文名>/`（含 CJK 與底線，路徑要引號包好）。
- **PNG 不轉 WebP**：`--webp` 旗標留著但預設關閉。

## 版控決定：素材不進 git

去重後仍有 **60 張 PNG、約 133 MB**。這是**從 writer vault 可完整重生**的二進位檔，進 git 會永久撐大 repo。因此：

- `vn/.gitignore` 排除 `assets/content/**/assets/**`（圖檔）
- **進版控**：`story.json` ×8、`pack.json`、`tool/import_pack.py`（合計約 330 KB 純文字）
- 新環境或 CI 要跑起來，先執行 `python3 vn/tool/import_pack.py`

> ⚠️ 代價：`writer/` 本身不在版控裡，圖檔的唯一副本是本機 Obsidian vault。這一點與現況相同（今天圖也只在 vault），不是本計畫造成的新風險，但要知道。

## File Structure

| 檔案 | 責任 |
|---|---|
| `vn/tool/import_pack.py` | writer → assets 的匯入：複製劇本、去重、去背、對齊、產 pack.json、驗證 |
| `vn/lib/main.dart` | 薄殼：`ProviderScope` ＋ `MaterialApp.router`。搬進 frontend 時丟掉 |
| `…/visual_novel/providers.dart` | 唯一公開介面：re-export domain 型別與所有 provider |
| `…/domain/story.dart` | `Story` / `Scene` / `StoryNode`(sealed 11 型) / `Condition` / `ChoiceOption` / `BranchRule` |
| `…/domain/cursor.dart` | `CursorStep` / `Cursor`：序列化、已讀鍵 |
| `…/domain/play_state.dart` | `PlayState` / `PlayStatus` / `SpriteOnStage` |
| `…/domain/story_player.dart` | `initState` / `advance` / `choose` / `visibleOptions` / `currentNode` |
| `…/domain/save_data.dart` | `SaveData`：cursor / vars / stage / bgm 的序列化 |
| `…/data/story_json_parser.dart` | `story.json` Map → `Story` |
| `…/data/pack_repository.dart` | `rootBundle` 讀 `pack.json` / `story.json`、組資產路徑、`missingAssets` 判定 |
| `…/data/save_store.dart` | `SharedPreferences` 讀寫存檔、`readNodes`、`endingsSeen`、設定 |
| `…/presentation/play/play_page.dart` | 播放頁組裝與手勢 |
| `…/presentation/play/layout.dart` | `VnLayout`：規範 §2 的所有版面數值 |
| `…/presentation/play/background_layer.dart` | 背景（cover ＋ topCenter）與 CG 全螢幕 |
| `…/presentation/play/sprite_layer.dart` | 立繪（0.72H、底邊 0.88H、單/雙人站位、filter） |
| `…/presentation/play/dialogue_box.dart` | 對話框 ＋ 名牌 ＋ 逐字顯示 |
| `…/presentation/play/choice_overlay.dart` | 選項 |
| `…/presentation/play/backlog_sheet.dart` | 回顧 |
| `…/presentation/pack/pack_page.dart` | 景點包首頁：8 篇卡片 |
| `…/presentation/endings/endings_page.dart` | 結局收藏 |
| `…/presentation/settings/settings_page.dart` | 文字速度、字級 |

---

### Task 1: `vn/` Flutter 專案骨架

**Files:**
- Create: `vn/`（`flutter create` 產生）、`vn/.fvmrc`、`vn/analysis_options.yaml`、`vn/.gitignore`
- Modify: `vn/pubspec.yaml`、`vn/lib/main.dart`
- Test: `vn/test/smoke_test.dart`

**Interfaces:**
- Consumes: 無
- Produces: 可執行的 Flutter Web 專案；`fvm flutter test` 與 `fvm flutter analyze --fatal-infos` 皆通過

- [ ] **Step 1: 建立專案**

```bash
cd /Users/paulwu/Documents/PLRepo/lorescape
fvm use 3.38.5 --force --directory . 2>/dev/null || true
mkdir -p vn && cd vn
echo '{ "flutter": "3.38.5" }' > .fvmrc
fvm flutter create --project-name lorescape_vn --platforms web --empty .
```

- [ ] **Step 2: 寫 pubspec 依賴**

把 `vn/pubspec.yaml` 的 `dependencies` / `dev_dependencies` 換成：

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.1
  go_router: ^17.0.0
  shared_preferences: ^2.3.4

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
```

`flutter:` 區段**這個 task 先不要宣告 assets**：

```yaml
flutter:
  uses-material-design: true
```

> **為什麼不先宣告**：Flutter 對不存在的 asset 目錄會在 build／test 時報
> `No file or variants found for asset`，而素材要到 Task 2 才產生。
> 宣告放在 Task 2 Step 5，那時目錄才真的存在。

- [ ] **Step 3: 複製 lint 設定與寫 .gitignore**

```bash
cd /Users/paulwu/Documents/PLRepo/lorescape
cp frontend/analysis_options.yaml vn/analysis_options.yaml
cat >> vn/.gitignore <<'EOF'

# 匯入的美術素材：可由 tool/import_pack.py 從 writer vault 重生，不進版控
assets/content/**/assets/backgrounds/
assets/content/**/assets/sprites/
assets/content/**/assets/audio/
tool/_review/
EOF
```

- [ ] **Step 4: 寫 main.dart**

`vn/lib/main.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: VnApp()));
}

class VnApp extends StatelessWidget {
  const VnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '龐貝 79',
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: const Scaffold(body: Center(child: Text('龐貝 79'))),
    );
  }
}
```

- [ ] **Step 5: 寫 smoke test**

`vn/test/smoke_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lorescape_vn/main.dart';

void main() {
  testWidgets('啟動時顯示景點包名稱', (tester) async {
    await tester.pumpWidget(const VnApp());
    expect(find.text('龐貝 79'), findsOneWidget);
  });
}
```

- [ ] **Step 6: 跑測試與 analyze**

```bash
cd vn && fvm flutter pub get && fvm flutter test && fvm flutter analyze --fatal-infos
```

Expected: 測試 PASS、analyze 零問題。

- [ ] **Step 7: Commit**

```bash
cd /Users/paulwu/Documents/PLRepo/lorescape
git add vn/
git commit -m "feat(vn): Flutter 專案骨架，鎖 3.38.5 對齊 frontend"
```

---

### Task 2: 匯入腳本 v1 — 劇本複製、資產去重、pack.json、驗證

**Files:**
- Create: `vn/tool/import_pack.py`
- Modify: `vn/pubspec.yaml`（Step 5 補 assets 宣告）
- Test: `vn/tool/test_import_pack.py`

**Interfaces:**
- Consumes: `writer/創作/龐貝/stories/*/story.json` 與 `*/assets/{backgrounds,sprites}/*.png`
- Produces:
  - `vn/assets/content/pompeii-79/stories/<order>-<slug>/story.json`（逐字複製）
  - `vn/assets/content/pompeii-79/assets/{backgrounds,sprites}/*.png`（去重）
  - `vn/assets/content/pompeii-79/pack.json`，形狀為：
    ```json
    { "id": "pompeii_79", "title": "龐貝 79", "place": "龐貝",
      "blurb": "…", "stories": [
        { "id": "pompeii_01_harbour_stranger", "order": 1, "dir": "01-harbour-stranger",
          "title": "港口的外地人", "subtitle": "爆發前一日", "estimatedMinutes": 12 } ] }
    ```
  - 本腳本的函式 `slug_of(meta_id) -> str`、`import_pack(webp: bool, use_cache: bool) -> dict`

- [ ] **Step 1: 寫失敗的測試**

`vn/tool/test_import_pack.py`：

```python
import json, subprocess, sys, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / 'vn/assets/content/pompeii-79'

def test_slug_strips_order_prefix():
    sys.path.insert(0, str(pathlib.Path(__file__).parent))
    from import_pack import slug_of
    assert slug_of('pompeii_01_harbour_stranger') == '01-harbour-stranger'
    assert slug_of('pompeii_08_the_new_house') == '08-the-new-house'

def test_import_produces_eight_stories_and_dedup_assets():
    subprocess.run([sys.executable, str(ROOT / 'vn/tool/import_pack.py')], check=True)
    pack = json.loads((OUT / 'pack.json').read_text(encoding='utf-8'))
    assert len(pack['stories']) == 8
    assert [s['order'] for s in pack['stories']] == list(range(1, 9))
    # 116 份重複參照，依檔名去重成 60 個檔案（其中 57 個內容互異）
    bgs = list((OUT / 'assets/backgrounds').glob('*.png'))
    sprites = list((OUT / 'assets/sprites').glob('*.png'))
    assert len(bgs) == 16, len(bgs)      # 15 背景 + cg_column_rising
    assert len(sprites) == 44, len(sprites)

def test_scripts_are_copied_verbatim():
    src = ROOT / 'writer/創作/龐貝/stories/01_港口的外地人/story.json'
    dst = OUT / 'stories/01-harbour-stranger/story.json'
    assert dst.read_bytes() == src.read_bytes()

def test_every_referenced_asset_exists():
    for story_dir in sorted((OUT / 'stories').iterdir()):
        s = json.loads((story_dir / 'story.json').read_text(encoding='utf-8'))
        for filename in s['backgrounds'].values():
            assert (OUT / 'assets/backgrounds' / filename).exists(), filename
        for char in s['characters'].values():
            for filename in (char.get('sprites') or {}).values():
                assert (OUT / 'assets/sprites' / filename).exists(), filename
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd /Users/paulwu/Documents/PLRepo/lorescape && python3 -m pytest vn/tool/test_import_pack.py -v`
Expected: FAIL —「No module named 'import_pack'」

- [ ] **Step 3: 實作腳本**

`vn/tool/import_pack.py`：

```python
#!/usr/bin/env python3
"""把 writer vault 的龐貝景點包匯入 vn/assets/。可重跑。

用法：
    python3 vn/tool/import_pack.py [--webp] [--no-cache]

本階段只做「複製與去重」。去背與對齊在 Task 6 / Task 7 接進 process_sprite()。
"""
import argparse, hashlib, json, pathlib, shutil, sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / 'writer/創作/龐貝/stories'
OUT = ROOT / 'vn/assets/content/pompeii-79'

PACK_TITLE = '龐貝 79'
PACK_PLACE = '龐貝'
PACK_BLURB = '同一座城，同一場災難，八個人各自的最後一個選擇。'


def slug_of(meta_id: str) -> str:
    """'pompeii_01_harbour_stranger' -> '01-harbour-stranger'"""
    _pack, order, *rest = meta_id.split('_')
    return f"{order}-{'-'.join(rest).replace('_', '-')}"


def collect_assets(story_dirs):
    """回傳 {('backgrounds'|'sprites', basename): 來源路徑}，同名不同內容即中止。"""
    picked, digests = {}, {}
    for d in story_dirs:
        for kind in ('backgrounds', 'sprites'):
            for path in sorted((d / 'assets' / kind).glob('*.png')):
                key = (kind, path.name)
                digest = hashlib.md5(path.read_bytes()).hexdigest()
                if key in digests and digests[key] != digest:
                    sys.exit(f'✗ 同名不同內容：{key} 於 {path}')
                digests.setdefault(key, digest)
                picked.setdefault(key, path)
    return picked


def verify(story_paths) -> None:
    missing = []
    for p in story_paths:
        s = json.loads(p.read_text(encoding='utf-8'))
        for filename in s['backgrounds'].values():
            if not (OUT / 'assets/backgrounds' / filename).exists():
                missing.append(filename)
        for char in s['characters'].values():
            for filename in (char.get('sprites') or {}).values():
                if not (OUT / 'assets/sprites' / filename).exists():
                    missing.append(filename)
    if missing:
        sys.exit(f'✗ 參照的檔案不存在：{sorted(set(missing))}')


def import_pack(webp: bool = False, use_cache: bool = True) -> dict:
    story_dirs = sorted(d for d in SRC.iterdir() if d.is_dir() and (d / 'story.json').exists())
    if len(story_dirs) != 8:
        sys.exit(f'✗ 預期 8 篇，實際 {len(story_dirs)}')

    for kind in ('backgrounds', 'sprites', 'audio'):
        (OUT / 'assets' / kind).mkdir(parents=True, exist_ok=True)

    entries, copied_scripts = [], []
    for d in story_dirs:
        src_json = d / 'story.json'
        meta = json.loads(src_json.read_text(encoding='utf-8'))['meta']
        dest_dir = OUT / 'stories' / slug_of(meta['id'])
        dest_dir.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src_json, dest_dir / 'story.json')  # 逐字複製
        copied_scripts.append(dest_dir / 'story.json')
        entries.append({
            'id': meta['id'], 'order': meta['order'], 'dir': slug_of(meta['id']),
            'title': meta['title'], 'subtitle': meta.get('subtitle', ''),
            'estimatedMinutes': meta['estimatedMinutes'],
        })

    picked = collect_assets(story_dirs)
    for (kind, name), src_path in sorted(picked.items()):
        process_asset(kind, src_path, OUT / 'assets' / kind / name, webp, use_cache)

    entries.sort(key=lambda e: e['order'])
    pack = {'id': 'pompeii_79', 'title': PACK_TITLE, 'place': PACK_PLACE,
            'blurb': PACK_BLURB, 'stories': entries}
    (OUT / 'pack.json').write_text(
        json.dumps(pack, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

    verify(copied_scripts)
    print(f'✅ 8 篇、{len(picked)} 張素材、pack.json 完成')
    return pack


def process_asset(kind: str, src: pathlib.Path, dest: pathlib.Path,
                  webp: bool, use_cache: bool) -> None:
    """本階段原樣複製。Task 6 在此接去背，Task 7 接對齊。"""
    shutil.copyfile(src, dest)


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--webp', action='store_true', help='轉 WebP（送審前才開）')
    ap.add_argument('--no-cache', action='store_true')
    a = ap.parse_args()
    import_pack(webp=a.webp, use_cache=not a.no_cache)
```

- [ ] **Step 4: 跑測試確認通過**

Run: `cd /Users/paulwu/Documents/PLRepo/lorescape && python3 -m pytest vn/tool/test_import_pack.py -v`
Expected: 4 PASS

- [ ] **Step 5: 宣告 assets 並確認 Flutter 讀得到**

素材目錄現在才真的存在，這時候才把 `vn/pubspec.yaml` 的 `flutter:` 區段補成：

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/content/pompeii-79/
    - assets/content/pompeii-79/assets/backgrounds/
    - assets/content/pompeii-79/assets/sprites/
    - assets/content/pompeii-79/stories/01-harbour-stranger/
    - assets/content/pompeii-79/stories/02-the-oven-went-out/
    - assets/content/pompeii-79/stories/03-the-well-fell/
    - assets/content/pompeii-79/stories/04-the-tree-in-the-sky/
    - assets/content/pompeii-79/stories/05-the-tablets/
    - assets/content/pompeii-79/stories/06-the-locked-door/
    - assets/content/pompeii-79/stories/07-cannot-land/
    - assets/content/pompeii-79/stories/08-the-new-house/
```

> Flutter 的 assets 宣告**不遞迴**，每個目錄都要單獨列一行。

```bash
cd vn && fvm flutter pub get && fvm flutter test && fvm flutter analyze --fatal-infos
du -sh assets/content/pompeii-79
git status --short vn/assets | head
```

Expected: 測試 PASS；`du` 約 133 MB；`git status` **不應列出任何 .png**（.gitignore 生效）。

- [ ] **Step 6: Commit**

```bash
git add vn/tool/ vn/assets/content/pompeii-79/pack.json vn/assets/content/pompeii-79/stories/
git commit -m "feat(vn): 匯入腳本與 8 篇劇本，素材去重 116→60 張"
```

---

### Task 3: Domain 資料模型與 story.json parser

**Files:**
- Create: `vn/lib/src/visual_novel/domain/story.dart`、`vn/lib/src/visual_novel/data/story_json_parser.dart`
- Test: `vn/test/src/visual_novel/data/story_json_parser_test.dart`

**Interfaces:**
- Consumes: Task 2 產出的 `story.json`
- Produces（後續 task 全依賴這些名稱）：

```dart
sealed class StoryNode
final class NarrationNode extends StoryNode { final String text; final String? style; }
final class DialogueNode  extends StoryNode { final String who, text; final String? sprite; }
final class ShowNode      extends StoryNode { final String who; final String? sprite, filter; }
final class HideNode      extends StoryNode
final class SfxNode       extends StoryNode { final String id; }
final class BgmNode       extends StoryNode { final String? id; }
final class CgNode        extends StoryNode { final String id; final bool fullscreen, hideDialogue; }
final class AddNode       extends StoryNode { final Map<String, num> vars; }
final class SetNode       extends StoryNode { final Map<String, Object?> vars; }
final class IfNode        extends StoryNode { final Condition cond; final List<StoryNode> then, orElse; }
final class ChoiceNode    extends StoryNode { final List<ChoiceOption> options; }

final class Condition   { final String varName, op; final Object? value;
                          bool evaluate(Map<String, Object?> vars); }
final class BranchRule  { final Condition? cond; final String goto; }   // cond == null ＝ default
final class ChoiceOption{ final String text; final Condition? cond;
                          final Map<String, num> addVars; final Map<String, Object?> setVars;
                          final List<StoryNode> then; final String? goto;
                          final List<BranchRule> branch; }
final class Scene       { final String id, title, background; final String? bgm;
                          final List<StoryNode> nodes; final String? next;
                          final bool isEnding; final String? endingId; }
final class VariableSpec{ final String label; final num initial, min, max; }
final class CharacterSpec{ final String name; final bool isPlayer; final Map<String,String>? sprites; }
final class EndingSpec  { final String title, note; }
final class StoryMeta   { final String id, pack, title, subtitle, locale;
                          final int order, estimatedMinutes; }
final class Story       { final StoryMeta meta;
                          final Map<String, VariableSpec> variables;
                          final Map<String, CharacterSpec> characters;
                          final Map<String, String> backgrounds;
                          final Map<String, Set<String>> missingAssets;  // type → ids
                          final String start;
                          final Map<String, Scene> scenes;
                          final Map<String, EndingSpec> endings; }

Story parseStory(Map<String, dynamic> json);   // story_json_parser.dart
```

- [ ] **Step 1: 寫失敗的測試**

`vn/test/src/visual_novel/data/story_json_parser_test.dart`：

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lorescape_vn/src/visual_novel/data/story_json_parser.dart';
import 'package:lorescape_vn/src/visual_novel/domain/story.dart';

Story loadFixture(String dir) {
  final file = File('assets/content/pompeii-79/stories/$dir/story.json');
  return parseStory(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);
}

void main() {
  group('parseStory', () {
    test('讀出 meta 與宣告的變數', () {
      final story = loadFixture('01-harbour-stranger');
      expect(story.meta.id, 'pompeii_01_harbour_stranger');
      expect(story.meta.order, 1);
      expect(story.meta.subtitle, '爆發前一日');
      expect(story.variables.keys, containsAll(<String>['affection', 'awareness']));
      expect(story.variables['affection']!.max, 4);
      expect(story.start, 'S01');
      expect(story.scenes.length, 12);
      expect(story.endings.keys, containsAll(<String>['A', 'B', 'C']));
    });

    test('主角是無立繪角色', () {
      final story = loadFixture('01-harbour-stranger');
      expect(story.characters['zabda']!.isPlayer, isTrue);
      expect(story.characters['zabda']!.sprites, isNull);
      expect(story.characters['vibia']!.sprites!['softened'], 'vibia_softened.png');
    });

    test('結局場帶 isEnding 與 endingId，且沒有 next', () {
      final scene = loadFixture('01-harbour-stranger').scenes['E_A']!;
      expect(scene.isEnding, isTrue);
      expect(scene.endingId, 'A');
      expect(scene.next, isNull);
      expect(scene.nodes.whereType<CgNode>().single.hideDialogue, isTrue);
    });

    test('解得出巢狀的 if／then／else', () {
      final scene = loadFixture('01-harbour-stranger').scenes['S09']!;
      final ifNode = scene.nodes.whereType<IfNode>().first;
      expect(ifNode.cond.varName, 'deal');
      expect(ifNode.cond.op, '==');
      expect(ifNode.cond.value, 'wait');
      expect(ifNode.then, isNotEmpty);
      expect(ifNode.orElse, isNotEmpty);
    });

    test('選項的 goto／branch／then 三種出口都解得出來', () {
      final scene = loadFixture('01-harbour-stranger').scenes['S09']!;
      final choice = scene.nodes.whereType<ChoiceNode>().last;
      expect(choice.options[0].goto, 'E_A');
      final rules = choice.options[1].branch;
      expect(rules.first.cond!.varName, 'affection');
      expect(rules.first.goto, 'E_C');
      expect(rules.last.cond, isNull, reason: 'default 規則的 cond 為 null');
      expect(rules.last.goto, 'E_B');
    });

    test('規範漏寫但資料在用的欄位：option.cond 與 show.filter', () {
      final withOptionCond = loadFixture('02-the-oven-went-out')
          .scenes['S07']!.nodes.whereType<ChoiceNode>()
          .expand((n) => n.options).where((o) => o.cond != null);
      expect(withOptionCond, isNotEmpty);

      final filtered = loadFixture('08-the-new-house')
          .scenes['S04']!.nodes.whereType<ShowNode>()
          .where((n) => n.filter == 'memory_desaturate');
      expect(filtered, hasLength(1));
    });

    test('八篇都解得出來，且沒有未知節點型別', () {
      const dirs = <String>[
        '01-harbour-stranger', '02-the-oven-went-out', '03-the-well-fell',
        '04-the-tree-in-the-sky', '05-the-tablets', '06-the-locked-door',
        '07-cannot-land', '08-the-new-house',
      ];
      for (final dir in dirs) {
        expect(() => loadFixture(dir), returnsNormally, reason: dir);
      }
    });

    test('未知的節點型別要報明確錯誤，不得靜默忽略', () {
      expect(
        () => parseStory(<String, dynamic>{
          'meta': <String, dynamic>{
            'id': 'x', 'pack': 'p', 'order': 1, 'title': 't',
            'subtitle': '', 'estimatedMinutes': 1, 'locale': 'zh-Hant',
          },
          'variables': <String, dynamic>{},
          'characters': <String, dynamic>{},
          'backgrounds': <String, dynamic>{},
          'missingAssets': <dynamic>[],
          'start': 'S01',
          'scenes': <String, dynamic>{
            'S01': <String, dynamic>{
              'title': 't', 'background': 'b',
              'nodes': <dynamic>[<String, dynamic>{'t': 'wat'}],
              'isEnding': true, 'endingId': 'A',
            },
          },
          'endings': <String, dynamic>{'A': <String, dynamic>{'title': 'x', 'note': 'y'}},
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd vn && fvm flutter test test/src/visual_novel/data/story_json_parser_test.dart`
Expected: FAIL — 找不到 `story.dart` / `story_json_parser.dart`

- [ ] **Step 3: 實作 domain 型別**

`vn/lib/src/visual_novel/domain/story.dart`：

```dart
/// 劇本的領域模型。**不得 import package:flutter/***——這一層要能用 dart test 跑。
sealed class StoryNode {
  const StoryNode();
}

final class NarrationNode extends StoryNode {
  const NarrationNode({required this.text, this.style});
  final String text;
  final String? style;
}

final class DialogueNode extends StoryNode {
  const DialogueNode({required this.who, required this.text, this.sprite});
  final String who;
  final String text;
  final String? sprite;
}

final class ShowNode extends StoryNode {
  const ShowNode({required this.who, this.sprite, this.filter});
  final String who;

  /// null ＝ 無立繪角色登場（`characters[who].sprites == null` 的路人）。
  /// 真實資料有 4 處：03/S01 婦人、06/S04 男人、08/S02 陶匠、08/S04 挖掘者。
  /// 這是敘事標記，沒有圖要畫——執行器把它當 stage no-op。
  final String? sprite;
  final String? filter;
}

final class HideNode extends StoryNode {
  const HideNode();
}

final class SfxNode extends StoryNode {
  const SfxNode(this.id);
  final String id;
}

final class BgmNode extends StoryNode {
  /// null ＝ 停止背景音樂。
  const BgmNode(this.id);
  final String? id;
}

final class CgNode extends StoryNode {
  const CgNode({required this.id, required this.fullscreen, required this.hideDialogue});
  final String id;
  final bool fullscreen;
  final bool hideDialogue;
}

final class AddNode extends StoryNode {
  const AddNode(this.vars);
  final Map<String, num> vars;
}

final class SetNode extends StoryNode {
  const SetNode(this.vars);
  final Map<String, Object?> vars;
}

final class IfNode extends StoryNode {
  const IfNode({required this.cond, required this.then, this.orElse = const <StoryNode>[]});
  final Condition cond;
  final List<StoryNode> then;
  final List<StoryNode> orElse;
}

final class ChoiceNode extends StoryNode {
  const ChoiceNode(this.options);
  final List<ChoiceOption> options;
}

/// 條件。未宣告的變數取 null（規範 §3.3）。
final class Condition {
  const Condition({required this.varName, required this.op, required this.value});
  final String varName;
  final String op;
  final Object? value;

  bool evaluate(Map<String, Object?> vars) {
    final actual = vars[varName];
    final expected = value;
    if (op == '==') return actual == expected;
    if (op == '!=') return actual != expected;
    // 大小比較只在兩邊都是數字時成立；型別不符一律 false，不丟例外。
    if (actual is! num || expected is! num) return false;
    return switch (op) {
      '>=' => actual >= expected,
      '<=' => actual <= expected,
      '>' => actual > expected,
      '<' => actual < expected,
      _ => false,
    };
  }
}

/// 選項的跳轉規則，依序求值，第一個成立者生效。cond 為 null ＝ default。
final class BranchRule {
  const BranchRule({this.cond, required this.goto});
  final Condition? cond;
  final String goto;
}

final class ChoiceOption {
  const ChoiceOption({
    required this.text,
    this.cond,
    this.addVars = const <String, num>{},
    this.setVars = const <String, Object?>{},
    this.then = const <StoryNode>[],
    this.goto,
    this.branch = const <BranchRule>[],
  });

  /// cond 不成立時這個選項不顯示（規範漏寫，資料有 4 處在用）。
  final Condition? cond;
  final String text;
  final Map<String, num> addVars;
  final Map<String, Object?> setVars;
  final List<StoryNode> then;
  final String? goto;
  final List<BranchRule> branch;
}

final class Scene {
  const Scene({
    required this.id,
    required this.title,
    required this.background,
    required this.nodes,
    this.bgm,
    this.next,
    this.isEnding = false,
    this.endingId,
  });
  final String id;
  final String title;
  final String background;
  final String? bgm;
  final List<StoryNode> nodes;
  final String? next;
  final bool isEnding;
  final String? endingId;
}

final class VariableSpec {
  const VariableSpec({
    required this.label,
    required this.initial,
    required this.min,
    required this.max,
  });
  final String label;
  final num initial;
  final num min;
  final num max;
}

final class CharacterSpec {
  const CharacterSpec({required this.name, required this.isPlayer, this.sprites});
  final String name;
  final bool isPlayer;

  /// null ＝ 無立繪角色（主角或只有名字的路人）。
  final Map<String, String>? sprites;
}

final class EndingSpec {
  const EndingSpec({required this.title, required this.note});
  final String title;
  final String note;
}

final class StoryMeta {
  const StoryMeta({
    required this.id,
    required this.pack,
    required this.order,
    required this.title,
    required this.subtitle,
    required this.estimatedMinutes,
    required this.locale,
  });
  final String id;
  final String pack;
  final int order;
  final String title;
  final String subtitle;
  final int estimatedMinutes;
  final String locale;
}

final class Story {
  const Story({
    required this.meta,
    required this.variables,
    required this.characters,
    required this.backgrounds,
    required this.missingAssets,
    required this.start,
    required this.scenes,
    required this.endings,
  });
  final StoryMeta meta;
  final Map<String, VariableSpec> variables;
  final Map<String, CharacterSpec> characters;

  /// key → 檔名（不含路徑）。
  final Map<String, String> backgrounds;

  /// 尚未產出的資產：type（'bgm' / 'sfx' / 'cg'）→ id 集合。
  final Map<String, Set<String>> missingAssets;
  final String start;
  final Map<String, Scene> scenes;
  final Map<String, EndingSpec> endings;
}
```

- [ ] **Step 4: 實作 parser**

`vn/lib/src/visual_novel/data/story_json_parser.dart`：

```dart
import 'package:lorescape_vn/src/visual_novel/domain/story.dart';

/// story.json → Story。未知的節點型別一律丟 FormatException——靜默忽略會讓
/// 劇本默默少走一段，那種錯到播放時才看得出來，而且看起來像文案問題。
Story parseStory(Map<String, dynamic> json) {
  final meta = json['meta'] as Map<String, dynamic>;
  return Story(
    meta: StoryMeta(
      id: meta['id'] as String,
      pack: meta['pack'] as String,
      order: meta['order'] as int,
      title: meta['title'] as String,
      subtitle: (meta['subtitle'] as String?) ?? '',
      estimatedMinutes: meta['estimatedMinutes'] as int,
      locale: (meta['locale'] as String?) ?? 'zh-Hant',
    ),
    variables: (json['variables'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, _variable(value as Map<String, dynamic>)),
    ),
    characters: (json['characters'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, _character(value as Map<String, dynamic>)),
    ),
    backgrounds: (json['backgrounds'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, value as String),
    ),
    missingAssets: _missingAssets(json['missingAssets'] as List<dynamic>?),
    start: json['start'] as String,
    scenes: (json['scenes'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, _scene(key, value as Map<String, dynamic>)),
    ),
    endings: (json['endings'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(
        key,
        EndingSpec(
          title: (value as Map<String, dynamic>)['title'] as String,
          note: (value['note'] as String?) ?? '',
        ),
      ),
    ),
  );
}

VariableSpec _variable(Map<String, dynamic> json) => VariableSpec(
      label: (json['label'] as String?) ?? '',
      initial: (json['initial'] as num?) ?? 0,
      min: (json['min'] as num?) ?? double.negativeInfinity,
      max: (json['max'] as num?) ?? double.infinity,
    );

CharacterSpec _character(Map<String, dynamic> json) {
  final sprites = json['sprites'] as Map<String, dynamic>?;
  return CharacterSpec(
    name: json['name'] as String,
    isPlayer: (json['isPlayer'] as bool?) ?? false,
    sprites: sprites?.map((key, value) => MapEntry(key, value as String)),
  );
}

Map<String, Set<String>> _missingAssets(List<dynamic>? json) {
  final result = <String, Set<String>>{};
  for (final entry in json ?? const <dynamic>[]) {
    final map = entry as Map<String, dynamic>;
    // 多數 entry 用複數 `ids` 陣列，但 08-the-new-house 的 filter 那筆用單數
    // `id`。兩種都收進同一個 Set，不要求資料端統一——劇本是既成事實。
    // 兩者皆缺時 `as String` 會對 null 丟 TypeError——刻意讓它吵，
    // 靜默略過會讓一整類缺件無聲消失。
    final ids = (map['ids'] as List<dynamic>?)?.cast<String>() ??
        <String>[map['id'] as String];
    result.putIfAbsent(map['type'] as String, () => <String>{}).addAll(ids);
  }
  return result;
}

Scene _scene(String id, Map<String, dynamic> json) => Scene(
      id: id,
      title: (json['title'] as String?) ?? '',
      background: json['background'] as String,
      bgm: json['bgm'] as String?,
      nodes: _nodes(json['nodes'] as List<dynamic>),
      next: json['next'] as String?,
      isEnding: (json['isEnding'] as bool?) ?? false,
      endingId: json['endingId'] as String?,
    );

List<StoryNode> _nodes(List<dynamic>? json) =>
    (json ?? const <dynamic>[]).map((e) => _node(e as Map<String, dynamic>)).toList();

StoryNode _node(Map<String, dynamic> json) {
  final type = json['t'] as String?;
  return switch (type) {
    'n' => NarrationNode(text: json['text'] as String, style: json['style'] as String?),
    'd' => DialogueNode(
        who: json['who'] as String,
        text: json['text'] as String,
        sprite: json['sprite'] as String?,
      ),
    'show' => ShowNode(
        who: json['who'] as String,
        sprite: json['sprite'] as String?,
        filter: json['filter'] as String?,
      ),
    'hide' => const HideNode(),
    'sfx' => SfxNode(json['id'] as String),
    'bgm' => BgmNode(json['id'] as String?),
    'cg' => CgNode(
        id: json['id'] as String,
        fullscreen: (json['fullscreen'] as bool?) ?? true,
        hideDialogue: (json['hideDialogue'] as bool?) ?? true,
      ),
    'add' => AddNode(_numVars(json['vars'] as Map<String, dynamic>)),
    'set' => SetNode(Map<String, Object?>.from(json['vars'] as Map<String, dynamic>)),
    'if' => IfNode(
        cond: _condition(json['cond'] as Map<String, dynamic>),
        then: _nodes(json['then'] as List<dynamic>?),
        orElse: _nodes(json['else'] as List<dynamic>?),
      ),
    'choice' => ChoiceNode(
        (json['options'] as List<dynamic>)
            .map((e) => _option(e as Map<String, dynamic>))
            .toList(),
      ),
    _ => throw FormatException('未知的節點型別：$type'),
  };
}

Map<String, num> _numVars(Map<String, dynamic> json) =>
    json.map((key, value) => MapEntry(key, value as num));

Condition _condition(Map<String, dynamic> json) => Condition(
      varName: json['var'] as String,
      op: json['op'] as String,
      value: json['value'],
    );

ChoiceOption _option(Map<String, dynamic> json) {
  final cond = json['cond'] as Map<String, dynamic>?;
  final add = json['add'] as Map<String, dynamic>?;
  final set = json['set'] as Map<String, dynamic>?;
  return ChoiceOption(
    text: json['text'] as String,
    cond: cond == null ? null : _condition(cond),
    addVars: add == null ? const <String, num>{} : _numVars(add),
    setVars: set == null ? const <String, Object?>{} : Map<String, Object?>.from(set),
    then: _nodes(json['then'] as List<dynamic>?),
    goto: json['goto'] as String?,
    branch: ((json['branch'] as List<dynamic>?) ?? const <dynamic>[])
        .map((e) => _branchRule(e as Map<String, dynamic>))
        .toList(),
  );
}

BranchRule _branchRule(Map<String, dynamic> json) {
  final cond = json['cond'] as Map<String, dynamic>?;
  return BranchRule(
    cond: cond == null ? null : _condition(cond),
    goto: json['goto'] as String,
  );
}
```

- [ ] **Step 5: 跑測試確認通過**

Run: `cd vn && fvm flutter test test/src/visual_novel/data/story_json_parser_test.dart && fvm flutter analyze --fatal-infos`
Expected: 8 個 test 全 PASS、analyze 零問題

- [ ] **Step 6: Commit**

```bash
git add vn/lib/src/visual_novel/domain/story.dart vn/lib/src/visual_novel/data/story_json_parser.dart vn/test/
git commit -m "feat(vn): story.json 的 domain 模型與 parser，含規範漏寫的 option.cond 與 show.filter"
```

---

### Task 4: Cursor、PlayState 與存檔序列化

**Files:**
- Create: `vn/lib/src/visual_novel/domain/cursor.dart`、`vn/lib/src/visual_novel/domain/play_state.dart`、`vn/lib/src/visual_novel/domain/save_data.dart`
- Test: `vn/test/src/visual_novel/domain/cursor_test.dart`、`vn/test/src/visual_novel/domain/save_data_test.dart`

**Interfaces:**
- Consumes: Task 3 的 `domain/story.dart`
- Produces:

```dart
final class CursorStep { const CursorStep(this.index, [this.branch]);
                         final int index; final String? branch; }
final class Cursor {
  const Cursor({required this.sceneId, required this.path});
  final String sceneId; final List<CursorStep> path;
  factory Cursor.atSceneStart(String sceneId);
  List<String> toTokens();                        // ['12','then','3']
  factory Cursor.fromTokens(String sceneId, List<String> tokens);
  String get readKey;                             // 'S06#12.then.3'（不含 sceneId 的前綴由呼叫端加）
  Cursor withLastIndex(int index);
  Cursor push(String branch);                     // 在最後一層加分支，並開新的一層 index 0
  Cursor pop();
  CursorStep get last;
}

enum PlayStatus { playing, choosing, ended }
final class SpriteOnStage { const SpriteOnStage({required this.who, required this.sprite, this.filter});
                            final String who, sprite; final String? filter; }
final class PlayState {
  const PlayState({required this.cursor, required this.vars, required this.stage,
                   required this.status, this.bgmId, this.endingId});
  final Cursor cursor; final Map<String, Object?> vars;
  final List<SpriteOnStage> stage; final PlayStatus status;
  final String? bgmId; final String? endingId;
  PlayState copyWith({...});
  String get readKey;                             // '<sceneId>#<path>'
}

final class SaveData {
  const SaveData({required this.storyId, required this.cursor, required this.vars,
                  required this.stage, this.bgmId, required this.updatedAt});
  Map<String, dynamic> toJson();
  factory SaveData.fromJson(Map<String, dynamic> json);
  factory SaveData.from(String storyId, PlayState state, DateTime now);
  PlayState toPlayState();
}
```

- [ ] **Step 1: 寫失敗的測試**

`vn/test/src/visual_novel/domain/cursor_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lorescape_vn/src/visual_novel/domain/cursor.dart';

void main() {
  group('Cursor', () {
    test('場開頭是單層的 index 0', () {
      final cursor = Cursor.atSceneStart('S01');
      expect(cursor.sceneId, 'S01');
      expect(cursor.path, hasLength(1));
      expect(cursor.last.index, 0);
      expect(cursor.last.branch, isNull);
    });

    test('序列化成規範 §6 的 token 形狀', () {
      final cursor = Cursor(sceneId: 'S06', path: const <CursorStep>[
        CursorStep(12, 'then'),
        CursorStep(3),
      ]);
      expect(cursor.toTokens(), <String>['12', 'then', '3']);
      expect(cursor.readKey, 'S06#12.then.3');
    });

    test('token 往返後是同一個游標', () {
      final original = Cursor(sceneId: 'S06', path: const <CursorStep>[
        CursorStep(12, 'then'),
        CursorStep(4, 'opt1'),
        CursorStep(0),
      ]);
      final restored = Cursor.fromTokens('S06', original.toTokens());
      expect(restored.toTokens(), original.toTokens());
      expect(restored.path.map((s) => s.index), <int>[12, 4, 0]);
      expect(restored.path.map((s) => s.branch), <String?>['then', 'opt1', null]);
    });

    test('push 在最後一層記下分支並開新的一層', () {
      final pushed = Cursor.atSceneStart('S01').withLastIndex(5).push('then');
      expect(pushed.toTokens(), <String>['5', 'then', '0']);
    });

    test('pop 收掉最後一層並清掉上一層的分支標記', () {
      final popped = Cursor.atSceneStart('S01').withLastIndex(5).push('then').pop();
      expect(popped.toTokens(), <String>['5']);
      expect(popped.last.branch, isNull);
    });
  });
}
```

`vn/test/src/visual_novel/domain/save_data_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lorescape_vn/src/visual_novel/domain/cursor.dart';
import 'package:lorescape_vn/src/visual_novel/domain/play_state.dart';
import 'package:lorescape_vn/src/visual_novel/domain/save_data.dart';

void main() {
  test('存檔往返：游標、變數、台上立繪都一致', () {
    final state = PlayState(
      cursor: Cursor(sceneId: 'S06', path: const <CursorStep>[CursorStep(12, 'then'), CursorStep(3)]),
      vars: const <String, Object?>{'affection': 2, 'deal': 'wait', 'bread': true},
      stage: const <SpriteOnStage>[SpriteOnStage(who: 'vibia', sprite: 'softened')],
      status: PlayStatus.playing,
      bgmId: 'quiet',
    );
    final save = SaveData.from('pompeii_01_harbour_stranger', state, DateTime.utc(2026, 8, 13));
    final restored = SaveData.fromJson(save.toJson()).toPlayState();

    expect(restored.cursor.toTokens(), state.cursor.toTokens());
    expect(restored.vars, state.vars);
    expect(restored.stage.single.who, 'vibia');
    expect(restored.stage.single.sprite, 'softened');
    expect(restored.bgmId, 'quiet');
  });

  test('存檔 JSON 的欄位符合規範 §6', () {
    final save = SaveData.from(
      'pompeii_01_harbour_stranger',
      PlayState(
        cursor: Cursor.atSceneStart('S01'),
        vars: const <String, Object?>{'affection': 0},
        stage: const <SpriteOnStage>[],
        status: PlayStatus.playing,
      ),
      DateTime.utc(2026, 8, 13),
    );
    final json = save.toJson();
    expect(json['storyId'], 'pompeii_01_harbour_stranger');
    expect((json['cursor'] as Map<String, dynamic>)['sceneId'], 'S01');
    expect((json['cursor'] as Map<String, dynamic>)['path'], <String>['0']);
    expect(json['updatedAt'], '2026-08-13T00:00:00.000Z');
  });
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd vn && fvm flutter test test/src/visual_novel/domain/`
Expected: FAIL — 找不到 `cursor.dart`

- [ ] **Step 3: 實作 cursor.dart**

```dart
/// 節點指標。這份路徑同時就是呼叫堆疊的投影——每一層記「在哪個 index」與
/// 「從那個 index 的節點往哪個分支鑽進去」，因此讀檔時不必另存 stack，
/// 從場的根節點陣列依路徑重走一次就回到原位。
final class CursorStep {
  const CursorStep(this.index, [this.branch]);

  final int index;

  /// 'then' / 'else' / 'opt<n>'；null ＝ 沒有再往下鑽（這是最後一層）。
  final String? branch;

  CursorStep withIndex(int value) => CursorStep(value, branch);
  CursorStep withBranch(String? value) => CursorStep(index, value);
}

final class Cursor {
  const Cursor({required this.sceneId, required this.path});

  factory Cursor.atSceneStart(String sceneId) =>
      Cursor(sceneId: sceneId, path: const <CursorStep>[CursorStep(0)]);

  /// ['12','then','3'] → [(12,'then'), (3,null)]
  factory Cursor.fromTokens(String sceneId, List<String> tokens) {
    final steps = <CursorStep>[];
    for (final token in tokens) {
      final index = int.tryParse(token);
      if (index != null) {
        steps.add(CursorStep(index));
      } else {
        if (steps.isEmpty) throw FormatException('分支 token 前面沒有 index：$tokens');
        steps[steps.length - 1] = steps.last.withBranch(token);
      }
    }
    if (steps.isEmpty) throw FormatException('空的游標路徑：$tokens');
    return Cursor(sceneId: sceneId, path: steps);
  }

  final String sceneId;
  final List<CursorStep> path;

  CursorStep get last => path.last;

  List<String> toTokens() => <String>[
        for (final step in path) ...<String>[
          '${step.index}',
          if (step.branch != null) step.branch!,
        ],
      ];

  String get readKey => '$sceneId#${toTokens().join('.')}';

  Cursor withLastIndex(int index) => Cursor(
        sceneId: sceneId,
        path: <CursorStep>[...path.take(path.length - 1), last.withIndex(index)],
      );

  Cursor push(String branch) => Cursor(
        sceneId: sceneId,
        path: <CursorStep>[
          ...path.take(path.length - 1),
          last.withBranch(branch),
          const CursorStep(0),
        ],
      );

  Cursor pop() {
    if (path.length <= 1) throw StateError('已經在最外層，不能再 pop');
    final parent = path[path.length - 2].withBranch(null);
    return Cursor(
      sceneId: sceneId,
      path: <CursorStep>[...path.take(path.length - 2), parent],
    );
  }
}
```

- [ ] **Step 4: 實作 play_state.dart**

```dart
import 'package:lorescape_vn/src/visual_novel/domain/cursor.dart';

enum PlayStatus { playing, choosing, ended }

final class SpriteOnStage {
  const SpriteOnStage({required this.who, required this.sprite, this.filter});
  final String who;
  final String sprite;
  final String? filter;
}

final class PlayState {
  const PlayState({
    required this.cursor,
    required this.vars,
    required this.stage,
    required this.status,
    this.bgmId,
    this.endingId,
  });

  final Cursor cursor;
  final Map<String, Object?> vars;

  /// 台上的立繪，最多 2 個（實測：單人 223 次、雙人 6 次、無三人）。
  final List<SpriteOnStage> stage;
  final PlayStatus status;
  final String? bgmId;
  final String? endingId;

  String get readKey => cursor.readKey;

  PlayState copyWith({
    Cursor? cursor,
    Map<String, Object?>? vars,
    List<SpriteOnStage>? stage,
    PlayStatus? status,
    String? bgmId,
    bool clearBgm = false,
    String? endingId,
  }) {
    return PlayState(
      cursor: cursor ?? this.cursor,
      vars: vars ?? this.vars,
      stage: stage ?? this.stage,
      status: status ?? this.status,
      bgmId: clearBgm ? null : (bgmId ?? this.bgmId),
      endingId: endingId ?? this.endingId,
    );
  }
}
```

- [ ] **Step 5: 實作 save_data.dart**

```dart
import 'package:lorescape_vn/src/visual_novel/domain/cursor.dart';
import 'package:lorescape_vn/src/visual_novel/domain/play_state.dart';

/// 規範 §6 的存檔格式，外加 `stage`。
///
/// 規範原本只存 cursor 與 vars，但台上有誰是 show/hide 累積出來的副作用，
/// 讀檔時若靠「從場開頭重跑一次」還原，那些 if 會用**存檔當下的**變數重新
/// 求值，可能走進與當初不同的分支。直接把台上狀態存下來就沒有這個問題。
final class SaveData {
  const SaveData({
    required this.storyId,
    required this.cursor,
    required this.vars,
    required this.stage,
    required this.updatedAt,
    this.bgmId,
  });

  factory SaveData.from(String storyId, PlayState state, DateTime now) => SaveData(
        storyId: storyId,
        cursor: state.cursor,
        vars: state.vars,
        stage: state.stage,
        bgmId: state.bgmId,
        updatedAt: now,
      );

  factory SaveData.fromJson(Map<String, dynamic> json) {
    final cursorJson = json['cursor'] as Map<String, dynamic>;
    return SaveData(
      storyId: json['storyId'] as String,
      cursor: Cursor.fromTokens(
        cursorJson['sceneId'] as String,
        (cursorJson['path'] as List<dynamic>).cast<String>(),
      ),
      vars: Map<String, Object?>.from(json['vars'] as Map<String, dynamic>),
      stage: ((json['stage'] as List<dynamic>?) ?? const <dynamic>[])
          .map((e) => e as Map<String, dynamic>)
          .map((e) => SpriteOnStage(
                who: e['who'] as String,
                sprite: e['sprite'] as String,
                filter: e['filter'] as String?,
              ))
          .toList(),
      bgmId: json['bgmId'] as String?,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  final String storyId;
  final Cursor cursor;
  final Map<String, Object?> vars;
  final List<SpriteOnStage> stage;
  final String? bgmId;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'storyId': storyId,
        'cursor': <String, dynamic>{'sceneId': cursor.sceneId, 'path': cursor.toTokens()},
        'vars': vars,
        'stage': <Map<String, dynamic>>[
          for (final sprite in stage)
            <String, dynamic>{
              'who': sprite.who,
              'sprite': sprite.sprite,
              if (sprite.filter != null) 'filter': sprite.filter,
            },
        ],
        if (bgmId != null) 'bgmId': bgmId,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  PlayState toPlayState() => PlayState(
        cursor: cursor,
        vars: vars,
        stage: stage,
        status: PlayStatus.playing,
        bgmId: bgmId,
      );
}
```

- [ ] **Step 6: 跑測試確認通過**

Run: `cd vn && fvm flutter test test/src/visual_novel/domain/ && fvm flutter analyze --fatal-infos`
Expected: 7 個 test 全 PASS

- [ ] **Step 7: Commit**

```bash
git add vn/lib/src/visual_novel/domain/ vn/test/src/visual_novel/domain/
git commit -m "feat(vn): Cursor 與存檔序列化，存檔多帶 stage 避免讀檔重算分支"
```

---

### Task 5: 執行器 `story_player.dart`

**Files:**
- Create: `vn/lib/src/visual_novel/domain/story_player.dart`
- Test: `vn/test/src/visual_novel/domain/story_player_test.dart`

**Interfaces:**
- Consumes: Task 3 的 `story.dart`、Task 4 的 `cursor.dart` / `play_state.dart`
- Produces:

```dart
PlayState initState(Story story);
StoryNode currentNode(Story story, PlayState state);
PlayState advance(Story story, PlayState state);
List<VisibleOption> visibleOptions(ChoiceNode node, Map<String, Object?> vars);
PlayState choose(Story story, PlayState state, int visibleIndex);
PlayState? resume(Story story, PlayState restored);  // 讀檔後重算 status；null ＝ 存檔已失效

final class VisibleOption { const VisibleOption(this.index, this.option);
                            final int index; final ChoiceOption option; }
```

**行為契約**（後續 UI 與走訪測試都依賴這些）：
- `cursor` 在 `playing` / `choosing` 時**一定**指向會停頓的節點（`n` / `d` / `cg` / `choice`）。
- 副作用節點（`sfx` / `bgm` / `add` / `set` / `show` / `hide`）不停頓，套用後自動往下走。
- **`show` 的 `sprite` 為 `null` 時是 stage no-op**（無立繪角色登場的敘事標記，沒有圖要畫）。因此 `SpriteOnStage.sprite` 維持非 nullable，`SpriteLayer` 不必處理 null。
- `add` 後的值夾在該變數宣告的 `min`／`max` 之間；**未宣告的變數不夾**。
- 走完場的根陣列 → 依 `next` 跳下一場；`isEnding` → `status: ended`。兩者皆無 → 丟 `StateError`（那是資料錯誤，要炸給測試看到）。
- **`resume` 是讀檔專用**：`SaveData` 不存 `status`，`toPlayState()` 一律回 `playing`。這個 `playing` 有兩種錯法——停在 `choice` 上會被 `advance` 跳過整個選擇；停在結局場的游標**必然越界**（`_settle` 只在越界時回傳 `ended`），直接 `currentNode` 會 `RangeError`。`resume` 先驗證游標路徑對得上現在的劇本，再交給 `_settle` 重算。**回傳 `null` ＝ 存檔已失效，呼叫端退回 `initState`。任何從存檔還原的路徑都必須經過它。**
- **`advance` 只在 `playing` 時動作**。`choosing` 時推進會靜默跳過整個選擇、不套用任何選項的變數。
- **場沒有宣告 `bgm` ＝ 沿用上一場**，不是停止。停止只由 `bgm` 節點帶 `id: null` 觸發。

- [ ] **Step 1: 寫失敗的測試**

`vn/test/src/visual_novel/domain/story_player_test.dart`：

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lorescape_vn/src/visual_novel/data/story_json_parser.dart';
import 'package:lorescape_vn/src/visual_novel/domain/play_state.dart';
import 'package:lorescape_vn/src/visual_novel/domain/story.dart';
import 'package:lorescape_vn/src/visual_novel/domain/story_player.dart';

Story build(
  Map<String, dynamic> scenes, {
  Map<String, dynamic>? variables,
  Map<String, dynamic>? characters,
}) {
  return parseStory(<String, dynamic>{
    'meta': <String, dynamic>{
      'id': 'test', 'pack': 'p', 'order': 1, 'title': 't',
      'subtitle': '', 'estimatedMinutes': 1, 'locale': 'zh-Hant',
    },
    'variables': variables ?? <String, dynamic>{},
    'characters': characters ??
        <String, dynamic>{'a': <String, dynamic>{'name': '甲', 'sprites': null}},
    'backgrounds': <String, dynamic>{'bg': 'bg.png'},
    'missingAssets': <dynamic>[],
    'start': 'S01',
    'scenes': scenes,
    'endings': <String, dynamic>{'A': <String, dynamic>{'title': '結局 A', 'note': ''}},
  });
}

Map<String, dynamic> scene(List<dynamic> nodes,
        {String? next, bool isEnding = false, String? endingId}) =>
    <String, dynamic>{
      'title': '場', 'background': 'bg', 'nodes': nodes,
      if (next != null) 'next': next,
      if (isEnding) 'isEnding': true,
      if (endingId != null) 'endingId': endingId,
    };

void main() {
  group('advance', () {
    test('副作用節點不停頓，直接走到下一個會停的節點', () {
      final story = build(<String, dynamic>{
        'S01': scene(<dynamic>[
          <String, dynamic>{'t': 'sfx', 'id': 'footsteps'},
          <String, dynamic>{'t': 'show', 'who': 'a', 'sprite': 'neutral'},
          <String, dynamic>{'t': 'n', 'text': '第一句'},
        ], isEnding: true, endingId: 'A'),
      });
      final state = initState(story);
      expect(currentNode(story, state), isA<NarrationNode>());
      expect((currentNode(story, state) as NarrationNode).text, '第一句');
      expect(state.stage.single.who, 'a', reason: 'show 的副作用要套用');
    });

    test('hide 收掉台上所有立繪', () {
      final story = build(<String, dynamic>{
        'S01': scene(<dynamic>[
          <String, dynamic>{'t': 'show', 'who': 'a', 'sprite': 'neutral'},
          <String, dynamic>{'t': 'n', 'text': '一'},
          <String, dynamic>{'t': 'hide'},
          <String, dynamic>{'t': 'n', 'text': '二'},
        ], isEnding: true, endingId: 'A'),
      });
      var state = initState(story);
      expect(state.stage, hasLength(1));
      state = advance(story, state);
      expect(state.stage, isEmpty);
    });

    test('if 成立時走 then，並在走完後回到上一層繼續', () {
      final story = build(
        <String, dynamic>{
          'S01': scene(<dynamic>[
            <String, dynamic>{'t': 'n', 'text': '前'},
            <String, dynamic>{
              't': 'if',
              'cond': <String, dynamic>{'var': 'v', 'op': '>=', 'value': 1},
              'then': <dynamic>[<String, dynamic>{'t': 'n', 'text': '裡面'}],
              'else': <dynamic>[<String, dynamic>{'t': 'n', 'text': '另一邊'}],
            },
            <String, dynamic>{'t': 'n', 'text': '後'},
          ], isEnding: true, endingId: 'A'),
        },
        variables: <String, dynamic>{
          'v': <String, dynamic>{'label': 'v', 'initial': 1, 'min': 0, 'max': 4},
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
          'S01': scene(<dynamic>[
            <String, dynamic>{
              't': 'if',
              'cond': <String, dynamic>{'var': 'v', 'op': '>=', 'value': 9},
              'then': <dynamic>[<String, dynamic>{'t': 'n', 'text': '裡面'}],
              'else': <dynamic>[<String, dynamic>{'t': 'n', 'text': '另一邊'}],
            },
          ], isEnding: true, endingId: 'A'),
        },
        variables: <String, dynamic>{
          'v': <String, dynamic>{'label': 'v', 'initial': 0, 'min': 0, 'max': 4},
        },
      );
      final state = initState(story);
      expect((currentNode(story, state) as NarrationNode).text, '另一邊');
    });

    test('走完場的根陣列後依 next 跳下一場', () {
      final story = build(<String, dynamic>{
        'S01': scene(<dynamic>[<String, dynamic>{'t': 'n', 'text': '一'}], next: 'S02'),
        'S02': scene(<dynamic>[<String, dynamic>{'t': 'n', 'text': '二'}],
            isEnding: true, endingId: 'A'),
      });
      var state = initState(story);
      state = advance(story, state);
      expect(state.cursor.sceneId, 'S02');
      expect((currentNode(story, state) as NarrationNode).text, '二');
    });

    test('結局場走完後 status 變 ended 並帶出 endingId', () {
      final story = build(<String, dynamic>{
        'S01': scene(<dynamic>[<String, dynamic>{'t': 'n', 'text': '一'}],
            isEnding: true, endingId: 'A'),
      });
      final state = advance(story, initState(story));
      expect(state.status, PlayStatus.ended);
      expect(state.endingId, 'A');
    });

    test('沒有 next 也不是結局的場走完 → StateError', () {
      final story = build(<String, dynamic>{
        'S01': scene(<dynamic>[<String, dynamic>{'t': 'n', 'text': '一'}]),
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
        'S02': scene(<dynamic>[<String, dynamic>{'t': 'n', 'text': '二'}],
            isEnding: true, endingId: 'A'),
      });
      expect(initState(story).status, PlayStatus.choosing);
    });
  });

  group('規格明列、但最容易無聲壞掉的邊界', () {
    test('if 不成立且沒有 else 時，往下一個節點走（22/26 個 if 屬此類）', () {
      final story = build(
        <String, dynamic>{
          'S01': scene(<dynamic>[
            <String, dynamic>{
              't': 'if',
              'cond': <String, dynamic>{'var': 'v', 'op': '>=', 'value': 9},
              'then': <dynamic>[<String, dynamic>{'t': 'n', 'text': '不該出現'}],
            },
            <String, dynamic>{'t': 'n', 'text': '後面'},
          ], isEnding: true, endingId: 'A'),
        },
        variables: <String, dynamic>{
          'v': <String, dynamic>{'label': 'v', 'initial': 0, 'min': 0, 'max': 4},
        },
      );
      final state = initState(story);
      expect((currentNode(story, state) as NarrationNode).text, '後面');
      expect(state.cursor.toTokens(), <String>['1'],
          reason: '空分支不得 push，否則 _listAt 拿到空陣列會誤觸「整場走完」而提前跳場');
    });

    test('show 的 sprite 為 null 是 stage no-op', () {
      final story = build(<String, dynamic>{
        'S01': scene(<dynamic>[
          <String, dynamic>{'t': 'show', 'who': 'a', 'sprite': null},
          <String, dynamic>{'t': 'n', 'text': '一'},
        ], isEnding: true, endingId: 'A'),
      });
      expect(initState(story).stage, isEmpty);
    });

    test('bgm 節點帶 id: null 會把 bgmId 清成 null', () {
      final story = build(<String, dynamic>{
        'S01': <String, dynamic>{
          'title': '場', 'background': 'bg', 'bgm': 'sea',
          'isEnding': true, 'endingId': 'A',
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
          'S01': scene(<dynamic>[
            <String, dynamic>{
              't': 'choice',
              'options': <dynamic>[
                <String, dynamic>{
                  'text': '甲',
                  'then': <dynamic>[
                    <String, dynamic>{
                      't': 'if',
                      'cond': <String, dynamic>{'var': 'v', 'op': '>=', 'value': 0},
                      'then': <dynamic>[<String, dynamic>{'t': 'n', 'text': '最內層'}],
                    },
                  ],
                },
                <String, dynamic>{'text': '乙', 'goto': 'S01'},
              ],
            },
            <String, dynamic>{'t': 'n', 'text': '匯流'},
          ], isEnding: true, endingId: 'A'),
        },
        variables: <String, dynamic>{
          'v': <String, dynamic>{'label': 'v', 'initial': 0, 'min': 0, 'max': 4},
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
      final story = build(<String, dynamic>{
        'S01': scene(<dynamic>[
          <String, dynamic>{'t': 'show', 'who': 'a', 'sprite': 'neutral',
              'filter': 'memory_desaturate'},
          <String, dynamic>{'t': 'show', 'who': 'b', 'sprite': 'neutral'},
          <String, dynamic>{'t': 'n', 'text': '一'},
          <String, dynamic>{'t': 'd', 'who': 'a', 'sprite': 'wry', 'text': '二'},
        ], isEnding: true, endingId: 'A'),
        }, characters: <String, dynamic>{
          'a': <String, dynamic>{'name': '甲', 'sprites': <String, dynamic>{'neutral': 'a.png', 'wry': 'aw.png'}},
          'b': <String, dynamic>{'name': '乙', 'sprites': <String, dynamic>{'neutral': 'b.png'}},
        });
      final state = advance(story, initState(story));
      expect(state.stage.map((s) => s.who), <String>['a', 'b'],
          reason: '換表情不得改變左右站位');
      expect(state.stage.first.sprite, 'wry');
      expect(state.stage.first.filter, 'memory_desaturate',
          reason: '換表情不得把 show 設定的濾鏡洗掉');
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
        'S02': scene(<dynamic>[<String, dynamic>{'t': 'n', 'text': '二'}],
            isEnding: true, endingId: 'A'),
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
        'S02': scene(<dynamic>[<String, dynamic>{'t': 'n', 'text': '二'}],
            isEnding: true, endingId: 'A'),
      });
      // 模擬讀檔：SaveData.toPlayState() 一律回 playing
      final fromSave = initState(story).copyWith(status: PlayStatus.playing);
      expect(resume(story, fromSave).status, PlayStatus.choosing);
    });

    test('存檔停在旁白上時維持 playing', () {
      final story = build(<String, dynamic>{
        'S01': scene(<dynamic>[<String, dynamic>{'t': 'n', 'text': '一'}],
            isEnding: true, endingId: 'A'),
      });
      expect(resume(story, initState(story))!.status, PlayStatus.playing);
    });

    test('結局場的越界游標還原成 ended 並帶回 endingId，不得 RangeError', () {
      final story = build(<String, dynamic>{
        'S01': scene(<dynamic>[<String, dynamic>{'t': 'n', 'text': '一'}],
            isEnding: true, endingId: 'A'),
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

    test('巢狀層越界回 null——不得被當成「整場走完」而傳送到結局', () {
      final story = build(<String, dynamic>{
        'S01': scene(<dynamic>[
          <String, dynamic>{
            't': 'choice',
            'options': <dynamic>[
              <String, dynamic>{
                'text': '甲',
                'then': <dynamic>[<String, dynamic>{'t': 'n', 'text': '裡面'}],
              },
              <String, dynamic>{'text': '乙', 'goto': 'S01'},
            ],
          },
        ], isEnding: true, endingId: 'A'),
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
        'S01': scene(<dynamic>[
          <String, dynamic>{
            't': 'choice',
            'options': <dynamic>[
              <String, dynamic>{
                'text': '甲',
                'then': <dynamic>[<String, dynamic>{'t': 'n', 'text': '裡面'}],
              },
              <String, dynamic>{'text': '乙', 'goto': 'S01'},
            ],
          },
        ], isEnding: true, endingId: 'A'),
      });
      final tampered = initState(story).copyWith(
        cursor: Cursor.fromTokens('S01', <String>['0', 'opt-1', '0']),
        status: PlayStatus.playing,
      );
      expect(resume(story, tampered), isNull);
    });

    test('路徑對不上現在的劇本時回 null，讓呼叫端退回開頭', () {
      final story = build(<String, dynamic>{
        'S01': scene(<dynamic>[<String, dynamic>{'t': 'n', 'text': '一'}],
            isEnding: true, endingId: 'A'),
      });
      final stale = initState(story).copyWith(
        cursor: Cursor.fromTokens('S01', <String>['0', 'then', '0']),
      );
      expect(resume(story, stale), isNull, reason: 'S01[0] 是旁白，沒有 then 分支');
      expect(resume(story, initState(story).copyWith(
        cursor: Cursor.atSceneStart('S99'),
      )), isNull, reason: '場不存在');
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
                  'text': '乙（要條件）', 'goto': 'S02',
                  'cond': <String, dynamic>{'var': 'v', 'op': '>=', 'value': 2},
                },
                <String, dynamic>{'text': '丙', 'goto': 'S02'},
              ],
            },
          ]),
          'S02': scene(<dynamic>[<String, dynamic>{'t': 'n', 'text': '二'}],
              isEnding: true, endingId: 'A'),
        },
        variables: <String, dynamic>{
          'v': <String, dynamic>{'label': 'v', 'initial': 0, 'min': 0, 'max': 4},
        },
      );
      final state = initState(story);
      final node = currentNode(story, state) as ChoiceNode;
      final visible = visibleOptions(node, state.vars);
      expect(visible.map((v) => v.option.text), <String>['甲', '丙']);
      expect(visible.map((v) => v.index), <int>[0, 2],
          reason: '游標的分支標記要用原始索引，否則存檔會指錯選項');
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
                <String, dynamic>{'text': '甲', 'add': <String, dynamic>{'v': 3}, 'goto': 'S02'},
                <String, dynamic>{'text': '乙', 'goto': 'S02'},
              ],
            },
          ]),
          'S02': scene(<dynamic>[<String, dynamic>{'t': 'n', 'text': '二'}],
              isEnding: true, endingId: 'A'),
        },
        variables: <String, dynamic>{
          'v': <String, dynamic>{'label': 'v', 'initial': 0, 'min': 0, 'max': 2},
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
              <String, dynamic>{'text': '甲', 'set': <String, dynamic>{'deal': 'wait'}, 'goto': 'S02'},
              <String, dynamic>{'text': '乙', 'goto': 'S02'},
            ],
          },
        ]),
        'S02': scene(<dynamic>[<String, dynamic>{'t': 'n', 'text': '二'}],
            isEnding: true, endingId: 'A'),
      });
      expect(choose(story, initState(story), 0).vars['deal'], 'wait');
    });

    test('選項的 then 走完後回到選項之後繼續', () {
      final story = build(<String, dynamic>{
        'S01': scene(<dynamic>[
          <String, dynamic>{
            't': 'choice',
            'options': <dynamic>[
              <String, dynamic>{
                'text': '甲',
                'then': <dynamic>[<String, dynamic>{'t': 'n', 'text': '選甲之後'}],
              },
              <String, dynamic>{'text': '乙', 'goto': 'S02'},
            ],
          },
          <String, dynamic>{'t': 'n', 'text': '匯流'},
        ], isEnding: true, endingId: 'A'),
        'S02': scene(<dynamic>[<String, dynamic>{'t': 'n', 'text': '二'}],
            isEnding: true, endingId: 'A'),
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
                          'cond': <String, dynamic>{'var': 'v', 'op': '>=', 'value': 2},
                          'goto': 'E_C',
                        },
                        <String, dynamic>{'default': true, 'goto': 'E_B'},
                      ],
                    },
                    <String, dynamic>{'text': '上船', 'goto': 'E_B'},
                  ],
                },
              ]),
              'E_B': scene(<dynamic>[<String, dynamic>{'t': 'n', 'text': 'B'}],
                  isEnding: true, endingId: 'A'),
              'E_C': scene(<dynamic>[<String, dynamic>{'t': 'n', 'text': 'C'}],
                  isEnding: true, endingId: 'A'),
            },
            variables: <String, dynamic>{
              'v': <String, dynamic>{'label': 'v', 'initial': affection, 'min': 0, 'max': 4},
            },
          );
      expect(choose(storyWith(2), initState(storyWith(2)), 0).cursor.sceneId, 'E_C');
      expect(choose(storyWith(0), initState(storyWith(0)), 0).cursor.sceneId, 'E_B');
    });
  });
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd vn && fvm flutter test test/src/visual_novel/domain/story_player_test.dart`
Expected: FAIL — 找不到 `story_player.dart`

- [ ] **Step 3: 實作執行器**

`vn/lib/src/visual_novel/domain/story_player.dart`：

```dart
import 'package:lorescape_vn/src/visual_novel/domain/cursor.dart';
import 'package:lorescape_vn/src/visual_novel/domain/play_state.dart';
import 'package:lorescape_vn/src/visual_novel/domain/story.dart';

final class VisibleOption {
  const VisibleOption(this.index, this.option);

  /// 在 ChoiceNode.options 裡的**原始**索引。游標的 'opt<n>' 用這個，
  /// 用可見索引會在條件變動後指到別的選項。
  final int index;
  final ChoiceOption option;
}

PlayState initState(Story story) {
  final scene = _scene(story, story.start);
  final state = PlayState(
    cursor: Cursor.atSceneStart(story.start),
    vars: <String, Object?>{
      for (final entry in story.variables.entries) entry.key: entry.value.initial,
    },
    stage: const <SpriteOnStage>[],
    status: PlayStatus.playing,
    bgmId: scene.bgm,
  );
  return _settle(story, state);
}

StoryNode currentNode(Story story, PlayState state) {
  final list = _listAt(story, state.cursor, state.cursor.path.length - 1);
  return list[state.cursor.last.index];
}

List<VisibleOption> visibleOptions(ChoiceNode node, Map<String, Object?> vars) => <VisibleOption>[
      for (var i = 0; i < node.options.length; i++)
        if (node.options[i].cond?.evaluate(vars) ?? true) VisibleOption(i, node.options[i]),
    ];

PlayState advance(Story story, PlayState state) {
  // choosing 時推進會靜默跳過整個選擇、不套用任何選項的 vars——那是最難查的一
  // 種 bug（玩家的選擇無聲消失）。這裡直接擋掉，不倚賴 UI 自律。
  if (state.status != PlayStatus.playing) return state;
  return _settle(story, _moveNext(story, state));
}

/// 讀檔還原用。存檔只記 cursor 與 vars，不記 status（`SaveData.toPlayState()`
/// 一律回 playing），但游標可能正停在一個 choice 上。那種情況下把 status 當成
/// playing 會讓 UI 不畫選項、而點擊直接 advance 過去——玩家的選擇被無聲跳過。
/// 因此 status 一律由「游標指著什麼節點」重算。
PlayState? resume(Story story, PlayState restored) {
  if (!_cursorResolvable(story, restored.cursor)) return null;
  // 交給 _settle 重算：它本來就負責「走到下一個會停頓的節點」與「場走完了要跳
  // 場還是結束」。讀檔與播放因此走同一條路，不會有第二套狀態推導邏輯。
  return _settle(story, restored);
}

/// 游標的每一層都要對得上現在的劇本結構。
///
/// **只有「單層且越界」才放行**——那是「這個場走完了」的合法狀態（結局狀態的
/// 游標必然越界），由 `_settle` 處理成跳場或結局。
///
/// 巢狀層越界則一律回 false。理由：`_settle` 的越界分支預設「越界 ＝ 這個場的
/// 根陣列走完了」，這個前提只在正常播放時成立——`_moveNext` 會先把巢狀層 pop
/// 掉，交到 `_settle` 手上的越界游標必然只剩一層。`resume` 餵的是任意存檔游標，
/// 前提就破了：劇本 v1 的 `opt0.then` 有 5 個節點、玩家存在 index 4，v2 縮成 2
/// 個，若放行，玩家一開檔就會被判成走完該場——是結局場就直接傳送到結局，有
/// `next` 就跳過整場剩下的內容。回 `null` 讓呼叫端退回開頭遠比這乾淨。
bool _cursorResolvable(Story story, Cursor cursor) {
  final scene = story.scenes[cursor.sceneId];
  if (scene == null) return false;
  var list = scene.nodes;
  for (var i = 0; i < cursor.path.length; i++) {
    final step = cursor.path[i];
    final isLast = i == cursor.path.length - 1;
    if (step.index < 0 || step.index >= list.length) {
      return isLast && cursor.path.length == 1;
    }
    if (isLast) return true;
    final node = list[step.index];
    final branch = step.branch;
    if (branch == 'then' && node is IfNode) {
      list = node.then;
    } else if (branch == 'else' && node is IfNode) {
      list = node.orElse;
    } else if (branch != null && branch.startsWith('opt') && node is ChoiceNode) {
      // 負索引也要擋：竄改過的存檔給 'opt-1' 時 tryParse 回 -1、過得了上界檢查，
      // 然後在這個「用來防崩潰」的函式裡丟 RangeError。
      final index = int.tryParse(branch.substring(3));
      if (index == null || index < 0 || index >= node.options.length) return false;
      list = node.options[index].then;
    } else {
      return false;
    }
  }
  return true;
}

PlayState choose(Story story, PlayState state, int visibleIndex) {
  final node = currentNode(story, state) as ChoiceNode;
  final visible = visibleOptions(node, state.vars);
  final picked = visible[visibleIndex];
  final option = picked.option;

  var next = state.copyWith(
    vars: _applyVars(story, state.vars, add: option.addVars, set: option.setVars),
    status: PlayStatus.playing,
  );

  if (option.then.isNotEmpty) {
    return _settle(story, next.copyWith(cursor: next.cursor.push('opt${picked.index}')));
  }
  final target = option.branch.isNotEmpty ? _resolveBranch(option.branch, next.vars) : option.goto;
  if (target != null) return _settle(story, _enterScene(story, next, target));
  return _settle(story, _moveNext(story, next));
}

// ─────────────────────────────────────────────────────────────────────────

Scene _scene(Story story, String id) {
  final scene = story.scenes[id];
  if (scene == null) throw StateError('場不存在：$id');
  return scene;
}

/// 走到 cursor 第 depth 層所在的節點陣列。
List<StoryNode> _listAt(Story story, Cursor cursor, int depth) {
  var list = _scene(story, cursor.sceneId).nodes;
  for (var i = 0; i < depth; i++) {
    final step = cursor.path[i];
    final node = list[step.index];
    final branch = step.branch;
    if (branch == 'then') {
      list = (node as IfNode).then;
    } else if (branch == 'else') {
      list = (node as IfNode).orElse;
    } else if (branch != null && branch.startsWith('opt')) {
      list = (node as ChoiceNode).options[int.parse(branch.substring(3))].then;
    } else {
      throw StateError('游標第 $i 層沒有分支標記：${cursor.toTokens()}');
    }
  }
  return list;
}

String? _resolveBranch(List<BranchRule> rules, Map<String, Object?> vars) {
  for (final rule in rules) {
    if (rule.cond == null || rule.cond!.evaluate(vars)) return rule.goto;
  }
  return null;
}

Map<String, Object?> _applyVars(
  Story story,
  Map<String, Object?> vars, {
  Map<String, num> add = const <String, num>{},
  Map<String, Object?> set = const <String, Object?>{},
}) {
  final next = Map<String, Object?>.from(vars);
  add.forEach((key, delta) {
    final current = next[key];
    final base = current is num ? current : 0;
    final spec = story.variables[key];
    final value = base + delta;
    next[key] = spec == null ? value : value.clamp(spec.min, spec.max);
  });
  next.addAll(set);
  return next;
}

PlayState _enterScene(Story story, PlayState state, String sceneId) {
  final scene = _scene(story, sceneId);
  // 場沒有宣告 bgm ＝ **未指定，沿用上一場**，不是停止播放。劇本要靜下來時是明
  // 寫 `bgm: "silence"` 的（多場在用）；若把「沒有欄位」當成停止，8 篇的結局場
  // 會全部無聲進場，而 01 篇的 E_A 明明寫了 `bgm: "sea"`。停止只由 `bgm` 節點
  // 帶 `id: null` 觸發。
  return state.copyWith(
    cursor: Cursor.atSceneStart(sceneId),
    bgmId: scene.bgm,
    status: PlayStatus.playing,
  );
}

/// 游標往前一格；走出當層就 pop 回上一層再往前，直到回到還有節點的層。
/// 全部走完（path 只剩一層且越界）就交給 _settle 決定跳場或結束。
PlayState _moveNext(Story story, PlayState state) {
  var cursor = state.cursor.withLastIndex(state.cursor.last.index + 1);
  while (cursor.path.length > 1 &&
      cursor.last.index >= _listAt(story, cursor, cursor.path.length - 1).length) {
    cursor = cursor.pop();
    cursor = cursor.withLastIndex(cursor.last.index + 1);
  }
  return state.copyWith(cursor: cursor);
}

/// 一路套用副作用節點，直到停在 n / d / cg / choice，或走完整個場。
PlayState _settle(Story story, PlayState state) {
  var current = state;
  while (true) {
    final list = _listAt(story, current.cursor, current.cursor.path.length - 1);
    if (current.cursor.last.index >= list.length) {
      final scene = _scene(story, current.cursor.sceneId);
      if (scene.isEnding) {
        return current.copyWith(status: PlayStatus.ended, endingId: scene.endingId);
      }
      final next = scene.next;
      if (next == null) {
        throw StateError('場 ${scene.id} 走到底，但既沒有 next 也不是結局');
      }
      current = _enterScene(story, current, next);
      continue;
    }

    final node = list[current.cursor.last.index];
    switch (node) {
      case NarrationNode() || DialogueNode() || CgNode():
        // 規範 §3.3：`d` 的 sprite 存在時「同時切換該角色表情並顯示」。
        if (node is DialogueNode && node.sprite != null) {
          current = current.copyWith(
            stage: _switchExpression(current.stage, node.who, node.sprite!),
          );
        }
        return current.copyWith(status: PlayStatus.playing);
      case ChoiceNode():
        return current.copyWith(status: PlayStatus.choosing);
      case ShowNode(:final who, :final sprite, :final filter):
        // sprite 為 null ＝ 無立繪角色登場，台上沒有東西要加。
        if (sprite != null) {
          current = current.copyWith(stage: _showSprite(current.stage, who, sprite, filter));
        }
      case HideNode():
        current = current.copyWith(stage: const <SpriteOnStage>[]);
      case BgmNode(:final id):
        current = current.copyWith(bgmId: id, clearBgm: id == null);
      case SfxNode():
        break; // 音效由 presentation 在進入節點時播；引擎只負責不停頓地走過去
      case AddNode(:final vars):
        current = current.copyWith(vars: _applyVars(story, current.vars, add: vars));
      case SetNode(:final vars):
        current = current.copyWith(vars: _applyVars(story, current.vars, set: vars));
      case IfNode(:final cond, :final then, :final orElse):
        final taken = cond.evaluate(current.vars);
        final branch = taken ? 'then' : 'else';
        final target = taken ? then : orElse;
        if (target.isEmpty) {
          current = _moveNext(story, current);
          continue;
        }
        current = current.copyWith(cursor: current.cursor.push(branch));
        continue;
    }
    current = _moveNext(story, current);
  }
}

/// `show`：設定某角色的立繪與濾鏡。既有角色**原位取代**，新角色才 append。
List<SpriteOnStage> _showSprite(
  List<SpriteOnStage> stage,
  String who,
  String sprite,
  String? filter,
) {
  final next = <SpriteOnStage>[...stage];
  final at = next.indexWhere((s) => s.who == who);
  final entry = SpriteOnStage(who: who, sprite: sprite, filter: filter);
  if (at < 0) {
    next.add(entry);
  } else {
    next[at] = entry;
  }
  return next;
}

/// `d` 切表情：**只換表情**，保留該角色現有的濾鏡與台上位置。
///
/// 兩個都是實際會被看見的：8 篇裡唯一一次 `show ... filter: memory_desaturate`
/// （08/S04）之後 vibia 還會講帶 sprite 的台詞，濾鏡若被洗掉，那整段回憶就失去
/// 視覺區隔；而「移除再 append」會讓雙人同台的兩人在對話中途左右對調
/// （07/S02、07/S03 各一次）。
List<SpriteOnStage> _switchExpression(List<SpriteOnStage> stage, String who, String sprite) {
  final next = <SpriteOnStage>[...stage];
  final at = next.indexWhere((s) => s.who == who);
  if (at < 0) {
    next.add(SpriteOnStage(who: who, sprite: sprite));
  } else {
    next[at] = SpriteOnStage(who: who, sprite: sprite, filter: next[at].filter);
  }
  return next;
}
```

- [ ] **Step 4: 跑測試確認通過**

Run: `cd vn && fvm flutter test test/src/visual_novel/domain/story_player_test.dart && fvm flutter analyze --fatal-infos`
Expected: 全 PASS

- [ ] **Step 5: Commit**

```bash
git add vn/lib/src/visual_novel/domain/story_player.dart vn/test/src/visual_novel/domain/story_player_test.dart
git commit -m "feat(vn): 執行器——節點指標即呼叫堆疊，副作用節點不停頓"
```

---

### Task 6: 以 8 篇真實劇本走訪的整包驗收測試

這是本專案最有價值的一組測試——內容是既成事實，引擎必須吃得下。

**Files:**
- Create: `vn/test/src/visual_novel/pack_walkthrough_test.dart`
- Test: 同上

**Interfaces:**
- Consumes: Task 2 的 8 份 `story.json`、Task 3 的 `parseStory`、Task 5 的執行器
- Produces: 無新 API；本 task 只驗證既有行為

- [ ] **Step 1: 寫測試**

`vn/test/src/visual_novel/pack_walkthrough_test.dart`：

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lorescape_vn/src/visual_novel/data/story_json_parser.dart';
import 'package:lorescape_vn/src/visual_novel/domain/play_state.dart';
import 'package:lorescape_vn/src/visual_novel/domain/story.dart';
import 'package:lorescape_vn/src/visual_novel/domain/story_player.dart';

const String packRoot = 'assets/content/pompeii-79';

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
  final Set<String> takenOptions = <String>{};   // '<readKey>#opt<n>'
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
      expect(visible, isNotEmpty,
          reason: '${story.meta.id} ${current.cursor.readKey}：所有選項都被條件擋掉了');
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
                  side.any((n) => n is NarrationNode || n is DialogueNode ||
                      n is CgNode || n is ChoiceNode),
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
        expect(declared.difference(result.takenOptions), isEmpty,
            reason: '有選項在任何路徑上都走不到');
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
                final prefix = '$sceneId#${<String>[...here, side.$1].join('.')}.';
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
          expect(File('$packRoot/assets/backgrounds/$filename').existsSync(), isTrue,
              reason: filename);
        }
        for (final character in story.characters.values) {
          for (final filename in (character.sprites ?? const <String, String>{}).values) {
            expect(File('$packRoot/assets/sprites/$filename').existsSync(), isTrue,
                reason: filename);
          }
        }
        void scanCg(List<StoryNode> nodes) {
          for (final node in nodes) {
            if (node is CgNode) {
              expect(File('$packRoot/assets/backgrounds/${node.id}.png').existsSync(), isTrue,
                  reason: node.id);
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
```

> `text.characters` 需要 `import 'package:characters/characters.dart';`。**要在 `pubspec.yaml` 的 `dev_dependencies` 明確宣告 `characters`**——靠 `flutter_test` 的傳遞依賴雖然 import 得到，但過不了 `depend_on_referenced_packages` 這條 lint。

### 兩條讓這組測試「不會空綠」的骨幹斷言

走訪測試最危險的失敗模式不是紅燈，是**全綠但什麼都沒斷言**——那會讓後面所有人以為內容驗過了。上面七條有兩個結構性漏洞必須補：

**（一）逐篇的基準數量。** `declared.difference(taken)` 在 `declared` 為空時也通過；`unreached` 在分支清單為空時也通過。若日後有人從某篇刪掉一整段分歧，這組測試依然全綠。因此每篇要斷言實測基準：

| # | 篇 | 路徑 | 選項 | 非空 if 分支 |
|---|---|:-:|:-:|:-:|
| 1 | 港口的外地人 | 128 | 14 | 9 |
| 2 | 烤爐熄了 | 40 | 11 | 3 |
| 3 | 井水退了 | 16 | 8 | 4 |
| 4 | 天上那棵樹 | 20 | 9 | 2 |
| 5 | 蠟板 | 80 | 13 | 3 |
| 6 | 上鎖的門 | 32 | 10 | 4 |
| 7 | 靠不了岸 | 32 | 10 | 2 |
| 8 | 普特奧利的新房子 | 20 | 9 | 3 |
| | **合計** | **368** | **84** | **30** |

**（二）已知死碼用 allowlist 雙向斷言，不要用 `skip:`。** `skip:` 關掉的是整條測試，有兩個方向的風險：日後往同一篇新增的死碼會被一起吞掉；而死碼修好之後測試永遠停在 skip，沒有任何訊號提示該把它刪掉。改成：

```dart
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
```

斷言改成：

```dart
        final known = knownDeadBranches[dir] ?? const <String>{};
        expect(unreached.toSet().difference(known), isEmpty,
            reason: '出現新的死碼——這些 if 分支在任何路徑上都進不去');
        expect(known.difference(unreached.toSet()), isEmpty,
            reason: '這些死碼已經走得到了，請從 knownDeadBranches 刪掉');
```

- [ ] **Step 2: 跑測試**

Run: `cd vn && fvm flutter test test/src/visual_novel/pack_walkthrough_test.dart`

- [ ] **Step 3: 處理失敗**

**如果「每個選項至少被走過一次」或「if 分支都走得到」失敗**：那代表劇本裡有走不到的內容，這是**真實發現，不是測試太嚴**。
- 不要放寬測試。
- 把走不到的 key 與對應的劇本片段整理出來，回報給 user 決定（可能是條件寫錯，也可能是刻意的死碼）。
- 在 user 決定之前，這個 test 標 `skip: '待 user 確認 <key>'` 並在 commit message 說明。

**如果超過步數預算**：先確認不是真的無窮迴圈（`goto` 繞回先前的場）。

- [ ] **Step 4: Commit**

```bash
git add vn/test/src/visual_novel/pack_walkthrough_test.dart
git commit -m "test(vn): 8 篇真實劇本的窮舉走訪——24 結局可達、分歧全覆蓋、資產完整"
```

---

### Task 7: 立繪去背

**Files:**
- Modify: `vn/tool/import_pack.py`（新增 `remove_background()`，接進 `process_asset()`）
- Test: `vn/tool/test_import_pack.py`（新增去背的斷言）

**Interfaces:**
- Consumes: Task 2 的 `process_asset(kind, src, dest, webp, use_cache)`
- Produces: `remove_background(src: Path) -> PIL.Image.Image`（RGBA）；`tool/_review/cutout_<name>.png` 對照圖

**背景**：立繪是 1024×1536 的平灰底（`hasAlpha: no`），直接疊在場景上會是一塊灰方塊。

- [ ] **Step 1: 寫失敗的測試**

在 `vn/tool/test_import_pack.py` 追加：

```python
def test_sprites_have_alpha_and_opaque_subject():
    from PIL import Image
    import numpy as np
    img = Image.open(OUT / 'assets/sprites/vibia_neutral.png')
    assert img.mode == 'RGBA', img.mode
    a = np.asarray(img)[:, :, 3]
    # 四角應該全透明（那是被去掉的灰底）
    assert a[0, 0] == 0 and a[0, -1] == 0, '左右上角沒去乾淨'
    # 中央偏下應該是人物，全不透明
    h, w = a.shape
    assert a[int(h * 0.6), int(w * 0.5)] == 255, '人物被啃掉了'
    # 透明佔比要落在合理區間——太低表示沒去到，太高表示啃過頭
    # 實測 44 張落在 0.337–0.508，區間取 0.25–0.60 留一點餘裕但不至於形同虛設。
    ratio = float((a == 0).mean())
    assert 0.25 < ratio < 0.60, f'透明佔比異常：{ratio:.2f}'


def _interior_islands(alpha):
    """回傳「不與畫面邊界連通的透明像素數」——會透出背景的破洞。"""
    import numpy as np
    transparent = alpha <= 127
    h, w = transparent.shape
    reach = np.zeros((h, w), dtype=bool)
    reach[0, :] |= transparent[0, :]
    reach[-1, :] |= transparent[-1, :]
    reach[:, 0] |= transparent[:, 0]
    reach[:, -1] |= transparent[:, -1]
    while True:
        grown = reach.copy()
        grown[1:, :] |= reach[:-1, :]
        grown[:-1, :] |= reach[1:, :]
        grown[:, 1:] |= reach[:, :-1]
        grown[:, :-1] |= reach[:, 1:]
        grown &= transparent
        if grown.sum() == reach.sum():
            break
        reach = grown
    return int((transparent & ~reach).sum())


def test_no_interior_holes():
    """閉運算會把咬痕的頸部填掉、讓殘骸變成孤島，_fill_interior 負責收拾。

    孤島 ＝ 人物身上會透出背景的破洞，一個都不該留。
    """
    from PIL import Image
    import numpy as np
    for path in sorted((OUT / 'assets/sprites').glob('*.png')):
        alpha = np.asarray(Image.open(path).convert('RGBA').getchannel('A')).astype(int)
        assert _interior_islands(alpha) == 0, f'{path.name} 有內部破洞'


def test_genuine_gaps_are_not_bridged():
    """尼基亞斯手臂與軀幹之間的縫隙不得被閉運算夾斷。

    這是 CLOSE_RADIUS 從 7 降到 4 的原因。**這個回歸在「透明比例」上量不到**
    ——r=7 時尼基亞斯的主體佔比只多 0.16 個百分點，看起來完全安全，實際上
    那條縫隙已經被從中間夾斷、上半段封成 3,150px 的孤島，再被 _fill_interior
    填實。只有量特定區域的拓樸才抓得到。
    """
    from PIL import Image
    import numpy as np
    for path in sorted((OUT / 'assets/sprites').glob('nikias_*.png')):
        alpha = np.asarray(Image.open(path).convert('RGBA').getchannel('A')).astype(int)
        gap = alpha[1250:1500, 150:280] <= 127
        # 實測四張表情都是 13.0–13.7%；被夾斷後會掉到 3% 左右。
        assert gap.mean() > 0.08, f'{path.name} 的手臂縫隙被填掉了：{gap.mean():.3f}'


def test_backgrounds_stay_opaque():
    from PIL import Image
    img = Image.open(OUT / 'assets/backgrounds/bg_harbour.png')
    assert img.mode in ('RGB', 'RGBA')
    if img.mode == 'RGBA':
        import numpy as np
        assert np.asarray(img)[:, :, 3].min() == 255, '背景不該被去背'
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd /Users/paulwu/Documents/PLRepo/lorescape && python3 -m pytest vn/tool/test_import_pack.py::test_sprites_have_alpha_and_opaque_subject -v`
Expected: FAIL — `img.mode == 'RGB'`

- [ ] **Step 3: 實作去背**

在 `vn/tool/import_pack.py` 加入（並在檔案頂端 `import collections` / `from PIL import Image, ImageFilter` / `import numpy as np`）：

```python
CACHE = ROOT / 'writer/創作/龐貝/美術測試/_processed'
REVIEW = ROOT / 'vn/tool/_review'

# 灰底判定的容差。AI 出的平灰底其實有輕微雜訊，純等值比對會留下一圈麻點。
BG_TOLERANCE = 26


def remove_background(src: pathlib.Path):
    """平灰底 → alpha。只從四邊界往內泛洪，避免把人物內部的灰色一起吃掉。

    為什麼是泛洪而不是「所有接近灰的像素都設透明」：維比婭的斗篷是灰綠色、
    多個角色有灰白頭髮，用顏色判定會在人物身上打洞。泛洪只吃「與邊界連通」
    的區域，人物內部再灰也不會被碰到。
    """
    img = Image.open(src).convert('RGB')
    pixels = np.asarray(img).astype(np.int16)
    h, w, _ = pixels.shape

    bg = _background_colour(pixels)
    similar = (np.abs(pixels - bg).max(axis=2) <= BG_TOLERANCE)

    # 從邊界泛洪（4 連通的 BFS，用 numpy 的逐列擴張代替遞迴）
    reachable = np.zeros((h, w), dtype=bool)
    reachable[0, :] |= similar[0, :]
    reachable[-1, :] |= similar[-1, :]
    reachable[:, 0] |= similar[:, 0]
    reachable[:, -1] |= similar[:, -1]
    while True:
        grown = reachable.copy()
        grown[1:, :] |= reachable[:-1, :]
        grown[:-1, :] |= reachable[1:, :]
        grown[:, 1:] |= reachable[:, :-1]
        grown[:, :-1] |= reachable[:, 1:]
        grown &= similar
        if grown.sum() == reachable.sum():
            break
        reachable = grown

    alpha = Image.fromarray(np.where(reachable, 0, 255).astype(np.uint8), mode='L')
    alpha = _close_bites(alpha)
    alpha = _fill_interior(np.asarray(alpha).astype(int))
    out = Image.fromarray(np.dstack([np.asarray(img), alpha]), mode='RGBA')
    # 1px 羽化：去背邊緣會有一圈灰，模糊 alpha 讓它過渡掉。
    out.putalpha(out.getchannel('A').filter(ImageFilter.GaussianBlur(radius=1.0)))
    return out


# 閉運算的半徑（px）。r=4 會填掉寬度 8px 以內的凹陷。
#
# **不要調大。** 實測掃過 r=1..9：r=5 起會橋接尼基亞斯手臂與軀幹之間的縫隙，
# 把那塊真實背景封成 3,150–3,461px 的孤島（四張表情都中）。r=4 是唯一同時
# 「填掉祭司咬痕」與「不碰真實縫隙」的窗口——祭司在 r=4 已填入 12,247px，
# 達到 r=7 的 92%。
CLOSE_RADIUS = 4


def _close_bites(alpha):
    """對主體遮罩做閉運算（先膨脹後侵蝕），填掉泛洪咬進衣服的細長凹陷。

    祭司的米白僧袍在右肩下緣的陰影剛好貼近背景灰，泛洪會沿著那裡鑽進布料，
    留下幾道深入的鋸齒——遊戲內縮到 0.72H 仍有 8–15px 寬，看起來像袍子破了。

    ⚠️ 閉運算的危險不在「多填了多少主體像素」（那個量很小、看指標會誤判安全），
    而在**它可能把一條真實的背景縫隙從中間夾斷**。判斷安全與否要看
    「有多少原本連通的背景被封成孤島」，不是看主體佔比增加多少。
    """
    binary = alpha.point(lambda v: 255 if v > 127 else 0)
    size = CLOSE_RADIUS * 2 + 1
    return binary.filter(ImageFilter.MaxFilter(size)).filter(ImageFilter.MinFilter(size))


def _fill_interior(alpha_array):
    """透明區域只有**與畫面邊界連通**的才算背景，其餘填實。

    這是把泛洪本來就依賴的那條不變式，在閉運算之後重新套一次——閉運算會把
    咬痕的「頸部」填掉，讓殘骸變成不再連通邊界的孤島。

    實測 r=4 下的孤島有兩類：祭司袍子上的咬痕殘骸（1,006–1,706px，正是要清掉
    的），以及莎爾維婭與特婭耳環圈裡的縫隙（555px／107px，遊戲內約 2px，
    填掉等於耳環變實心，看不出來）。兩類都填是對的取捨。
    """
    transparent = alpha_array <= 127
    height, width = transparent.shape
    reachable = np.zeros((height, width), dtype=bool)
    reachable[0, :] |= transparent[0, :]
    reachable[-1, :] |= transparent[-1, :]
    reachable[:, 0] |= transparent[:, 0]
    reachable[:, -1] |= transparent[:, -1]
    while True:
        grown = reachable.copy()
        grown[1:, :] |= reachable[:-1, :]
        grown[:-1, :] |= reachable[1:, :]
        grown[:, 1:] |= reachable[:, :-1]
        grown[:, :-1] |= reachable[:, 1:]
        grown &= transparent
        if grown.sum() == reachable.sum():
            break
        reachable = grown
    return np.where(reachable, 0, 255).astype(np.uint8)


# 去背演算法的版本號。**改動 remove_background() 的行為時要手動 +1。**
PIPELINE_VERSION = 1


def _cache_key(src: pathlib.Path) -> str:
    """快取鍵要綁「來源圖 ＋ 演算法參數 ＋ 版本號」，不能只綁來源圖。

    只綁來源圖的話，調了 BG_TOLERANCE 或 CLOSE_RADIUS 卻忘記加 `--no-cache`，
    就會靜默命中舊 hash、吐出用舊參數跑出來的舊結果，而且不會有任何警告。
    這一版的三輪修正全都是「來源圖沒變、演算法變了」，正是這個坑的形狀。
    """
    stamp = f'{BG_TOLERANCE}:{CLOSE_RADIUS}:{PIPELINE_VERSION}'.encode()
    return hashlib.md5(src.read_bytes() + stamp).hexdigest()


def _background_colour(pixels):
    """取邊界像素的**眾數**當背景色。

    不要用「四角中位數」——這批立繪是半身像，人物的衣服延伸到畫面下緣，
    **下面兩角取到的是人物本身**。實測 vibia_neutral 的下緣兩角是 (91,80,55)
    與 (84,74,47)，那是她的橄欖綠斗篷；混進中位數會把背景估成 (135,129,112)，
    與真正的背景 (150,149,148) 差了 37，超過容差，於是泛洪從邊界長不出去、
    幾乎沒去到背景。

    眾數對「人物佔掉一部分邊界」免疫：實測 44 張，背景色都是邊界的**最大宗**
    （相對多數 18.5–84.6%，不是絕對多數），且沒有任何一張的人物碰到上緣。

    佔比最低的 philemon_neutral 只有 18.5%，是因為它的背景本身有雜訊，被 /8
    量化拆成四個相鄰 bin（合計約 53%）。它仍然能正確去背——真正的安全網是
    「相對多數勝出 ＋ 容差夠寬，把相鄰的量化 bin 一起吃進來」，**不是**
    「背景要過半」。日後有人排查新素材去背失敗，不要往「背景佔比為何偏低」
    這個方向找，那不是原因。
    """
    height, width, _ = pixels.shape
    border = np.concatenate([
        pixels[0:4, :].reshape(-1, 3), pixels[height - 4:, :].reshape(-1, 3),
        pixels[:, 0:4].reshape(-1, 3), pixels[:, width - 4:].reshape(-1, 3),
    ])
    # 量化到 /8 再數，避免 JPEG 式雜訊把同一個顏色拆成幾十種。
    quantised = border // 8
    counts = collections.Counter(map(tuple, quantised))
    return np.array(counts.most_common(1)[0][0]) * 8 + 4


def write_review(name: str, before, after) -> None:
    """把去背前後拼成一張對照圖，人工驗收用。"""
    REVIEW.mkdir(parents=True, exist_ok=True)
    checker = Image.new('RGB', after.size, (220, 60, 160))  # 洋紅底，殘留的灰會很明顯
    checker.paste(after, (0, 0), after)
    canvas = Image.new('RGB', (before.width * 2, before.height))
    canvas.paste(before.convert('RGB'), (0, 0))
    canvas.paste(checker, (before.width, 0))
    canvas.resize((canvas.width // 3, canvas.height // 3)).save(REVIEW / f'cutout_{name}')
```

把 `process_asset()` 換成：

```python
def process_asset(kind: str, src: pathlib.Path, dest: pathlib.Path,
                  webp: bool, use_cache: bool) -> None:
    if kind != 'sprites':
        shutil.copyfile(src, dest)   # 背景不去背
        return
    CACHE.mkdir(parents=True, exist_ok=True)
    cached = CACHE / f'{_cache_key(src)}_cutout.png'
    if use_cache and cached.exists():
        shutil.copyfile(cached, dest)
        return
    cutout = remove_background(src)
    cutout.save(cached)
    shutil.copyfile(cached, dest)
    write_review(src.name, Image.open(src), cutout)
```

- [ ] **Step 4: 先做一張給 user 驗收**

```bash
cd /Users/paulwu/Documents/PLRepo/lorescape
python3 - <<'EOF'
import sys, pathlib
sys.path.insert(0, 'vn/tool')
from PIL import Image
from import_pack import remove_background, write_review, ROOT
src = ROOT / 'writer/創作/龐貝/stories/01_港口的外地人/assets/sprites/vibia_neutral.png'
write_review(src.name, Image.open(src), remove_background(src))
print('→ vn/tool/_review/cutout_vibia_neutral.png')
EOF
```

**停在這裡，把 `vn/tool/_review/cutout_vibia_neutral.png` 給 user 看過再往下。** 洋紅底上若有灰邊或人物缺角，調 `BG_TOLERANCE`（灰邊 → 調高；缺角 → 調低）後重看。

> **實測基準**（`BG_TOLERANCE = 26` ＋ 眾數背景色）：透明比例落在 34–42%，人物中軸由上到下完全保留。若你的結果離這個區間很遠，先懷疑背景色估錯了，不要急著動容差——**容差能補的是雜訊，補不了採樣點選錯**。

- [ ] **Step 5: 全跑並驗收**

```bash
python3 vn/tool/import_pack.py --no-cache
python3 -m pytest vn/tool/test_import_pack.py -v
```

Expected: 全 PASS。另外把 `vn/tool/_review/` 裡幾張灰髮／灰袍角色（`pliny_*`、`priest_*`、`vibia_*`）挑出來給 user 看。

- [ ] **Step 6: Commit**

```bash
git add vn/tool/
git commit -m "feat(vn): 立繪去背——邊界泛洪避免吃掉人物身上的灰"
```

---

### Task 8: 表情差分對齊

**Files:**
- Modify: `vn/tool/import_pack.py`（新增 `align_to_base()`，接進 `process_asset()`）
- Test: `vn/tool/test_import_pack.py`（新增對齊的斷言）

**Interfaces:**
- Consumes: Task 7 的 `remove_background()`
- Produces: `align_to_base(base_rgba, variant_rgba) -> (PIL.Image.Image, dict)`；`tool/_review/align_<name>.png`

**背景**：表情差分是 image-to-image 從基底生的，與基底之間有輕微尺度／位置飄移（`美術驗收記錄` 第 6 輪）。不對齊的話切表情時人物會跳動。基底檔名是 `<角色>_neutral.png`，差分是同角色的其他表情。

> **對規範的刻意偏離**：`Flutter製作規範` §4.2 指定用「兩眼中點 ＋ 眼距」對齊，但環境沒有臉部偵測可用。改用整張圖的正規化互相關做縮放 ＋ 平移搜尋。差分與基底的整體相關性夠高，全域對齊在此等價且更穩。設計文件 §6 已記錄此事。

- [ ] **Step 1: 寫失敗的測試**

在 `vn/tool/test_import_pack.py` 追加：

```python
def test_expression_variants_align_with_base():
    from PIL import Image
    import numpy as np

    def head_box(path):
        """回傳不透明像素的外框（left, top, right, bottom）。"""
        a = np.asarray(Image.open(path))[:, :, 3] > 128
        rows, cols = np.where(a)
        return cols.min(), rows.min(), cols.max(), rows.max()

    for character in ('vibia', 'nikias', 'philemon'):
        base = head_box(OUT / f'assets/sprites/{character}_neutral.png')
        for variant in sorted((OUT / 'assets/sprites').glob(f'{character}_*.png')):
            if variant.name.endswith('_neutral.png'):
                continue
            box = head_box(variant)
            # 頭頂位置與整體寬度對齊到 12px 以內，切表情才不會跳
            assert abs(box[1] - base[1]) <= 12, f'{variant.name} 頭頂差 {box[1] - base[1]}px'
            assert abs((box[2] - box[0]) - (base[2] - base[0])) <= 24, \
                f'{variant.name} 寬度差太多'
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd /Users/paulwu/Documents/PLRepo/lorescape && python3 -m pytest vn/tool/test_import_pack.py::test_expression_variants_align_with_base -v`
Expected: FAIL（若意外通過，表示飄移本來就在容差內——記錄下來、保留這個 test 當回歸守門，直接跳到 Step 6）

- [ ] **Step 3: 實作對齊**

在 `vn/tool/import_pack.py` 加入：

```python
# 對齊搜尋範圍。菲勒蒙的基底取景較近，需要縮小才對得上（進度與交接 §3）。
SCALE_RANGE = [0.88 + 0.02 * i for i in range(13)]   # 0.88 … 1.12
SHIFT_LIMIT = 72                                      # px，於 1/4 解析度上為 18


# 對齊分數的下限。低於它就不套用對齊——那種分數代表素材本身有問題
# （畫錯人、畫錯時代），硬套對齊只會把它變得更歪。
ALIGN_MIN_SCORE = 0.95

# 已知有問題的立繪：分數過低是**素材問題**，不是對齊失敗。
#
# 用 allowlist 而不是默默跳過，是為了讓兩個方向都有訊號：多出新的壞素材會紅，
# 而素材被重出修好之後這裡沒刪也會紅（與 Task 6 的 knownDeadBranches 同一套路）。
KNOWN_BAD_SPRITES = {
    # 十九世紀海軍軍官制服，時代錯置。用在 07-cannot-land S01/S02 共 5 處。
    'officer_hard.png': '時代錯置：19 世紀海軍軍官',
    # 以下三張與別的角色位元組相同，是表情差分被指到了別人的臉。
    'hylas_scared.png': '錯掛：實為盧奇烏斯（≡ master_impatient）',
    'orestes_urgent.png': '錯掛：實為忒亞（≡ thea_afraid）',
    'survivor_sharp.png': '錯掛：實為普林尼（≡ pliny_labored）',
}


def _score(a, b):
    """正規化互相關。兩張同尺寸的 numpy 陣列。"""
    a = a - a.mean()
    b = b - b.mean()
    denom = np.sqrt((a * a).sum() * (b * b).sum())
    return float((a * b).sum() / denom) if denom else -1.0


def align_to_base(base_rgba, variant_rgba):
    """把 variant 縮放 + 平移對到 base，回傳 (對齊後的 RGBA, 參數)。

    先在 1/4 解析度粗搜縮放與平移，再於全解析度做 ±4px 細修。
    """
    w, h = base_rgba.size

    # **比 alpha 剪影，不要比灰階亮度。**
    #
    # 差分的原始畫布尺寸不一定與基底相同（實測 4 張是 1023×1537、officer_hard
    # 是 1122×1402，其餘 39 張才是 1024×1536）。把差分貼到基底尺寸的畫布上時，
    # 邊緣會留下一圈墊底色，而 `convert('L')` 丟掉 alpha 只看 RGB——那圈邊在
    # 互相關裡是極強的人造對比，分數整個被它主導。實測灰階法會把
    # nikias_watchful 評成 0.38 並挑出 scale 0.90 的錯誤解，把一張本來就對齊
    # 的圖弄歪 132px。
    #
    # alpha 對此免疫：透明區的值是 0，與畫布留白同值，沒有人造邊。改用 alpha
    # 之後 24/28 個差分都是 score ≥ 0.978、scale 1.00、位移 (0,0)。
    def silhouette(image):
        return np.asarray(image.getchannel('A').resize((w // 4, h // 4))).astype(np.float32)

    base_small = silhouette(base_rgba)

    best = (-1.0, 1.0, 0, 0)
    for scale in SCALE_RANGE:
        scaled = variant_rgba.resize((int(w * scale), int(h * scale)))
        canvas = Image.new('RGBA', (w, h))
        canvas.paste(scaled, ((w - scaled.width) // 2, (h - scaled.height) // 2))
        small = silhouette(canvas)
        for dy in range(-SHIFT_LIMIT // 4, SHIFT_LIMIT // 4 + 1, 2):
            for dx in range(-SHIFT_LIMIT // 4, SHIFT_LIMIT // 4 + 1, 2):
                shifted = np.roll(np.roll(small, dy, axis=0), dx, axis=1)
                score = _score(base_small, shifted)
                if score > best[0]:
                    best = (score, scale, dx * 4, dy * 4)

    score, scale, dx, dy = best
    if score < ALIGN_MIN_SCORE:
        # 分數這麼低不是「沒對齊」，是「這兩張根本不是同一個人／同一個時代」。
        # 硬套搜尋出來的最佳解只會把它縮放平移到更歪的位置——實測就發生過。
        # 原樣貼進基底畫布，尺寸統一但內容不動。
        out = Image.new('RGBA', (w, h))
        out.paste(variant_rgba, ((w - variant_rgba.width) // 2, (h - variant_rgba.height) // 2))
        return out, {'scale': 1.0, 'dx': 0, 'dy': 0, 'score': round(score, 4), 'skipped': True}
    scaled = variant_rgba.resize((int(w * scale), int(h * scale)))
    out = Image.new('RGBA', (w, h))
    out.paste(scaled, ((w - scaled.width) // 2 + dx, (h - scaled.height) // 2 + dy))
    return out, {'scale': round(scale, 3), 'dx': dx, 'dy': dy, 'score': round(score, 4),
                 'skipped': False}


def write_align_review(name: str, base, before, after) -> None:
    """三聯圖：基底 / 對齊前 / 對齊後，各自疊在基底輪廓上看偏移。"""
    REVIEW.mkdir(parents=True, exist_ok=True)
    def overlay(img):
        canvas = Image.new('RGB', base.size, (18, 18, 18))
        canvas.paste(Image.new('RGB', base.size, (60, 90, 140)), (0, 0), base)
        canvas.paste(Image.new('RGB', base.size, (220, 90, 60)), (0, 0),
                     img.getchannel('A').point(lambda v: v // 2))
        return canvas
    canvas = Image.new('RGB', (base.width * 3, base.height))
    canvas.paste(base.convert('RGB'), (0, 0))
    canvas.paste(overlay(before), (base.width, 0))
    canvas.paste(overlay(after), (base.width * 2, 0))
    canvas.resize((canvas.width // 4, canvas.height // 4)).save(REVIEW / f'align_{name}')
```

`process_asset()` 的 sprites 分支改成：對齊需要同角色的基底，因此改由 `import_pack()` 在收齊所有立繪後統一處理。把立繪的處理抽成一個新函式並在 `import_pack()` 裡呼叫：

```python
def process_sprites(picked, use_cache: bool) -> None:
    """先全部去背，再把差分對齊到同角色的 _neutral 基底。"""
    CACHE.mkdir(parents=True, exist_ok=True)
    cutouts = {}
    for (kind, name), src in sorted(picked.items()):
        if kind != 'sprites':
            continue
        digest = hashlib.md5(src.read_bytes()).hexdigest()
        cached = CACHE / f'{digest}_cutout.png'
        if not (use_cache and cached.exists()):
            remove_background(src).save(cached)
        cutouts[name] = (Image.open(cached).convert('RGBA'), digest)

    for name, (img, digest) in sorted(cutouts.items()):
        character = name.rsplit('_', 1)[0]
        base_name = f'{character}_neutral.png'
        dest = OUT / 'assets/sprites' / name
        if name == base_name or base_name not in cutouts:
            img.save(dest)
            continue
        aligned_cache = CACHE / f'{digest}_aligned.png'
        if use_cache and aligned_cache.exists():
            shutil.copyfile(aligned_cache, dest)
            continue
        base = cutouts[base_name][0]
        aligned, params = align_to_base(base, img)
        aligned.save(aligned_cache)
        aligned.save(dest)
        write_align_review(name, base, img, aligned)
        print(f'  對齊 {name}: {params}')
```

`process_asset()` 縮回只處理背景，並在 `import_pack()` 中改為：

```python
    for (kind, name), src_path in sorted(picked.items()):
        if kind == 'backgrounds':
            shutil.copyfile(src_path, OUT / 'assets/backgrounds' / name)
    process_sprites(picked, use_cache)
```

- [ ] **Step 4: 跑一次並看對照圖**

```bash
cd /Users/paulwu/Documents/PLRepo/lorescape
python3 vn/tool/import_pack.py --no-cache
ls vn/tool/_review/align_*.png
```

**停在這裡，把 `align_vibia_softened.png`、`align_philemon_warm.png`、`align_nikias_weary.png` 給 user 看。** 第三格（對齊後）的橘色輪廓應該貼合藍色基底。菲勒蒙若 `scale` 明顯小於 1（例如 0.90），那是預期的——他的基底取景較近。

- [ ] **Step 5: 跑測試確認通過**

Run: `python3 -m pytest vn/tool/test_import_pack.py -v`
Expected: 全 PASS。**若某個角色始終對不上**，不要放寬容差——把該角色從差分清單移除、改成只用基底，並回報給 user（風險 2 的既定退路）。

- [ ] **Step 6: Commit**

```bash
git add vn/tool/
git commit -m "feat(vn): 表情差分對齊——互相關取代規範的眼距基準，環境無臉部偵測"
```

---

### Task 9: Repository、存檔儲存與 `providers.dart`

**Files:**
- Create: `vn/lib/src/visual_novel/data/pack_repository.dart`、`vn/lib/src/visual_novel/data/save_store.dart`、`vn/lib/src/visual_novel/providers.dart`
- Modify: `vn/lib/main.dart`
- Test: `vn/test/src/visual_novel/data/pack_repository_test.dart`、`vn/test/src/visual_novel/data/save_store_test.dart`

**Interfaces:**
- Consumes: Task 3–5 的 domain 與 parser
- Produces（`providers.dart` re-export，presentation 只准 import 這個檔）：

```dart
final class PackEntry { const PackEntry({required this.id, required this.order,
    required this.dir, required this.title, required this.subtitle,
    required this.estimatedMinutes}); ... }
final class Pack { final String id, title, place, blurb; final List<PackEntry> stories; }

abstract interface class PackRepository {
  Future<Pack> loadPack();
  Future<Story> loadStory(String storyId);
  String? backgroundPath(Story story, String key);   // 'assets/content/…/bg_x.png'；缺件回 null
  String? spritePath(Story story, String who, String sprite);
  String? cgPath(Story story, String cgId);
}

abstract interface class SaveStore {
  SaveData? loadSave(String storyId);
  Future<void> writeSave(SaveData data);
  Future<void> clearSave(String storyId);
  Set<String> readNodes();
  Future<void> markRead(String key);
  Set<String> endingsSeen();                          // '<storyId>#<endingId>'
  Future<void> markEnding(String storyId, String endingId);
  double textSpeed();                                  // 每字毫秒，預設 28
  Future<void> setTextSpeed(double value);
  double fontScale();                                  // 預設 1.0
  Future<void> setFontScale(double value);
}

// providers
final sharedPreferencesProvider = Provider<SharedPreferences>((_) => throw UnimplementedError());
final packRepositoryProvider = Provider<PackRepository>(...);
final saveStoreProvider = Provider<SaveStore>(...);
final packProvider = FutureProvider<Pack>(...);
final storyProvider = FutureProvider.family<Story, String>(...);
```

- [ ] **Step 1: 寫失敗的測試**

`vn/test/src/visual_novel/data/save_store_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lorescape_vn/src/visual_novel/data/save_store.dart';
import 'package:lorescape_vn/src/visual_novel/domain/cursor.dart';
import 'package:lorescape_vn/src/visual_novel/domain/play_state.dart';
import 'package:lorescape_vn/src/visual_novel/domain/save_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late SharedPreferencesSaveStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    store = SharedPreferencesSaveStore(prefs);
  });

  test('沒有存檔時回 null', () {
    expect(store.loadSave('pompeii_01_harbour_stranger'), isNull);
  });

  test('存檔往返', () async {
    final data = SaveData(
      storyId: 'pompeii_01_harbour_stranger',
      cursor: Cursor(sceneId: 'S03', path: const <CursorStep>[CursorStep(7)]),
      vars: const <String, Object?>{'affection': 1},
      stage: const <SpriteOnStage>[],
      updatedAt: DateTime.utc(2026, 8, 13),
    );
    await store.writeSave(data);
    final loaded = store.loadSave('pompeii_01_harbour_stranger')!;
    expect(loaded.cursor.toTokens(), <String>['7']);
    expect(loaded.vars['affection'], 1);
  });

  test('已讀節點跨故事累積', () async {
    await store.markRead('S01#0');
    await store.markRead('S01#1');
    await store.markRead('S01#0');
    expect(store.readNodes(), <String>{'S01#0', 'S01#1'});
  });

  test('結局收藏以 storyId#endingId 記錄', () async {
    await store.markEnding('pompeii_01_harbour_stranger', 'A');
    expect(store.endingsSeen(), contains('pompeii_01_harbour_stranger#A'));
  });

  test('設定有預設值且可改', () async {
    expect(store.textSpeed(), 28);
    expect(store.fontScale(), 1.0);
    await store.setTextSpeed(12);
    await store.setFontScale(1.2);
    expect(SharedPreferencesSaveStore(prefs).textSpeed(), 12);
    expect(SharedPreferencesSaveStore(prefs).fontScale(), 1.2);
  });

  test('清存檔不影響已讀與結局', () async {
    await store.markRead('S01#0');
    await store.markEnding('pompeii_01_harbour_stranger', 'A');
    await store.clearSave('pompeii_01_harbour_stranger');
    expect(store.readNodes(), isNotEmpty);
    expect(store.endingsSeen(), isNotEmpty);
  });
}
```

`vn/test/src/visual_novel/data/pack_repository_test.dart`：

```dart
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
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd vn && fvm flutter test test/src/visual_novel/data/`
Expected: FAIL — 找不到 `save_store.dart` / `pack_repository.dart`

- [ ] **Step 3: 實作 pack_repository.dart**

```dart
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:lorescape_vn/src/visual_novel/data/story_json_parser.dart';
import 'package:lorescape_vn/src/visual_novel/domain/story.dart';

const String packRoot = 'assets/content/pompeii-79';

final class PackEntry {
  const PackEntry({
    required this.id,
    required this.order,
    required this.dir,
    required this.title,
    required this.subtitle,
    required this.estimatedMinutes,
  });
  final String id;
  final int order;
  final String dir;
  final String title;
  final String subtitle;
  final int estimatedMinutes;
}

final class Pack {
  const Pack({
    required this.id,
    required this.title,
    required this.place,
    required this.blurb,
    required this.stories,
  });
  final String id;
  final String title;
  final String place;
  final String blurb;
  final List<PackEntry> stories;
}

abstract interface class PackRepository {
  Future<Pack> loadPack();
  Future<Story> loadStory(String storyId);
  String? backgroundPath(Story story, String key);
  String? spritePath(Story story, String who, String sprite);
  String? cgPath(Story story, String cgId);
}

final class BundlePackRepository implements PackRepository {
  BundlePackRepository(this._bundle);

  final AssetBundle _bundle;
  Pack? _pack;
  final Map<String, Story> _stories = <String, Story>{};

  @override
  Future<Pack> loadPack() async {
    final cached = _pack;
    if (cached != null) return cached;
    final json = jsonDecode(await _bundle.loadString('$packRoot/pack.json'))
        as Map<String, dynamic>;
    final entries = (json['stories'] as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .map((e) => PackEntry(
              id: e['id'] as String,
              order: e['order'] as int,
              dir: e['dir'] as String,
              title: e['title'] as String,
              subtitle: (e['subtitle'] as String?) ?? '',
              estimatedMinutes: e['estimatedMinutes'] as int,
            ))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return _pack = Pack(
      id: json['id'] as String,
      title: json['title'] as String,
      place: json['place'] as String,
      blurb: json['blurb'] as String,
      stories: entries,
    );
  }

  @override
  Future<Story> loadStory(String storyId) async {
    final cached = _stories[storyId];
    if (cached != null) return cached;
    final pack = await loadPack();
    final entry = pack.stories.firstWhere((s) => s.id == storyId,
        orElse: () => throw StateError('pack.json 沒有這篇：$storyId'));
    final json = jsonDecode(await _bundle.loadString('$packRoot/stories/${entry.dir}/story.json'))
        as Map<String, dynamic>;
    return _stories[storyId] = parseStory(json);
  }

  /// 缺件一律回 null 而不是丟例外——`missingAssets` 的降級要求是「不得崩潰」。
  @override
  String? backgroundPath(Story story, String key) {
    final filename = story.backgrounds[key];
    return filename == null ? null : '$packRoot/assets/backgrounds/$filename';
  }

  @override
  String? spritePath(Story story, String who, String sprite) {
    final filename = story.characters[who]?.sprites?[sprite];
    return filename == null ? null : '$packRoot/assets/sprites/$filename';
  }

  @override
  String? cgPath(Story story, String cgId) {
    if (story.missingAssets['cg']?.contains(cgId) ?? false) return null;
    return '$packRoot/assets/backgrounds/$cgId.png';
  }
}
```

- [ ] **Step 4: 實作 save_store.dart**

```dart
import 'dart:convert';

import 'package:lorescape_vn/src/visual_novel/domain/save_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class SaveStore {
  SaveData? loadSave(String storyId);
  Future<void> writeSave(SaveData data);
  Future<void> clearSave(String storyId);
  Set<String> readNodes();
  Future<void> markRead(String key);
  Set<String> endingsSeen();
  Future<void> markEnding(String storyId, String endingId);
  double textSpeed();
  Future<void> setTextSpeed(double value);
  double fontScale();
  Future<void> setFontScale(double value);
}

final class SharedPreferencesSaveStore implements SaveStore {
  SharedPreferencesSaveStore(this._prefs);

  static const String _readKey = 'vn.readNodes';
  static const String _endingsKey = 'vn.endingsSeen';
  static const String _textSpeedKey = 'vn.textSpeed';
  static const String _fontScaleKey = 'vn.fontScale';

  final SharedPreferences _prefs;

  String _saveKey(String storyId) => 'vn.save.$storyId';

  @override
  SaveData? loadSave(String storyId) {
    final raw = _prefs.getString(_saveKey(storyId));
    if (raw == null) return null;
    try {
      return SaveData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      // 劇本改版後舊存檔可能指向不存在的路徑；當成沒有存檔，不要讓玩家卡在錯誤頁。
      return null;
    }
  }

  @override
  Future<void> writeSave(SaveData data) =>
      _prefs.setString(_saveKey(data.storyId), jsonEncode(data.toJson()));

  @override
  Future<void> clearSave(String storyId) => _prefs.remove(_saveKey(storyId)).then((_) {});

  @override
  Set<String> readNodes() => (_prefs.getStringList(_readKey) ?? const <String>[]).toSet();

  @override
  Future<void> markRead(String key) async {
    final current = readNodes();
    if (!current.add(key)) return;
    await _prefs.setStringList(_readKey, current.toList()..sort());
  }

  @override
  Set<String> endingsSeen() => (_prefs.getStringList(_endingsKey) ?? const <String>[]).toSet();

  @override
  Future<void> markEnding(String storyId, String endingId) async {
    final current = endingsSeen();
    if (!current.add('$storyId#$endingId')) return;
    await _prefs.setStringList(_endingsKey, current.toList()..sort());
  }

  @override
  double textSpeed() => _prefs.getDouble(_textSpeedKey) ?? 28;

  @override
  Future<void> setTextSpeed(double value) => _prefs.setDouble(_textSpeedKey, value);

  @override
  double fontScale() => _prefs.getDouble(_fontScaleKey) ?? 1.0;

  @override
  Future<void> setFontScale(double value) => _prefs.setDouble(_fontScaleKey, value);
}
```

- [ ] **Step 5: 實作 providers.dart**

```dart
/// 這個 feature 的**唯一**公開介面。presentation 只准 import 這個檔；
/// 日後搬進 frontend/lib/features/visual_novel/ 後，跨 feature 引用也只看這裡。
library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lorescape_vn/src/visual_novel/data/pack_repository.dart';
import 'package:lorescape_vn/src/visual_novel/data/save_store.dart';
import 'package:lorescape_vn/src/visual_novel/domain/story.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:lorescape_vn/src/visual_novel/data/pack_repository.dart'
    show Pack, PackEntry, PackRepository;
export 'package:lorescape_vn/src/visual_novel/data/save_store.dart' show SaveStore;
export 'package:lorescape_vn/src/visual_novel/domain/cursor.dart';
export 'package:lorescape_vn/src/visual_novel/domain/play_state.dart';
export 'package:lorescape_vn/src/visual_novel/domain/save_data.dart';
export 'package:lorescape_vn/src/visual_novel/domain/story.dart';
export 'package:lorescape_vn/src/visual_novel/domain/story_player.dart';

/// main() 於啟動時以 overrideWithValue 覆寫。
final Provider<SharedPreferences> sharedPreferencesProvider =
    Provider<SharedPreferences>((ref) => throw UnimplementedError('未於 main() 覆寫'));

final Provider<PackRepository> packRepositoryProvider =
    Provider<PackRepository>((ref) => BundlePackRepository(rootBundle));

final Provider<SaveStore> saveStoreProvider =
    Provider<SaveStore>((ref) => SharedPreferencesSaveStore(ref.watch(sharedPreferencesProvider)));

final FutureProvider<Pack> packProvider =
    FutureProvider<Pack>((ref) => ref.watch(packRepositoryProvider).loadPack());

final FutureProviderFamily<Story, String> storyProvider =
    FutureProvider.family<Story, String>(
  (ref, storyId) => ref.watch(packRepositoryProvider).loadStory(storyId),
);
```

- [ ] **Step 6: main.dart 接上 SharedPreferences**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lorescape_vn/src/visual_novel/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: <Override>[sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const VnApp(),
    ),
  );
}

class VnApp extends StatelessWidget {
  const VnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '龐貝 79',
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: const Scaffold(body: Center(child: Text('龐貝 79'))),
    );
  }
}
```

同步把 `vn/test/smoke_test.dart` 包上 `ProviderScope`：

```dart
await tester.pumpWidget(const ProviderScope(child: VnApp()));
```

- [ ] **Step 7: 跑測試與 analyze**

Run: `cd vn && fvm flutter test && fvm flutter analyze --fatal-infos`
Expected: 全 PASS

- [ ] **Step 8: Commit**

```bash
git add vn/lib/src/visual_novel/data/ vn/lib/src/visual_novel/providers.dart vn/lib/main.dart vn/test/
git commit -m "feat(vn): repository、存檔儲存與 providers.dart 公開介面"
```

---

### Task 10: 播放版面

**Files:**
- Create: `vn/lib/src/visual_novel/presentation/play/layout.dart`、`background_layer.dart`、`sprite_layer.dart`、`dialogue_box.dart`、`choice_overlay.dart`、`play_page.dart`、`play_controller.dart`
- Modify: `vn/lib/src/visual_novel/providers.dart`（export `playControllerProvider`）
- Test: `vn/test/src/visual_novel/presentation/play/play_page_test.dart`

**Interfaces:**
- Consumes: Task 9 的 `providers.dart`
- Produces:

```dart
final class VnLayout {
  const VnLayout(this.size);
  factory VnLayout.of(BuildContext context);
  final Size size;
  double get w; double get h;
  double get dialogueHeight;      // 0.35 h
  double get spriteHeight;        // 0.72 h
  double get spriteBottom;        // 0.88 h → 距底 0.12 h
  double get sideInset;           // 0.06 w
  double get choiceInset;         // 0.10 w
  double get safeInset;           // 0.08 h
  double get bodyFontSize;        // w / 20
  double get spriteOffset;        // 0.18 w（雙人時左右偏移）
}

class PlayController extends FamilyNotifier<PlayState, String> { ... }
final playControllerProvider = NotifierProvider.family<PlayController, PlayState, String>(...);
```

- [ ] **Step 1: 寫失敗的測試**

`vn/test/src/visual_novel/presentation/play/play_page_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/play/dialogue_box.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/play/layout.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/play/play_page.dart';
import 'package:lorescape_vn/src/visual_novel/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpPlayPage(WidgetTester tester, String storyId) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(home: PlayPage(storyId: storyId)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('VnLayout', () {
    test('版面數值照 Flutter製作規範 §2', () {
      const layout = VnLayout(Size(400, 800));
      expect(layout.dialogueHeight, 800 * 0.35);
      expect(layout.spriteHeight, 800 * 0.72);
      expect(layout.sideInset, 400 * 0.06);
      expect(layout.choiceInset, 400 * 0.10);
      expect(layout.bodyFontSize, 400 / 20);
      expect(layout.spriteOffset, 400 * 0.18);
    });
  });

  group('PlayPage', () {
    testWidgets('開場顯示第一段旁白，且沒有名牌', (tester) async {
      await pumpPlayPage(tester, 'pompeii_01_harbour_stranger');
      expect(find.text('天還沒全亮，海面是鉛的顏色。'), findsOneWidget);
      expect(find.byKey(DialogueBox.nameTagKey), findsNothing);
    });

    testWidgets('點擊推進到下一個節點', (tester) async {
      await pumpPlayPage(tester, 'pompeii_01_harbour_stranger');
      await tester.tap(find.byKey(PlayPage.advanceAreaKey));
      await tester.pumpAndSettle();
      expect(find.text('天還沒全亮，海面是鉛的顏色。'), findsNothing);
    });

    testWidgets('對白節點顯示名牌與立繪', (tester) async {
      await pumpPlayPage(tester, 'pompeii_01_harbour_stranger');
      // 走到第一句對白（尼基亞斯：札布達。）
      for (var i = 0; i < 8; i++) {
        await tester.tap(find.byKey(PlayPage.advanceAreaKey));
        await tester.pumpAndSettle();
        if (find.text('札布達。').evaluate().isNotEmpty) break;
      }
      expect(find.text('札布達。'), findsOneWidget);
      expect(find.byKey(DialogueBox.nameTagKey), findsOneWidget);
      expect(find.text('尼基亞斯'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('sprite-nikias')), findsOneWidget);
    });

    testWidgets('缺件的 sfx 與 bgm 不造成例外', (tester) async {
      await pumpPlayPage(tester, 'pompeii_01_harbour_stranger');
      for (var i = 0; i < 12; i++) {
        await tester.tap(find.byKey(PlayPage.advanceAreaKey));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  });
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd vn && fvm flutter test test/src/visual_novel/presentation/`
Expected: FAIL — 找不到 `layout.dart`

- [ ] **Step 3: 實作 layout.dart**

```dart
import 'package:flutter/widgets.dart';

/// Flutter製作規範 §2 的版面數值，全部收在這裡。改版面只改這個檔。
final class VnLayout {
  const VnLayout(this.size);

  factory VnLayout.of(BuildContext context) => VnLayout(MediaQuery.sizeOf(context));

  final Size size;

  double get w => size.width;
  double get h => size.height;

  double get dialogueHeight => h * 0.35;
  double get spriteHeight => h * 0.72;

  /// 立繪底邊置於 0.88h ⇒ 距畫面底部 0.12h。下緣被對話框蓋住是預期行為。
  double get spriteBottom => h * 0.12;
  double get spriteOffset => w * 0.18;
  double get sideInset => w * 0.06;
  double get choiceInset => w * 0.10;
  double get safeInset => h * 0.08;
  double get bodyFontSize => w / 20;
}
```

- [ ] **Step 4: 實作 play_controller.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lorescape_vn/src/visual_novel/domain/play_state.dart';
import 'package:lorescape_vn/src/visual_novel/domain/save_data.dart';
import 'package:lorescape_vn/src/visual_novel/domain/story.dart';
import 'package:lorescape_vn/src/visual_novel/domain/story_player.dart' as player;
import 'package:lorescape_vn/src/visual_novel/providers.dart' show saveStoreProvider, storyProvider;

/// ⚠️ 這個檔被 providers.dart re-export，因此**只能**具名 import 它需要的兩個
/// provider，不可整份 import——整份 import 會讓兩個檔互相看見對方的 export，
/// 名稱衝突時的錯誤訊息會很難讀。
class PlayController extends FamilyNotifier<PlayState, String> {
  @override
  PlayState build(String storyId) {
    final story = ref.watch(storyProvider(storyId)).requireValue;
    final saved = ref.read(saveStoreProvider).loadSave(storyId);
    // 讀檔一律經過 resume：存檔沒記 status，停在選項上的存檔若當成 playing，
    // 點一下就會把那個選擇跳過。
    // resume 回 null ＝ 存檔對現在的劇本已失效（劇本改版後路徑位移），退回開頭
    // 重來，而不是崩在玩家臉上。
    final initial = saved == null
        ? player.initState(story)
        : (player.resume(story, saved.toPlayState()) ?? player.initState(story));
    _persist(storyId, initial);
    return initial;
  }

  Story get _story => ref.read(storyProvider(arg)).requireValue;

  void advance() {
    if (state.status != PlayStatus.playing) return;
    _apply(player.advance(_story, state));
  }

  void choose(int visibleIndex) {
    if (state.status != PlayStatus.choosing) return;
    _apply(player.choose(_story, state, visibleIndex));
  }

  void restart() {
    final store = ref.read(saveStoreProvider);
    store.clearSave(arg);
    state = player.initState(_story);
  }

  void _apply(PlayState next) {
    state = next;
    _persist(arg, next);
  }

  void _persist(String storyId, PlayState value) {
    final store = ref.read(saveStoreProvider);
    store.markRead(value.readKey);
    if (value.status == PlayStatus.ended) {
      final endingId = value.endingId;
      if (endingId != null) store.markEnding(storyId, endingId);
      store.clearSave(storyId);
      return;
    }
    store.writeSave(SaveData.from(storyId, value, DateTime.now()));
  }
}

final NotifierProviderFamily<PlayController, PlayState, String> playControllerProvider =
    NotifierProvider.family<PlayController, PlayState, String>(PlayController.new);
```

在 `providers.dart` 追加 export：

```dart
export 'package:lorescape_vn/src/visual_novel/presentation/play/play_controller.dart'
    show PlayController, playControllerProvider;
```

- [ ] **Step 5: 實作三個圖層與對話框**

`background_layer.dart`：

```dart
import 'package:flutter/material.dart';

class BackgroundLayer extends StatelessWidget {
  const BackgroundLayer({required this.assetPath, super.key});

  final String? assetPath;

  @override
  Widget build(BuildContext context) {
    final path = assetPath;
    if (path == null) return const ColoredBox(color: Color(0xFF1C1A19));
    return Image.asset(
      path,
      fit: BoxFit.cover,
      // 關鍵構圖都在上半部，螢幕更長時裁下緣（美術風格聖經 §3.1）。
      alignment: Alignment.topCenter,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF1C1A19)),
    );
  }
}
```

`sprite_layer.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/play/layout.dart';
import 'package:lorescape_vn/src/visual_novel/providers.dart';

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
        for (var i = 0; i < stage.length; i++) _sprite(stage[i], i, stage.length),
      ],
    );
  }

  Widget _sprite(SpriteOnStage sprite, int index, int total) {
    final path = pathOf(sprite);
    if (path == null) return const SizedBox.shrink();
    // 單人置中；雙人左右各偏移 0.18w。實測不存在三人同台。
    final dx = total == 1 ? 0.0 : (index == 0 ? -layout.spriteOffset : layout.spriteOffset);
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
          0.42, 0.50, 0.14, 0, 12,
          0.36, 0.46, 0.12, 0, 4,
          0.28, 0.38, 0.10, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: image,
      );
    }
    return Positioned(
      key: ValueKey<String>('sprite-${sprite.who}'),
      bottom: layout.spriteBottom,
      left: 0,
      right: 0,
      child: Transform.translate(offset: Offset(dx, 0), child: Center(child: image)),
    );
  }
}
```

`dialogue_box.dart`（逐字顯示留到 Task 11，本 task 先一次顯示全文）：

```dart
import 'package:flutter/material.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/play/layout.dart';

class DialogueBox extends StatelessWidget {
  const DialogueBox({
    required this.text,
    required this.layout,
    this.speakerName,
    this.graffiti = false,
    this.fontScale = 1.0,
    super.key,
  });

  static const ValueKey<String> nameTagKey = ValueKey<String>('dialogue-name-tag');

  final String text;
  final String? speakerName;
  final bool graffiti;
  final double fontScale;
  final VnLayout layout;

  @override
  Widget build(BuildContext context) {
    final name = speakerName;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: layout.dialogueHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          const Positioned.fill(child: ColoredBox(color: Color(0xD11C1A19))),
          if (name != null)
            Positioned(
              key: nameTagKey,
              left: layout.sideInset,
              top: -18,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                color: const Color(0xF21C1A19),
                child: Text(
                  name,
                  style: TextStyle(
                    color: const Color(0xFFE8DCC8),
                    fontSize: layout.bodyFontSize * 0.85 * fontScale,
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: layout.sideInset,
              vertical: layout.dialogueHeight * 0.16,
            ),
            child: Text(
              text,
              style: TextStyle(
                color: graffiti ? const Color(0xFFB9A98C) : const Color(0xFFF2ECE1),
                fontSize: layout.bodyFontSize * fontScale,
                height: 1.7,
                fontStyle: graffiti ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

`choice_overlay.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/play/layout.dart';
import 'package:lorescape_vn/src/visual_novel/providers.dart';

class ChoiceOverlay extends StatelessWidget {
  const ChoiceOverlay({
    required this.options,
    required this.onChoose,
    required this.layout,
    super.key,
  });

  final List<VisibleOption> options;
  final void Function(int visibleIndex) onChoose;
  final VnLayout layout;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: layout.choiceInset,
      right: layout.choiceInset,
      top: layout.h * 0.45,
      bottom: layout.h * 0.25,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          for (var i = 0; i < options.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  key: ValueKey<String>('choice-$i'),
                  onPressed: () => onChoose(i),
                  child: Text(options[i].option.text),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: 實作 play_page.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/play/background_layer.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/play/choice_overlay.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/play/dialogue_box.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/play/layout.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/play/sprite_layer.dart';
import 'package:lorescape_vn/src/visual_novel/providers.dart';

class PlayPage extends ConsumerWidget {
  const PlayPage({required this.storyId, super.key});

  static const ValueKey<String> advanceAreaKey = ValueKey<String>('play-advance-area');

  final String storyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storyAsync = ref.watch(storyProvider(storyId));
    return Scaffold(
      backgroundColor: const Color(0xFF0E0D0C),
      body: storyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('讀不到這篇：$error')),
        data: (story) => _Stage(storyId: storyId, story: story),
      ),
    );
  }
}

class _Stage extends ConsumerWidget {
  const _Stage({required this.storyId, required this.story});

  final String storyId;
  final Story story;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playControllerProvider(storyId));
    final controller = ref.read(playControllerProvider(storyId).notifier);
    final repository = ref.watch(packRepositoryProvider);
    final fontScale = ref.watch(saveStoreProvider).fontScale();
    final layout = VnLayout.of(context);

    if (state.status == PlayStatus.ended) {
      return _EndingView(story: story, endingId: state.endingId);
    }

    final node = currentNode(story, state);
    final scene = story.scenes[state.cursor.sceneId]!;
    final cg = node is CgNode ? repository.cgPath(story, node.id) : null;
    final hideDialogue = node is CgNode && node.hideDialogue;

    return GestureDetector(
      key: PlayPage.advanceAreaKey,
      behavior: HitTestBehavior.opaque,
      onTap: state.status == PlayStatus.playing ? controller.advance : null,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          BackgroundLayer(
            assetPath: cg ?? repository.backgroundPath(story, scene.background),
          ),
          if (cg == null)
            SpriteLayer(
              stage: state.stage,
              layout: layout,
              pathOf: (sprite) => repository.spritePath(story, sprite.who, sprite.sprite),
            ),
          if (!hideDialogue && node is NarrationNode)
            DialogueBox(
              text: node.text,
              layout: layout,
              fontScale: fontScale,
              graffiti: node.style == 'graffiti',
            ),
          if (!hideDialogue && node is DialogueNode)
            DialogueBox(
              text: node.text,
              layout: layout,
              fontScale: fontScale,
              speakerName: story.characters[node.who]?.name ?? node.who,
            ),
          if (state.status == PlayStatus.choosing && node is ChoiceNode)
            ChoiceOverlay(
              options: visibleOptions(node, state.vars),
              layout: layout,
              onChoose: controller.choose,
            ),
        ],
      ),
    );
  }
}

class _EndingView extends StatelessWidget {
  const _EndingView({required this.story, required this.endingId});

  final Story story;
  final String? endingId;

  @override
  Widget build(BuildContext context) {
    final ending = endingId == null ? null : story.endings[endingId];
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text('你走到了', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(ending?.title ?? '結局', style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: 跑測試與 analyze**

Run: `cd vn && fvm flutter test && fvm flutter analyze --fatal-infos`
Expected: 全 PASS

- [ ] **Step 8: 用真機（瀏覽器）看一眼**

```bash
cd vn && fvm flutter run -d chrome
```

暫時把 `main.dart` 的 `home` 改成 `PlayPage(storyId: 'pompeii_01_harbour_stranger')`，確認背景、立繪、對話框、名牌都在正確位置。**把截圖給 user 看過再往下。**

- [ ] **Step 9: Commit**

```bash
git add vn/lib/src/visual_novel/presentation/ vn/lib/src/visual_novel/providers.dart vn/test/
git commit -m "feat(vn): 播放版面——照規範 §2 的直式對話框、名牌與立繪站位"
```

---

### Task 11: 逐字顯示、點擊補完與圖片預載

**Files:**
- Create: `vn/lib/src/visual_novel/presentation/play/typewriter_text.dart`、`vn/lib/src/visual_novel/presentation/play/preloader.dart`
- Modify: `dialogue_box.dart`、`play_page.dart`
- Test: `vn/test/src/visual_novel/presentation/play/typewriter_text_test.dart`、追加 `play_page_test.dart`

**Interfaces:**
- Consumes: Task 10 的 `DialogueBox` / `PlayPage`
- Produces:

```dart
class TypewriterText extends StatefulWidget {
  const TypewriterText({required this.text, required this.style,
      required this.msPerCharacter, required this.completed,
      required this.onCompleted, super.key});
  static const ValueKey<String> key_ = ValueKey<String>('typewriter');
}

Future<void> precacheNode(BuildContext context, PackRepository repository,
                          Story story, PlayState state);
```

**行為**：文字逐字浮現；**點擊時若還沒顯示完，先補完不推進**；補完後再點才推進。

- [ ] **Step 1: 寫失敗的測試**

`vn/test/src/visual_novel/presentation/play/typewriter_text_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/play/typewriter_text.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('文字逐字浮現，時間到了才全出來', (tester) async {
    await tester.pumpWidget(wrap(TypewriterText(
      text: '天還沒全亮',
      style: const TextStyle(),
      msPerCharacter: 20,
      completed: false,
      onCompleted: () {},
    )));
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('天'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('天還沒全亮'), findsOneWidget);
  });

  testWidgets('completed 為 true 時直接顯示全文', (tester) async {
    await tester.pumpWidget(wrap(TypewriterText(
      text: '天還沒全亮',
      style: const TextStyle(),
      msPerCharacter: 200,
      completed: true,
      onCompleted: () {},
    )));
    await tester.pump();
    expect(find.text('天還沒全亮'), findsOneWidget);
  });

  testWidgets('顯示完會呼叫 onCompleted 一次', (tester) async {
    var calls = 0;
    await tester.pumpWidget(wrap(TypewriterText(
      text: '天亮',
      style: const TextStyle(),
      msPerCharacter: 10,
      completed: false,
      onCompleted: () => calls++,
    )));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls, 1);
  });
}
```

追加到 `play_page_test.dart`：

```dart
    testWidgets('逐字顯示中點擊先補完，再點才推進', (tester) async {
      await pumpPlayPage(tester, 'pompeii_01_harbour_stranger');
      await tester.pump(const Duration(milliseconds: 10));
      // 第一次點：補完當前這段
      await tester.tap(find.byKey(PlayPage.advanceAreaKey));
      await tester.pump();
      expect(find.text('天還沒全亮，海面是鉛的顏色。'), findsOneWidget);
      // 第二次點：推進到下一段
      await tester.tap(find.byKey(PlayPage.advanceAreaKey));
      await tester.pumpAndSettle();
      expect(find.text('天還沒全亮，海面是鉛的顏色。'), findsNothing);
    });
```

> `pumpPlayPage` 原本結尾是 `pumpAndSettle()`，逐字動畫會讓它一直不 settle。把它改成 `await tester.pump(); await tester.pump(const Duration(seconds: 5));`，並在既有的其他 test 裡沿用。

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd vn && fvm flutter test test/src/visual_novel/presentation/play/typewriter_text_test.dart`
Expected: FAIL — 找不到 `typewriter_text.dart`

- [ ] **Step 3: 實作 typewriter_text.dart**

```dart
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
```

- [ ] **Step 4: 讓 DialogueBox 用 TypewriterText**

把 `dialogue_box.dart` 的 `Text(text, style: …)` 換成：

```dart
            child: TypewriterText(
              text: text,
              completed: completed,
              onCompleted: onCompleted,
              msPerCharacter: msPerCharacter,
              style: TextStyle(
                color: graffiti ? const Color(0xFFB9A98C) : const Color(0xFFF2ECE1),
                fontSize: layout.bodyFontSize * fontScale,
                height: 1.7,
                fontStyle: graffiti ? FontStyle.italic : FontStyle.normal,
              ),
            ),
```

並在建構子加上 `required this.completed`、`required this.onCompleted`、`required this.msPerCharacter` 三個欄位。

- [ ] **Step 5: PlayPage 接上「先補完再推進」**

`_Stage` 改成 `ConsumerStatefulWidget`，持有 `bool _typingDone`：

```dart
  bool _typingDone = false;

  // 節點換了就重置。用 readKey 當識別，同一段文字在不同節點也算換了一段。
  String? _lastKey;

  void _handleTap(PlayController controller, PlayState state) {
    if (state.status != PlayStatus.playing) return;
    if (!_typingDone) {
      setState(() => _typingDone = true);
      return;
    }
    controller.advance();
  }
```

在 `build` 開頭：

```dart
    if (_lastKey != state.readKey) {
      _lastKey = state.readKey;
      _typingDone = false;
    }
```

`DialogueBox` 傳入 `completed: _typingDone`、`onCompleted: () { if (!_typingDone) setState(() => _typingDone = true); }`、`msPerCharacter: ref.watch(saveStoreProvider).textSpeed()`。

`GestureDetector` 的 `onTap` 改成 `() => _handleTap(controller, state)`。

- [ ] **Step 6: 實作 preloader.dart 並接上**

```dart
import 'package:flutter/material.dart';
import 'package:lorescape_vn/src/visual_novel/providers.dart';

/// Web 上單張 PNG 有 2.2–2.6 MB，AssetImage 是進到那個節點才走 HTTP 抓，
/// 不預載就會看到背景先白一下。把「這一場的背景 ＋ 台上角色的所有表情」
/// 先塞進 image cache。
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
```

在 `_Stage` 的 `build` 末尾（或 `didChangeDependencies`）以 `WidgetsBinding.instance.addPostFrameCallback` 呼叫，失敗不影響畫面。

- [ ] **Step 7: 跑測試與 analyze**

Run: `cd vn && fvm flutter test && fvm flutter analyze --fatal-infos`
Expected: 全 PASS

- [ ] **Step 8: Commit**

```bash
git add vn/lib/src/visual_novel/presentation/play/ vn/test/
git commit -m "feat(vn): 逐字顯示與點擊補完，加上下一場背景的預載"
```

---

### Task 12: 回顧 backlog 與已讀跳過

**Files:**
- Create: `vn/lib/src/visual_novel/presentation/play/backlog_sheet.dart`
- Modify: `play_controller.dart`（加 `backlog` 與 `skipRead()`）、`play_page.dart`（工具列按鈕）
- Test: 追加 `vn/test/src/visual_novel/presentation/play/play_page_test.dart`

**Interfaces:**
- Consumes: Task 10 的 `PlayController`、Task 9 的 `SaveStore.readNodes()`
- Produces:

```dart
final class BacklogEntry { const BacklogEntry({required this.speakerName, required this.text});
                           final String? speakerName; final String text; }
// PlayController 新增：
List<BacklogEntry> get backlog;      // 本次遊玩累積，最多保留 200 筆
void skipRead();                     // 連續推進，直到碰到未讀節點或選項或結局
```

**已讀判定**：`SaveStore.readNodes()` 內有 `state.readKey` 即為已讀。`skipRead()` **不得跳過未讀節點**。

- [ ] **Step 1: 寫失敗的測試**

追加到 `play_page_test.dart`：

```dart
  group('backlog 與已讀跳過', () {
    testWidgets('回顧列出已讀文字與說話者', (tester) async {
      await pumpPlayPage(tester, 'pompeii_01_harbour_stranger');
      for (var i = 0; i < 10; i++) {
        await tester.tap(find.byKey(PlayPage.advanceAreaKey));
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.tap(find.byKey(PlayPage.backlogButtonKey));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('天還沒全亮，海面是鉛的顏色。'), findsOneWidget);
      expect(find.text('尼基亞斯'), findsWidgets);
    });

    testWidgets('已讀跳過碰到未讀節點就停', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        // 只把前三個節點標成已讀
        'vn.readNodes': <String>['S01#0', 'S01#1', 'S01#2'],
      });
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const MaterialApp(home: PlayPage(storyId: 'pompeii_01_harbour_stranger')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));

      await tester.tap(find.byKey(PlayPage.skipButtonKey));
      await tester.pump(const Duration(seconds: 1));
      // 第 4 段（索引 3）未讀，應停在這裡
      expect(find.text('我要裝滿它。裝魚醬。'), findsOneWidget);
    });
  });
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd vn && fvm flutter test test/src/visual_novel/presentation/play/play_page_test.dart`
Expected: FAIL — 找不到 `PlayPage.backlogButtonKey`

- [ ] **Step 3: PlayController 加 backlog 與 skipRead**

```dart
  final List<BacklogEntry> _backlog = <BacklogEntry>[];

  List<BacklogEntry> get backlog => List<BacklogEntry>.unmodifiable(_backlog);

  void _record(PlayState value) {
    final node = player.currentNode(_story, value);
    final entry = switch (node) {
      NarrationNode(:final text) => BacklogEntry(speakerName: null, text: text),
      DialogueNode(:final who, :final text) =>
        BacklogEntry(speakerName: _story.characters[who]?.name ?? who, text: text),
      _ => null,
    };
    if (entry == null) return;
    _backlog.add(entry);
    // 一篇約 300 個節點，留 200 筆足夠往回捲，也不會讓記憶體無限長。
    if (_backlog.length > 200) _backlog.removeAt(0);
  }

  /// 只跳已讀節點。未讀、選項、結局都要停——這是規範 §5.3 的硬要求。
  void skipRead() {
    final read = ref.read(saveStoreProvider).readNodes();
    var guard = 2000;
    var next = state;
    while (guard-- > 0) {
      if (next.status != PlayStatus.playing) break;
      if (!read.contains(next.readKey)) break;
      final candidate = player.advance(_story, next);
      if (candidate.status != PlayStatus.playing || !read.contains(candidate.readKey)) {
        next = candidate;
        break;
      }
      next = candidate;
    }
    _apply(next);
  }
```

在 `_apply()` 與 `build()` 建立初始狀態時各呼叫一次 `_record()`。

- [ ] **Step 4: 實作 backlog_sheet.dart**

```dart
import 'package:flutter/material.dart';
import 'package:lorescape_vn/src/visual_novel/providers.dart';

class BacklogSheet extends StatelessWidget {
  const BacklogSheet({required this.entries, super.key});

  final List<BacklogEntry> entries;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView.separated(
        reverse: true,
        padding: const EdgeInsets.all(24),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final entry = entries[entries.length - 1 - index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (entry.speakerName != null)
                Text(entry.speakerName!, style: Theme.of(context).textTheme.labelMedium),
              Text(entry.text, style: Theme.of(context).textTheme.bodyLarge),
            ],
          );
        },
      ),
    );
  }
}
```

`BacklogEntry` 放進 `play_controller.dart` 並在 `providers.dart` export。

- [ ] **Step 5: PlayPage 加兩顆按鈕**

在 `_Stage` 的 `Stack` 最上層加一列（`Positioned(top: layout.safeInset, right: layout.sideInset, …)`）：

```dart
          Positioned(
            top: layout.safeInset,
            right: layout.sideInset,
            child: Row(
              children: <Widget>[
                IconButton(
                  key: PlayPage.backlogButtonKey,
                  icon: const Icon(Icons.history),
                  color: const Color(0xFFE8DCC8),
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    backgroundColor: const Color(0xF21C1A19),
                    builder: (_) => BacklogSheet(entries: controller.backlog),
                  ),
                ),
                IconButton(
                  key: PlayPage.skipButtonKey,
                  icon: const Icon(Icons.fast_forward),
                  color: const Color(0xFFE8DCC8),
                  onPressed: controller.skipRead,
                ),
              ],
            ),
          ),
```

並在 `PlayPage` 宣告：

```dart
  static const ValueKey<String> backlogButtonKey = ValueKey<String>('play-backlog');
  static const ValueKey<String> skipButtonKey = ValueKey<String>('play-skip');
```

- [ ] **Step 6: 跑測試與 analyze**

Run: `cd vn && fvm flutter test && fvm flutter analyze --fatal-infos`
Expected: 全 PASS

- [ ] **Step 7: Commit**

```bash
git add vn/lib/src/visual_novel/presentation/play/ vn/test/
git commit -m "feat(vn): 回顧 backlog 與已讀跳過，未讀節點一律不跳"
```

---

### Task 13: 景點包首頁與 go_router 導覽

**Files:**
- Create: `vn/lib/src/visual_novel/presentation/pack/pack_page.dart`、`vn/lib/src/visual_novel/presentation/vn_router.dart`
- Modify: `vn/lib/main.dart`、`providers.dart`
- Test: `vn/test/src/visual_novel/presentation/pack/pack_page_test.dart`

**Interfaces:**
- Consumes: `packProvider`、`saveStoreProvider`
- Produces: `GoRouter buildVnRouter()`，路由 `/`、`/play/:storyId`、`/endings`、`/settings`

- [ ] **Step 1: 寫失敗的測試**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/pack/pack_page.dart';
import 'package:lorescape_vn/src/visual_novel/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpPackPage(WidgetTester tester, {Map<String, Object>? prefsValues}) async {
  SharedPreferences.setMockInitialValues(prefsValues ?? <String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MaterialApp(home: PackPage()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('列出 8 篇，依 order 排序並顯示副標與分鐘數', (tester) async {
    await pumpPackPage(tester);
    expect(find.byKey(PackPage.storyCardKey('pompeii_01_harbour_stranger')), findsOneWidget);
    expect(find.text('港口的外地人'), findsOneWidget);
    expect(find.text('爆發前一日'), findsOneWidget);
    expect(find.textContaining('12 分鐘'), findsWidgets);
    expect(find.text('普特奧利的新房子'), findsOneWidget);
  });

  testWidgets('顯示每篇的結局進度', (tester) async {
    await pumpPackPage(tester, prefsValues: <String, Object>{
      'vn.endingsSeen': <String>[
        'pompeii_01_harbour_stranger#A',
        'pompeii_01_harbour_stranger#B',
      ],
    });
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text('0 / 3'), findsNWidgets(7));
  });
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd vn && fvm flutter test test/src/visual_novel/presentation/pack/`
Expected: FAIL — 找不到 `pack_page.dart`

- [ ] **Step 3: 實作 pack_page.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lorescape_vn/src/visual_novel/providers.dart';

class PackPage extends ConsumerWidget {
  const PackPage({super.key});

  static ValueKey<String> storyCardKey(String storyId) => ValueKey<String>('story-card-$storyId');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packAsync = ref.watch(packProvider);
    final seen = ref.watch(saveStoreProvider).endingsSeen();

    return Scaffold(
      backgroundColor: const Color(0xFF0E0D0C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.auto_stories_outlined),
            onPressed: () => context.go('/endings'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: packAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('讀不到景點包：$error')),
        data: (pack) => ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
          children: <Widget>[
            Text(pack.title, style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 8),
            Text(pack.blurb, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            for (final entry in pack.stories)
              Card(
                key: storyCardKey(entry.id),
                color: const Color(0xFF1C1A19),
                child: ListTile(
                  onTap: () => context.go('/play/${entry.id}'),
                  title: Text(entry.title),
                  // 副標與分鐘數拆成兩個 Text：它們是兩件事，排版與測試都比較好處理。
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(entry.subtitle),
                      Text('${entry.estimatedMinutes} 分鐘',
                          style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                  trailing: Text(
                    '${seen.where((e) => e.startsWith('${entry.id}#')).length} / 3',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 實作 vn_router.dart 並接進 main**

```dart
import 'package:go_router/go_router.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/endings/endings_page.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/pack/pack_page.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/play/play_page.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/settings/settings_page.dart';

GoRouter buildVnRouter() => GoRouter(
      routes: <RouteBase>[
        GoRoute(path: '/', builder: (_, _) => const PackPage()),
        GoRoute(
          path: '/play/:storyId',
          builder: (_, state) => PlayPage(storyId: state.pathParameters['storyId']!),
        ),
        GoRoute(path: '/endings', builder: (_, _) => const EndingsPage()),
        GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
      ],
    );
```

`main.dart` 的 `MaterialApp` 換成 `MaterialApp.router(routerConfig: buildVnRouter(), …)`。`EndingsPage` / `SettingsPage` 在 Task 14 實作，本 task 先各建一個只有標題的 `Scaffold` 佔位，讓 router 編得過。

> **佔位規則**：這兩個檔在 Task 14 會被完整實作，本 task 只寫 `Scaffold(appBar: AppBar(title: const Text('結局收藏')), body: const SizedBox.shrink())`。這不是 TODO——它是能編譯、能導覽的最小實作。

- [ ] **Step 5: 直式鎖定**

`main.dart` 的 `MaterialApp.router` 加 `builder`，在寬螢幕上以 9:16 置中，兩側留黑，模擬手機：

```dart
      builder: (context, child) => ColoredBox(
        color: const Color(0xFF000000),
        child: Center(
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: ClipRect(child: child),
          ),
        ),
      ),
```

- [ ] **Step 6: 跑測試與 analyze，並用瀏覽器走一遍**

```bash
cd vn && fvm flutter test && fvm flutter analyze --fatal-infos
fvm flutter run -d chrome
```

從首頁點進第 1 篇、玩到一個結局、回首頁看進度變成 `1 / 3`。**把截圖給 user 看。**

- [ ] **Step 7: Commit**

```bash
git add vn/lib/ vn/test/
git commit -m "feat(vn): 景點包首頁與 go_router 導覽，web 上鎖 9:16 直式"
```

---

### Task 14: 結局收藏與設定

**Files:**
- Create（取代 Task 13 的佔位）: `vn/lib/src/visual_novel/presentation/endings/endings_page.dart`、`vn/lib/src/visual_novel/presentation/settings/settings_page.dart`
- Test: `vn/test/src/visual_novel/presentation/endings/endings_page_test.dart`、`vn/test/src/visual_novel/presentation/settings/settings_page_test.dart`

**Interfaces:**
- Consumes: `packProvider`、`storyProvider`、`saveStoreProvider`
- Produces: 無新公開 API

**規範 §5.6 的硬要求**：未達成的結局**只顯示鎖頭，不劇透標題**。

- [ ] **Step 1: 寫失敗的測試**

`endings_page_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/endings/endings_page.dart';
import 'package:lorescape_vn/src/visual_novel/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pump(WidgetTester tester, Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MaterialApp(home: EndingsPage()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  testWidgets('未達成的結局只顯示鎖頭，不顯示標題', (tester) async {
    await pump(tester, <String, Object>{});
    expect(find.text('天上那棵樹'), findsNothing, reason: '結局 A 的標題不得劇透');
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(24));
  });

  testWidgets('達成過的結局顯示標題', (tester) async {
    await pump(tester, <String, Object>{
      'vn.endingsSeen': <String>['pompeii_01_harbour_stranger#A'],
    });
    expect(find.text('天上那棵樹'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(23));
  });
}
```

`settings_page_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/settings/settings_page.dart';
import 'package:lorescape_vn/src/visual_novel/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('調整文字速度會寫進 SaveStore', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    late SaveStore store;
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[sharedPreferencesProvider.overrideWithValue(prefs)],
        child: Consumer(
          builder: (context, ref, _) {
            store = ref.watch(saveStoreProvider);
            return const MaterialApp(home: SettingsPage());
          },
        ),
      ),
    );
    await tester.pump();

    expect(store.textSpeed(), 28);
    await tester.drag(find.byKey(SettingsPage.textSpeedSliderKey), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(store.textSpeed(), lessThan(28));
  });
}
```

- [ ] **Step 2: 跑測試確認失敗**

Run: `cd vn && fvm flutter test test/src/visual_novel/presentation/endings/ test/src/visual_novel/presentation/settings/`
Expected: FAIL — 佔位頁沒有這些內容

- [ ] **Step 3: 實作 endings_page.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lorescape_vn/src/visual_novel/providers.dart';

class EndingsPage extends ConsumerWidget {
  const EndingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packAsync = ref.watch(packProvider);
    final seen = ref.watch(saveStoreProvider).endingsSeen();

    return Scaffold(
      backgroundColor: const Color(0xFF0E0D0C),
      appBar: AppBar(title: const Text('結局收藏'), backgroundColor: Colors.transparent),
      body: packAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('讀不到景點包：$error')),
        data: (pack) => ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
          children: <Widget>[
            for (final entry in pack.stories)
              _StoryEndings(entry: entry, seen: seen),
          ],
        ),
      ),
    );
  }
}

class _StoryEndings extends ConsumerWidget {
  const _StoryEndings({required this.entry, required this.seen});

  final PackEntry entry;
  final Set<String> seen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storyAsync = ref.watch(storyProvider(entry.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 16),
        Text(entry.title, style: Theme.of(context).textTheme.titleMedium),
        storyAsync.maybeWhen(
          orElse: () => const SizedBox(height: 8),
          data: (story) => Column(
            children: <Widget>[
              for (final ending in story.endings.entries)
                ListTile(
                  dense: true,
                  leading: seen.contains('${entry.id}#${ending.key}')
                      ? const Icon(Icons.check_circle_outline)
                      : const Icon(Icons.lock_outline),
                  // 未達成只顯示鎖頭與代號，標題本身就是劇透（規範 §5.6）。
                  title: Text(
                    seen.contains('${entry.id}#${ending.key}')
                        ? ending.value.title
                        : '結局 ${ending.key}',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: 實作 settings_page.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lorescape_vn/src/visual_novel/providers.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  static const ValueKey<String> textSpeedSliderKey = ValueKey<String>('settings-text-speed');
  static const ValueKey<String> fontScaleSliderKey = ValueKey<String>('settings-font-scale');

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  double? _textSpeed;
  double? _fontScale;

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(saveStoreProvider);
    final textSpeed = _textSpeed ??= store.textSpeed();
    final fontScale = _fontScale ??= store.fontScale();

    return Scaffold(
      backgroundColor: const Color(0xFF0E0D0C),
      appBar: AppBar(title: const Text('設定'), backgroundColor: Colors.transparent),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          // 數字是「每個字幾毫秒」，所以往左拉（值變小）＝ 變快。
          Text('文字速度（${textSpeed.round()} ms／字）'),
          Slider(
            key: SettingsPage.textSpeedSliderKey,
            value: textSpeed,
            min: 4,
            max: 60,
            onChanged: (value) => setState(() => _textSpeed = value),
            onChangeEnd: store.setTextSpeed,
          ),
          const SizedBox(height: 24),
          Text('字級（${fontScale.toStringAsFixed(2)}×）'),
          Slider(
            key: SettingsPage.fontScaleSliderKey,
            value: fontScale,
            min: 0.8,
            max: 1.4,
            onChanged: (value) => setState(() => _fontScale = value),
            onChangeEnd: store.setFontScale,
          ),
        ],
      ),
    );
  }
}
```

> `onChangeEnd` 才寫入，拖曳過程不會每一格都打一次 `SharedPreferences`。上面的 settings test 用 `drag` 會觸發 `onChangeEnd`，測得到。

- [ ] **Step 5: 跑測試與 analyze**

Run: `cd vn && fvm flutter test && fvm flutter analyze --fatal-infos`
Expected: 全 PASS

- [ ] **Step 6: Commit**

```bash
git add vn/lib/src/visual_novel/presentation/ vn/test/
git commit -m "feat(vn): 結局收藏與設定，未達成結局只顯示鎖頭"
```

---

### Task 15: 移除 `story/` 並更新 `CLAUDE.md`

**Files:**
- Delete: `story/`（整個目錄）
- Modify: `CLAUDE.md`
- Create: `vn/README.md`

**Interfaces:**
- Consumes: 無
- Produces: 無

- [ ] **Step 1: 確認沒有其他地方引用 story/**

```bash
cd /Users/paulwu/Documents/PLRepo/lorescape
grep -rn --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=story \
  -e 'story/' -e 'pompeii-bakery' -e 'tower-of-london-anne' \
  . | grep -v '^./docs/superpowers/' | grep -v '^./writer/'
```

Expected: 只剩 `CLAUDE.md` 的結構表那一列。若 `.github/workflows/` 有跑 `story/` 的 CI job，一併移除。

- [ ] **Step 2: 刪除**

```bash
git rm -r --quiet story/
```

- [ ] **Step 3: 更新 CLAUDE.md**

把 repo 結構表的 `story/` 那一列：

```
| `story/` | 獨立 Vite + React SPA：沉浸式互動劇本引擎（`/play/:slug`），資料以 `public/content/<slug>/` 純檔案為準；內建本機視覺化工作台（`npm run dev` → `/editor`，僅 DEV，見 `story/README.md`） |
```

換成：

```
| `vn/` | 獨立 Flutter 專案：直式視覺小說引擎，播放 `writer/創作/龐貝/` 的龐貝景點包 8 篇。先跑 Flutter Web 驗證，之後整包搬進 `frontend/lib/features/visual_novel/`。素材由 `tool/import_pack.py` 從 writer vault 匯入（不進版控），見 `vn/README.md` |
| `writer/` | Obsidian vault（**不進版控**）：劇本、美術與製作規範。`製作規範/story_tool.py` 驗 `story.json`，`創作/<景點>/` 放各景點包的內容與素材 |
```

- [ ] **Step 4: 寫 vn/README.md**

```markdown
# vn — 龐貝景點包視覺小說

直式手機視覺小說引擎，播放 `writer/創作/龐貝/` 的 8 篇群像短篇。
目前跑 **Flutter Web** 做驗證，確認後整包搬進 `frontend/lib/features/visual_novel/`。

## 先決條件

素材與劇本來自 **`writer/`（Obsidian vault，不在版控裡）**。首次 clone 後必須先匯入：

```bash
python3 vn/tool/import_pack.py
```

沒跑這一步的話，`assets/content/pompeii-79/assets/` 是空的，測試會失敗、畫面會全黑。

## 執行

```bash
cd vn
fvm flutter pub get
fvm flutter run -d chrome        # Web 驗證
fvm flutter test                 # 全部測試
fvm flutter analyze --fatal-infos
```

## 結構

`lib/src/visual_novel/` 是**可整包搬移**的模組：

- `domain/` — 零 Flutter 依賴的劇本模型與執行器
- `data/` — `story.json` parser、bundle repository、`SharedPreferences` 存檔
- `presentation/` — 直式版面（版面數值全在 `play/layout.dart`）
- `providers.dart` — **唯一**公開介面

## 規格來源

- 版面、`story.json` schema、必備功能：`writer/製作規範/Flutter製作規範.md`
- 設計決策：`docs/superpowers/specs/2026-08-13-pompeii-vn-flutter-design.md`
```

- [ ] **Step 5: 全部測試最後跑一次**

```bash
cd vn && fvm flutter test && fvm flutter analyze --fatal-infos
cd .. && python3 -m pytest vn/tool/test_import_pack.py -v
```

- [ ] **Step 6: Commit**

```bash
git add -A CLAUDE.md vn/README.md story/
git commit -m "chore: 移除 story/ React SPA，改由 vn/ 承接龐貝景點包"
```

---

## Self-Review 檢查結果

對照 spec 逐節確認：

| Spec 段落 | 對應 task |
|---|---|
| §1 專案結構 | Task 1、9 |
| §2 資料模型 | Task 3 |
| §3 執行器 | Task 5 |
| §4 播放版面 | Task 10 |
| §5 功能（逐字／backlog／已讀跳過／結局收藏／設定／存讀檔） | Task 9、11、12、14 |
| §6 匯入腳本（複製／去重／去背／對齊／pack.json／驗證／--webp） | Task 2、7、8 |
| §7 音訊與缺件降級 | Task 10（`missingAssets` 回 null）；`AudioPort` **見下方偏差** |
| §8 導覽 | Task 13 |
| §9 刪除 `story/` | Task 15 |
| 測試 1–20 | Task 3、4、5、6、9、10、11、12、14 |

**與 spec 的兩處偏差，已在計畫中就地決定：**

1. **不建 `AudioPort` 介面**（spec §7 說要留）。整包無聲、26 個 sfx 與 15 個 bgm 全缺，現在建一個沒有任何實作會用到的介面是憑空猜未來的形狀。引擎照常走過 `sfx`／`bgm` 節點、`PlayState.bgmId` 也照常維護——**接音訊時要動的只有 presentation 一層**，介面等真的有 `just_audio` 再長出來。
2. **存檔多存 `stage`**（規範 §6 沒有）。理由寫在 `save_data.dart` 的註解：靠重播還原台上立繪，會用存檔當下的變數重新求值那些 `if`，可能走進與當初不同的分支。

**Task 6 的預期風險**：「每個選項至少被走過一次」與「if 分支都走得到」兩條有可能在真實資料上失敗。Task 6 Step 3 已寫明處置——**不放寬測試**，把走不到的 key 回報給 user 判斷。
