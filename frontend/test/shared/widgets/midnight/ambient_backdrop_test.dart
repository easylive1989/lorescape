import 'package:context_app/app/config/app_colors.dart';
import 'package:context_app/shared/widgets/midnight/ambient_backdrop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AmbientBackdrop', () {
    testWidgets('renders child on top', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AmbientBackdrop(child: Text('content'))),
      );
      expect(find.text('content'), findsOneWidget);
    });

    testWidgets('paints backgroundDark as the base layer', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AmbientBackdrop(child: SizedBox.shrink())),
      );
      final coloredBoxes = find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == AppColors.backgroundDark,
      );
      expect(coloredBoxes, findsAtLeastNWidgets(1));
    });

    testWidgets('honours decorationImage when provided', (tester) async {
      // Suppress image-not-found errors from the fake asset.
      final errors = <FlutterErrorDetails>[];
      final original = FlutterError.onError;
      FlutterError.onError = errors.add;

      await tester.pumpWidget(
        const MaterialApp(
          home: AmbientBackdrop(
            decorationImage: DecorationImage(
              image: AssetImage('assets/test_texture.png'),
              fit: BoxFit.cover,
            ),
            child: SizedBox.shrink(),
          ),
        ),
      );
      // Allow image error handler to run.
      await tester.pump(const Duration(milliseconds: 200));

      FlutterError.onError = original;

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).image != null,
        ),
        findsAtLeastNWidgets(1),
      );
    });
  });
}
