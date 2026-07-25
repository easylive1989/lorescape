// 一次性產圖工具：把 MountainPainter 渲染成靜態 PNG，供
// flutter_native_splash 當作原生 splash 的 mark，確保系統 splash → Flutter
// splash（SplashScreen）無縫交棒（同一份幾何、同一色）。
//
// 執行：fvm flutter test test/tool/generate_splash_mark.dart
// 產出：assets/images/splash_mark.png（progress=1 的米白山形，透明底）
import 'dart:io';
import 'dart:ui' as ui;

import 'package:context_app/app/config/lorescape_tokens.dart';
import 'package:context_app/features/splash/presentation/mountain_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generate splash_mark.png', () async {
    const dim = 512.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    MountainPainter(
      strokeProgress: 1,
      footprintProgress: 1,
      color: LorescapeTokens.fallback.paper,
    ).paint(canvas, const Size(dim, dim));
    final img = await recorder.endRecording().toImage(dim.toInt(), dim.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final file = File('assets/images/splash_mark.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    expect(file.existsSync(), isTrue);
  });
}
