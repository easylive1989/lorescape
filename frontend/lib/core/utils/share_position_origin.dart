import 'package:flutter/widgets.dart';

/// The screen-space rect of [context]'s render box, for use as the
/// share sheet's `sharePositionOrigin`.
///
/// iOS rejects a share sheet whose origin is empty: `share_plus`
/// bails out with a `FlutterError` when the activity view controller
/// carries a popover presentation controller and the origin rect is
/// `CGRectZero`. Before Xcode 26 that popover controller only existed
/// on iPad, so omitting the origin merely broke tablets; built with
/// Xcode 26 it exists on iPhone too and the sheet never appears at
/// all. See share_plus issue #3699.
///
/// Returns null when the element is not laid out, which callers pass
/// straight through — on Android the argument is ignored anyway.
Rect? sharePositionOriginOf(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}
