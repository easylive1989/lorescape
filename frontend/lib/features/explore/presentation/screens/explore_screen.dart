import 'package:cached_network_image/cached_network_image.dart';
import 'package:context_app/app/config/lorescape_tokens.dart';
import 'package:context_app/features/explore/domain/errors/location_error.dart';
import 'package:context_app/features/explore/domain/models/place.dart';
import 'package:context_app/features/explore/presentation/widgets/lorescape_map.dart';
import 'package:context_app/features/explore/presentation/widgets/place_map_pin.dart';
import 'package:context_app/features/explore/providers.dart';
import 'package:context_app/features/saved_locations/providers.dart';
import 'package:context_app/features/settings/providers.dart';
import 'package:context_app/shared/widgets/adaptive/adaptive_widgets.dart';
import 'package:context_app/shared/widgets/journal/category_tag.dart';
import 'package:context_app/shared/widgets/journal/glyph_thumb.dart';
import 'package:context_app/shared/widgets/journal/masthead.dart';
import 'package:context_app/shared/widgets/midnight/_press_scale.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  /// 從首頁搜尋建議進來時帶的關鍵字。null 表示走預設的附近景點模式。
  final String? initialQuery;

  const ExploreScreen({super.key, this.initialQuery});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();

  /// 設計稿：點卡片時 `flyTo(coord, 14)`。
  static const double _kFocusZoom = 14;

  void _focusOn(Place place) {
    _mapController.move(
      LatLng(place.location.latitude, place.location.longitude),
      _kFocusZoom,
    );
  }

  @override
  void initState() {
    super.initState();
    final query = widget.initialQuery;
    if (query == null || query.isEmpty) return;
    _searchController.text = query;
    // build 期間不能改 provider，等第一幀畫完再送出搜尋。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(searchQueryProvider.notifier).state = query;
      ref.read(placesControllerProvider.notifier).search(query);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 同步 EasyLocalization 的語言到 languageProvider
    // 使用 addPostFrameCallback 延遲更新，避免在 widget build 期間修改 provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncLanguage();
    });
  }

  /// 同步 EasyLocalization 語言到 Provider
  void _syncLanguage() {
    if (!mounted) return;
    final localeTag =
        EasyLocalization.of(context)?.locale.toLanguageTag() ?? 'zh-TW';
    ref.read(currentLanguageProvider.notifier).updateLanguage(localeTag);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFilterPanel() {
    showAdaptiveModalBottomSheet(
      context: context,
      builder: (context) => const _FilterPanel(),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(searchQueryProvider.notifier).state = '';
    ref.read(placesControllerProvider.notifier).search('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final placesState = ref.watch(filteredPlacesProvider);
    final maxDistance = ref.watch(maxDistanceProvider);
    final isFilterActive = maxDistance != kDefaultMaxDistanceMeters;
    final places = placesState.valueOrNull ?? const <Place>[];

    return Scaffold(
      body: Stack(
        children: [
          LorescapeMap(
            mapController: _mapController,
            fitToPoints: [
              for (final place in places)
                LatLng(place.location.latitude, place.location.longitude),
            ],
            children: [
              MarkerLayer(
                markers: [
                  for (final place in places)
                    Marker(
                      point: LatLng(
                        place.location.latitude,
                        place.location.longitude,
                      ),
                      width: PlaceMapPin.markerSize,
                      height: PlaceMapPin.markerSize,
                      // 尖端落在座標上：把標記整個往上推一個身高。
                      alignment: Alignment.topCenter,
                      child: PlaceMapPin(
                        category: place.category.journalCategory,
                        onTap: () => context.pushNamed('config', extra: place),
                      ),
                    ),
                ],
              ),
            ],
          ),
          _MapTopOverlay(
            placeCount: places.length,
            searchController: _searchController,
            isFilterActive: isFilterActive,
            onBack: () => context.pop(),
            onFilter: _showFilterPanel,
            onRefresh: () {
              _searchController.clear();
              ref.read(placesControllerProvider.notifier).refresh();
            },
            onSearchChanged: (_) => setState(() {}),
            onSearchSubmitted: (value) {
              ref.read(searchQueryProvider.notifier).state = value;
              ref.read(placesControllerProvider.notifier).search(value);
            },
            onSearchClear: _searchController.text.isNotEmpty
                ? _clearSearch
                : null,
          ),
          _MapCardsRail(state: placesState, onFocus: _focusOn),
          // 型別化 object pattern：僅在 error 為 LocationError 時比對成功，
          // 並把 error 綁成 LocationError（`when ... is` guard 不會提升型別）。
          if (placesState case AsyncError(error: final LocationError error))
            Positioned.fill(
              child: Center(
                child: SingleChildScrollView(
                  child: _LocationGateCard(error: error),
                ),
              ),
            ),
          // FAB 疊在卡片列上方。設計稿把 FAB 放在 bottom:96，但那個位置正好
          // 被卡片列蓋住（實機上直接壓在卡片上），所以改成貼著卡片列往上放。
          Positioned(
            right: 18,
            bottom:
                MediaQuery.paddingOf(context).bottom +
                _MapCardsRail.railBottomGap +
                _MapCardsRail.railHeight +
                12,
            child: const SavedLocationsFab(),
          ),
        ],
      ),
    );
  }
}

/// Circular 40×40 icon button on a sunken-paper surface, matching the
/// design's `.iconbtn` on `--paper-sunk`.
class _FilterButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback onPressed;

  const _FilterButton({required this.isActive, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _CircleButton(
          icon: Icons.tune,
          iconColor: colorScheme.onSurface,
          background: colorScheme.surfaceContainerHighest,
          iconSize: 22,
          onPressed: onPressed,
        ),
        if (isActive) const Positioned(top: 2, right: 2, child: _ActiveDot()),
      ],
    );
  }
}

/// Circular 40×40 clay action button, matching the design's clay `.iconbtn`.
class _RefreshButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _RefreshButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _CircleButton(
      icon: Icons.refresh,
      iconColor: colorScheme.onPrimary,
      background: colorScheme.primary,
      iconSize: 20,
      onPressed: onPressed,
    );
  }
}

/// 地圖資料來源標示，改用一顆 ⓘ 收在頂部 icon 列裡。
///
/// **這是授權義務，不是裝飾**：OpenFreeMap / OpenMapTiles / OpenStreetMap 的
/// 出處必須讓看地圖的人合理可及（見 ADR 0005）。OSM attribution guideline
/// 允許在小螢幕上把完整文字收進一個明顯、直接可點的入口——這顆 ⓘ 就是那個
/// 入口，點擊彈出完整出處與版權連結，等同於原本角落那行文字的義務。
class _AttributionButton extends StatelessWidget {
  const _AttributionButton();

  static final Uri _osmCopyright = Uri.parse(
    'https://www.openstreetmap.org/copyright',
  );

  Future<void> _showAttribution(BuildContext context) {
    return showAdaptiveAlertDialog<void>(
      context: context,
      title: 'explore.map.attribution_title'.tr(),
      content: 'explore.map.attribution_body'.tr(),
      actions: [
        AdaptiveDialogAction(
          label: 'explore.map.attribution_source'.tr(),
          onPressed: () {
            Navigator.of(context).pop();
            launchUrl(_osmCopyright, mode: LaunchMode.externalApplication);
          },
        ),
        AdaptiveDialogAction(
          label: 'explore.map.attribution_close'.tr(),
          isDefault: true,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'explore.map.attribution_tooltip'.tr(),
      child: _CircleButton(
        icon: Icons.info_outline,
        iconColor: colorScheme.onSurface,
        background: colorScheme.surfaceContainerHighest,
        iconSize: 22,
        onPressed: () => _showAttribution(context),
      ),
    );
  }
}

/// 從首頁搜尋建議 zoom 進地圖後，用來退回地球儀首頁的返回鈕。
///
/// `_CircleButton` 沒有 `tooltip` 參數，比照 `_AttributionButton` 用
/// `Semantics` 包一層來承載無障礙標籤——順便把 [Key] 放在這層，測試才點得到。
class _GlobeBackButton extends StatelessWidget {
  const _GlobeBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      key: const Key('explore-globe-back'),
      button: true,
      label: 'explore.back_to_globe'.tr(),
      child: _CircleButton(
        icon: Icons.public,
        iconColor: colorScheme.onSurface,
        background: colorScheme.surfaceContainerHighest,
        iconSize: 22,
        onPressed: onPressed,
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.iconColor,
    required this.background,
    required this.iconSize,
    required this.onPressed,
  });

  final IconData icon;
  final Color iconColor;
  final Color background;
  final double iconSize;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onPressed,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: iconColor, size: iconSize),
          ),
        ),
      ),
    );
  }
}

class _ActiveDot extends StatelessWidget {
  const _ActiveDot();

  /// 測試用：畫面上有多個有顏色的小圓（地圖 pin、卡片前往鈕），靠造型找不準。
  static const Key testKey = Key('explore-filter-active-dot');

  @override
  Widget build(BuildContext context) {
    return Container(
      key: testKey,
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Pill-shaped search field on a sunken-paper surface, matching `.search`.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<LorescapeTokens>();
    final hintColor = tokens?.ink3 ?? colorScheme.onSurfaceVariant;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 20, color: hintColor),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              style: Theme.of(context).textTheme.bodyLarge,
              cursorColor: colorScheme.primary,
              // The field carries its own pill container, so it must fully
              // opt out of the global outlined+filled inputDecorationTheme —
              // `collapsed` still inherits enabledBorder/focusedBorder/fill.
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                hintText: 'explore.search_hint'.tr(),
                hintStyle: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: hintColor),
              ),
            ),
          ),
          if (onClear != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClear,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.clear, size: 20, color: hintColor),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterPanel extends ConsumerStatefulWidget {
  const _FilterPanel();

  @override
  ConsumerState<_FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends ConsumerState<_FilterPanel> {
  late double _sliderValue;

  /// 滑桿的刻度值（公尺）：500, 1000, 2000, 5000, 10000, 20000, 30000
  static const List<double> _steps = [
    500,
    1000,
    2000,
    5000,
    10000,
    20000,
    30000,
  ];

  @override
  void initState() {
    super.initState();
    final current = ref.read(maxDistanceProvider);
    _sliderValue = _valueToSlider(current);
  }

  /// 將距離值對應到滑桿位置（0.0 ~ 1.0）
  double _valueToSlider(double value) {
    for (int i = 0; i < _steps.length; i++) {
      if (value <= _steps[i]) return i / (_steps.length - 1);
    }
    return 1.0;
  }

  /// 將滑桿位置轉換為距離值
  double _sliderToValue(double slider) {
    final index = (slider * (_steps.length - 1)).round().clamp(
      0,
      _steps.length - 1,
    );
    return _steps[index];
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      final km = meters / 1000;
      return km == km.roundToDouble() ? '${km.toInt()} km' : '$km km';
    }
    return '${meters.toInt()} m';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentValue = _sliderToValue(_sliderValue);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: colorScheme.outline,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'explore.filter.title'.tr(),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 24),
          Text(
            'explore.filter.max_distance'.tr(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AdaptiveSlider(
                  value: _sliderValue,
                  onChanged: (value) {
                    setState(() {
                      _sliderValue = value;
                    });
                  },
                  onChangeEnd: (value) {
                    final newDistance = _sliderToValue(value);
                    ref.read(maxDistanceProvider.notifier).state = newDistance;
                    if (ref.read(searchQueryProvider).isEmpty) {
                      ref
                          .read(placesControllerProvider.notifier)
                          .refresh(radius: newDistance);
                    }
                  },
                ),
              ),
              SizedBox(
                width: 72,
                child: Text(
                  _formatDistance(currentValue),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('500 m', style: Theme.of(context).textTheme.bodySmall),
                Text('30 km', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'explore.filter.description'.tr(),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () {
                ref.read(maxDistanceProvider.notifier).state =
                    kDefaultMaxDistanceMeters;
                setState(() {
                  _sliderValue = _valueToSlider(kDefaultMaxDistanceMeters);
                });
                if (ref.read(searchQueryProvider).isEmpty) {
                  ref
                      .read(placesControllerProvider.notifier)
                      .refresh(radius: kDefaultMaxDistanceMeters);
                }
              },
              child: Text('explore.filter.reset'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}

/// 60×60 縮圖：有照片用照片，否則用分類字符（設計稿 `.map-card__thumb`）。
class _PlaceThumb extends StatelessWidget {
  const _PlaceThumb({required this.place});

  final Place place;

  static const _size = 60.0;
  static const _radius = 10.0;

  @override
  Widget build(BuildContext context) {
    final photoUrl = place.primaryPhoto?.url;
    if (photoUrl == null) return _glyph;

    return ClipRRect(
      borderRadius: BorderRadius.circular(_radius),
      child: CachedNetworkImage(
        imageUrl: photoUrl,
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _glyph,
      ),
    );
  }

  Widget get _glyph => GlyphThumb(
    category: place.category.journalCategory,
    size: _size,
    borderRadius: _radius,
  );
}

class _BookmarkButton extends StatelessWidget {
  final bool isSaved;
  final VoidCallback onTap;

  const _BookmarkButton({required this.isSaved, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<LorescapeTokens>();
    final restColor = tokens?.ink3 ?? colorScheme.onSurfaceVariant;

    return PressScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: Icon(
            isSaved ? Icons.bookmark : Icons.bookmark_border,
            key: ValueKey(isSaved),
            color: isSaved ? colorScheme.primary : restColor,
            size: 24,
          ),
        ),
      ),
    );
  }
}

/// 浮在地圖上方的標題區，對應設計稿的 `.map-top`：紙色漸層讓底下的地圖不會
/// 干擾文字，但只有實際控制項吃得到觸控（`pointer-events` 的等價作法）。
class _MapTopOverlay extends StatelessWidget {
  const _MapTopOverlay({
    required this.placeCount,
    required this.searchController,
    required this.isFilterActive,
    required this.onBack,
    required this.onFilter,
    required this.onRefresh,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onSearchClear,
  });

  final int placeCount;
  final TextEditingController searchController;
  final bool isFilterActive;
  final VoidCallback onBack;
  final VoidCallback onFilter;
  final VoidCallback onRefresh;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback? onSearchClear;

  @override
  Widget build(BuildContext context) {
    final paper = context.tokens.paper;
    final topPadding = MediaQuery.paddingOf(context).top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Stack(
        children: [
          // 漸層只是襯底，必須讓觸控穿過去，使用者才能拖到露出來的地圖。
          // 注意：不能把整個浮層包進 IgnorePointer 再用巢狀
          // IgnorePointer(ignoring: false) 想「收回來」——外層一旦排除整個
          // 子樹，內層就救不回來，搜尋/篩選/重新整理會全部點不到。
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      paper.withValues(alpha: 0.97),
                      paper.withValues(alpha: 0.97),
                      paper.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.46, 1],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            // 只墊安全區：標題的左緣與上方間距由 Masthead 自己帶，才會跟
            // 故事／歷程兩頁（SafeArea + 同一個 Masthead）對到同一個位置。
            padding: EdgeInsets.only(top: topPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Masthead(
                  eyebrow: 'explore.atlas_eyebrow'.tr(args: ['$placeCount']),
                  title: 'explore.title'.tr(),
                  // 地圖上不畫分隔線，靠漸層與底圖分隔。
                  showRule: false,
                  actions: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _GlobeBackButton(onPressed: onBack),
                      const SizedBox(width: 8),
                      const _AttributionButton(),
                      const SizedBox(width: 8),
                      _FilterButton(
                        isActive: isFilterActive,
                        onPressed: onFilter,
                      ),
                      const SizedBox(width: 8),
                      _RefreshButton(onPressed: onRefresh),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  // 跟著標題的內距走，搜尋列才會與大標左緣對齊。
                  padding: const EdgeInsets.fromLTRB(
                    Masthead.horizontalInset,
                    0,
                    Masthead.horizontalInset,
                    22,
                  ),
                  child: _SearchField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    onSubmitted: onSearchSubmitted,
                    onClear: onSearchClear,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 底部橫向卡片列（`.map-cards`）。點卡片把地圖飛到該地點，點箭頭進地點頁。
class _MapCardsRail extends StatelessWidget {
  const _MapCardsRail({required this.state, required this.onFocus});

  final AsyncValue<List<Place>> state;
  final ValueChanged<Place> onFocus;

  /// 卡片內容（縮圖 60 / 兩行名稱＋標籤）＋卡片內距 20 ＋列內距 14。
  /// 太矮會讓名稱那欄 overflow，測試會直接抓到。
  static const double railHeight = 116;

  /// 卡片列與 body 底緣的間距。shell 的 Scaffold 沒有 extendBody，body 底緣
  /// 就是 bottom navigation bar 的頂端，所以這裡只留一點讓卡片陰影透氣的小
  /// 間距、讓卡片貼著 nav bar，不需再墊一個 tab bar 的高度。
  static const double railBottomGap = 12;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Positioned(
      left: 0,
      right: 0,
      bottom: bottomInset + railBottomGap,
      height: railHeight,
      child: state.when(
        loading: () => const SizedBox.shrink(),
        // 錯誤（最常見是定位被拒）一定要說出來。地圖本身還是會顯示，若這裡
        // 也沉默，使用者只會看到一張沒有任何地點、也沒有任何說明的地圖。
        error: (error, _) => error is LocationError
            ? const SizedBox.shrink()
            : _RailNotice(text: '${'common.error_prefix'.tr()}: $error'),
        data: (places) {
          if (places.isEmpty) {
            return _RailNotice(text: 'explore.empty'.tr());
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            itemCount: places.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final place = places[index];
              return _MapCard(place: place, onTap: () => onFocus(place));
            },
          );
        },
      ),
    );
  }
}

/// 沒有地點或載入失敗時，卡片列的位置改放一張說明卡，而不是留一片空白
/// 讓人以為畫面壞了。
class _RailNotice extends StatelessWidget {
  const _RailNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LorescapeTokens>();
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: tokens?.paperRaised ?? colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(context.tokens.rLg),
          border: Border.all(color: tokens?.line ?? colorScheme.outlineVariant),
          boxShadow: context.tokens.e2,
        ),
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

/// 定位不可用時疊在地圖中央的引導卡：共用插圖＋依狀態的說明與按鈕。
class _LocationGateCard extends ConsumerWidget {
  const _LocationGateCard({required this.error});

  final LocationError error;

  /// i18n key 用的狀態名（對齊 assets/translations 的結構）。
  String get _stateKey => switch (error) {
    LocationError.serviceDisabled => 'service_disabled',
    LocationError.permissionDenied => 'permission_denied',
    LocationError.permissionDeniedForever => 'permission_denied_forever',
  };

  Future<void> _onAction(WidgetRef ref) async {
    final service = ref.read(locationServiceProvider);
    switch (error) {
      case LocationError.permissionDenied:
        final granted = await service.requestPermission();
        if (granted) {
          ref.read(placesControllerProvider.notifier).refresh();
        }
      case LocationError.permissionDeniedForever:
        await service.openAppSettings();
      case LocationError.serviceDisabled:
        await service.openLocationSettings();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<LorescapeTokens>();
    final colorScheme = Theme.of(context).colorScheme;
    final base = 'explore.location_gate.$_stateKey';

    return Container(
      width: 320,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: tokens?.paperRaised ?? colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(context.tokens.rLg),
        border: Border.all(color: tokens?.line ?? colorScheme.outlineVariant),
        boxShadow: context.tokens.e3,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 插圖載入失敗時退回一段留白，讓測試與缺圖情境都不會 crash。
          Image.asset(
            'assets/images/location_gate.png',
            width: 160,
            height: 120,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox(height: 120),
          ),
          const SizedBox(height: 20),
          Text(
            '$base.title'.tr(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Text(
            '$base.description'.tr(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _onAction(ref),
              child: Text('$base.action'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}

/// 單張地點卡（`.map-card`）：252px 寬、紙色浮起、縮圖＋名稱＋分類標籤＋前往鈕。
class _MapCard extends ConsumerWidget {
  const _MapCard({required this.place, required this.onTap});

  final Place place;
  final VoidCallback onTap;

  static const double _width = 252;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<LorescapeTokens>();
    final colorScheme = Theme.of(context).colorScheme;
    final radius = context.tokens.rLg;
    final savedLocations = ref.watch(savedLocationsProvider);
    final isSaved =
        savedLocations.valueOrNull?.any((e) => e.placeId == place.id) ?? false;

    return PressScale(
      onTap: onTap,
      child: Container(
        width: _width,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: tokens?.paperRaised ?? colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: tokens?.line ?? colorScheme.outlineVariant),
          boxShadow: context.tokens.e3,
        ),
        child: Row(
          children: [
            // 書籤疊在縮圖角落。設計稿的 map-card 沒有書籤，但這是全 App 唯一
            // 能收藏地點的入口，照抄會把功能弄丟；壓在縮圖上才不會擠掉名稱。
            Stack(
              children: [
                _PlaceThumb(place: place),
                Positioned(
                  top: -8,
                  right: -8,
                  // 紙色底盤：書籤壓在照片上時，深色圖示在深色照片上幾乎看不見。
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.tokens.paperRaised.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                      boxShadow: context.tokens.e1,
                    ),
                    child: _BookmarkButton(
                      isSaved: isSaved,
                      onTap: () => ref
                          .read(savedLocationsProvider.notifier)
                          .togglePlace(place),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    place.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 17,
                      height: 1.2,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  CategoryTag(category: place.category.journalCategory),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _GoButton(onTap: () => context.pushNamed('config', extra: place)),
          ],
        ),
      ),
    );
  }
}

/// `.map-card__go`：34px 圓形前往鈕。
class _GoButton extends StatelessWidget {
  const _GoButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<LorescapeTokens>();
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: 'explore.view_place'.tr(),
      child: PressScale(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: tokens?.paperSunk ?? colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.chevron_right,
            size: 20,
            color: tokens?.ink2 ?? colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
