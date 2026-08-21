import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:context_app/shared/widgets/adaptive/adaptive_dialog.dart';

/// Shows a platform-appropriate action sheet and returns the chosen action's
/// `result` (null when dismissed or cancelled).
///
/// On iOS/macOS renders a `CupertinoActionSheet` — the platform convention for
/// «which of these do you mean?», where a destructive item doubles as its own
/// confirmation. On other platforms renders a Material modal bottom sheet with
/// one list tile per action.
///
/// [cancelLabel] adds the trailing cancel affordance; omit it for sheets that
/// can only be dismissed by tapping outside.
Future<T?> showAdaptiveActionSheet<T>({
  required BuildContext context,
  String? title,
  String? message,
  required List<AdaptiveDialogAction<T>> actions,
  String? cancelLabel,
}) {
  final platform = Theme.of(context).platform;
  final isCupertino =
      platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

  if (isCupertino) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: title == null ? null : Text(title),
        message: message == null ? null : Text(message),
        actions: [
          for (final action in actions)
            CupertinoActionSheetAction(
              onPressed: () => _run(ctx, action),
              isDefaultAction: action.isDefault,
              isDestructiveAction: action.isDestructive,
              child: Text(action.label),
            ),
        ],
        cancelButton: cancelLabel == null
            ? null
            : CupertinoActionSheetAction(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(cancelLabel),
              ),
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final colorScheme = Theme.of(ctx).colorScheme;
      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null || message != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (title != null)
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(ctx).textTheme.titleMedium,
                      ),
                    if (message != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              ),
            for (final action in actions)
              ListTile(
                title: Text(
                  action.label,
                  style: action.isDestructive
                      ? TextStyle(color: colorScheme.error)
                      : null,
                ),
                onTap: () => _run(ctx, action),
              ),
            if (cancelLabel != null)
              ListTile(
                title: Text(cancelLabel),
                onTap: () => Navigator.of(ctx).pop(),
              ),
          ],
        ),
      );
    },
  );
}

void _run<T>(BuildContext context, AdaptiveDialogAction<T> action) {
  if (action.onPressed != null) {
    action.onPressed!();
    return;
  }
  Navigator.of(context).pop(action.result);
}
