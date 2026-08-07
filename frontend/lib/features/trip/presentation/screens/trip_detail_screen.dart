import 'dart:async';

import 'package:context_app/core/utils/share_position_origin.dart';
import 'package:context_app/features/export/domain/models/pdf_export_result.dart';
import 'package:context_app/features/export/domain/services/trip_pdf_export_service.dart';
import 'package:context_app/features/export/providers.dart';
import 'package:context_app/features/journey/domain/models/journey_entry.dart';
import 'package:context_app/features/journey/domain/models/journey_item.dart';
import 'package:context_app/shared/widgets/journal/notebook_pager.dart';
import 'package:context_app/features/journey/providers.dart';
import 'package:context_app/features/trip/domain/models/trip.dart';
import 'package:context_app/features/trip/presentation/widgets/trip_empty_state.dart';
import 'package:context_app/features/trip/providers.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:context_app/shared/widgets/adaptive/adaptive_widgets.dart';

/// 顯示單一 Trip 的條目時間軸。
///
/// 傳入 `tripId = null` 代表顯示「未分類」（tripId 為 null 的條目）。
class TripDetailScreen extends ConsumerStatefulWidget {
  final String? tripId;

  const TripDetailScreen({super.key, this.tripId});

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  final Set<String> _selectedIds = {};
  bool _selectionMode = false;
  bool _moving = false;

  bool get _isUncategorized => widget.tripId == null;

  void _enterSelectionMode() {
    setState(() {
      _selectionMode = true;
      _selectedIds.clear();
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<JourneyItem> items) {
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(items.map((e) => e.id));
    });
  }

  Future<void> _moveSelected(List<JourneyItem> items) async {
    if (_selectedIds.isEmpty || _moving) return;
    final selection = await showMoveToTripSheet(
      context: context,
      currentTripId: widget.tripId,
      itemCount: _selectedIds.length,
    );
    if (selection == null) return;
    if (selection.tripId == widget.tripId) {
      _exitSelectionMode();
      return;
    }
    setState(() => _moving = true);
    try {
      final journeyRepo = ref.read(journeyRepositoryProvider);
      await Future.wait(
        items.where((it) => _selectedIds.contains(it.id)).map((item) {
          return switch (item) {
            NarrationJourneyItem(:final entry) => journeyRepo.save(
              entry.copyWithTripId(selection.tripId),
            ),
          };
        }),
      );
      ref.invalidate(allJourneyItemsProvider);
      if (mounted) _exitSelectionMode();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'common.error_prefix'.tr()}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _moving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripAsync = _isUncategorized
        ? const AsyncValue<Trip?>.data(null)
        : ref.watch(tripByIdProvider(widget.tripId!));
    final itemsAsync = ref.watch(journeyItemsForTripProvider(widget.tripId));
    final items = itemsAsync.asData?.value ?? const <JourneyItem>[];

    return Scaffold(
      appBar: _buildAppBar(tripAsync, items),
      body: Column(
        children: [
          if (!_selectionMode) _NotebookLead(trip: tripAsync.asData?.value),
          Expanded(
            child: _ItemsList(
              itemsAsync: itemsAsync,
              selectionMode: _selectionMode,
              selectedIds: _selectedIds,
              onToggleSelection: _toggleSelection,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _selectionMode ? _buildSelectionBar(items) : null,
    );
  }

  AppBar _buildAppBar(AsyncValue<Trip?> tripAsync, List<JourneyItem> items) {
    if (_selectionMode) {
      return AppBar(
        leading: AdaptiveIconButton(
          icon: const Icon(Icons.close),
          onPressed: _exitSelectionMode,
        ),
        title: Text('trip.selected_count'.tr(args: ['${_selectedIds.length}'])),
        actions: [
          AdaptiveButton(
            style: AdaptiveButtonStyle.text,
            onPressed: items.isEmpty ? null : () => _selectAll(items),
            child: Text('trip.select_all'.tr()),
          ),
        ],
      );
    }

    return AppBar(
      title: tripAsync.when(
        data: (trip) => Text(
          _isUncategorized
              ? 'trip.uncategorized'.tr()
              : (trip?.name ?? 'trip.not_found'.tr()),
        ),
        loading: () => const Text(''),
        error: (_, _) => Text('trip.not_found'.tr()),
      ),
      actions: [
        if (_isUncategorized && items.isNotEmpty)
          AdaptiveIconButton(
            icon: const Icon(Icons.checklist),
            onPressed: _enterSelectionMode,
          )
        else if (!_isUncategorized)
          _TripMenuButton(tripId: widget.tripId!),
      ],
    );
  }

  Widget _buildSelectionBar(List<JourneyItem> items) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: AdaptiveButton(
          expanded: true,
          padding: const EdgeInsets.symmetric(vertical: 14),
          icon: _moving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: AdaptiveProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.drive_file_move_outlined),
          onPressed: _selectedIds.isEmpty || _moving
              ? null
              : () => _moveSelected(items),
          child: Text('trip.move_selected'.tr()),
        ),
      ),
    );
  }
}

/// 手記上方的 lead 列（設計稿 `.trip-lead`）：顯示旅程日期。重聽鍵已改成
/// 每頁手記標題右側的 icon 圓鈕（見 `NotebookPage.onReplay`），不在這裡。
class _NotebookLead extends StatelessWidget {
  const _NotebookLead({required this.trip});

  final Trip? trip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final range = trip == null
        ? null
        : _formatDateRange(trip!.startDate, trip!.endDate);
    if (range == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
      child: Row(
        children: [
          Icon(Icons.event, size: 17, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              range,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _formatDateRange(DateTime? start, DateTime? end) {
    final fmt = DateFormat.yMMMd();
    if (start == null && end == null) return null;
    if (start != null && end != null) {
      return '${fmt.format(start)} – ${fmt.format(end)}';
    }
    return fmt.format(start ?? end!);
  }
}

class _TripMenuButton extends ConsumerWidget {
  final String tripId;

  const _TripMenuButton({required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTripId = ref.watch(currentTripIdProvider);
    final isCurrent = currentTripId == tripId;

    return PopupMenuButton<_TripMenuAction>(
      onSelected: (action) => _handleAction(context, ref, action, isCurrent),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _TripMenuAction.setCurrent,
          child: Text(
            isCurrent ? 'trip.end_current'.tr() : 'trip.set_as_current'.tr(),
          ),
        ),
        PopupMenuItem(
          value: _TripMenuAction.edit,
          child: Text('trip.edit_action'.tr()),
        ),
        PopupMenuItem(
          value: _TripMenuAction.exportPdf,
          child: Text('export.menu_item'.tr()),
        ),
        PopupMenuItem(
          value: _TripMenuAction.delete,
          child: Text(
            'trip.delete_action'.tr(),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    _TripMenuAction action,
    bool isCurrent,
  ) async {
    switch (action) {
      case _TripMenuAction.setCurrent:
        await ref
            .read(currentTripIdProvider.notifier)
            .setCurrentTripId(isCurrent ? null : tripId);
      case _TripMenuAction.edit:
        if (context.mounted) context.push('/trip/edit/$tripId');
      case _TripMenuAction.exportPdf:
        await _exportPdf(context, ref, tripId);
      case _TripMenuAction.delete:
        final confirmed = await _confirmDelete(context);
        if (!confirmed) return;
        // 孤兒化：把屬於此 trip 的條目 tripId 清成 null，回到「未分類」。
        await _orphanItemsOfTrip(ref, tripId);
        await ref.read(tripRepositoryProvider).delete(tripId);
        if (isCurrent) {
          await ref.read(currentTripIdProvider.notifier).clear();
        }
        ref.invalidate(tripsProvider);
        ref.invalidate(allJourneyItemsProvider);
        if (context.mounted) context.pop();
    }
  }

  Future<void> _orphanItemsOfTrip(WidgetRef ref, String tripId) async {
    final journeyRepo = ref.read(journeyRepositoryProvider);
    final journeyEntries = await journeyRepo.getAll();
    await Future.wait([
      for (final e in journeyEntries.where((e) => e.tripId == tripId))
        journeyRepo.save(e.copyWithTripId(null)),
    ]);
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showAdaptiveAlertDialog<bool>(
      context: context,
      title: 'trip.delete_title'.tr(),
      content: 'trip.delete_message'.tr(),
      actions: [
        AdaptiveDialogAction<bool>(label: 'trip.cancel'.tr(), result: false),
        AdaptiveDialogAction<bool>(
          label: 'trip.delete_confirm'.tr(),
          isDestructive: true,
          result: true,
        ),
      ],
    );
    return result ?? false;
  }
}

enum _TripMenuAction { setCurrent, edit, exportPdf, delete }

Future<void> _exportPdf(
  BuildContext context,
  WidgetRef ref,
  String tripId,
) async {
  final messenger = ScaffoldMessenger.of(context);

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 16),
          Expanded(child: Text('export.generating'.tr())),
        ],
      ),
    ),
  );

  try {
    final result = await exportTripAsPdf(
      ref: ref,
      context: context,
      tripId: tripId,
      strings: _buildExportStrings(),
    );
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    _showResultSnackBar(messenger, result);
  } on EmptyTripExportException {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    messenger.showSnackBar(SnackBar(content: Text('export.empty_trip'.tr())));
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text('export.failed'.tr(namedArgs: {'error': e.toString()})),
      ),
    );
  }
}

void _showResultSnackBar(
  ScaffoldMessengerState messenger,
  PdfExportResult result,
) {
  if (result.hasMissingImages) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'export.some_images_missing'.tr(
            namedArgs: {'count': '${result.missingImagePlaceNames.length}'},
          ),
        ),
      ),
    );
    return;
  }
  messenger.showSnackBar(SnackBar(content: Text('export.success'.tr())));
}

TripPdfExportStrings _buildExportStrings() {
  return TripPdfExportStrings(
    stampLabel: 'export.stamp_label'.tr(),
    appName: 'app.name'.tr(),
    tagline: 'app.tagline'.tr(),
    entryCountLabel: 'export.entry_count_label'.tr(),
    pdfLabels: PdfLabels(pageOfTotal: 'export.page_of_total'.tr()),
  );
}

class _ItemsList extends ConsumerWidget {
  final AsyncValue<List<JourneyItem>> itemsAsync;
  final bool selectionMode;
  final Set<String> selectedIds;
  final void Function(String id) onToggleSelection;

  const _ItemsList({
    required this.itemsAsync,
    required this.selectionMode,
    required this.selectedIds,
    required this.onToggleSelection,
  });

  /// 重聽這一則：記錄裡就存著完整敘事文字，播放頁只要拿到地點與
  /// narration 內容就能重新合成語音，不必再打一次生成 API。
  void _replay(BuildContext context, JourneyEntry entry) {
    context.pushNamed(
      'player',
      extra: {
        'place': entry.place.toPlace(),
        'narrationContent': entry.narrationContent,
        // 按下「重聽」的意圖就是要聽，不必再多按一次播放鍵。
        'autoPlay': true,
      },
    );
  }

  /// 把這則手記收進另一本旅程，對應設計稿的「加入旅程」。
  Future<void> _addToTrip(
    BuildContext context,
    WidgetRef ref,
    JourneyEntry entry,
  ) async {
    final selection = await showMoveToTripSheet(
      context: context,
      currentTripId: entry.tripId,
    );
    if (selection == null || selection.tripId == entry.tripId) return;
    await ref
        .read(journeyRepositoryProvider)
        .save(entry.copyWithTripId(selection.tripId));
    ref.invalidate(allJourneyItemsProvider);
  }

  void _share(BuildContext context, JourneyEntry entry) {
    unawaited(
      JourneySharingService.shareJourneyCard(
        context: context,
        placeName: entry.place.name,
        placeAddress: entry.place.address,
        narrationExcerpt: entry.narrationContent.text,
        visitedAt: entry.createdAt,
        imageUrl: entry.place.imageUrl,
        sharePositionOrigin: sharePositionOriginOf(context),
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    JourneyEntry entry,
  ) async {
    final confirmed = await showAdaptiveAlertDialog<bool>(
      context: context,
      title: 'journey.delete_title'.tr(),
      content: 'journey.delete_message'.tr(),
      actions: [
        AdaptiveDialogAction<bool>(label: 'journey.cancel'.tr(), result: false),
        AdaptiveDialogAction<bool>(
          label: 'journey.delete_confirm'.tr(),
          isDestructive: true,
          result: true,
        ),
      ],
    );
    if (confirmed != true) return;
    await ref.read(journeyRepositoryProvider).delete(entry.id);
    ref.invalidate(allJourneyItemsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return itemsAsync.when(
      data: (items) {
        if (items.isEmpty) return const TripEmptyState();
        // 一般閱讀模式用手記翻頁器；進入多選後改回列表——翻頁器一次只看得到
        // 一張，沒辦法批次勾選、移動或匯出，硬套會把既有功能弄殘。
        if (!selectionMode) {
          return NotebookPager(
            pages: [
              for (var i = 0; i < items.length; i++)
                switch (items[i]) {
                  NarrationJourneyItem(:final entry) => NotebookPage(
                    title: entry.place.name,
                    dateLabel: DateFormat(
                      'yyyy/MM/dd · HH:mm',
                    ).format(entry.createdAt),
                    text: entry.narrationContent.text,
                    address: entry.place.address,
                    imageUrl: entry.place.imageUrl,
                    onReplay: () => _replay(context, entry),
                    onAddToTrip: () => _addToTrip(context, ref, entry),
                    onShare: () => _share(context, entry),
                    onDelete: () => _delete(context, ref, entry),
                  ),
                },
            ],
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final isLast = index == items.length - 1;
            final entryWidget = switch (item) {
              NarrationJourneyItem(:final entry) => TimelineEntry(
                key: ValueKey(item.id),
                entry: entry,
                isLast: isLast,
              ),
            };

            if (!selectionMode) return entryWidget;

            final isSelected = selectedIds.contains(item.id);
            return _SelectableEntry(
              isSelected: isSelected,
              onTap: () => onToggleSelection(item.id),
              child: entryWidget,
            );
          },
        );
      },
      loading: () => const Center(child: AdaptiveProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          '${'trip.load_error'.tr()}: $e',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}

class _SelectableEntry extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final Widget child;

  const _SelectableEntry({
    required this.isSelected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        AbsorbPointer(child: child),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onTap,
            child: Container(
              margin: TimelineEntry.contentPadding,
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primary.withValues(alpha: 0.10)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? Border.all(color: colorScheme.primary, width: 2)
                    : null,
              ),
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.surface,
                      border: Border.all(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.outline,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
