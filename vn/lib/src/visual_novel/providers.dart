/// 這個 feature 的**唯一**公開介面。`presentation/` 只准 import 這個檔；
/// 日後這一包整包搬進另一個 Flutter 專案的 `features/visual_novel/` 後，
/// 跨 feature 引用也只看這裡。
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

final Provider<SaveStore> saveStoreProvider = Provider<SaveStore>(
  (ref) => SharedPreferencesSaveStore(ref.watch(sharedPreferencesProvider)),
);

final FutureProvider<Pack> packProvider =
    FutureProvider<Pack>((ref) => ref.watch(packRepositoryProvider).loadPack());

final FutureProviderFamily<Story, String> storyProvider = FutureProvider.family<Story, String>(
  (ref, storyId) => ref.watch(packRepositoryProvider).loadStory(storyId),
);
