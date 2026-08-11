import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:context_app/app/config/feature_flags.dart';
import 'package:context_app/app/config/lorescape_tokens.dart';
import 'package:context_app/features/daily_story/domain/models/daily_story.dart';
import 'package:context_app/features/daily_story/providers.dart';
import 'package:context_app/features/home/domain/models/globe_pin.dart';
import 'package:context_app/features/home/presentation/widgets/globe_view.dart';
import 'package:context_app/features/home/presentation/widgets/home_top_bar.dart';
import 'package:context_app/features/home/presentation/widgets/story_rail.dart';
import 'package:context_app/features/home/providers.dart';
import 'package:context_app/features/settings/domain/models/language.dart';

/// 首頁：一顆釘著每日故事地點的地球儀，底下是故事卡片列。
///
/// 進入 `/map` 時，這一頁由 `secondaryAnimation` 驅動地球儀放大淡出、卡片
/// 列下滑，跟地圖的淡入接在一起（設計稿的 zoom-into-map）。
class GlobeHomeScreen extends ConsumerStatefulWidget {
  const GlobeHomeScreen({super.key});

  /// 地球儀上最多釘幾篇故事。更舊的故事只有被選中時才會出現那顆大 pin。
  static const int pinnedStoryCount = 7;

  @override
  ConsumerState<GlobeHomeScreen> createState() => _GlobeHomeScreenState();
}

class _GlobeHomeScreenState extends ConsumerState<GlobeHomeScreen> {
  static const Duration _debounce = Duration(milliseconds: 300);

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  String _query = '';
  int _activeIndex = 0;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      if (!mounted) return;
      setState(() => _query = value.trim());
    });
    // clear 按鈕的顯示與否要立刻反應。
    setState(() {});
  }

  void _openMap({String? query}) {
    final suffix = (query == null || query.isEmpty)
        ? ''
        : '?q=${Uri.encodeQueryComponent(query)}';
    context.push('/map$suffix');
  }

  /// 重新抓故事卡片列。`homeStoriesProvider` 不是 autoDispose，只
  /// invalidate 它自己沒有用——它的 body 是 `ref.watch(...future)`
  /// 兩個底層 per-language provider，那兩個才是真正快取住錯誤的地方，
  /// 三個都要一起清掉才會真的重打 API。
  void _retryStories(String language) {
    ref.invalidate(latestDailyStoryByLanguageProvider(language));
    ref.invalidate(dailyStoryHistoryByLanguageProvider(language));
    ref.invalidate(homeStoriesProvider(language));
  }

  GlobePin? _pinFor(DailyStory story) {
    final lat = story.latitude;
    final lng = story.longitude;
    if (lat == null || lng == null) return null;
    return GlobePin(
      id: story.publishDate.toIso8601String(),
      coordinate: LatLng(lat, lng),
      label: story.placeName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final language = _dbLanguageFromLocale(context.locale);
    final storiesState = ref.watch(homeStoriesProvider(language));
    final stories = storiesState.valueOrNull ?? const [];
    final outline = ref.watch(worldOutlineProvider).valueOrNull;

    final pins = <GlobePin>[
      for (final story in stories.take(GlobeHomeScreen.pinnedStoryCount))
        if (_pinFor(story) case final pin?) pin,
    ];
    final active = _activeIndex < stories.length
        ? _pinFor(stories[_activeIndex])
        : null;

    final secondary =
        ModalRoute.of(context)?.secondaryAnimation ?? kAlwaysDismissedAnimation;
    // 用 drive(CurveTween) 而不是 CurvedAnimation：後者的建構子會在 parent
    // （這裡的 secondaryAnimation，跟著 `/` 這頁活整個 App 生命週期）上掛一個
    // status listener，只有 dispose() 會移除，但這段是 build() 裡的區域變數
    // 沒地方 dispose——每次 build（每敲一個字、每換一張卡）都會多掛一個。
    // drive() 不需要額外持有、也不用手動釋放。
    final zoom = secondary.drive(
      CurveTween(curve: const Cubic(0.55, 0, 0.85, 0.36)),
    );

    return Scaffold(
      backgroundColor: tokens.paper,
      body: AnimatedBuilder(
        animation: zoom,
        builder: (context, _) {
          final t = zoom.value;
          return Stack(
            children: [
              if (outline != null)
                Positioned.fill(
                  child: Center(
                    child: Opacity(
                      opacity: 1 - t,
                      child: Transform.scale(
                        scale: 1 + 3.8 * t,
                        child: GlobeView(
                          outline: outline,
                          pins: pins,
                          focus: active,
                          // 點非選中的釘點：把那篇故事切成選中，地球飛過
                          // 去、卡片列也捲到那張卡（StoryRail 會跟上）。
                          onPinTap: (pin) {
                            final index = stories.indexWhere(
                              (story) =>
                                  story.publishDate.toIso8601String() == pin.id,
                            );
                            if (index < 0 || index == _activeIndex) return;
                            setState(() => _activeIndex = index);
                          },
                          // 點選中地點的地名 chip：直接進那篇每日故事。
                          onFocusTap: _activeIndex < stories.length
                              ? () => context.push(
                                  '/daily-story/detail',
                                  extra: stories[_activeIndex],
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: MediaQuery.paddingOf(context).top,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: 1 - t,
                  child: HomeTopBar(
                    controller: _searchController,
                    query: _query,
                    onQueryChanged: _onQueryChanged,
                    onSuggestionTap: (value) {
                      _searchController.clear();
                      setState(() => _query = '');
                      _openMap(query: value);
                    },
                    onOpenJourney: kBookshelfEnabled
                        ? () => context.push('/journey')
                        : null,
                    onOpenSettings: () => context.push('/settings'),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: MediaQuery.paddingOf(context).bottom + 176,
                child: Opacity(
                  opacity: 1 - t,
                  child: _LocateButton(onPressed: () => _openMap()),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.paddingOf(context).bottom + 4,
                child: FractionalTranslation(
                  translation: Offset(0, 1.2 * t),
                  child: Opacity(
                    opacity: 1 - t,
                    child: StoryRail(
                      stories: stories,
                      isError: storiesState.hasError,
                      onRetry: () => _retryStories(language),
                      activeIndex: _activeIndex,
                      onActiveChanged: (index) =>
                          setState(() => _activeIndex = index),
                      onOpen: (story) =>
                          context.push('/daily-story/detail', extra: story),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LocateButton extends StatelessWidget {
  const _LocateButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      button: true,
      label: 'home.locate'.tr(),
      child: InkResponse(
        key: const Key('home-locate'),
        onTap: onPressed,
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tokens.clay,
            shape: BoxShape.circle,
            boxShadow: tokens.e2,
          ),
          child: Icon(Icons.my_location, size: 22, color: tokens.paperRaised),
        ),
      ),
    );
  }
}

/// 從 EasyLocalization 的 `context.locale` 換算 DB 的語言字串，避免用只會
/// 反映作業系統語言的 `currentLanguageProvider`（同一套邏輯的說明另見
/// `daily_story/providers.dart` 對 `latestDailyStoryByLanguageProvider` 的
/// 註解）。「locale → Language」與「Language → DB 字串」都各自只有一份共用
/// 實作（分別是 `languageFromLocaleTag` 與 `dbLanguageOf`），這裡只是把兩段
/// 接起來。
String _dbLanguageFromLocale(Locale locale) =>
    dbLanguageOf(languageFromLocaleTag(locale.toLanguageTag()));
