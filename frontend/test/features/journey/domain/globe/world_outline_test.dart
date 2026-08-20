import 'package:context_app/features/journey/domain/globe/world_outline.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('given a compact rings payload, '
      'when parsing it, '
      'then each flat coordinate pair becomes a LatLng in lng/lat order', () {
    final outline = WorldOutline.parse(
      '{"rings":[[12.45,41.9,12.5,41.95,12.45,41.9]]}',
    );

    expect(outline.rings, hasLength(1));
    expect(outline.rings.single, hasLength(3));
    expect(outline.rings.single.first.latitude, 41.9);
    expect(outline.rings.single.first.longitude, 12.45);
  });

  testWidgets('given the bundled world outline asset, '
      'when loading it, '
      'then it yields the full Natural Earth 110m ring set', (tester) async {
    // WorldOutline.load 用 compute() 開真正的背景 isolate；testWidgets
    // 預設跑在 FakeAsync zone，等不到真實 isolate 的回應會卡死，所以要用
    // runAsync 讓這段跳出 FakeAsync、用真實事件迴圈執行。
    final outline = (await tester.runAsync(
      () => WorldOutline.load(rootBundle),
    ))!;

    // 127 個 land feature，但其中歐亞大陸的 Polygon 挖了一個裡海形狀的
    // 內環（裡海是內陸水域），所以環數是 128，不是 127。
    expect(outline.rings, hasLength(128));
    expect(
      outline.rings.every((ring) => ring.length >= 4),
      isTrue,
      reason: '每條環至少要有 4 個點才畫得出多邊形',
    );
  });
}
