import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CLAUDE.md「依賴規則」的守門測試。
///
/// 規則：
/// 1. feature 之間只能跨引他 feature 的 `domain/` 與 `providers.dart`
///    （providers.dart 得 re-export 精選元件作為公開介面）。
/// 2. `app/` 僅得以 composition root 身分（router、shell）引用 features。
/// 3. `core/`、`shared/` 不得引用 features。
/// 4. feature 內部 `domain/` 不得引用任何 feature 的 `presentation/` 或
///    `data/`（含自己 feature）——domain 必須是純業務規則，不依賴 UI 或
///    基礎設施實作。
///
/// `_pendingCrossFeature` / `_pendingAppFiles` 是已知技術債的暫時允許
/// 清單，還債任務逐條移除；新增違規會讓本測試立即失敗。

final RegExp _featureImportRe = RegExp(
  "(?:import|export) 'package:context_app/(features/[^']+)'",
);

/// 已知跨 feature 違規：「來源檔 -> import 目標」。已清零；不得新增。
const Set<String> _pendingCrossFeature = {};

/// app/ 中已知違規檔案（整檔豁免）。已清零；不得新增。
const Set<String> _pendingAppFiles = {};

/// 已知 domain -> presentation/data 違規：「來源檔 -> import 目標」。
/// 已清零；不得新增。
const Set<String> _pendingDomainLayer = {};

/// app/ 中允許引用 features 的 composition root（檔案或目錄前綴）。
const List<String> _appCompositionRoots = [
  'lib/app/config/router_config.dart',
  'lib/app/shell/',
];

Iterable<File> _dartFiles(String root) sync* {
  final dir = Directory(root);
  if (!dir.existsSync()) return;
  yield* dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));
}

String _posix(String path) => path.replaceAll(r'\', '/');

List<String> _featureImports(File file) => _featureImportRe
    .allMatches(file.readAsStringSync())
    .map((m) => m.group(1)!)
    .toList();

void main() {
  test('掃描根目錄存在（防 cwd 錯誤時 vacuous pass）', () {
    expect(
      Directory('lib/features').existsSync(),
      isTrue,
      reason: '測試須從 frontend/ package root 執行',
    );
  });

  test('feature 之間只能跨引 domain 與 providers.dart', () {
    final violations = <String>[];
    final stillPending = <String>{};
    for (final file in _dartFiles('lib/features')) {
      final path = _posix(file.path);
      final feature = path.split('/')[2];
      for (final target in _featureImports(file)) {
        final segments = target.split('/');
        final targetFeature = segments[1];
        if (targetFeature == feature) continue;
        final rest = segments.sublist(2).join('/');
        final legal = rest == 'providers.dart' || rest.startsWith('domain/');
        if (legal) continue;
        final key = '$path -> $target';
        if (_pendingCrossFeature.contains(key)) {
          stillPending.add(key);
        } else {
          violations.add(key);
        }
      }
    }
    expect(violations, isEmpty, reason: '出現允許清單外的跨 feature 引用');
    expect(
      _pendingCrossFeature.difference(stillPending),
      isEmpty,
      reason: '允許清單中有已修復項目，請自 _pendingCrossFeature 移除',
    );
  });

  test('app/ 僅 composition root 可引用 features', () {
    final violations = <String>[];
    for (final file in _dartFiles('lib/app')) {
      final path = _posix(file.path);
      if (_appCompositionRoots.any(path.startsWith)) continue;
      if (_pendingAppFiles.contains(path)) continue;
      for (final target in _featureImports(file)) {
        violations.add('$path -> $target');
      }
    }
    expect(violations, isEmpty, reason: 'app/ 非 composition root 引用 features');
  });

  test('feature 內部 domain/ 不得引用 presentation/ 或 data/', () {
    final violations = <String>[];
    final stillPending = <String>{};
    for (final file in _dartFiles('lib/features')) {
      final path = _posix(file.path);
      final segments = path.split('/');
      // path: lib/features/<feature>/<layer>/...
      final layer = segments.length > 3 ? segments[3] : '';
      if (layer != 'domain') continue;
      for (final target in _featureImports(file)) {
        final targetLayer = target.split('/')[2];
        if (targetLayer != 'presentation' && targetLayer != 'data') continue;
        final key = '$path -> $target';
        if (_pendingDomainLayer.contains(key)) {
          stillPending.add(key);
        } else {
          violations.add(key);
        }
      }
    }
    expect(violations, isEmpty, reason: 'domain/ 反向引用 presentation/ 或 data/');
    expect(
      _pendingDomainLayer.difference(stillPending),
      isEmpty,
      reason: '允許清單中有已修復項目，請自 _pendingDomainLayer 移除',
    );
  });

  test('core/ 與 shared/ 不得引用 features', () {
    final violations = <String>[];
    for (final file in [
      ..._dartFiles('lib/core'),
      ..._dartFiles('lib/shared'),
    ]) {
      final path = _posix(file.path);
      for (final target in _featureImports(file)) {
        violations.add('$path -> $target');
      }
    }
    expect(violations, isEmpty, reason: 'core/ 或 shared/ 引用 features');
  });
}
