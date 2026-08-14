import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/play/background_layer.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/play/choice_overlay.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/play/dialogue_box.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/play/layout.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/play/sprite_layer.dart';
import 'package:lorescape_vn/src/visual_novel/providers.dart';

class PlayPage extends ConsumerWidget {
  const PlayPage({required this.storyId, super.key});

  static const ValueKey<String> advanceAreaKey = ValueKey<String>('play-advance-area');

  final String storyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storyAsync = ref.watch(storyProvider(storyId));
    return Scaffold(
      backgroundColor: VnColors.backdrop,
      body: storyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('讀不到這篇：$error')),
        data: (story) => _Stage(storyId: storyId, story: story),
      ),
    );
  }
}

class _Stage extends ConsumerWidget {
  const _Stage({required this.storyId, required this.story});

  final String storyId;
  final Story story;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playControllerProvider(storyId));
    final controller = ref.read(playControllerProvider(storyId).notifier);
    final repository = ref.watch(packRepositoryProvider);
    final fontScale = ref.watch(saveStoreProvider).fontScale();
    final layout = VnLayout.of(context);

    if (state.status == PlayStatus.ended) {
      return _EndingView(story: story, endingId: state.endingId);
    }

    final node = currentNode(story, state);
    final scene = story.scenes[state.cursor.sceneId]!;
    final cg = node is CgNode ? repository.cgPath(story, node.id) : null;
    final hideDialogue = node is CgNode && node.hideDialogue;

    return GestureDetector(
      key: PlayPage.advanceAreaKey,
      behavior: HitTestBehavior.opaque,
      onTap: state.status == PlayStatus.playing ? controller.advance : null,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          BackgroundLayer(
            assetPath: cg ?? repository.backgroundPath(story, scene.background),
          ),
          if (cg == null)
            SpriteLayer(
              stage: state.stage,
              layout: layout,
              pathOf: (sprite) => repository.spritePath(story, sprite.who, sprite.sprite),
            ),
          if (!hideDialogue && node is NarrationNode)
            DialogueBox(
              text: node.text,
              layout: layout,
              fontScale: fontScale,
              graffiti: node.style == 'graffiti',
            ),
          if (!hideDialogue && node is DialogueNode)
            DialogueBox(
              text: node.text,
              layout: layout,
              fontScale: fontScale,
              speakerName: story.characters[node.who]?.name ?? node.who,
            ),
          if (state.status == PlayStatus.choosing && node is ChoiceNode)
            ChoiceOverlay(
              options: visibleOptions(node, state.vars),
              layout: layout,
              onChoose: controller.choose,
            ),
        ],
      ),
    );
  }
}

class _EndingView extends StatelessWidget {
  const _EndingView({required this.story, required this.endingId});

  final Story story;
  final String? endingId;

  @override
  Widget build(BuildContext context) {
    final ending = endingId == null ? null : story.endings[endingId];
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text('你走到了', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(ending?.title ?? '結局', style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
    );
  }
}
