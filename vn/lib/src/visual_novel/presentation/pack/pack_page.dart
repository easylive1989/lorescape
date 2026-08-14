import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lorescape_vn/src/visual_novel/providers.dart';

/// 景點包首頁：列出這一包的所有故事，顯示標題、副標、預估分鐘數，
/// 以及每篇的結局收藏進度（n / 3）。
class PackPage extends ConsumerWidget {
  const PackPage({super.key});

  static ValueKey<String> storyCardKey(String storyId) => ValueKey<String>('story-card-$storyId');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Pack> packAsync = ref.watch(packProvider);
    final Set<String> seen = ref.watch(saveStoreProvider).endingsSeen();

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
            for (final PackEntry entry in pack.stories)
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
                      Text(
                        '${entry.estimatedMinutes} 分鐘',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
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
