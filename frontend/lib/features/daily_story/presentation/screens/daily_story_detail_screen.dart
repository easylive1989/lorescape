import 'package:cached_network_image/cached_network_image.dart';
import 'package:context_app/features/daily_story/domain/models/daily_story.dart';
import 'package:context_app/features/daily_story/domain/models/daily_story_card_mode.dart';
import 'package:context_app/features/daily_story/presentation/utils/daily_story_config_launcher.dart';
import 'package:context_app/features/daily_story/presentation/widgets/card_layout_body.dart';
import 'package:context_app/features/daily_story/presentation/widgets/card_reader_theme.dart';
import 'package:context_app/features/daily_story/presentation/widgets/more_stories_cta.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class DailyStoryDetailScreen extends StatelessWidget {
  final DailyStory story;
  const DailyStoryDetailScreen({super.key, required this.story});

  @override
  Widget build(BuildContext context) {
    // Only offer "explore more stories" when the place can be resolved to a
    // wikidata-prefixed Place; generation needs it. Otherwise hide the CTA.
    final onExploreMore = story.wikidataId != null
        ? () => launchSamePlaceStories(context, story)
        : null;
    final isCard = story.hasCardLayout;
    return Scaffold(
      backgroundColor: isCard ? CardReaderTheme.readBg : null,
      appBar: isCard
          ? _buildDarkAppBar(context)
          : AppBar(title: Text(story.placeName)),
      body: isCard
          ? CardLayoutBody(story: story, onExploreMore: onExploreMore)
          : _LegacyLayoutBody(story: story, onExploreMore: onExploreMore),
    );
  }

  /// Dark "topbar" that blends into the hero photo, per the editorial reader
  /// design: ink-bg background, clay back chevron, cream serif title.
  PreferredSizeWidget _buildDarkAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: CardReaderTheme.inkBg,
      foregroundColor: CardReaderTheme.onDark,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leadingWidth: 44,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          size: 20,
          color: CardReaderTheme.clay,
        ),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      titleSpacing: 0,
      title: Text(
        story.placeName,
        style: GoogleFonts.notoSerifTc(
          color: CardReaderTheme.onDark,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _LegacyLayoutBody extends StatelessWidget {
  final DailyStory story;
  final VoidCallback? onExploreMore;
  const _LegacyLayoutBody({required this.story, this.onExploreMore});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (story.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: story.imageUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      const Icon(Icons.image_not_supported_outlined),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(story.placeName, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          _MetaRow(
            label: 'daily_story.detail_location_label'.tr(),
            value: story.placeLocation,
          ),
          _MetaRow(
            label: 'daily_story.detail_era_label'.tr(),
            value: story.era,
          ),
          const SizedBox(height: 16),
          _StoryBody(text: story.story, style: theme.textTheme.bodyLarge),
          if (onExploreMore != null) ...[
            const SizedBox(height: 28),
            MoreStoriesCta(
              onTap: onExploreMore!,
              accentColor: theme.colorScheme.primary,
              onAccentColor: theme.colorScheme.onPrimary,
            ),
          ],
        ],
      ),
    );
  }
}

class _StoryBody extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const _StoryBody({required this.text, this.style});

  @override
  Widget build(BuildContext context) {
    final paragraphs = _splitIntoParagraphs(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < paragraphs.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          Text(paragraphs[i], style: style),
        ],
      ],
    );
  }

  static List<String> _splitIntoParagraphs(String text) {
    final normalized = text.replaceAll('\r\n', '\n').trim();
    final parts = normalized
        .split(RegExp(r'\n+'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    return parts.isEmpty ? [normalized] : parts;
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
