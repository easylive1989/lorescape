import 'package:context_app/features/journey/presentation/widgets/trip_bookshelf.dart';
import 'package:context_app/features/trip/domain/models/trip.dart';
import 'package:context_app/features/trip/providers.dart';
import 'package:context_app/shared/widgets/journal/masthead.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:context_app/shared/widgets/adaptive/adaptive_widgets.dart';

/// 歷程首頁：Masthead ＋ 旅程書架。
///
/// v2 設計把「全部時間軸」從首頁移除了——所有記錄改成點進某本旅程後、以手記
/// 翻頁器閱讀。未歸類的記錄仍有自己的一本書（`tripId == null`）。
class JourneyScreen extends ConsumerWidget {
  const JourneyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTrips = ref.watch(tripsProvider);
    final asyncCounts = ref.watch(tripItemCountsProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 建立旅程的入口不在頁首——它是書架末端那本虛線佔位書。
              Masthead(
                eyebrow: 'journey.eyebrow'.tr(),
                title: 'journey.title'.tr(),
              ),
              const _CurrentTripBanner(),
              asyncTrips.when(
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
                data: (trips) {
                  final counts =
                      asyncCounts.asData?.value ?? const <String?, int>{};
                  return TripBookshelf(
                    caption: 'journey.bookshelf'.tr(
                      args: ['${_bookCount(trips, counts)}'],
                    ),
                    books: _buildBooks(context, trips, counts),
                    onAddTrip: () => context.push('/trip/edit'),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _bookCount(List<Trip> trips, Map<String?, int> counts) =>
      trips.length + (_showUncategorized(trips, counts) ? 1 : 0);

  /// 未歸類的記錄仍要有地方去。沒有任何旅程時也顯示，否則書架會整個空掉。
  bool _showUncategorized(List<Trip> trips, Map<String?, int> counts) =>
      (counts[null] ?? 0) > 0 || trips.isEmpty;

  List<ShelfBook> _buildBooks(
    BuildContext context,
    List<Trip> trips,
    Map<String?, int> counts,
  ) {
    final uncategorizedCount = counts[null] ?? 0;
    return [
      if (_showUncategorized(trips, counts))
        ShelfBook(
          title: 'trip.uncategorized'.tr(),
          subtitle: 'trip.item_count'.tr(args: ['$uncategorizedCount']),
          hasEntries: uncategorizedCount > 0,
          onTap: () => context.push('/trip/uncategorized'),
        ),
      for (final trip in trips)
        ShelfBook(
          title: trip.name,
          subtitle: 'trip.item_count'.tr(args: ['${counts[trip.id] ?? 0}']),
          hasEntries: (counts[trip.id] ?? 0) > 0,
          onTap: () => context.push('/trip/${trip.id}'),
        ),
    ];
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
