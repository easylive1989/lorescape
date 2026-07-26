import 'package:context_app/shared/widgets/adaptive/adaptive_widgets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 旅程（含「未分類」）沒有任何記錄時的空狀態。
///
/// 只有一行灰字的空狀態是條死巷——第一次進來的使用者看不出記錄是從哪裡長出
/// 來的。這裡補上插圖與一顆把人帶回探索頁的按鈕。
class TripEmptyState extends StatelessWidget {
  const TripEmptyState({super.key});

  /// 插圖尚未進版控時 `Image.asset` 會丟例外，由 `errorBuilder` 退回等高留白，
  /// 程式碼因此不必等素材就緒。詳見設計文件的「缺圖時的行為」。
  static const String _illustration = 'assets/images/empty_trip.png';
  static const double _illustrationSize = 200;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Center 讓內容在空間充裕時置中，SingleChildScrollView 則保證小螢幕
    // 不會 overflow。
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 純裝飾，語意交給下方的標題與按鈕承擔。
            ExcludeSemantics(
              child: Image.asset(
                _illustration,
                width: _illustrationSize,
                height: _illustrationSize,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    const SizedBox(height: _illustrationSize),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'trip.no_items'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'trip.empty_hint'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            AdaptiveButton(
              // go 而非 push：使用者按下引導後不該還能退回這本空旅程。
              onPressed: () => context.go('/?tab=explore'),
              child: Text('trip.empty_cta'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
