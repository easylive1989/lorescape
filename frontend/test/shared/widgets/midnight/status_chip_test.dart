import 'package:context_app/shared/widgets/midnight/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('StatusChip', () {
    testWidgets('renders label uppercased', (tester) async {
      await tester.pumpWidget(host(const StatusChip(label: 'Active')));
      expect(find.text('ACTIVE'), findsOneWidget);
    });

    testWidgets('renders icon when provided', (tester) async {
      await tester.pumpWidget(
        host(const StatusChip(label: 'Saved', icon: Icons.bookmark)),
      );
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
    });

    testWidgets('all tones render without crash', (tester) async {
      for (final tone in StatusChipTone.values) {
        await tester.pumpWidget(host(StatusChip(label: tone.name, tone: tone)));
        expect(find.text(tone.name.toUpperCase()), findsOneWidget);
      }
    });
  });
}
