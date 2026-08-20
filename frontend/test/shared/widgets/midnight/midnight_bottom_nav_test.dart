import 'package:context_app/shared/widgets/midnight/midnight_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  const items = [
    MidnightBottomNavItem(icon: Icons.explore, label: 'Explore'),
    MidnightBottomNavItem(icon: Icons.location_on, label: 'Nearby'),
    MidnightBottomNavItem(icon: Icons.bookmark, label: 'Saved'),
    MidnightBottomNavItem(icon: Icons.person, label: 'Profile'),
  ];

  group('MidnightBottomNav', () {
    testWidgets('renders all items', (tester) async {
      await tester.pumpWidget(
        host(MidnightBottomNav(items: items, currentIndex: 0, onTap: (_) {})),
      );
      expect(find.text('EXPLORE'), findsOneWidget);
      expect(find.text('NEARBY'), findsOneWidget);
      expect(find.text('SAVED'), findsOneWidget);
      expect(find.text('PROFILE'), findsOneWidget);
    });

    testWidgets('invokes onTap with item index', (tester) async {
      var lastIndex = -1;
      await tester.pumpWidget(
        host(
          MidnightBottomNav(
            items: items,
            currentIndex: 0,
            onTap: (i) => lastIndex = i,
          ),
        ),
      );
      await tester.tap(find.text('SAVED'));
      expect(lastIndex, 2);
    });
  });
}
