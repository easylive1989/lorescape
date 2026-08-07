import 'package:context_app/core/utils/share_position_origin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sharePositionOriginOf', () {
    testWidgets(
      'given a laid-out widget, when the origin is read, then it is that '
      "widget's rect in screen coordinates",
      (tester) async {
        late BuildContext buttonContext;

        await tester.pumpWidget(
          MaterialApp(
            home: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 30, top: 40),
                child: SizedBox(
                  width: 120,
                  height: 50,
                  child: Builder(
                    builder: (context) {
                      buttonContext = context;
                      return const SizedBox.expand();
                    },
                  ),
                ),
              ),
            ),
          ),
        );

        expect(
          sharePositionOriginOf(buttonContext),
          const Rect.fromLTWH(30, 40, 120, 50),
        );
      },
    );

    testWidgets(
      'given a widget scrolled down a list, when the origin is read, then it '
      'follows the widget on screen instead of its offset in the list',
      (tester) async {
        late BuildContext rowContext;

        await tester.pumpWidget(
          MaterialApp(
            home: ListView(
              children: [
                for (var i = 0; i < 20; i++)
                  SizedBox(
                    height: 100,
                    child: i == 5
                        ? Builder(
                            builder: (context) {
                              rowContext = context;
                              return const SizedBox.expand();
                            },
                          )
                        : const SizedBox.expand(),
                  ),
              ],
            ),
          ),
        );

        final beforeScroll = sharePositionOriginOf(rowContext)!;
        await tester.drag(find.byType(ListView), const Offset(0, -100));
        await tester.pumpAndSettle();
        final afterScroll = sharePositionOriginOf(rowContext)!;

        expect(afterScroll.top, beforeScroll.top - 100);
        // iOS rejects an empty origin outright, so the rect must keep
        // real bounds whatever the scroll position.
        expect(afterScroll.isEmpty, isFalse);
      },
    );
  });
}
