import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:lorescape_story/src/visual_novel/data/story_json_parser.dart';
import 'package:lorescape_story/src/visual_novel/domain/story.dart';

/// 所有景點包所在的根目錄。底下每個子資料夾是一個包，
/// `packs.json` 是它們的清單（由 `import_pack.py` 掃描磁碟產生）。
const String contentRoot = 'assets/content';

/// pack.json 裡一篇故事的目錄項目。
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

/// 一個景點包。
final class Pack {
  const Pack({
    required this.id,
    required this.dir,
    required this.title,
    required this.place,
    required this.blurb,
    required this.stories,
    this.assetFormat = 'png',
  });
  final String id;

  /// 資產路徑用的資料夾名（`pompeii-79`）。與 `id`（`pompeii_79`）刻意分開：
  /// 資料夾名要能當 URL 片段，id 要跟劇本 `meta.pack` 一致。
  final String dir;
  final String title;
  final String place;
  final String blurb;
  final List<PackEntry> stories;

  /// 素材的實際格式（`png` 或 `webp`），由 `import_pack.py` 寫進 pack.json。
  ///
  /// `story.json` 裡的檔名一律是 `.png`——劇本是逐字複製的、不能改。副檔名
  /// 的轉換由**引擎組路徑時**處理，這正是 Flutter製作規範 §1 說的「資產參照
  /// 是不含路徑的檔名，引擎負責組出路徑」。
  final String assetFormat;
}

abstract interface class PackRepository {
  /// 書架：所有已匯入的包，依 `packs.json` 的順序。
  Future<List<Pack>> loadLibrary();

  Future<Pack> loadPack(String packId);

  /// storyId 全域唯一（劇本 id 內嵌了包名），所以不需要另外給 packId。
  Future<Story> loadStory(String storyId);

  /// 缺件（未知 key）一律回 null，不得丟例外。
  String? backgroundPath(Story story, String key);
  String? spritePath(Story story, String who, String sprite);
  String? cgPath(Story story, String cgId);
}

/// 從 asset bundle 讀書架、景點包與劇本，記憶體內快取。
final class BundlePackRepository implements PackRepository {
  BundlePackRepository(this._bundle);

  final AssetBundle _bundle;
  List<Pack>? _library;
  final Map<String, Story> _stories = <String, Story>{};

  /// storyId → 它所屬的包。`loadLibrary()` 建立，`loadStory()` 與資產路徑都靠它。
  final Map<String, Pack> _packOfStory = <String, Pack>{};

  /// meta.pack → 包。資產路徑要用它把 `story.meta.pack` 換成資料夾名。
  final Map<String, Pack> _packById = <String, Pack>{};

  @override
  Future<List<Pack>> loadLibrary() async {
    final cached = _library;
    if (cached != null) return cached;
    final manifest =
        jsonDecode(await _bundle.loadString('$contentRoot/packs.json'))
            as Map<String, dynamic>;
    final packs = <Pack>[];
    for (final row in (manifest['packs'] as List<dynamic>)) {
      packs.add(await _readPack((row as Map<String, dynamic>)['dir'] as String));
    }
    for (final pack in packs) {
      _packById[pack.id] = pack;
      for (final entry in pack.stories) {
        _packOfStory[entry.id] = pack;
      }
    }
    return _library = packs;
  }

  @override
  Future<Pack> loadPack(String packId) async {
    final packs = await loadLibrary();
    return packs.firstWhere(
      (p) => p.id == packId,
      orElse: () => throw StateError('packs.json 沒有這個包：$packId'),
    );
  }

  Future<Pack> _readPack(String dir) async {
    final json =
        jsonDecode(await _bundle.loadString('$contentRoot/$dir/pack.json'))
            as Map<String, dynamic>;
    final entries =
        (json['stories'] as List<dynamic>)
            .map((e) => e as Map<String, dynamic>)
            .map(
              (e) => PackEntry(
                id: e['id'] as String,
                order: e['order'] as int,
                dir: e['dir'] as String,
                title: e['title'] as String,
                subtitle: (e['subtitle'] as String?) ?? '',
                estimatedMinutes: e['estimatedMinutes'] as int,
              ),
            )
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
    return Pack(
      id: json['id'] as String,
      dir: dir,
      title: json['title'] as String,
      place: json['place'] as String,
      blurb: json['blurb'] as String,
      assetFormat: (json['assetFormat'] as String?) ?? 'png',
      stories: entries,
    );
  }

  @override
  Future<Story> loadStory(String storyId) async {
    final cached = _stories[storyId];
    if (cached != null) return cached;
    await loadLibrary();
    final pack = _packOfStory[storyId];
    if (pack == null) throw StateError('沒有任何包含這篇：$storyId');
    final entry = pack.stories.firstWhere((s) => s.id == storyId);
    final json =
        jsonDecode(
              await _bundle.loadString(
                '$contentRoot/${pack.dir}/stories/${entry.dir}/story.json',
              ),
            )
            as Map<String, dynamic>;
    return _stories[storyId] = parseStory(json);
  }

  /// 劇本自己說它屬於哪個包（`meta.pack`），路徑就從那裡長出來。
  ///
  /// 這是多包之後唯一需要小心的地方：資產路徑**不能**綁在 repository 上，
  /// 必須跟著劇本走——否則同一顆 repository 服務兩個包時會把凡爾賽的背景
  /// 指到龐貝的資料夾。
  Pack? _packOf(Story story) => _packById[story.meta.pack];

  /// 把 story.json 寫的 `.png` 換成該包實際的素材格式。
  String _withExtension(Pack pack, String filename) {
    if (pack.assetFormat == 'png' || !filename.endsWith('.png')) return filename;
    return '${filename.substring(0, filename.length - 4)}.${pack.assetFormat}';
  }

  /// 缺件一律回 null 而不是丟例外——`missingAssets` 的降級要求是「不得崩潰」。
  @override
  String? backgroundPath(Story story, String key) {
    final pack = _packOf(story);
    final filename = story.backgrounds[key];
    if (pack == null || filename == null) return null;
    return '$contentRoot/${pack.dir}/assets/backgrounds/'
        '${_withExtension(pack, filename)}';
  }

  @override
  String? spritePath(Story story, String who, String sprite) {
    final pack = _packOf(story);
    final filename = story.characters[who]?.sprites?[sprite];
    if (pack == null || filename == null) return null;
    return '$contentRoot/${pack.dir}/assets/sprites/'
        '${_withExtension(pack, filename)}';
  }

  @override
  String? cgPath(Story story, String cgId) {
    final pack = _packOf(story);
    if (pack == null) return null;
    if (story.missingAssets['cg']?.contains(cgId) ?? false) return null;
    return '$contentRoot/${pack.dir}/assets/backgrounds/'
        '${_withExtension(pack, '$cgId.png')}';
  }
}
