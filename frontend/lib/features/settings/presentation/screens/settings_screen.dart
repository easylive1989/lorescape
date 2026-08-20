import 'package:context_app/app/config/lorescape_tokens.dart';
import 'package:context_app/features/auth/domain/services/auth_service.dart';
import 'package:context_app/features/auth/providers.dart';
import 'package:context_app/features/onboarding/providers.dart';
import 'package:context_app/features/settings/providers.dart';
import 'package:context_app/features/subscription/providers.dart';
import 'package:context_app/shared/widgets/adaptive/adaptive_widgets.dart';
import 'package:context_app/shared/widgets/journal/floating_back_button.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                // 讓出頁首左上角浮動返回鈕的位置。
                const SizedBox(height: 44),
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 14),
                  child: Text(
                    'settings.title'.tr(),
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                ),
                const _UpgradeCard(),
                const _PreferencesGroup(),
                const SizedBox(height: 26),
                const _AccountGroup(),
                const SizedBox(height: 26),
                const _SyncGroup(),
                const SizedBox(height: 26),
                const _OnboardingGroup(),
                const SizedBox(height: 26),
                const _MapSourceGroup(),
                const SizedBox(height: 36),
                const _Footer(),
              ],
            ),
          ),
          const FloatingBackButton(),
        ],
      ),
    );
  }
}

// ============================================================================
// Setting groups
// ============================================================================

/// 深色升級卡：設定清單最上方的付費牆入口（設計稿 `.upgrade`）。
///
/// 訂閱中的使用者不該再看到升級推銷、也不該點得進付費牆重複購買，所以先看
/// [isPremiumProvider]：訂閱中就換成唯讀的「已是會員」狀態，不可點按。
class _UpgradeCard extends ConsumerWidget {
  const _UpgradeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);
    final tokens = context.tokens;
    return Padding(
      // 左右不再自己加內距——外層 ListView 已經有 20，再疊上去會比下方各
      // 區塊的卡片窄一圈。下方留 26，跟其他區塊之間的間距一致。
      padding: const EdgeInsets.only(top: 16, bottom: 26),
      child: Material(
        key: const Key('settings-upgrade-card'),
        color: tokens.inkBg,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isPremium ? null : () => context.push('/subscription'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(
                  isPremium ? Icons.diamond : Icons.diamond_outlined,
                  size: 30,
                  color: tokens.claySoft,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isPremium
                            ? 'subscription.premium_active'.tr()
                            : 'subscription.upgrade_title'.tr(),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: tokens.onDark,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      if (!isPremium) ...[
                        const SizedBox(height: 4),
                        Text(
                          'subscription.upgrade_subtitle'.tr(),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: tokens.onDark2),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!isPremium)
                  Icon(Icons.chevron_right, size: 22, color: tokens.onDark2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreferencesGroup extends ConsumerWidget {
  const _PreferencesGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(settingsControllerProvider.notifier);
    return _SettingsGroup(
      label: 'settings.preferences'.tr(),
      child: _SettingsCard(
        children: [
          _SettingsRow(
            icon: Icons.language,
            title: 'settings.change_language'.tr(),
            trailing: _TrailingValue(
              context.locale.languageCode == 'en' ? 'English' : '繁體中文',
              chevron: true,
            ),
            onTap: () => controller.changeLanguage(context),
          ),
        ],
      ),
    );
  }
}

class _AccountGroup extends ConsumerWidget {
  const _AccountGroup();

  Future<void> _handleSignIn(
    BuildContext context,
    WidgetRef ref, {
    required bool useApple,
  }) async {
    final service = ref.read(authServiceProvider);
    try {
      if (useApple) {
        await service.signInWithApple();
      } else {
        await service.signInWithGoogle();
      }
    } on AuthCancelledException {
      return;
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('settings.sign_in_failed'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('settings.sign_out'.tr()),
        content: Text('settings.logout_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('settings.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('settings.sign_out'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authServiceProvider).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    // Anonymous users have a session but no real identity yet, so treat them
    // as signed out here — they must see the Google/Apple buttons to upgrade
    // (which links the identity in place via linkIdentity).
    if (user != null && !user.isAnonymous) {
      return _SettingsGroup(
        label: 'settings.account_section'.tr(),
        child: _SettingsCard(
          children: [
            _SettingsRow(
              icon: Icons.person_outline,
              title: 'settings.account_signed_in_as'.tr(
                namedArgs: {'name': user.displayName ?? user.email ?? user.id},
              ),
              subtitle: user.email,
              trailing: TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _handleSignOut(context, ref),
                child: Text('settings.sign_out'.tr()),
              ),
            ),
          ],
        ),
      );
    }

    return _SettingsGroup(
      label: 'settings.account_section'.tr(),
      child: _SettingsCard(
        children: [
          _SettingsRow(
            icon: Icons.person_outline,
            title: 'settings.account_not_signed_in'.tr(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('sign_in_google'),
                  icon: Image.asset(
                    'assets/images/google_logo.png',
                    width: 18,
                    height: 18,
                  ),
                  label: Text('settings.sign_in_google'.tr()),
                  onPressed: () => _handleSignIn(context, ref, useApple: false),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const ValueKey('sign_in_apple'),
                  icon: const Icon(Icons.apple),
                  label: Text('settings.sign_in_apple'.tr()),
                  onPressed: () => _handleSignIn(context, ref, useApple: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 雲端同步的狀態列。沒有開關——journey 與 trip 一律同步（見
/// syncSessionProvider）。留著這一列是因為「資料有沒有被備份」使用者有權知
/// 道，而且匿名帳號那個限制（重裝就換一個 id、資料拿不回來）必須講清楚。
class _SyncGroup extends ConsumerWidget {
  const _SyncGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final hasAccount = user != null && !user.isAnonymous;

    return _SettingsGroup(
      label: 'settings.sync_section'.tr(),
      child: _SettingsCard(
        children: [
          _SettingsRow(
            key: const ValueKey('sync_status_row'),
            icon: Icons.cloud_done_outlined,
            title: 'settings.sync_status'.tr(),
            subtitle: hasAccount
                ? 'settings.sync_status_account'.tr()
                : 'settings.sync_status_anonymous'.tr(),
          ),
          // 沒登入的人備份是綁在匿名帳號上的，這串 id 是他唯一能拿來要求刪
          // 除資料的識別碼（隱私政策也是這樣寫的）。不顯示的話，「刪除我的
          // 資料」這個權利對匿名使用者等於行使不了。
          if (user != null && !hasAccount)
            _SettingsRow(
              key: const ValueKey('sync_account_id_row'),
              icon: Icons.tag,
              title: 'settings.sync_account_id'.tr(),
              subtitle: user.id,
              trailing: const Icon(Icons.copy_all_outlined, size: 18),
              onTap: () => _copyAccountId(context, user.id),
            ),
        ],
      ),
    );
  }

  Future<void> _copyAccountId(BuildContext context, String id) async {
    await Clipboard.setData(ClipboardData(text: id));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('settings.sync_account_id_copied'.tr()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _OnboardingGroup extends ConsumerWidget {
  const _OnboardingGroup();

  Future<void> _confirmReplay(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('settings_onboarding.confirm_replay_title'.tr()),
        content: Text('settings_onboarding.confirm_replay_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('journey.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('settings_onboarding.confirm_replay_action'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(onboardingControllerProvider.notifier).resetAll();
    if (!context.mounted) return;
    context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ink3 =
        Theme.of(context).extension<LorescapeTokens>()?.ink3 ??
        Theme.of(context).colorScheme.onSurfaceVariant;
    return _SettingsGroup(
      label: 'settings_onboarding.section'.tr(),
      child: _SettingsCard(
        children: [
          _SettingsRow(
            icon: Icons.school_outlined,
            title: 'settings_onboarding.replay'.tr(),
            trailing: Icon(Icons.chevron_right, color: ink3, size: 18),
            onTap: () => _confirmReplay(context, ref),
          ),
        ],
      ),
    );
  }
}

/// 地圖資料來源。
///
/// **這是授權義務，不是裝飾**：OpenFreeMap / OpenMapTiles / OpenStreetMap 的
/// 出處必須讓使用者合理可及（見 `docs/adr/0005-map-tile-provider.md`）。地圖
/// 上本身已有右下角的角標，那是 OSM guideline 要求的「從地圖直接可及」那一
/// 份；這裡是完整版，附 openstreetmap.org/copyright 連結。**兩者都不得移除。**
class _MapSourceGroup extends StatelessWidget {
  const _MapSourceGroup();

  static final Uri _osmCopyright = Uri.parse(
    'https://www.openstreetmap.org/copyright',
  );

  Future<void> _showAttribution(BuildContext context) {
    return showAdaptiveAlertDialog<void>(
      context: context,
      title: 'settings_map.source_title'.tr(),
      content: 'settings_map.source_body'.tr(),
      actions: [
        AdaptiveDialogAction(
          label: 'settings_map.source_link'.tr(),
          onPressed: () {
            Navigator.of(context).pop();
            launchUrl(_osmCopyright, mode: LaunchMode.externalApplication);
          },
        ),
        AdaptiveDialogAction(
          label: 'settings_map.source_close'.tr(),
          isDefault: true,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ink3 =
        Theme.of(context).extension<LorescapeTokens>()?.ink3 ??
        Theme.of(context).colorScheme.onSurfaceVariant;
    return _SettingsGroup(
      label: 'settings_map.section'.tr(),
      child: _SettingsCard(
        children: [
          _SettingsRow(
            key: const Key('settings-map-source'),
            icon: Icons.public_outlined,
            title: 'settings_map.source_title'.tr(),
            trailing: Icon(Icons.chevron_right, color: ink3, size: 18),
            onTap: () => _showAttribution(context),
          ),
        ],
      ),
    );
  }
}

class _Footer extends ConsumerWidget {
  const _Footer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appVersionAsync = ref.watch(appVersionStringProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        children: [
          appVersionAsync.when(
            data: (version) => Text(
              version,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            loading: () => const SizedBox(
              width: 12,
              height: 12,
              child: AdaptiveProgressIndicator(strokeWidth: 1),
            ),
            error: (_, __) => Text(
              'settings.app_version'.tr(),
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'settings.copyright'.tr(),
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Reusable building blocks (Field Journal style)
// ============================================================================

/// A labelled group: an uppercase section label above a [_SettingsCard].
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ink3 =
        Theme.of(context).extension<LorescapeTokens>()?.ink3 ??
        colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: ink3,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// A raised paper card holding one or more [_SettingsRow]s, separated by hair
/// dividers.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final radius = tokens.rLg;

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(
          Divider(height: 1, thickness: 1, color: colorScheme.outlineVariant),
        );
      }
      rows.add(children[i]);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(radius),
        border: Border.fromBorderSide(
          BorderSide(color: colorScheme.outlineVariant),
        ),
        boxShadow: tokens.e1,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: Column(children: rows),
      ),
    );
  }
}

/// A single settings row: a rounded-square leading icon, a title with an
/// optional subtitle, and an optional trailing widget.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _LeadingIcon(icon: icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: textTheme.bodySmall?.copyWith(height: 1.45),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );

    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

/// 38×38 rounded-square icon badge tinted with the clay accent.
class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, color: colorScheme.onPrimaryContainer, size: 20),
    );
  }
}

/// A muted trailing value, optionally followed by a chevron.
class _TrailingValue extends StatelessWidget {
  const _TrailingValue(this.text, {this.chevron = false});

  final String text;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ink3 =
        Theme.of(context).extension<LorescapeTokens>()?.ink3 ??
        colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: ink3),
        ),
        if (chevron) ...[
          const SizedBox(width: 6),
          Icon(Icons.chevron_right, color: ink3, size: 18),
        ],
      ],
    );
  }
}
