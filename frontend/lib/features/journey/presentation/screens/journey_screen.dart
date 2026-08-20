import 'package:context_app/app/config/lorescape_tokens.dart';
import 'package:context_app/features/journey/presentation/widgets/globe_view.dart';
import 'package:context_app/features/journey/presentation/widgets/trip_bookshelf.dart';
import 'package:context_app/features/journey/providers.dart';
import 'package:context_app/features/trip/domain/models/trip.dart';
import 'package:context_app/features/trip/providers.dart';
import 'package:context_app/shared/widgets/journal/floating_back_button.dart';
import 'package:context_app/shared/widgets/journal/masthead.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:context_app/shared/widgets/adaptive/adaptive_widgets.dart';

/// 書架頁：上半地球儀釘選中旅程的停點，下半是木板書架與立著的書背。
///
/// v2 設計把「全部時間軸」從首頁移除了——所有記錄改成點進某本旅程後、以手記
/// 翻頁器閱讀。未歸類的記錄仍有自己的一本書（`tripId == null`）。
///
/// v3 再把地球儀從舊首頁搬過來當底層：書架選哪一本，地球儀就釘哪一本的停點，
/// 所以架上的書要點兩下才進得去——第一下是換選、第二下才打開手記。
class JourneyScreen extends ConsumerStatefulWidget {
  const JourneyScreen({super.key});

  @override
  ConsumerState<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends ConsumerState<JourneyScreen> {
  /// 地球儀上下留的空間，對應設計稿的 `.shelfscr .hm-globe`。
  static const double _globeTopInset = 128;
  static const double _globeBottomInset = 322;

  /// 標題左緣要讓出的寬度，位置留給浮動返回鈕（[Masthead] 自己已含 22）。
  ///
  /// 值＝返回鈕的右緣（左緣 ＋ 直徑）再留 8 的間隙，扣掉 Masthead 自帶的
  /// 內距。寫死成 48 時鈕的右緣（54）會壓到大標的左緣，兩者重疊。
  static const double _mastheadBackInset =
      FloatingBackButton.leftInset +
      FloatingBackButton.size +
      8 -
      Masthead.horizontalInset;

  /// 使用者選中的那本旅程。
  ///
  /// `null` 有兩種意思，由 [_selectedTripIdOf] 收斂：架上有「未分類」時是
  /// 未分類那本，沒有時代表「還沒選過」，退回架上第一本。
  String? _selectedTripId;

  @override
  void initState() {
    super.initState();
    // 舊記錄沒存座標（見 BackfillJourneyCoordsUseCase），不補的話地球儀上一
    // 個點都沒有。放在這裡而不是 App 啟動時：只有真的看得到地球儀的人才值得
    // 花那幾個網路請求。
    ref.read(journeyCoordsBackfillProvider);
  }

  @override
  Widget build(BuildContext context) {
    final asyncTrips = ref.watch(tripsProvider);
    final counts =
        ref.watch(tripItemCountsProvider).asData?.value ??
        const <String?, int>{};
    final trips = asyncTrips.asData?.value ?? const [];
    final volumes = _volumes(trips, counts);
    final selectedTripId = _selectedTripIdOf(volumes);

    return Scaffold(
      body: Stack(
        children: [
          // 底層：地球儀，釘選中那本旅程的停點。
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(
                top: _globeTopInset,
                bottom: _globeBottomInset,
              ),
              child: Center(
                child: _TripGlobe(
                  tripId: selectedTripId,
                  onSelectTrip: (tripId) =>
                      setState(() => _selectedTripId = tripId),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: _mastheadBackInset),
                    child: Masthead(title: 'journey.title'.tr()),
                  ),
                  const _CurrentTripBanner(),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: asyncTrips.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: AdaptiveProgressIndicator()),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '${'trip.load_error'.tr()}: $error',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                data: (_) =>
                    _buildShelf(context, volumes, trips.length, selectedTripId),
              ),
            ),
          ),
          const FloatingBackButton(),
        ],
      ),
    );
  }

  Widget _buildShelf(
    BuildContext context,
    List<_Volume> volumes,
    int tripCount,
    String? selectedTripId,
  ) {
    final matches = volumes.where((volume) => volume.tripId == selectedTripId);
    final selected = matches.isEmpty ? null : matches.first;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TripBookshelf(
          // 架上那本「未分類」不是使用者建的旅程，不算進這個數字；沒有任何
          // 旅程時要顯示 0，而不是把那本合成書算成 1。
          caption: 'journey.shelf_count'.plural(tripCount),
          books: [
            for (final volume in volumes)
              ShelfBook(
                title: volume.title,
                subtitle: 'trip.item_count'.tr(args: ['${volume.count}']),
                hasEntries: volume.count > 0,
                isSelected: volume.tripId == selectedTripId,
                onTap: () => _onVolumeTap(volume, selectedTripId),
              ),
          ],
          onAddTrip: () => context.push('/trip/edit'),
        ),
        if (selected != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 14),
            child: Text(
              'journey.shelf_hint'.tr(args: [selected.title]),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: context.tokens.ink3),
            ),
          ),
      ],
    );
  }

  /// 點沒選中的書＝把地球儀轉去那本旅程；點已經選中的書才進手記。
  void _onVolumeTap(_Volume volume, String? selectedTripId) {
    if (volume.tripId != selectedTripId) {
      setState(() => _selectedTripId = volume.tripId);
      return;
    }
    context.push('/trip/${volume.tripId ?? 'uncategorized'}');
  }

  /// 目前選中的旅程 id。選過的那本若已經不在架上（例如被刪掉），退回第一本。
  String? _selectedTripIdOf(List<_Volume> volumes) {
    if (volumes.any((volume) => volume.tripId == _selectedTripId)) {
      return _selectedTripId;
    }
    return volumes.isEmpty ? null : volumes.first.tripId;
  }

  /// 架上的書，未分類那本永遠排在最前面。
  List<_Volume> _volumes(List<Trip> trips, Map<String?, int> counts) {
    final uncategorizedCount = counts[null] ?? 0;
    // 未歸類的記錄仍要有地方去。沒有任何旅程時也顯示，否則書架會整個空掉。
    final showUncategorized = uncategorizedCount > 0 || trips.isEmpty;
    return [
      if (showUncategorized)
        _Volume(
          tripId: null,
          title: 'trip.uncategorized'.tr(),
          count: uncategorizedCount,
        ),
      for (final trip in trips)
        _Volume(tripId: trip.id, title: trip.name, count: counts[trip.id] ?? 0),
    ];
  }
}

/// 書架上的一本書所需的資料：`tripId` 為 `null` 就是未分類那本。
@immutable
class _Volume {
  const _Volume({
    required this.tripId,
    required this.title,
    required this.count,
  });

  final String? tripId;
  final String title;
  final int count;
}

/// 釘著某本旅程停點的地球儀。輪廓還在載入時先不畫。
class _TripGlobe extends ConsumerWidget {
  const _TripGlobe({required this.tripId, required this.onSelectTrip});

  final String? tripId;

  /// 點地球儀上別本書的釘點＝換選那本書（與點書架上的書同一個動作）。
  final ValueChanged<String?> onSelectTrip;

  /// 設計稿在書架頁把地球儀縮到 300（首頁那顆是 344）。
  static const double _size = 300;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outline = ref.watch(worldOutlineProvider).asData?.value;
    if (outline == null) return const SizedBox.shrink();

    // 一本書一個釘點，選中那本轉過去。找不到（那本書一個有座標的故事都沒
    // 有）就不轉，地球儀維持原角度。
    final pins = ref.watch(shelfGlobePinsProvider);
    final focusId = globePinIdForTrip(tripId);
    final focus = pins.where((pin) => pin.id == focusId).firstOrNull;
    return GlobeView(
      outline: outline,
      pins: pins,
      focus: focus,
      onPinTap: (pin) => onSelectTrip(tripIdForGlobePin(pin.id)),
      size: _size,
    );
  }
}

class _CurrentTripBanner extends ConsumerWidget {
  const _CurrentTripBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTripId = ref.watch(currentTripIdProvider);
    if (currentTripId == null) return const SizedBox.shrink();

    final tripAsync = ref.watch(tripByIdProvider(currentTripId));
    return tripAsync.maybeWhen(
      data: (trip) {
        if (trip == null) return const SizedBox.shrink();
        final colorScheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.push('/trip/${trip.id}'),
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      colorScheme.primary.withValues(alpha: 0.85),
                      colorScheme.primary.withValues(alpha: 0.65),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.flag_outlined,
                        color: colorScheme.onPrimary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'trip.current_badge'.tr(),
                              style: TextStyle(
                                color: colorScheme.onPrimary.withValues(
                                  alpha: 0.85,
                                ),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              trip.name,
                              style: TextStyle(
                                color: colorScheme.onPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      AdaptiveButton(
                        style: AdaptiveButtonStyle.text,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        onPressed: () =>
                            ref.read(currentTripIdProvider.notifier).clear(),
                        child: Text(
                          'trip.end_current'.tr(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
