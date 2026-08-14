import 'package:flutter/widgets.dart';

/// 全案配色。美術風格聖經定的是龐貝壁畫色調——暖灰、赭、奶油白，**沒有紫色**。
/// Material 3 不給 seed 就會發預設的紫，所以主題與所有自訂元件都從這裡取色。
abstract final class VnColors {
  /// 對話框與名牌的底。
  static const Color ground = Color(0xFF1C1A19);

  /// 正文。
  static const Color body = Color(0xFFF2ECE1);

  /// 名牌與次要文字。
  static const Color muted = Color(0xFFE8DCC8);

  /// 塗鴉樣式的旁白，以及邊框。
  static const Color ochre = Color(0xFFB9A98C);

  /// 讀不到背景時的底色。
  static const Color backdrop = Color(0xFF0E0D0C);
}

/// Flutter製作規範 §2 的版面數值，全部收在這裡。改版面只改這個檔。
final class VnLayout {
  const VnLayout(this.size);

  factory VnLayout.of(BuildContext context) => VnLayout(MediaQuery.sizeOf(context));

  final Size size;

  double get w => size.width;
  double get h => size.height;

  double get dialogueHeight => h * 0.35;
  double get spriteHeight => h * 0.72;

  /// 立繪底邊置於 0.88h ⇒ 距畫面底部 0.12h。下緣被對話框蓋住是預期行為。
  double get spriteBottom => h * 0.12;
  double get spriteOffset => w * 0.18;
  double get sideInset => w * 0.06;
  double get choiceInset => w * 0.10;
  double get safeInset => h * 0.08;
  double get bodyFontSize => w / 20;

  /// 選項區的上下界（規範 §2：0.45H–0.75H）。距底 0.25H。
  double get choiceTop => h * 0.45;
  double get choiceBottom => h * 0.25;
}
