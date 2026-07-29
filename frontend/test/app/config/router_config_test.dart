import 'package:context_app/app/config/router_config.dart';
import 'package:context_app/features/analytics/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('given the app router, '
      'when listing its top-level routes, '
      'then the flat globe-home layout is in place', () {
    final container = ProviderContainer(
      overrides: [
        // Avoids touching Firebase during router construction (see
        // router_splash_test.dart for the same workaround).
        routeObserversProvider.overrideWithValue(const []),
      ],
    );
    addTearDown(container.dispose);

    final paths = container
        .read(routerProvider)
        .configuration
        .routes
        .whereType<GoRoute>()
        .map((route) => route.path)
        .toList();

    expect(paths, containsAll(['/', '/map', '/journey', '/settings']));
  });
}
