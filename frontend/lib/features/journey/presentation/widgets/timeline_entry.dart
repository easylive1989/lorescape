import 'dart:async';

import 'package:context_app/app/config/lorescape_tokens.dart';
import 'package:context_app/features/journey/presentation/services/journey_sharing_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:context_app/core/services/place_image_cache_manager.dart';
import 'package:context_app/features/journey/providers.dart';
import 'package:context_app/features/journey/domain/models/journey_entry.dart';
import 'package:context_app/features/trip/providers.dart';
import 'package:context_app/shared/widgets/adaptive/adaptive_widgets.dart';

class TimelineEntry extends ConsumerStatefulWidget {
  final JourneyEntry entry;
  final bool isLast;

  const TimelineEntry({super.key, required this.entry, this.isLast = false});

  /// Shared outer padding used by timeline entries so overlays
  /// (e.g. selection mode) can align without duplicating magic numbers.
  static const EdgeInsets contentPadding = EdgeInsets.only(
    left: 32,
    bottom: 40,
  );

  @override
  ConsumerState<TimelineEntry> createState() => _TimelineEntryState();
}

class _TimelineEntryState extends ConsumerState<TimelineEntry> {
  bool _isDeleting = false;
  bool _isSharing = false;

  Future<void> _shareAsCard() async {
    if (_isSharing || _isDeleting) return;
    setState(() => _isSharing = true);

    unawaited(
      JourneySharingService.shareJourneyCard(
        context: context,
        placeName: widget.entry.place.name,
        placeAddress: widget.entry.place.address,
        narrationExcerpt: widget.entry.narrationContent.text,
        visitedAt: widget.entry.createdAt,
        imageUrl: widget.entry.place.imageUrl,
        onSheetPresented: () {
          if (mounted) {
            setState(() => _isSharing = false);
          }
        },
      ),
    );
  }

  Future<void> _showMoveToTripSheet() async {
    if (_isDeleting) return;
    final selection = await showMoveToTripSheet(
      context: context,
      currentTripId: widget.entry.tripId,
    );
    if (selection == null) return;
    if (selection.tripId == widget.entry.tripId) return;
    try {
      await ref
          .read(journeyRepositoryProvider)
          .save(widget.entry.copyWithTripId(selection.tripId));
      ref.invalidate(allJourneyItemsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'common.error_prefix'.tr()}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmDialog() async {
    if (_isDeleting) return; // Prevent multiple clicks

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

    if (confirmed == true) {
      if (!mounted) return;
      setState(() {
        _isDeleting = true;
      });

      try {
        await ref.read(journeyRepositoryProvider).delete(widget.entry.id);
        ref.invalidate(allJourneyItemsProvider);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${'common.error_prefix'.tr()}: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
          // Only reset deleting state if error occurred (if success, widget might be removed)
          setState(() {
            _isDeleting = false;
          });
        }
      }
    }
  }

  String _formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final entryDate = DateTime(date.year, date.month, date.day);

    if (entryDate == today) {
      return 'journey.today'.tr();
    } else if (entryDate == yesterday) {
      return 'journey.yesterday'.tr();
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final clayTint = tokens.clayTint;

    // 重聽入口已移到手記翻頁器的重聽鍵（`NotebookPage.onPlay`）——這個 widget
    // 現在只在多選模式下渲染，tap 會被外層的選取 overlay 接走。
    return GestureDetector(
      onLongPress: _showMoveToTripSheet,
      child: Container(
        padding: TimelineEntry.contentPadding,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Connector Line
            if (!widget.isLast)
              Positioned(
                left: -27,
                top: 26,
                bottom: -40,
                child: Container(width: 2, color: colorScheme.outline),
              ),

            // Timeline Node — clay dot with a clay-tint halo
            Positioned(
              left: -34,
              top: 4,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: clayTint, spreadRadius: 4)],
                ),
              ),
            ),

            // Content
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _formatDateLabel(
                                  widget.entry.createdAt,
                                ).toUpperCase(),
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                timeFormat.format(widget.entry.createdAt),
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.entry.place.name,
                            style: GoogleFonts.notoSerifTc(
                              color: colorScheme.onSurface,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.entry.place.address,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Thumbnail
                    if (widget.entry.place.imageUrl != null &&
                        widget.entry.place.imageUrl!.isNotEmpty)
                      Container(
                        width: 48,
                        height: 48,
                        margin: const EdgeInsets.only(left: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: colorScheme.surfaceContainerHigh,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: CachedNetworkImage(
                          imageUrl: widget.entry.place.imageUrl!,
                          fit: BoxFit.cover,
                          cacheManager: PlaceImageCacheManager.instance,
                          placeholder: (context, url) => Container(
                            color: colorScheme.surfaceContainerHigh,
                          ),
                          errorWidget: (context, url, error) => Icon(
                            Icons.image_not_supported,
                            color: colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                // Content Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(tokens.rLg),
                    border: Border.all(color: colorScheme.outlineVariant),
                    boxShadow: tokens.e1,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.entry.narrationContent.text,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSerifTc(
                          color: colorScheme.onSurface,
                          fontSize: 16,
                          height: 1.7,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () {},
                        child: Container(
                          padding: const EdgeInsets.only(top: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (_isSharing)
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: AdaptiveProgressIndicator(
                                    strokeWidth: 2,
                                    color: colorScheme.primary,
                                  ),
                                )
                              else
                                _ActionButton(
                                  icon: Icons.share_outlined,
                                  label: 'share_card.share'.tr(),
                                  onTap: _shareAsCard,
                                ),
                              const SizedBox(width: 16),
                              if (_isDeleting)
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: AdaptiveProgressIndicator(
                                    strokeWidth: 2,
                                    color: colorScheme.primary,
                                  ),
                                )
                              else
                                _ActionButton(
                                  icon: Icons.delete_outline,
                                  label: 'journey.delete_confirm'.tr(),
                                  onTap: _showDeleteConfirmDialog,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
