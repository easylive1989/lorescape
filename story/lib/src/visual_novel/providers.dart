/// 這個 feature 的**唯一**公開介面。`presentation/` 只准 import 這個檔；
/// 日後這一包整包搬進另一個 Flutter 專案的 `features/visual_novel/` 後，
/// 跨 feature 引用也只看這裡。
library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lorescape_story/src/visual_novel/data/pack_repository.dart';
import 'package:lorescape_story/src/visual_novel/data/save_store.dart';
import 'package:lorescape_story/src/visual_novel/domain/story.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:lorescape_story/src/visual_novel/data/pack_repository.dart'
    show Pack, PackEntry, PackRepository;
export 'package:lorescape_story/src/visual_novel/data/save_store.dart'
    show SaveStore;
export 'package:lorescape_story/src/visual_novel/domain/cursor.dart';
export 'package:lorescape_story/src/visual_novel/domain/play_state.dart';
export 'package:lorescape_story/src/visual_novel/domain/save_data.dart';
export 'package:lorescape_story/src/visual_novel/domain/story.dart';
export 'package:lorescape_story/src/visual_novel/domain/story_player.dart';
export 'package:lorescape_story/src/visual_novel/presentation/play/play_controller.dart'
    show BacklogEntry, PlayController, playControllerProvider;

/// main() 於啟動時以 overrideWithValue 覆寫。
final Provider<SharedPreferences> sharedPreferencesProvider =
    Provider<SharedPreferences>(
      (ref) => throw UnimplementedError('未於 main() 覆寫'),
    );

/// ⚠️ 這裡刻意不用共用的 `rootBundle` 單例，改成每次都給一顆新的
/// `PlatformAssetBundle()`——**不要「順手」改回 `rootBundle`**，那不是多此一舉。
///
/// `rootBundle` 內部會快取「載入中的 Future」，在 widget test 裡每個
/// testWidgets 都會建一個新的 ProviderScope（因此也是新的
/// BundlePackRepository），但 `rootBundle` 是全域共用——第二個以後的
/// testWidgets 重用同一個 rootBundle 時，那個快取的 Future 永遠不會 resolve，
/// pumpAndSettle 會因為 CircularProgressIndicator 的動畫一直排新影格而逾時卡死
/// （已實測重現：兩個 testWidgets 各呼叫一次 `rootBundle.loadString`，不牽扯
/// 任何專案程式碼，同檔案第二個起一律卡住；換一顆全新的 PlatformAssetBundle
/// 就正常）。App 正式執行時這個 provider 只會被建立一次，且
/// `BundlePackRepository` 自己有 `_pack`／`_stories` 快取，不會因為放棄
/// `rootBundle` 的快取而損失什麼。
final Provider<PackRepository> packRepositoryProvider =
    Provider<PackRepository>(
      (ref) => BundlePackRepository(PlatformAssetBundle()),
    );

final Provider<SaveStore> saveStoreProvider = Provider<SaveStore>(
  (ref) => SharedPreferencesSaveStore(ref.watch(sharedPreferencesProvider)),
);

final FutureProvider<Pack> packProvider = FutureProvider<Pack>(
  (ref) => ref.watch(packRepositoryProvider).loadPack(),
);

final FutureProviderFamily<Story, String> storyProvider =
    FutureProvider.family<Story, String>(
      (ref, storyId) => ref.watch(packRepositoryProvider).loadStory(storyId),
    );
