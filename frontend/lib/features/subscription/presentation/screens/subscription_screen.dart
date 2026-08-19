import 'package:context_app/app/config/legal_urls.dart';
import 'package:context_app/features/auth/domain/services/auth_service.dart';
import 'package:context_app/features/auth/providers.dart';
import 'package:context_app/features/subscription/domain/models/subscription_plan.dart';
import 'package:context_app/features/subscription/presentation/widgets/paywall_palette.dart';
import 'package:context_app/features/subscription/presentation/widgets/subscription_plan_card.dart';
import 'package:context_app/features/subscription/providers.dart';
import 'package:context_app/shared/widgets/adaptive/adaptive_widgets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

typedef UrlLauncher = Future<bool> Function(Uri uri);

/// Midnight Kyoto paywall screen. Multi-plan: Weekly / Monthly / Yearly.
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key, UrlLauncher? launchUrl})
    : _launchUrl = launchUrl;

  final UrlLauncher? _launchUrl;

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _isPurchasing = false;
  bool _isLoadingPlans = true;
  List<SubscriptionPlan> _plans = const [];
  SubscriptionPeriod? _selectedPeriod;
  String? _plansError;
  bool _showHeadline = false;
  bool _showSubheadline = false;
  bool _showPlanCards = false;

  static Future<bool> _defaultLaunchUrl(Uri uri) {
    return url_launcher.launchUrl(
      uri,
      mode: url_launcher.LaunchMode.externalApplication,
    );
  }

  UrlLauncher get _launchUrl => widget._launchUrl ?? _defaultLaunchUrl;

  @override
  void initState() {
    super.initState();
    _loadPlans();
    _scheduleEntryAnimation();
  }

  Future<void> _scheduleEntryAnimation() async {
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    setState(() => _showHeadline = true);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    setState(() => _showSubheadline = true);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    setState(() => _showPlanCards = true);
  }

  Widget _entry({required bool visible, required Widget child}) {
    return AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, 0.04),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        child: child,
      ),
    );
  }

  Future<void> _loadPlans() async {
    setState(() {
      _isLoadingPlans = true;
      _plansError = null;
    });
    try {
      final plans = await ref
          .read(subscriptionServiceProvider)
          .getAvailablePlans();
      if (!mounted) return;
      if (plans.isEmpty) {
        setState(() {
          _plansError = 'subscription.plan_load_failed'.tr();
          _isLoadingPlans = false;
        });
        return;
      }
      setState(() {
        _plans = plans;
        _selectedPeriod =
            plans.any((p) => p.period == SubscriptionPeriod.yearly)
            ? SubscriptionPeriod.yearly
            : plans.first.period;
        _isLoadingPlans = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _plansError = 'subscription.plan_load_failed'.tr();
        _isLoadingPlans = false;
      });
    }
  }

  Future<void> _purchase() async {
    final period = _selectedPeriod;
    if (period == null) return;

    // Approach A: a purchase must be attributed to a permanent account so the
    // backend (keyed by user id) keeps the entitlement across future sign-ins
    // and devices. Anonymous users sign in first.
    final user = ref.read(currentUserProvider);
    if (user == null || user.isAnonymous) {
      final signedIn = await _promptSignIn();
      if (!signedIn) return;
    }

    setState(() => _isPurchasing = true);
    try {
      final service = ref.read(subscriptionServiceProvider);
      final result = await service.purchase(period);
      if (result != null && result.isPremium && mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'common.error_prefix'.tr()}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        await _loadPlans();
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  /// Prompts the user to sign in with Google or Apple before purchasing.
  ///
  /// Returns true once a permanent account is signed in (and RevenueCat is
  /// re-identified to it), or false if the user dismisses or cancels.
  Future<bool> _promptSignIn() async {
    final provider = await showAdaptiveModalBottomSheet<_SignInProvider>(
      context: context,
      builder: (_) => const _SignInPrompt(),
    );
    if (provider == null || !mounted) return false;

    try {
      final authService = ref.read(authServiceProvider);
      final user = switch (provider) {
        _SignInProvider.google => await authService.signInWithGoogle(),
        _SignInProvider.apple => await authService.signInWithApple(),
      };
      // Identify RevenueCat with the permanent account before the purchase so
      // the purchase event's app_user_id matches this backend user.
      await ref.read(subscriptionServiceProvider).logIn(user.id);
      return true;
    } on AuthCancelledException {
      return false;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('settings.sign_in_failed'.tr())));
      }
      return false;
    }
  }

  Future<void> _restore() async {
    setState(() => _isPurchasing = true);
    try {
      final service = ref.read(subscriptionServiceProvider);
      final result = await service.restorePurchases();
      if (mounted) {
        if (result.isPremium) {
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('subscription.no_purchases_found'.tr())),
          );
        }
      }
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
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  Future<void> _openUrl(Uri uri) async {
    final opened = await _launchUrl(uri);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${'common.error_prefix'.tr()}: $uri'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  String _planLabelKey(SubscriptionPeriod period) => switch (period) {
    SubscriptionPeriod.weekly => 'subscription.plan_weekly',
    SubscriptionPeriod.monthly => 'subscription.plan_monthly',
    SubscriptionPeriod.yearly => 'subscription.plan_yearly',
  };

  String _periodLabelKey(SubscriptionPeriod period) => switch (period) {
    SubscriptionPeriod.weekly => 'subscription.period_weekly',
    SubscriptionPeriod.monthly => 'subscription.period_monthly',
    SubscriptionPeriod.yearly => 'subscription.period_yearly',
  };

  String _subscribeLabel(SubscriptionPeriod? period) => switch (period) {
    SubscriptionPeriod.weekly => 'subscription.subscribe_weekly'.tr(),
    SubscriptionPeriod.monthly => 'subscription.subscribe_monthly'.tr(),
    SubscriptionPeriod.yearly => 'subscription.subscribe_yearly'.tr(),
    null => 'subscription.subscribe_yearly'.tr(),
  };

  SubscriptionPlanCardState _cardState(SubscriptionPlan plan) {
    return SubscriptionPlanCardState.ready(
      planLabel: _planLabelKey(plan.period).tr(),
      priceString: plan.priceString,
      periodLabel: _periodLabelKey(plan.period).tr(),
      bullets: [
        'subscription.benefit_unlimited'.tr(),
        'subscription.benefit_route'.tr(),
      ],
      autoRenewNotice: 'subscription.auto_renew_notice'.tr(),
      selected: plan.period == _selectedPeriod,
      isBestValue: plan.isBestValue,
      freeTrialLabel: plan.freeTrialDays != null
          ? 'subscription.free_trial_days'.tr(
              namedArgs: {'days': '${plan.freeTrialDays}'},
            )
          : null,
      onTap: _isPurchasing
          ? null
          : () => setState(() => _selectedPeriod = plan.period),
    );
  }

  Widget _plansSection() {
    if (_isLoadingPlans) {
      return const Column(
        children: [
          SubscriptionPlanCard(state: SubscriptionPlanCardState.loading()),
          SizedBox(height: 12),
          SubscriptionPlanCard(state: SubscriptionPlanCardState.loading()),
          SizedBox(height: 12),
          SubscriptionPlanCard(state: SubscriptionPlanCardState.loading()),
        ],
      );
    }
    final err = _plansError;
    if (err != null) {
      return SubscriptionPlanCard(
        state: SubscriptionPlanCardState.error(message: err),
        onRetry: _loadPlans,
      );
    }
    return IgnorePointer(
      ignoring: _isPurchasing,
      child: Column(
        children: [
          for (var i = 0; i < _plans.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            SubscriptionPlanCard(state: _cardState(_plans[i])),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = PaywallPalette.of(context);
    return Scaffold(
      backgroundColor: palette.inkBg,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -1.05),
            radius: 1.2,
            colors: [const Color(0xFF34291F), palette.inkBg],
            stops: const [0, 0.72],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AdaptiveIconButton(
                    icon: Icon(Icons.close, color: palette.onDark),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      _PremiumIcon(color: palette.clay),
                      const SizedBox(height: 20),
                      _entry(
                        visible: _showHeadline,
                        child: Text(
                          'subscription.hero_title'.tr(),
                          style: GoogleFonts.notoSerifTc(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: palette.onDark,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _entry(
                        visible: _showSubheadline,
                        child: Text(
                          'subscription.hero_subtitle'.tr(),
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.55,
                            color: palette.onDark2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _entry(visible: _showPlanCards, child: _plansSection()),
                      const SizedBox(height: 20),
                      _SubscribeButton(
                        isLoading: _isPurchasing,
                        label: _subscribeLabel(_selectedPeriod),
                        palette: palette,
                        onPressed:
                            _isPurchasing ||
                                _plans.isEmpty ||
                                _selectedPeriod == null
                            ? null
                            : _purchase,
                      ),
                      const SizedBox(height: 4),
                      AdaptiveButton(
                        style: AdaptiveButtonStyle.text,
                        foregroundColor: palette.onDark2,
                        onPressed: _isPurchasing ? null : _restore,
                        child: Text(
                          'subscription.restore'.tr(),
                          style: TextStyle(
                            fontSize: 14,
                            color: palette.onDark2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _LegalFooter(onOpen: _openUrl, palette: palette),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumIcon extends StatelessWidget {
  const _PremiumIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.diamond_outlined, size: 92, color: color);
  }
}

class _SubscribeButton extends StatelessWidget {
  const _SubscribeButton({
    required this.isLoading,
    required this.onPressed,
    required this.label,
    required this.palette,
  });

  final bool isLoading;
  final VoidCallback? onPressed;
  final String label;
  final PaywallPalette palette;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: palette.clay,
          foregroundColor: const Color(0xFFFBF1E9),
          disabledBackgroundColor: palette.clay.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(palette.rLg),
          ),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        icon: isLoading
            ? const SizedBox.shrink()
            : const Icon(Icons.lock_outline, size: 18),
        label: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: AdaptiveProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFFBF1E9),
                ),
              )
            : Text(label),
      ),
    );
  }
}

class _LegalFooter extends StatelessWidget {
  const _LegalFooter({required this.onOpen, required this.palette});

  final Future<void> Function(Uri) onOpen;
  final PaywallPalette palette;

  @override
  Widget build(BuildContext context) {
    final muted = palette.onDark3;
    final linkStyle = TextStyle(
      fontSize: 12,
      color: muted,
      decoration: TextDecoration.underline,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onOpen(Uri.parse(LegalUrls.termsOfUse)),
          child: Text('subscription.terms'.tr(), style: linkStyle),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('·', style: TextStyle(fontSize: 12, color: muted)),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onOpen(Uri.parse(LegalUrls.privacyPolicy)),
          child: Text('subscription.privacy'.tr(), style: linkStyle),
        ),
      ],
    );
  }
}

/// The identity provider chosen in the [_SignInPrompt].
enum _SignInProvider { google, apple }

/// Bottom sheet asking the user to sign in (Google or Apple) before they can
/// purchase. Pops with the chosen [_SignInProvider], or null when dismissed.
class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'subscription.login_required'.tr(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          AdaptiveButton(
            expanded: true,
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => Navigator.of(context).pop(_SignInProvider.google),
            child: Text('settings.sign_in_google'.tr()),
          ),
          const SizedBox(height: 12),
          AdaptiveButton(
            expanded: true,
            style: AdaptiveButtonStyle.outlined,
            icon: const Icon(Icons.apple),
            onPressed: () => Navigator.of(context).pop(_SignInProvider.apple),
            child: Text('settings.sign_in_apple'.tr()),
          ),
          const SizedBox(height: 12),
          AdaptiveButton(
            style: AdaptiveButtonStyle.text,
            onPressed: () => Navigator.of(context).pop(),
            child: Text('settings.cancel'.tr()),
          ),
        ],
      ),
    );
  }
}
