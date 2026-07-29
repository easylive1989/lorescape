import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:context_app/features/daily_story/domain/models/daily_story.dart';
import 'package:context_app/features/daily_story/providers.dart';
import 'package:context_app/features/home/domain/globe/world_outline.dart';

/// 首頁卡片列要顯示的故事：最新一篇在前，接著最多 30 篇歷史。
///
/// 用 DB 語言字串（例如 `'zh-TW'`）當 key，而不是 `currentLanguageProvider`
/// ——後者讀的是作業系統語言，沒有機制隨 EasyLocalization 的語言同步，會
/// 跟畫面實際顯示的語言兜不起來。呼叫端從 `context.locale` 算出這個字串
/// 傳進來，跟 `GlobeHomeScreen._dbLanguageFromLocale` 是同一套邏輯（另見
/// `daily_story/providers.dart` 對 `latestDailyStoryByLanguageProvider` 的
/// 說明——同一個理由）。
final homeStoriesProvider = FutureProvider.family<List<DailyStory>, String>((
  ref,
  language,
) async {
  final latest = await ref.watch(
    latestDailyStoryByLanguageProvider(language).future,
  );
  final history = await ref.watch(
    dailyStoryHistoryByLanguageProvider(language).future,
  );
  return [if (latest != null) latest, ...history];
});

/// 地球儀的世界輪廓。只解析一次，之後所有畫面共用。
final worldOutlineProvider = FutureProvider<WorldOutline>(
  (ref) => WorldOutline.load(rootBundle),
);
