import 'package:context_app/features/onboarding/domain/models/onboarding_state.dart';
import 'package:context_app/features/onboarding/domain/onboarding_repository.dart';

/// Test double for [OnboardingRepository] that keeps state in memory and
/// exposes counters for assertions.
class InMemoryOnboardingRepository implements OnboardingRepository {
  InMemoryOnboardingRepository({bool welcomeDone = false})
    : _welcomeDone = welcomeDone;

  bool _welcomeDone;
  int loadCalls = 0;
  int markWelcomeDoneCalls = 0;
  int resetCalls = 0;

  @override
  Future<OnboardingState> load() async {
    loadCalls += 1;
    return OnboardingState(hasLoaded: true, welcomeDone: _welcomeDone);
  }

  @override
  Future<void> markWelcomeDone() async {
    markWelcomeDoneCalls += 1;
    _welcomeDone = true;
  }

  @override
  Future<void> reset() async {
    resetCalls += 1;
    _welcomeDone = false;
  }
}
