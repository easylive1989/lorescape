import 'package:context_app/app/config/lorescape_tokens.dart';
import 'package:context_app/features/saved_locations/presentation/widgets/saved_locations_sheet.dart';
import 'package:context_app/features/saved_locations/providers.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Floating action button that opens the saved locations as a bottom sheet,
/// with a badge reflecting the saved count.
class SavedLocationsFab extends ConsumerWidget {
  const SavedLocationsFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedLocations = ref.watch(savedLocationsProvider);
    final count = savedLocations.valueOrNull?.length ?? 0;

    return FloatingActionButton(
      shape: const CircleBorder(),
      onPressed: () => showSavedLocationsSheet(context),
      child: Badge(
        isLabelVisible: count > 0,
        label: Text('$count', style: const TextStyle(fontSize: 10)),
        child: Icon(
          Icons.bookmark,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }
}

/// 收在探索頁頂部 icon 列裡的儲存地點入口。
///
/// 與 [SavedLocationsFab] 是同一個功能的兩種擺法——地圖上那個顯眼的位置留給
/// 「回地球儀」，儲存清單改用這顆小圓鈕。尺寸與底色刻意對齊探索頁 icon 列
/// 其他按鈕（40×40、下沉紙色）。
class SavedLocationsButton extends ConsumerWidget {
  const SavedLocationsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(savedLocationsProvider).valueOrNull?.length ?? 0;
    final tokens = Theme.of(context).extension<LorescapeTokens>();
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      key: const Key('explore-saved-locations'),
      button: true,
      label: 'saved_locations.title'.tr(),
      child: Material(
        color: tokens?.paperSunk ?? colorScheme.surfaceContainerHighest,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showSavedLocationsSheet(context),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Badge(
              isLabelVisible: count > 0,
              label: Text('$count', style: const TextStyle(fontSize: 10)),
              child: Icon(
                Icons.bookmark,
                size: 21,
                color: tokens?.ink2 ?? colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
