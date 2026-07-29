import 'package:context_app/features/home/domain/globe/globe_rotation.dart';
import 'package:context_app/features/home/domain/globe/orthographic_projection.dart';
import 'package:context_app/features/home/domain/globe/world_outline.dart';
import 'package:context_app/features/home/domain/models/globe_pin.dart';
import 'package:context_app/features/home/presentation/widgets/globe_painter.dart';
import 'package:context_app/features/home/presentation/widgets/globe_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import '../../../../helpers/pump_app.dart';

final _outline = WorldOutline.parse('{"rings":[[0,0,10,0,10,10,0,10]]}');

const _rome = GlobePin(
  id: 'stpeters',
  coordinate: LatLng(41.9, 12.45),
  label: '聖伯多祿大殿',
);
const _taichung = GlobePin(
  id: 'temple',
  coordinate: LatLng(24.06, 120.54),
  label: '四面佛寺',
);

Future<void> _givenGlobe(WidgetTester tester, {GlobePin? focus}) async {
  await pumpScreen(
    tester,
    child: Scaffold(
      body: Center(
        child: GlobeView(
          outline: _outline,
          pins: const [_rome, _taichung],
          focus: focus ?? _rome,
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(initTestEnvironment);

  testWidgets('given a focused pin, '
      'when the globe renders, '
      'then its label chip is shown', (tester) async {
    await _givenGlobe(tester);

    expect(find.text('聖伯多祿大殿'), findsOneWidget);
  });

  testWidgets('given a globe focused on one pin, '
      'when the focus changes to another pin, '
      'then the chip shows the new label once the flight settles', (
    tester,
  ) async {
    await _givenGlobe(tester);

    await _givenGlobe(tester, focus: _taichung);
    await tester.pumpAndSettle();

    expect(find.text('四面佛寺'), findsOneWidget);
    expect(find.text('聖伯多祿大殿'), findsNothing);

    // 光是看 chip 文字換了不夠：_FocusMarker 的 label 直接讀
    // widget.focus.label，跟飛行動畫轉到哪完全無關，就算動畫卡在半路也會
    // 顯示新標籤。這裡額外驗證 settle 後的旋轉真的落在台中正面，才是
    // 測試名稱說的「flight settles」。
    final rotation =
        (tester.widget<CustomPaint>(find.byKey(GlobeView.canvasKey)).painter!
                as GlobePainter)
            .rotation;
    final expected = GlobeRotation.facing(_taichung.coordinate);
    expect(rotation.lambda, closeTo(expected.lambda, 0.01));
    expect(rotation.phi, closeTo(expected.phi, 0.01));
  });

  testWidgets('given a rendered globe, '
      'when the user drags across it, '
      'then the painter repaints with a different rotation', (tester) async {
    await _givenGlobe(tester);
    double lambda() =>
        (tester.widget<CustomPaint>(find.byKey(GlobeView.canvasKey)).painter!
                as GlobePainter)
            .rotation
            .lambda;
    final before = lambda();

    await tester.drag(find.byKey(GlobeView.canvasKey), const Offset(80, 0));
    await tester.pump();

    // 拖曳增益 0.32，80px 應該轉出約 25.6 度。
    expect(lambda() - before, closeTo(25.6, 0.01));
  });

  testWidgets('given the globe constrained narrower than its default 344 size, '
      'when it renders a focused pin, '
      'then the marker offset matches the painter’s actual radius/center', (
    tester,
  ) async {
    // 320pt 寬的裝置（或開了「顯示縮放」的 iPhone）：外層給的 maxWidth
    // 比 GlobeView 預設的 344 窄，SizedBox 會被壓小。
    const narrowWidth = 320.0;
    await pumpScreen(
      tester,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: narrowWidth,
          height: narrowWidth,
          child: GlobeView(
            outline: _outline,
            pins: const [_rome],
            focus: _rome,
          ),
        ),
      ),
    );

    // 畫布真的被壓到窄螢幕的尺寸，而不是保持預設的 344。
    final canvasSize = tester.getSize(find.byKey(GlobeView.canvasKey));
    expect(canvasSize.width, narrowWidth);
    expect(canvasSize.height, narrowWidth);

    // marker 的 Positioned 座標必須跟畫布實際尺寸算出來的投影一致；如果
    // 還是用 widget.size（344）當基準，這裡會對不上。
    final positioned = tester.widget<Positioned>(
      find
          .ancestor(
            of: find.text(_rome.label),
            matching: find.byType(Positioned),
          )
          .first,
    );
    final expectedProjection = OrthographicProjection(
      rotation: GlobeRotation.facing(_rome.coordinate),
      center: const Offset(narrowWidth / 2, narrowWidth / 2),
      radius: narrowWidth / 2 - 3,
    );
    final expectedOffset = expectedProjection.project(_rome.coordinate)!;
    expect(positioned.left, closeTo(expectedOffset.dx, 0.5));
    expect(positioned.top, closeTo(expectedOffset.dy, 0.5));
  });
}
