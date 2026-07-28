import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:context_app/app/config/lorescape_tokens.dart';
import 'package:context_app/features/explore/providers.dart';

/// 首頁頂部：眼眉字＋字標＋歷程/設定兩顆 icon，底下是搜尋列與建議清單。
class HomeTopBar extends ConsumerWidget {
  const HomeTopBar({
    super.key,
    required this.controller,
    required this.query,
    required this.onQueryChanged,
    required this.onSuggestionTap,
    required this.onOpenJourney,
    required this.onOpenSettings,
  });

  final TextEditingController controller;

  /// 已經過 debounce 的查詢字串；空字串代表不顯示建議。
  final String query;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onSuggestionTap;
  final VoidCallback onOpenJourney;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final suggestions = query.isEmpty
        ? const AsyncValue<List<String>>.data([])
        : ref.watch(placeSuggestionsProvider(query));

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'home.eyebrow'.tr(),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.3,
                        color: tokens.clay,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'home.brand'.tr(),
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 27,
                        height: 1,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              _RaisedIconButton(
                key: const Key('home-open-journey'),
                icon: Icons.menu_book_outlined,
                label: 'home.open_journey'.tr(),
                onPressed: onOpenJourney,
              ),
              const SizedBox(width: 8),
              _RaisedIconButton(
                key: const Key('home-open-settings'),
                icon: Icons.settings_outlined,
                label: 'home.open_settings'.tr(),
                onPressed: onOpenSettings,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: tokens.paperRaised,
              borderRadius: BorderRadius.circular(tokens.rLg),
              boxShadow: tokens.e2,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(Icons.search, size: 20, color: tokens.ink3),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    key: const Key('home-search'),
                    controller: controller,
                    onChanged: onQueryChanged,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'home.search_hint'.tr(),
                    ),
                  ),
                ),
                if (controller.text.isNotEmpty)
                  IconButton(
                    key: const Key('home-search-clear'),
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'home.search_clear'.tr(),
                    onPressed: () {
                      controller.clear();
                      onQueryChanged('');
                    },
                  ),
              ],
            ),
          ),
          suggestions.maybeWhen(
            data: (items) => items.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _SuggestionList(
                      items: items,
                      onTap: onSuggestionTap,
                    ),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _RaisedIconButton extends StatelessWidget {
  const _RaisedIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Semantics(
      button: true,
      label: label,
      child: InkResponse(
        onTap: onPressed,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: tokens.paperRaised,
            shape: BoxShape.circle,
            boxShadow: tokens.e1,
          ),
          child: Icon(icon, size: 21, color: tokens.ink2),
        ),
      ),
    );
  }
}

class _SuggestionList extends StatelessWidget {
  const _SuggestionList({required this.items, required this.onTap});

  final List<String> items;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: tokens.paperRaised,
        border: Border.all(color: tokens.line),
        borderRadius: BorderRadius.circular(tokens.rLg),
        boxShadow: tokens.e3,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, item) in items.indexed) ...[
            if (index > 0) Divider(height: 1, color: tokens.line),
            ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 17,
                backgroundColor: tokens.clayTint,
                child: Icon(
                  Icons.place_outlined,
                  size: 17,
                  color: tokens.clayDeep,
                ),
              ),
              title: Text(item),
              trailing: Icon(Icons.chevron_right, color: tokens.ink3),
              onTap: () => onTap(item),
            ),
          ],
        ],
      ),
    );
  }
}
