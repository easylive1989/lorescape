import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:lorescape_story/src/visual_novel/data/story_json_parser.dart';
import 'package:lorescape_story/src/visual_novel/domain/story.dart';

/// 景點包在 asset bundle 裡的根路徑。
const String packRoot = 'assets/content/pompeii-79';

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

/// 一個景點包（目前只有龐貝 79）。
final class Pack {
  const Pack({
    required this.id,
    required this.title,
    required this.place,
    required this.blurb,
    required this.stories,
    this.assetFormat = 'png',
  });
  final String id;
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
  Future<Pack> loadPack();
  Future<Story> loadStory(String storyId);

  /// 缺件（未知 key）一律回 null，不得丟例外。
  String? backgroundPath(Story story, String key);
  String? spritePath(Story story, String who, String sprite);
  String? cgPath(Story story, String cgId);
}

/// 從 asset bundle 讀景點包與劇本，記憶體內快取。
final class BundlePackRepository implements PackRepository {
  BundlePackRepository(this._bundle);

  final AssetBundle _bundle;
  Pack? _pack;
  final Map<String, Story> _stories = <String, Story>{};

  @override
  Future<Pack> loadPack() async {
    final cached = _pack;
    if (cached != null) return cached;
    final json =
        jsonDecode(await _bundle.loadString('$packRoot/pack.json'))
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
    return _pack = Pack(
      id: json['id'] as String,
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
    final pack = await loadPack();
    final entry = pack.stories.firstWhere(
      (s) => s.id == storyId,
      orElse: () => throw StateError('pack.json 沒有這篇：$storyId'),
    );
    final json =
        jsonDecode(
              await _bundle.loadString(
                '$packRoot/stories/${entry.dir}/story.json',
              ),
            )
            as Map<String, dynamic>;
    return _stories[storyId] = parseStory(json);
  }

  /// 把 story.json 寫的 `.png` 換成這個景點包實際的素材格式。
  ///
  /// `loadStory` 內部一定先 `loadPack`，所以走到這裡時 `_pack` 必然已載入；
  /// 真的沒有就退回 `.png`（與 `Pack.assetFormat` 的預設一致）。
  String _withExtension(String filename) {
    final format = _pack?.assetFormat ?? 'png';
    if (format == 'png' || !filename.endsWith('.png')) return filename;
    return '${filename.substring(0, filename.length - 4)}.$format';
  }

  /// 缺件一律回 null 而不是丟例外——`missingAssets` 的降級要求是「不得崩潰」。
  @override
  String? backgroundPath(Story story, String key) {
    final filename = story.backgrounds[key];
    if (filename == null) return null;
    return '$packRoot/assets/backgrounds/${_withExtension(filename)}';
  }

  @override
  String? spritePath(Story story, String who, String sprite) {
    final filename = story.characters[who]?.sprites?[sprite];
    if (filename == null) return null;
    return '$packRoot/assets/sprites/${_withExtension(filename)}';
  }

  @override
  String? cgPath(Story story, String cgId) {
    if (story.missingAssets['cg']?.contains(cgId) ?? false) return null;
    return '$packRoot/assets/backgrounds/${_withExtension('$cgId.png')}';
  }
}
