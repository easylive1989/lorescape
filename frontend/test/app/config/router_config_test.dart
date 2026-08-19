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
      'then the map is the home route and /map is gone', () {
    final paths = _routePaths();
    expect(paths, containsAll(['/', '/settings']));
    expect(paths, isNot(contains('/map')));
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

  test('given the daily story feature is gone from the app, '
      'when listing the router top-level routes, '
      'then neither the detail route nor the story deep link is registered', () {
    final paths = _routePaths();
    expect(paths, isNot(contains('/daily-story/detail')));
    expect(paths, isNot(contains('/:locale/story/:date')));
  });

  test('given the paywall is back, '
      'when listing the router top-level routes, '
      'then /subscription is registered', () {
    expect(_routePaths(), contains('/subscription'));
  });
}
