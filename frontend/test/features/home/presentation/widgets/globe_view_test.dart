import 'package:context_app/features/home/domain/globe/world_outline.dart';
import 'package:context_app/features/home/domain/models/globe_pin.dart';
import 'package:context_app/features/home/presentation/widgets/globe_painter.dart';
import 'package:context_app/features/home/presentation/widgets/globe_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import '../../../../helpers/pump_app.dart';

final _outline = WorldOutline.parse(
  '{"rings":[[0,0,10,0,10,10,0,10]]}',
);

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

  testWidgets(
    'given a focused pin, '
    'when the globe renders, '
    'then its label chip is shown',
    (tester) async {
      await _givenGlobe(tester);

      expect(find.text('聖伯多祿大殿'), findsOneWidget);
    },
  );

  testWidgets(
    'given a globe focused on one pin, '
    'when the focus changes to another pin, '
    'then the chip shows the new label once the flight settles',
    (tester) async {
      await _givenGlobe(tester);

      await _givenGlobe(tester, focus: _taichung);
      await tester.pumpAndSettle();

      expect(find.text('四面佛寺'), findsOneWidget);
      expect(find.text('聖伯多祿大殿'), findsNothing);
    },
  );

  testWidgets(
    'given a rendered globe, '
    'when the user drags across it, '
    'then the painter repaints with a different rotation',
    (tester) async {
      await _givenGlobe(tester);
      double lambda() => (tester
              .widget<CustomPaint>(find.byKey(GlobeView.canvasKey))
              .painter!
          as GlobePainter)
          .rotation
          .lambda;
      final before = lambda();

      await tester.drag(find.byKey(GlobeView.canvasKey), const Offset(80, 0));
      await tester.pump();

      // 拖曳增益 0.32，80px 應該轉出約 25.6 度。
      expect(lambda() - before, closeTo(25.6, 0.01));
    },
  );
}
