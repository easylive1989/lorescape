import 'dart:typed_data';

import 'package:context_app/app/config/lorescape_tokens.dart';
import 'package:context_app/features/analytics/domain/models/analytics_event.dart';
import 'package:context_app/features/analytics/providers.dart';
import 'package:context_app/features/explore/domain/models/place.dart';
import 'package:context_app/features/explore/providers.dart';
import 'package:context_app/features/narration/domain/models/story_hook.dart';
import 'package:context_app/features/narration/presentation/controllers/narration_generation_controller.dart';
import 'package:context_app/features/narration/presentation/controllers/story_hook_controller.dart';
import 'package:context_app/features/narration/presentation/widgets/editorial_hero.dart';
import 'package:context_app/features/narration/presentation/widgets/story_generating.dart';
import 'package:context_app/features/narration/providers.dart';
import 'package:context_app/features/settings/domain/models/language.dart';
import 'package:context_app/shared/widgets/adaptive/adaptive_widgets.dart';
import 'package:context_app/shared/widgets/journal/category_tag.dart';
import 'package:context_app/shared/widgets/midnight/_press_scale.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Fallback warm card shadow (design token `e1`).

/// 「挑一段歷史故事」選擇頁。
///
/// 開啟時自動呼叫 [StoryHookService] 為景點產生 2-3 個歷史故事鉤子，
/// 使用者挑一張卡片後再展開為完整 narration。
/// 若鉤子產生失敗或為空，顯示「直接聽故事」fallback 按鈕。
class SelectStoryHookScreen extends ConsumerStatefulWidget {
  final Place place;
  final Uint8List? capturedImageBytes;

  const SelectStoryHookScreen({
    super.key,
    required this.place,
    this.capturedImageBytes,
  });

  @override
  ConsumerState<SelectStoryHookScreen> createState() =>
      _SelectStoryHookScreenState();
}

class _SelectStoryHookScreenState extends ConsumerState<SelectStoryHookScreen> {
  String? _selectedStoryTitle;

  Language _currentLanguage() {
    final locale = EasyLocalization.of(context)?.locale.toLanguageTag();
    return Language(locale ?? 'zh-TW');
  }

  void _onHookSelected(StoryHook? hook) {
    _selectedStoryTitle = hook?.title;
    _emitHookSelected(hook);
    // The backend is the source of truth for generation errors; failures
    // surface via the generation-state listener below.
    ref
        .read(narrationGenerationControllerProvider.notifier)
        .generate(
          place: widget.place,
          language: _currentLanguage(),
          hook: hook,
        );
  }

  /// 記下使用者最後是「挑了第幾個角度」還是「直接聽故事」。
  ///
  /// hook 為 null 有兩種來路：後端沒給角度時的 fallback，以及使用者看完角度
  /// 仍選擇直接聽——兩者都送 `selected_default`，靠 [HooksReturned] 的 outcome
  /// 在報表上分開。
  void _emitHookSelected(StoryHook? hook) {
    final language = _currentLanguage();
    final hooks = ref
        .read(
          storyHookControllerProvider(
            StoryHookArgs(place: widget.place, language: language),
          ),
        )
        .hooks;
    final index = hook == null ? null : hooks.indexOf(hook);
    ref
        .read(analyticsEmitterProvider)
        .emit(
          HookSelected(
            placeId: widget.place.id,
            language: language.code,
            // indexOf 找不到時回 -1，寧可送 null 也不要送一個假的位置。
            hookIndex: index == null || index < 0 ? null : index,
            hookCount: hooks.length,
          ),
        );
  }

  void _navigateToPlayer(NarrationGenerationState genState) {
    ref.read(narrationGenerationControllerProvider.notifier).reset();
    context.pushNamed(
      'player',
      extra: {
        'place': widget.place,
        'narrationContent': genState.content,
        'storyTitle': _selectedStoryTitle,
        'autoPlay': true,
      },
    );
  }

  void _showErrorDialog(NarrationGenerationState genState) {
    ref.read(narrationGenerationControllerProvider.notifier).reset();
    if (genState.errorType == NarrationGenerationErrorType.quotaExceeded) {
      // 今日免費額度用盡（backend 回 402）。不顯示錯誤，直接把使用者
      // 帶到付費牆——那裡才有他要的答案。
      if (!context.mounted) return;
      context.push('/subscription');
      return;
    }
    final isInsufficient =
        genState.errorType == NarrationGenerationErrorType.insufficientSource;
    final title = isInsufficient
        ? 'config_screen.generation_insufficient_source_title'.tr()
        : 'config_screen.generation_error_title'.tr();
    final content = isInsufficient
        ? 'config_screen.generation_insufficient_source_message'.tr()
        : (genState.errorMessage ??
              'config_screen.generation_error_message'.tr());
    showAdaptiveAlertDialog<void>(
      context: context,
      title: title,
      content: content,
      actions: [
        AdaptiveDialogAction<void>(
          label: 'config_screen.generation_error_ok'.tr(),
          isDefault: true,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = _currentLanguage();
    final hookArgs = StoryHookArgs(place: widget.place, language: language);
    final hookState = ref.watch(storyHookControllerProvider(hookArgs));
    final generationState = ref.watch(narrationGenerationControllerProvider);

    ref.listen<NarrationGenerationState>(
      narrationGenerationControllerProvider,
      (previous, current) {
        if (previous?.isSuccess != true && current.isSuccess) {
          _navigateToPlayer(current);
        }
        if (previous?.hasError != true && current.hasError) {
          _showErrorDialog(current);
        }
      },
    );

    final tokens = Theme.of(context).extension<LorescapeTokens>();
    final isGenerating = generationState.isGenerating;
    final isHookLoading = hookState.status == StoryHookStatus.loading;

    // 生成中（挖掘故事線或寫完整故事）走設計稿的 `.genscr` 版面：210px
    // 標頭壓縮到上緣，其餘空間交給 StoryGenerating 的整頁動畫。其他狀態
    // 維持原本的 editorial 版面（大 hero ＋ 內容往下捲）。
    if (isGenerating || isHookLoading) {
      return Scaffold(
        backgroundColor: tokens?.paper ?? Theme.of(context).colorScheme.surface,
        body: Stack(
          children: [
            Positioned.fill(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeroSection(
                    place: widget.place,
                    capturedImageBytes: widget.capturedImageBytes,
                    compact: true,
                  ),
                  Expanded(
                    child: isGenerating
                        ? StoryGenerating(
                            key: const ValueKey('gen-write'),
                            title: 'story_generating.write_title'.tr(
                              args: [_selectedStoryTitle ?? widget.place.name],
                            ),
                            subtitle: 'story_generating.write_sub'.tr(),
                            steps: [
                              'story_generating.write_step_1'.tr(),
                              'story_generating.write_step_2'.tr(),
                              'story_generating.write_step_3'.tr(),
                            ],
                            icon: Icons.edit_outlined,
                          )
                        : StoryGenerating(
                            key: const ValueKey('gen-scan'),
                            title: 'story_generating.scan_title'.tr(
                              args: [widget.place.name],
                            ),
                            subtitle: 'story_generating.scan_sub'.tr(),
                            steps: [
                              'story_generating.scan_step_1'.tr(),
                              'story_generating.scan_step_2'.tr(),
                              'story_generating.scan_step_3'.tr(),
                            ],
                            icon: Icons.menu_book_outlined,
                          ),
                  ),
                ],
              ),
            ),
            // 挖掘中仍可退出；寫作中維持原本「不可中途離開」的行為（生成
            // 完成會直接導去播放器，中途離開會讓導頁落在錯的畫面上）。
            if (!isGenerating)
              Positioned(
                top: MediaQuery.of(context).padding.top + 6,
                left: 14,
                child: _OnPhotoBackButton(onPressed: () => context.pop()),
              ),
          ],
        ),
      );
    }

    // Editorial layout (design: `PlaceScreen` in screens_story.jsx): a
    // bounded hero on top, with the generation copy flowing below it on the
    // warm paper surface — not a full-bleed photo with overlaid content.
    return Scaffold(
      backgroundColor: tokens?.paper ?? Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeroSection(
                    place: widget.place,
                    capturedImageBytes: widget.capturedImageBytes,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(22),
                    child: _HookContent(
                      state: hookState,
                      onHookTap: _onHookSelected,
                      onListenDefault: () => _onHookSelected(null),
                      onExplore: () => context.pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 6,
            left: 14,
            child: _OnPhotoBackButton(onPressed: () => context.pop()),
          ),
        ],
      ),
    );
  }
}

/// Bounded editorial hero: a place photo (or a category-tinted gradient with
/// a glyph when no photo is available), darkened by a scrim, captioned with
/// the place name and category tag.
class _HeroSection extends StatelessWidget {
  final Place place;
  final Uint8List? capturedImageBytes;

  /// 生成中的壓縮標頭（設計稿 `.genscr__hd`）：固定 210 高、字級縮小、
  /// 不放分類標籤，把版面讓給底下的生成動畫。
  final bool compact;

  const _HeroSection({
    required this.place,
    this.capturedImageBytes,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final height = compact
        ? 210.0
        : (MediaQuery.of(context).size.height * 0.5).clamp(320.0, 440.0);
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          EditorialHeroBackground(
            place: place,
            capturedImageBytes: capturedImageBytes,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(gradient: kEditorialHeroScrim),
          ),
          Positioned(
            left: 22,
            right: 22,
            bottom: compact ? 18 : 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  place.name,
                  style: GoogleFonts.notoSerifTc(
                    fontSize: compact ? 27 : 32,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.12,
                    shadows: const [
                      Shadow(
                        color: Color(0x66000000),
                        blurRadius: 18,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 10),
                  CategoryTag(
                    category: place.category.journalCategory,
                    onPhoto: true,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular translucent back button for use over the hero (design token
/// `.iconbtn.on-photo`).
class _OnPhotoBackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _OnPhotoBackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Material(
        color: const Color(0x6B14100C),
        child: InkWell(
          onTap: onPressed,
          child: const SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

class _HookContent extends StatelessWidget {
  final StoryHookState state;
  final void Function(StoryHook hook) onHookTap;
  final VoidCallback onListenDefault;
  final VoidCallback onExplore;

  const _HookContent({
    required this.state,
    required this.onHookTap,
    required this.onListenDefault,
    required this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
    return switch (state.status) {
      // 載入中由外層的 StoryGenerating 整頁動畫接手，這裡不會被 render 到。
      StoryHookStatus.loading => const SizedBox.shrink(),
      StoryHookStatus.success => _HookListState(
        hooks: state.hooks,
        onTap: onHookTap,
      ),
      StoryHookStatus.insufficientSource => _HookInsufficientSourceState(
        onExplore: onExplore,
      ),
      StoryHookStatus.empty ||
      StoryHookStatus.error => _HookFallbackState(onListen: onListenDefault),
    };
  }
}

class _HookListState extends StatelessWidget {
  final List<StoryHook> hooks;
  final void Function(StoryHook hook) onTap;

  const _HookListState({required this.hooks, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'story_hook.title'.tr(),
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < hooks.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: StoryHookCard(
              hook: hooks[i],
              index: i + 1,
              onTap: () => onTap(hooks[i]),
            ),
          ),
      ],
    );
  }
}

/// Shown when the backend reports `insufficient_source: true` — the
/// place has no Wikipedia-backed historical content. We deliberately
/// do NOT offer a "listen anyway" button here: the follow-up
/// /narration call would just hit the same dead-end. The user should
/// pick a different place via the back button.
class _HookInsufficientSourceState extends StatelessWidget {
  final VoidCallback onExplore;

  const _HookInsufficientSourceState({required this.onExplore});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<LorescapeTokens>();
    final clay = tokens?.clay ?? cs.primary;
    final ink = tokens?.ink ?? cs.onSurface;
    final ink2 = tokens?.ink2 ?? cs.onSurfaceVariant;
    final line = tokens?.line ?? cs.outlineVariant;
    final paperRaised = tokens?.paperRaised ?? cs.surface;
    final radius = BorderRadius.circular(context.tokens.rLg);

    return Container(
      decoration: BoxDecoration(
        color: paperRaised,
        border: Border.fromBorderSide(BorderSide(color: line)),
        borderRadius: radius,
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book_outlined, color: clay, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'story_hook.insufficient_source_title'.tr(),
                  style: GoogleFonts.notoSerifTc(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'story_hook.insufficient_source_body'.tr(),
            style: TextStyle(fontSize: 15, height: 1.65, color: ink2),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: onExplore,
              style: OutlinedButton.styleFrom(
                backgroundColor: paperRaised,
                foregroundColor: ink,
                side: BorderSide(color: line),
                shape: RoundedRectangleBorder(borderRadius: radius),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text('story_hook.insufficient_source_explore_button'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}

class _HookFallbackState extends StatelessWidget {
  final VoidCallback onListen;
  const _HookFallbackState({required this.onListen});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'story_hook.fallback_title'.tr(),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'story_hook.fallback_body'.tr(),
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onListen,
            icon: const Icon(Icons.play_arrow, size: 20),
            label: Text('story_hook.listen_default_button'.tr()),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class StoryHookCard extends StatelessWidget {
  final StoryHook hook;
  final int index;
  final VoidCallback onTap;

  const StoryHookCard({
    super.key,
    required this.hook,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<LorescapeTokens>();
    final ink3 = tokens?.ink3 ?? cs.onSurfaceVariant;

    return PressScale(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(context.tokens.rLg),
          border: Border.fromBorderSide(BorderSide(color: cs.outlineVariant)),
          boxShadow: context.tokens.e1,
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(context.tokens.rLg),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 26,
                    child: Text(
                      index.toString().padLeft(2, '0'),
                      style: GoogleFonts.notoSerifTc(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hook.title,
                          style: GoogleFonts.notoSerifTc(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          hook.teaser,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: cs.onSurfaceVariant,
                                height: 1.55,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(Icons.chevron_right, color: ink3, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
