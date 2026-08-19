import 'package:context_app/app/config/router_config.dart';
import 'package:context_app/features/analytics/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

List<String> _routePaths() {
  final container = ProviderContainer(
    overrides: [
      // Avoids touching Firebase during router construction (see
      // router_splash_test.dart for the same workaround).
      routeObserversProvider.overrideWithValue(const []),
    ],
  );
  addTearDown(container.dispose);

  return container
      .read(routerProvider)
      .configuration
      .routes
      .whereType<GoRoute>()
      .map((route) => route.path)
      .toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('given the app router, '
      'when listing its top-level routes, '
      'then the flat globe-home layout is in place', () {
    expect(_routePaths(), containsAll(['/', '/map', '/settings']));
  });

  test('given the bookshelf is part of the product again, '
      'when listing the router top-level routes, '
      'then journey and all five trip routes are registered', () {
    expect(
      _routePaths(),
      containsAll([
        '/journey',
        '/trips',
        '/trip/edit',
        '/trip/edit/:id',
        '/trip/uncategorized',
        '/trip/:id',
      ]),
    );
  });
}
