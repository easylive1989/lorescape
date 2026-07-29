import 'package:flutter/painting.dart';

/// 地球儀專屬的插畫色。
///
/// 這幾個顏色不在 `LorescapeTokens` 裡——它們只描述那顆手繪風的球（米白
/// 的海、抹茶綠的陸地），不是全 App 的語意色票，放進 tokens 反而會讓別的
/// 畫面誤用。
abstract final class GlobePalette {
  static const Color ocean = Color(0xFFFCF8ED);
  static const Color land = Color(0xFFCBD8A9);
  static const Color landStroke = Color.fromRGBO(101, 116, 74, 0.42);
  static const Color graticule = Color.fromRGBO(111, 124, 86, 0.17);
  static const Color rim = Color.fromRGBO(120, 106, 70, 0.3);
  static const Color shadeEdge = Color.fromRGBO(120, 106, 70, 0.22);
  static const Color pinDot = Color(0xFF5F7148);
  static const Color pinDotStroke = ocean;
  static const Color pinLabel = Color(0xFF6E6350);
}
