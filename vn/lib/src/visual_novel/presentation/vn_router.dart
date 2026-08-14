import 'package:go_router/go_router.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/endings/endings_page.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/pack/pack_page.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/play/play_page.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/settings/settings_page.dart';

/// App 的導覽表：景點包首頁 → 播放頁 → 結局收藏／設定。
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
