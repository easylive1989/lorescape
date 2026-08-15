import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lorescape_story/src/visual_novel/presentation/play/layout.dart';
import 'package:lorescape_story/src/visual_novel/providers.dart';

/// 書架：列出所有景點包。
///
/// 為什麼首頁從「一個包的故事清單」變成「包的清單」：線上要同時放得下多組
/// 景點，而每個包是獨立的 SKU（產品規格書 §2.3）。包與包之間沒有順序，也不
/// 共用背景庫與角色——它們是並列的作品，不是章節。
class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  static ValueKey<String> packCardKey(String packId) =>
      ValueKey<String>('pack-card-$packId');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Pack>> libraryAsync = ref.watch(libraryProvider);
    final Set<String> seen = ref.watch(saveStoreProvider).endingsSeen();

    return Scaffold(
      backgroundColor: VnColors.backdrop,
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
      body: libraryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('讀不到書架：$error')),
        data: (packs) => ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
          children: <Widget>[
            Text('景點', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 24),
            for (final Pack pack in packs)
              Card(
                key: packCardKey(pack.id),
                color: VnColors.ground,
                child: ListTile(
                  onTap: () => context.go('/pack/${pack.id}'),
                  title: Text(pack.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(pack.blurb),
                      Text(
                        '${pack.stories.length} 篇',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                  // 整包的結局進度。每篇 3 個結局，所以分母是篇數 ×3。
                  trailing: Text(
                    '${_seenIn(pack, seen)} / ${pack.stories.length * 3}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  int _seenIn(Pack pack, Set<String> seen) {
    final ids = pack.stories.map((e) => e.id).toSet();
    return seen.where((e) => ids.contains(e.split('#').first)).length;
  }
}
