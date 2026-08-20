import 'dart:async';

import 'package:context_app/features/subscription/domain/errors/subscription_errors.dart';
import 'package:context_app/features/subscription/domain/models/subscription_plan.dart';
import 'package:context_app/features/subscription/domain/models/subscription_status.dart';
import 'package:context_app/features/subscription/domain/services/subscription_service.dart';

/// Fake [SubscriptionService] backed by an in-memory state controller.
///
/// Tests can seed the current status and drive purchase/restore outcomes
/// without touching RevenueCat.
class FakeSubscriptionService implements SubscriptionService {
  SubscriptionStatus _current;
  SubscriptionStatus? _purchaseResult;
  SubscriptionStatus? _restoreResult;
  Exception? _purchaseError;
  Exception? _restoreError;
  List<SubscriptionPlan> _plans = const [];
  Exception? _plansError;
  final List<SubscriptionPeriod> _purchaseCalls = [];

  final StreamController<SubscriptionStatus> _controller =
      StreamController<SubscriptionStatus>.broadcast();

  FakeSubscriptionService({
    SubscriptionStatus initial = SubscriptionStatus.free,
  }) : _current = initial;

  /// Inspect the periods that [purchase] was invoked with, in order.
  List<SubscriptionPeriod> get purchaseCalls =>
      List.unmodifiable(_purchaseCalls);

  /// Sets the value returned by [purchase].
  ///
  /// When [status] is `null`, [purchase] simulates user cancellation.
  /// When [error] is non-null, [purchase] throws it.
  void stubPurchase({SubscriptionStatus? status, Exception? error}) {
    _purchaseResult = status;
    _purchaseError = error;
  }

  /// Sets the value returned by [restorePurchases].
  void stubRestore({SubscriptionStatus? status, Exception? error}) {
    _restoreResult = status;
    _restoreError = error;
  }

  /// Sets the value returned by [getAvailablePlans].
  ///
  /// When [plans] is `null`, [getAvailablePlans] returns an empty list
  /// (matching "no offerings"). When [error] is non-null, it throws.
  void stubGetAvailablePlans({
    List<SubscriptionPlan>? plans,
    Exception? error,
  }) {
    _plans = plans ?? const [];
    _plansError = error;
  }

  /// Emits [status] on [statusStream] and updates current status.
  void emit(SubscriptionStatus status) {
    _current = status;
    _controller.add(status);
  }

  @override
  Future<void> initialize({required String apiKey}) async {
    _controller.add(_current);
  }

  @override
  Future<void> logIn(String userId) async {}

  @override
  Future<void> logOut() async {}

  @override
  Stream<SubscriptionStatus> get statusStream => _controller.stream;

  @override
  Future<SubscriptionStatus> getStatus() async => _current;

  @override
  Future<SubscriptionStatus?> purchase(SubscriptionPeriod period) async {
    _purchaseCalls.add(period);
    if (_purchaseError != null) throw _purchaseError!;
    final exists = _plans.any((p) => p.period == period);
    if (!exists && _plans.isNotEmpty) {
      throw SubscriptionPlanNotAvailableException(period);
    }
    if (_purchaseResult != null) {
      emit(_purchaseResult!);
    }
    return _purchaseResult;
  }

  @override
  Future<SubscriptionStatus> restorePurchases() async {
    if (_restoreError != null) throw _restoreError!;
    final result = _restoreResult ?? _current;
    emit(result);
    return result;
  }

  @override
  Future<List<SubscriptionPlan>> getAvailablePlans() async {
    if (_plansError != null) throw _plansError!;
    return _plans;
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
