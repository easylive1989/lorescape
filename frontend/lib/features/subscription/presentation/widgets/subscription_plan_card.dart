import 'package:context_app/features/subscription/presentation/widgets/paywall_palette.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paywall plan card in the Field Journal brand language.
///
/// Renders a single subscription plan on the immersive dark paywall. The
/// billed price is the most visually dominant element on the card to satisfy
/// App Store Guideline 3.1.2(c).
class SubscriptionPlanCard extends StatelessWidget {
  const SubscriptionPlanCard({super.key, required this.state, this.onRetry});

  final SubscriptionPlanCardState state;
  final VoidCallback? onRetry;

  static const double _priceFontSize = 40;
  static const double _periodFontSize = 14;
  static const double _planLabelFontSize = 11;
  static const double _bulletFontSize = 14;
  static const double _noticeFontSize = 11;

  @override
  Widget build(BuildContext context) {
    final palette = PaywallPalette.of(context);
    return switch (state) {
      SubscriptionPlanCardStateLoading() => _cardShell(
        palette,
        borderColor: palette.lineDark,
        fillColor: Colors.transparent,
        child: const _Loading(),
      ),
      SubscriptionPlanCardStateError(:final message) => _cardShell(
        palette,
        borderColor: palette.lineDark,
        fillColor: Colors.transparent,
        child: _Error(message: message, onRetry: onRetry),
      ),
      SubscriptionPlanCardStateReady(
        :final planLabel,
        :final priceString,
        :final periodLabel,
        :final bullets,
        :final autoRenewNotice,
        :final selected,
        :final isBestValue,
        :final freeTrialLabel,
        :final onTap,
      ) =>
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(palette.rLg),
          child: _cardShell(
            palette,
            borderColor: selected ? palette.clay : palette.lineDark,
            fillColor: selected ? palette.claySelected : Colors.transparent,
            child: _Ready(
              planLabel: planLabel,
              priceString: priceString,
              periodLabel: periodLabel,
              bullets: bullets,
              autoRenewNotice: autoRenewNotice,
              selected: selected,
              isBestValue: isBestValue,
              freeTrialLabel: freeTrialLabel,
            ),
          ),
        ),
    };
  }

  Widget _cardShell(
    PaywallPalette palette, {
    required Color borderColor,
    required Color fillColor,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: fillColor,
        border: Border.all(color: borderColor, width: 1.5),
        borderRadius: BorderRadius.circular(palette.rLg),
      ),
      padding: const EdgeInsets.all(18),
      child: child,
    );
  }
}

/// Discriminated state for [SubscriptionPlanCard].
sealed class SubscriptionPlanCardState {
  const SubscriptionPlanCardState();

  const factory SubscriptionPlanCardState.loading() =
      SubscriptionPlanCardStateLoading;

  const factory SubscriptionPlanCardState.error({required String message}) =
      SubscriptionPlanCardStateError;

  const factory SubscriptionPlanCardState.ready({
    required String planLabel,
    required String priceString,
    required String periodLabel,
    required List<String> bullets,
    required String autoRenewNotice,
    bool selected,
    bool isBestValue,
    String? freeTrialLabel,
    VoidCallback? onTap,
  }) = SubscriptionPlanCardStateReady;
}

final class SubscriptionPlanCardStateLoading extends SubscriptionPlanCardState {
  const SubscriptionPlanCardStateLoading();
}

final class SubscriptionPlanCardStateError extends SubscriptionPlanCardState {
  const SubscriptionPlanCardStateError({required this.message});
  final String message;
}

final class SubscriptionPlanCardStateReady extends SubscriptionPlanCardState {
  const SubscriptionPlanCardStateReady({
    required this.planLabel,
    required this.priceString,
    required this.periodLabel,
    required this.bullets,
    required this.autoRenewNotice,
    this.selected = false,
    this.isBestValue = false,
    this.freeTrialLabel,
    this.onTap,
  });

  final String planLabel;
  final String priceString;
  final String periodLabel;
  final List<String> bullets;
  final String autoRenewNotice;
  final bool selected;
  final bool isBestValue;

  /// Pre-formatted free-trial line (e.g. "7 天免費試用"), or `null` when the
  /// plan has no trial. Shown upfront so the offer is visible before the user
  /// selects the plan.
  final String? freeTrialLabel;
  final VoidCallback? onTap;
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SkeletonBar(
          key: ValueKey('planCard.labelSkeleton'),
          width: 120,
          height: 12,
        ),
        SizedBox(height: 16),
        _SkeletonBar(
          key: ValueKey('planCard.priceSkeleton'),
          width: 160,
          height: 36,
        ),
        SizedBox(height: 20),
        _SkeletonBar(width: double.infinity, height: 14),
        SizedBox(height: 10),
        _SkeletonBar(width: double.infinity, height: 14),
        SizedBox(height: 10),
        _SkeletonBar(width: 180, height: 14),
      ],
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({super.key, required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PaywallPalette.of(context).lineDark,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: SizedBox(width: width, height: height),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = PaywallPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(message, style: TextStyle(fontSize: 14, color: palette.onDark2)),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const ValueKey('planCard.retry'),
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: palette.clay,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Retry',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _Ready extends StatelessWidget {
  const _Ready({
    required this.planLabel,
    required this.priceString,
    required this.periodLabel,
    required this.bullets,
    required this.autoRenewNotice,
    required this.selected,
    required this.isBestValue,
    required this.freeTrialLabel,
  });

  final String planLabel;
  final String priceString;
  final String periodLabel;
  final List<String> bullets;
  final String autoRenewNotice;
  final bool selected;
  final bool isBestValue;
  final String? freeTrialLabel;

  @override
  Widget build(BuildContext context) {
    final palette = PaywallPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (selected) ...[
              Icon(Icons.check_circle, size: 18, color: palette.clay),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                planLabel,
                style: TextStyle(
                  fontSize: SubscriptionPlanCard._planLabelFontSize,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: palette.onDark2,
                ),
              ),
            ),
            if (isBestValue) const _BestValueBadge(),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              priceString,
              style: GoogleFonts.notoSerifTc(
                fontSize: SubscriptionPlanCard._priceFontSize,
                fontWeight: FontWeight.w700,
                color: palette.onDark,
                height: 1,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              periodLabel,
              style: TextStyle(
                fontSize: SubscriptionPlanCard._periodFontSize,
                fontWeight: FontWeight.w500,
                color: palette.onDark2,
              ),
            ),
          ],
        ),
        if (freeTrialLabel != null) ...[
          const SizedBox(height: 8),
          Text(
            freeTrialLabel!,
            style: TextStyle(
              fontSize: SubscriptionPlanCard._bulletFontSize,
              fontWeight: FontWeight.w600,
              color: palette.clay,
            ),
          ),
        ],
        if (selected) ...[
          const SizedBox(height: 16),
          _Divider(palette: palette),
          const SizedBox(height: 16),
          Column(
            key: const Key('plan-features'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...bullets.map((b) => _bulletRow(b, palette)),
              const SizedBox(height: 16),
              _Divider(palette: palette),
              const SizedBox(height: 12),
              Text(
                autoRenewNotice,
                style: TextStyle(
                  fontSize: SubscriptionPlanCard._noticeFontSize,
                  color: palette.onDark3,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _bulletRow(String text, PaywallPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome, size: 16, color: palette.clay),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: SubscriptionPlanCard._bulletFontSize,
                color: palette.onDark,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BestValueBadge extends StatelessWidget {
  const _BestValueBadge();

  @override
  Widget build(BuildContext context) {
    final palette = PaywallPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: palette.badgeSurface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'subscription.badge_best_value'.tr(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: palette.onDark,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.palette});

  final PaywallPalette palette;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: palette.lineDark),
      child: const SizedBox(height: 1),
    );
  }
}
