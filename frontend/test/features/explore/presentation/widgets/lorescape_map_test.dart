import 'dart:async';

import 'package:context_app/features/explore/presentation/widgets/lorescape_map.dart';
import 'package:context_app/features/explore/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

import '../../../../helpers/fake_map_style.dart';
import '../../../../helpers/pump_app.dart';

void main() {
  setUp(() async {
    await initTestEnvironment();
  });

  testWidgets('given the map style is still loading, '
      'when the map is shown, '
      'then no map is rendered yet and no error is surfaced', (tester) async {
    await _givenLorescapeMap(tester, style: () => Completer<Style>().future);

    expect(find.byType(FlutterMap), findsNothing);
    expect(find.text('explore.map.unavailable'), findsNothing);
  });

  testWidgets('given the map style fails to load, '
      'when the map is shown, '
      'then the unavailable message is rendered instead of the map', (
    tester,
  ) async {
    await _givenLorescapeMap(tester, style: () => Future<Style>.error('boom'));

    expect(find.text('explore.map.unavailable'), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
  });

  testWidgets('given the map style loaded, '
      'when the map is shown, '
      'then the map renders and overlay children are placed on top', (
    tester,
  ) async {
    await _givenLorescapeMap(
      tester,
      style: () => Future<Style>.value(fakeMapStyle()),
      children: const [SizedBox(key: Key('overlay'))],
    );

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byKey(const Key('overlay')), findsOneWidget);
  });

  testWidgets('given the map style loaded, '
      'when the map is shown, '
      'then the licence-mandated attribution badge is painted on the map', (
    tester,
  ) async {
    await _givenLorescapeMap(
      tester,
      style: () => Future<Style>.value(fakeMapStyle()),
    );

    // 授權義務，不是裝飾：OpenFreeMap 要求原字樣顯示（見 ADR 0005）。
    // 角標畫在 LorescapeMap 內，任何用到底圖的畫面都自動帶著它。
    expect(
      find.text('OpenFreeMap © OpenMapTiles Data from OpenStreetMap'),
      findsOneWidget,
    );
  });

  testWidgets(
    'given a caller that stacks a bottom-anchored overlay on the map, '
    'when it passes attributionBottomInset, '
    'then the badge sits above that overlay instead of behind it',
    (tester) async {
      const inset = 128.0;
      await _givenLorescapeMap(
        tester,
        style: () => Future<Style>.value(fakeMapStyle()),
        attributionBottomInset: inset,
      );

      // 角標被浮層蓋住等同沒有署名，所以這裡驗的是實際幾何而不是參數有傳。
      final badge = find.text(
        'OpenFreeMap © OpenMapTiles Data from OpenStreetMap',
      );
      final mapBottom = tester.getRect(find.byType(FlutterMap)).bottom;
      expect(
        tester.getRect(badge).bottom,
        lessThanOrEqualTo(mapBottom - inset),
      );
    },
  );
}

Future<void> _givenLorescapeMap(
  WidgetTester tester, {
  required Future<Style> Function() style,
  List<Widget> children = const [],
  double attributionBottomInset = 0,
}) async {
  await pumpScreen(
    tester,
    child: LorescapeMap(
      attributionBottomInset: attributionBottomInset,
      children: children,
    ),
    // 用 factory 而非現成的 Future：先建好的 Future.error 在被 provider
    // 接手前就成了 unhandled error，測試框架會直接判定失敗。
    overrides: [
      mapStyleProvider.overrideWith((ref) => style()),
      // 版本只用來決定快取目錄名稱，測試裡給個固定值即可；不 override 的話
      // 會去讀 asset，在測試環境拿不到而讓地圖永遠停在載入中。
      mapStyleVersionProvider.overrideWith((ref) async => 'test'),
    ],
  );
  await settleMapTimers(tester);
}
