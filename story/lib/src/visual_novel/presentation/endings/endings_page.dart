import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/play/layout.dart';
import 'package:lorescape_vn/src/visual_novel/providers.dart';

/// 結局收藏頁：列出每篇故事的三個結局。
///
/// 規範 §5.6 的硬要求：未達成的結局**只顯示鎖頭與代號，不得顯示標題**——標題
/// 本身就是劇透（例如第 1 篇的三個結局叫「天上那棵樹」「為了貨」「為了人」，
/// 看到名字等於知道結局在講什麼）。
class EndingsPage extends ConsumerWidget {
  const EndingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Pack> packAsync = ref.watch(packProvider);
    final Set<String> seen = ref.watch(saveStoreProvider).endingsSeen();

    return Scaffold(
      backgroundColor: VnColors.backdrop,
      appBar: AppBar(
        title: const Text('結局收藏'),
        backgroundColor: Colors.transparent,
      ),
      body: packAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('讀不到景點包：$error')),
        data: (pack) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
          // 固定 8 篇 × 3 結局，筆數不多也不會再長——用一般 Column 就好，不必
          // 上 ListView 的 lazy building（否則畫面外的結局不會被建出來，玩家
          // 得先滑到那一段才看得到自己解鎖了沒，體驗上也怪）。
          child: Column(
            children: <Widget>[
              for (final PackEntry entry in pack.stories)
                _StoryEndings(entry: entry, seen: seen),
            ],
          ),
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
    final AsyncValue<Story> storyAsync = ref.watch(storyProvider(entry.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 16),
        Text(
          entry.title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: VnColors.body),
        ),
        storyAsync.maybeWhen(
          orElse: () => const SizedBox(height: 8),
          data: (story) => Column(
            children: <Widget>[
              for (final MapEntry<String, EndingSpec> ending
                  in story.endings.entries)
                _EndingTile(
                  achieved: seen.contains('${entry.id}#${ending.key}'),
                  endingKey: ending.key,
                  title: ending.value.title,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EndingTile extends StatelessWidget {
  const _EndingTile({
    required this.achieved,
    required this.endingKey,
    required this.title,
  });

  final bool achieved;
  final String endingKey;
  final String title;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      // 未達成只顯示鎖頭與代號，標題本身就是劇透（規範 §5.6）。
      leading: Icon(
        achieved ? Icons.check_circle_outline : Icons.lock_outline,
        color: VnColors.ochre,
      ),
      title: Text(
        achieved ? title : '結局 $endingKey',
        style: TextStyle(color: achieved ? VnColors.body : VnColors.muted),
      ),
    );
  }
}
