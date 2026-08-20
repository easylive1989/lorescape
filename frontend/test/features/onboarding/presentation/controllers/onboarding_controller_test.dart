import 'package:context_app/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../fakes/in_memory_onboarding_repository.dart';

void main() {
  group('OnboardingController', () {
    test('given a fresh repository, when the controller loads, '
        'then state flips to hasLoaded with welcomeDone false', () async {
      final repo = InMemoryOnboardingRepository();
      final container = _containerWith(repo);

      await _ensureLoaded(container);

      final state = container.read(onboardingControllerProvider);
      expect(state.hasLoaded, isTrue);
      expect(state.welcomeDone, isFalse);
      expect(repo.loadCalls, 1);
    });

    test('given welcome not done, when completeWelcome is called, '
        'then the flag is persisted and reflected in state', () async {
      final repo = InMemoryOnboardingRepository();
      final container = _containerWith(repo);
      await _ensureLoaded(container);

      await container
          .read(onboardingControllerProvider.notifier)
          .completeWelcome();

      expect(repo.markWelcomeDoneCalls, 1);
      expect(container.read(onboardingControllerProvider).welcomeDone, isTrue);
    });

    test('given the user has finished onboarding, when resetAll is called, '
        'then state returns to the default but stays hasLoaded', () async {
      final repo = InMemoryOnboardingRepository(welcomeDone: true);
      final container = _containerWith(repo);
      await _ensureLoaded(container);

      await container.read(onboardingControllerProvider.notifier).resetAll();

      final state = container.read(onboardingControllerProvider);
      expect(state.hasLoaded, isTrue);
      expect(state.welcomeDone, isFalse);
      expect(repo.resetCalls, 1);
    });
  });
}

ProviderContainer _containerWith(InMemoryOnboardingRepository repo) {
  final container = ProviderContainer(
    overrides: [onboardingRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _ensureLoaded(ProviderContainer container) async {
  await container.read(onboardingControllerProvider.notifier).ensureLoaded();
}
