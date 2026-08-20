// 同步的開關已經拿掉：登入本身就是開關——有正式帳號就自動同步，匿名帳號
// 完全不上傳。這裡釘住的是那個決定的兩個要害——
//   1. syncSessionProvider 只認正式帳號，匿名 session 不會讓資料離開裝置。
//   2. syncBootstrapProvider 在 session 第一次讀到就已經是 active 時（冷啟動
//      的實際情況）也要跑 full sync。用 ref.listen 的話這裡會無聲失敗。
// 衝突解法與各 repository 的接線分別由 sync_merger_test 與
// syncing_journey_repository_test 覆蓋。

import 'package:context_app/features/auth/domain/models/auth_user.dart';
import 'package:context_app/features/auth/providers.dart';
import 'package:context_app/features/journey/domain/models/journey_entry.dart';
import 'package:context_app/features/sync/domain/services/sync_coordinator.dart';
import 'package:context_app/features/sync/domain/services/sync_engine.dart';
import 'package:context_app/features/sync/providers.dart';
import 'package:context_app/features/trip/domain/models/trip.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fakes/fake_auth_service.dart';

const _permanentUser = AuthUser(
  id: 'user-42',
  email: 'u@example.com',
  displayName: 'U',
);

const _anonymousUser = AuthUser(id: 'anon-7', isAnonymous: true);

/// 只數 runFullSync 被呼叫幾次；engine 本身不該被碰到，碰到就是接線錯了。
class _SpyCoordinator implements SyncCoordinator {
  int fullSyncCount = 0;

  @override
  Future<void> runFullSync() async => fullSyncCount++;

  @override
  SyncEngine<JourneyEntry> get journey => throw UnimplementedError();

  @override
  SyncEngine<Trip> get trip => throw UnimplementedError();
}

/// 讓 stream 事件與 Riverpod 的通知都跑完。
///
/// 兩者不在同一個 event-loop turn：authStateChanges 的事件先到，provider 的
/// listener 是下一輪才被通知。只等一輪的話會量到「還沒發生」而誤判。
Future<void> _settle() async {
  for (var i = 0; i < 3; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

ProviderContainer _container({AuthUser? user, SyncCoordinator? coordinator}) {
  // 沒有這個 override，syncSessionProvider 會去 watch 真的 Supabase
  // authStateChanges() stream 然後炸掉。
  final container = ProviderContainer(
    overrides: [
      authServiceProvider.overrideWithValue(
        FakeAuthService(initialUser: user),
      ),
      if (coordinator != null)
        syncCoordinatorProvider.overrideWithValue(coordinator),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(() {
    WidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Sync session composition', () {
    test(
      'given no user at all, when the session is read, then it is inactive',
      () async {
        expect(_container().read(syncSessionProvider).isActive, isFalse);
      },
    );

    test(
      'given only an anonymous session, when the session is read, then it is '
      'inactive — anonymous data never leaves the device',
      () async {
        final container = _container(user: _anonymousUser);
        container.read(authStateProvider);
        await _settle();

        final session = container.read(syncSessionProvider);

        expect(session.isActive, isFalse);
        expect(session.userId, isNull);
      },
    );

    test(
      'given a signed-in user, when the session is read, then it is active',
      () async {
        final container = _container(user: _permanentUser);
        container.read(authStateProvider);
        await _settle();

        final session = container.read(syncSessionProvider);

        expect(session.isActive, isTrue);
        expect(session.userId, 'user-42');
      },
    );
  });

  group('Sync bootstrap', () {
    test(
      'given the session is already active on the very first read — what a '
      'cold start actually looks like — when the bootstrap provider is '
      'watched, then a full sync still runs',
      () async {
        // Supabase 的 session 在建 widget tree 之前就還原好了（main() 的
        // init() 裡 await 完才建），所以第一次 build 時 session 就已經
        // active，不會有「非啟用 → 啟用」的轉換可以聽。
        final coordinator = _SpyCoordinator();
        final container = _container(
          user: _permanentUser,
          coordinator: coordinator,
        );

        container.read(syncBootstrapProvider);

        expect(coordinator.fullSyncCount, 1);
      },
    );

    test(
      'given only an anonymous session, when the bootstrap provider is '
      'watched, then nothing is uploaded',
      () async {
        final coordinator = _SpyCoordinator();
        final container = _container(
          user: _anonymousUser,
          coordinator: coordinator,
        );

        container.listen(syncBootstrapProvider, (_, __) {});
        await _settle();

        expect(coordinator.fullSyncCount, 0);
      },
    );

    test(
      'given an anonymous user who then signs in, when the session becomes '
      'active, then their local data is finally uploaded',
      () async {
        final coordinator = _SpyCoordinator();
        final auth = FakeAuthService(initialUser: _anonymousUser);
        addTearDown(auth.dispose);
        final container = ProviderContainer(
          overrides: [
            authServiceProvider.overrideWithValue(auth),
            syncCoordinatorProvider.overrideWithValue(coordinator),
          ],
        );
        addTearDown(container.dispose);

        // 保持訂閱，session 變動時 listener 才會被通知。
        container.listen(syncBootstrapProvider, (_, __) {});
        container.read(authStateProvider);
        await _settle();
        expect(coordinator.fullSyncCount, 0, reason: '匿名階段不上傳');

        await auth.signInWithGoogle();
        await _settle();

        expect(coordinator.fullSyncCount, 1, reason: '登入後才第一次同步');
      },
    );
  });
}
