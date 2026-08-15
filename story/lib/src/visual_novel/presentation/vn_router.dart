import 'package:go_router/go_router.dart';
import 'package:lorescape_story/src/visual_novel/presentation/endings/endings_page.dart';
import 'package:lorescape_story/src/visual_novel/presentation/library/library_page.dart';
import 'package:lorescape_story/src/visual_novel/presentation/pack/pack_page.dart';
import 'package:lorescape_story/src/visual_novel/presentation/play/play_page.dart';
import 'package:lorescape_story/src/visual_novel/presentation/settings/settings_page.dart';

/// App 的導覽表：書架 → 景點包 → 播放頁 → 結局收藏／設定。
///
/// `/play/:storyId` 不帶 packId——劇本 id 全域唯一（內嵌了包名），
/// repository 自己查得到它屬於哪個包。少一層路徑參數，也少一個會對不上的東西。
GoRouter buildVnRouter() => GoRouter(
  routes: <RouteBase>[
    GoRoute(path: '/', builder: (_, _) => const LibraryPage()),
    GoRoute(
      path: '/pack/:packId',
      builder: (_, state) => PackPage(packId: state.pathParameters['packId']!),
    ),
    GoRoute(
      path: '/play/:storyId',
      builder: (_, state) =>
          PlayPage(storyId: state.pathParameters['storyId']!),
    ),
    GoRoute(path: '/endings', builder: (_, _) => const EndingsPage()),
    GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
  ],
);
