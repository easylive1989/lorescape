import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/play/background_layer.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/play/choice_overlay.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/play/dialogue_box.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/play/layout.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/play/preloader.dart';
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

class _Stage extends ConsumerStatefulWidget {
  const _Stage({required this.storyId, required this.story});

  final String storyId;
  final Story story;

  @override
  ConsumerState<_Stage> createState() => _StageState();
}

class _StageState extends ConsumerState<_Stage> {
  bool _typingDone = false;

  // 節點換了就重置。用 readKey 當識別，同一段文字在不同節點也算換了一段。
  String? _lastKey;

  void _handleTap(PlayController controller, PlayState state) {
    if (state.status != PlayStatus.playing) return;
    if (!_typingDone) {
      setState(() => _typingDone = true);
      return;
    }
    controller.advance();
  }

  void _markTypingDone() {
    if (!_typingDone) setState(() => _typingDone = true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playControllerProvider(widget.storyId));
    final controller = ref.read(playControllerProvider(widget.storyId).notifier);
    final repository = ref.watch(packRepositoryProvider);
    final fontScale = ref.watch(saveStoreProvider).fontScale();
    final msPerCharacter = ref.watch(saveStoreProvider).textSpeed();
    final layout = VnLayout.of(context);

    if (_lastKey != state.readKey) {
      _lastKey = state.readKey;
      _typingDone = false;
    }

    if (state.status == PlayStatus.ended) {
      return _EndingView(story: widget.story, endingId: state.endingId);
    }

    final node = currentNode(widget.story, state);
    final scene = widget.story.scenes[state.cursor.sceneId]!;
    // CG 是會停頓的節點型別之一，所以 node 是 CgNode 時就不可能同時是旁白或
    // 對白——對話框本來就不會出現，`CgNode.hideDialogue` 對現在的渲染沒有可
    // 觀察的效果。等哪天要做「CG 蓋住上一句台詞」才需要它，屆時要有『上一句』
    // 這個狀態，不是延伸現在的邏輯就能做到。
    final cg = node is CgNode ? repository.cgPath(widget.story, node.id) : null;

    // 這一場的背景 ＋ 下一場的背景 ＋ 台上角色的所有表情，先塞進 image cache。
    // 失敗（缺件）不影響畫面，precacheNode 內部吞掉例外。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      precacheNode(context, repository, widget.story, state);
    });

    return GestureDetector(
      key: PlayPage.advanceAreaKey,
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleTap(controller, state),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          BackgroundLayer(
            assetPath: cg ?? repository.backgroundPath(widget.story, scene.background),
          ),
          if (cg == null)
            SpriteLayer(
              stage: state.stage,
              layout: layout,
              pathOf: (sprite) =>
                  repository.spritePath(widget.story, sprite.who, sprite.sprite),
            ),
          if (node is NarrationNode)
            DialogueBox(
              text: node.text,
              layout: layout,
              fontScale: fontScale,
              graffiti: node.style == 'graffiti',
              completed: _typingDone,
              onCompleted: _markTypingDone,
              msPerCharacter: msPerCharacter,
            ),
          if (node is DialogueNode)
            DialogueBox(
              text: node.text,
              layout: layout,
              fontScale: fontScale,
              speakerName: widget.story.characters[node.who]?.name ?? node.who,
              completed: _typingDone,
              onCompleted: _markTypingDone,
              msPerCharacter: msPerCharacter,
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
