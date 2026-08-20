import 'package:context_app/app/config/router_config.dart';
import 'package:context_app/features/analytics/providers.dart';
import 'package:context_app/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/in_memory_onboarding_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('given the app router, when it is created, '
      'then it starts at /splash', () {
    final container = ProviderContainer(
      overrides: [
        // Avoids touching Firebase during router construction.
        routeObserversProvider.overrideWithValue(const []),
        onboardingRepositoryProvider.overrideWithValue(
          InMemoryOnboardingRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final router = container.read(routerProvider);

    expect(router.routeInformationProvider.value.uri.toString(), '/splash');
  });
}
