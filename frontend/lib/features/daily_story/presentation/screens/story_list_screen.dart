import 'package:context_app/features/daily_story/domain/models/daily_story.dart';
import 'package:context_app/features/daily_story/presentation/widgets/story_deck.dart';
import 'package:context_app/shared/widgets/journal/masthead.dart';
import 'package:context_app/features/daily_story/providers.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The Story tab: a chronological list of all daily stories, with the latest
/// story at the top followed by historical ones.
class StoryListScreen extends ConsumerWidget {
  const StoryListScreen({super.key});

  static const _detailRoute = '/daily-story/detail';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = _dbLanguageFromLocale(context.locale);
    final latest = ref.watch(latestDailyStoryByLanguageProvider(language));
    final history = ref.watch(dailyStoryHistoryByLanguageProvider(language));

    return Scaffold(body: SafeArea(child: _build(context, latest, history)));
  }

  Widget _build(
    BuildContext context,
    AsyncValue<DailyStory?> latest,
    AsyncValue<List<DailyStory>> history,
  ) {
    final cs = Theme.of(context).colorScheme;
    if (latest.isLoading || history.isLoading) {
      return Center(child: CircularProgressIndicator(color: cs.primary));
    }
    if (latest.hasError) {
      return Center(child: Text(latest.error.toString()));
    }
    if (history.hasError) {
      return Center(child: Text(history.error.toString()));
    }

    final stories = <DailyStory>[
      if (latest.value != null) latest.value!,
      ...history.value ?? const [],
    ];

    if (stories.isEmpty) {
      return Column(
        children: [
          _masthead(count: 0),
          Expanded(child: Center(child: Text('story.list_empty'.tr()))),
        ],
      );
    }

    return Column(
      children: [
        _masthead(count: stories.length),
        Expanded(
          child: StoryDeck(
            stories: stories,
            onOpen: (story) => context.push(_detailRoute, extra: story),
          ),
        ),
      ],
    );
  }

  Widget _masthead({required int count}) => Masthead(
    eyebrow: 'story.list_eyebrow'.tr(args: ['$count']),
    title: 'story.list_title'.tr(),
  );
}

String _dbLanguageFromLocale(Locale locale) {
  final tag = locale.toLanguageTag();
  if (tag.startsWith('zh')) return 'zh-TW';
  return 'en';
}
