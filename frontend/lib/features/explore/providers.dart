import 'dart:convert';

import 'package:context_app/core/utils/geo_utils.dart';
import 'package:context_app/features/explore/domain/use_cases/search_nearby_places_use_case.dart';
import 'package:context_app/features/explore/data/services/geolocator_service.dart';
import 'package:context_app/features/explore/data/services/wikidata_landmark_query_service.dart';
import 'package:context_app/features/explore/data/services/wikipedia_places_service.dart';
import 'package:context_app/features/explore/data/services/hive_places_cache_service.dart';
import 'package:context_app/features/explore/data/services/map_tile_cache_service.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:context_app/features/explore/domain/repositories/places_repository.dart';
import 'package:context_app/features/explore/domain/services/location_service.dart';
import 'package:context_app/features/explore/data/repositories/places_repository_impl.dart';
import 'package:context_app/features/explore/data/repositories/caching_places_repository.dart';
import 'package:context_app/features/explore/domain/models/place.dart';
import 'package:context_app/features/explore/domain/models/place_location.dart';
import 'package:context_app/features/settings/domain/models/language.dart';
import 'package:context_app/features/settings/providers.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart'
    show ThemeReader;

// Feature 公開介面：providers.dart 得 re-export 精選元件供他 feature 使用。
export 'presentation/extensions/place_category_extension.dart';

// Infrastructure Providers
final locationServiceProvider = Provider<LocationService>((ref) {
  return GeolocatorService();
});

final wikipediaPlacesServiceProvider = Provider<WikipediaPlacesService>((ref) {
  return WikipediaPlacesService();
});

final wikidataLandmarkQueryServiceProvider =
    Provider<WikidataLandmarkQueryService>((ref) {
      return WikidataLandmarkQueryService();
    });

final placesRepositoryProvider = Provider<PlacesRepository>((ref) {
  final service = ref.watch(wikipediaPlacesServiceProvider);
  final landmarkService = ref.watch(wikidataLandmarkQueryServiceProvider);
  final cacheService = ref.watch(placesCacheServiceProvider);
  final apiRepository = PlacesRepositoryImpl(
    service,
    landmarkService: landmarkService,
  );
  return CachingPlacesRepository(apiRepository, cacheService);
});

final placesCacheServiceProvider = Provider<HivePlacesCacheService>((ref) {
  return HivePlacesCacheService();
});

// Map Providers

/// OpenFreeMap 的上游 style JSON。**不要改成硬編 tile URL**——tile 路徑帶著
/// 每週重建的日期段（例如 `/planet/20260621_080001_pt/{z}/{x}/{y}.pbf`），
/// 必須由 style/TileJSON 在執行期解析。選型與授權義務見
/// `docs/adr/0005-map-tile-provider.md`。
const String kMapStyleUrl = 'https://tiles.openfreemap.org/styles/positron';

/// 重新上色成 field journal 色票的本地樣式，由 `tool/build_map_style.py`
/// 從上游 positron 產生。
const String kLorescapeStyleAsset = 'assets/map/lorescape_style.json';

final mapTileCacheServiceProvider = Provider<MapTileCacheService>((ref) {
  return const MapTileCacheService();
});

/// 目前樣式的版本（內容雜湊，由 `tool/build_map_style.py` 寫入
/// `metadata.version`）。用來隔離 tile 快取目錄，見 [mapCacheFolderProvider]。
final mapStyleVersionProvider = FutureProvider<String>((ref) async {
  ref.keepAlive();
  final json =
      jsonDecode(await rootBundle.loadString(kLorescapeStyleAsset))
          as Map<String, dynamic>;
  return (json['metadata'] as Map<String, dynamic>?)?['version'] as String? ??
      'unknown';
});

/// 讀取並快取地圖樣式。
///
/// 兩邊各司其職：**配色**來自本地 asset（我們控制，才能對上設計稿的暖紙感），
/// **tile 來源與 sprites** 仍交給上游 `StyleReader` 解析——那段包含每週變動的
/// tile 路徑，寫死會在下次重建時壞掉。
///
/// 讀取會打數個網路請求，故以 provider 快取、全 App 只讀一次。
final mapStyleProvider = FutureProvider<Style>((ref) async {
  ref.keepAlive();
  final upstream = await StyleReader(uri: kMapStyleUrl).read();
  final localJson =
      jsonDecode(await rootBundle.loadString(kLorescapeStyleAsset))
          as Map<String, dynamic>;
  final theme = ThemeReader().read(localJson);
  // 只保留本地樣式真的會用到的 source。上游 positron 還帶著一個 Natural Earth
  // 的 raster source（`ne2_shaded`），我們的樣式沒有任何圖層引用它，全部照收
  // 會讓 App 白白下載一堆永遠不會顯示的 PNG（2026-07-21 在快取目錄裡實際看到）。
  final providers = TileProviders({
    for (final source in theme.tileSources)
      if (upstream.providers.tileProviderBySource[source] case final provider?)
        source: provider,
  });
  return Style(
    name: localJson['name'] as String?,
    theme: theme,
    providers: providers,
    sprites: upstream.sprites,
  );
});

// Filter Providers

/// 使用者目前位置，由 [PlacesController] 在載入附近地點時更新
final userLocationProvider = StateProvider<PlaceLocation?>((ref) => null);

/// 探索頁面預設的距離過濾上限（公尺）。
const double kDefaultMaxDistanceMeters = 10000.0;

/// 距離過濾上限（公尺），預設 [kDefaultMaxDistanceMeters]
final maxDistanceProvider = StateProvider<double>(
  (ref) => kDefaultMaxDistanceMeters,
);

/// 目前的搜尋關鍵字；空字串表示顯示附近地點模式
final searchQueryProvider = StateProvider<String>((ref) => '');

/// 根據最大距離過濾後的地點列表
///
/// 監聽 [placesControllerProvider]、[maxDistanceProvider] 與
/// [userLocationProvider]，當任一改變時自動重新過濾。
/// 在搜尋模式（[searchQueryProvider] 非空）下跳過距離過濾。
final filteredPlacesProvider = Provider<AsyncValue<List<Place>>>((ref) {
  final placesAsync = ref.watch(placesControllerProvider);
  final maxDistance = ref.watch(maxDistanceProvider);
  final userLocation = ref.watch(userLocationProvider);
  final searchQuery = ref.watch(searchQueryProvider);

  return placesAsync.whenData((places) {
    if (searchQuery.isNotEmpty) return places;
    if (userLocation == null) return places;
    return places.where((p) {
      final distance = calculateHaversineDistance(
        fromLatitude: userLocation.latitude,
        fromLongitude: userLocation.longitude,
        toLatitude: p.location.latitude,
        toLongitude: p.location.longitude,
      );
      return distance <= maxDistance;
    }).toList();
  });
});

// Use Case Providers
final searchNearbyPlacesUseCaseProvider = Provider<SearchNearbyPlacesUseCase>((
  ref,
) {
  final locationService = ref.watch(locationServiceProvider);
  final repository = ref.watch(placesRepositoryProvider);
  return SearchNearbyPlacesUseCase(locationService, repository);
});

// UI-facing Providers
final placesControllerProvider =
    AsyncNotifierProvider<PlacesController, List<Place>>(() {
      return PlacesController();
    });

class PlacesController extends AsyncNotifier<List<Place>> {
  @override
  Future<List<Place>> build() async {
    final language = ref.watch(currentLanguageProvider);
    final radius = ref.read(maxDistanceProvider);
    final useCase = ref.read(searchNearbyPlacesUseCaseProvider);
    final result = await useCase.execute(language: language, radius: radius);
    ref.read(userLocationProvider.notifier).state = result.userLocation;
    return result.places;
  }

  Future<List<Place>> _loadNearbyPlaces({double? radius}) async {
    final language = ref.read(currentLanguageProvider);
    final double effectiveRadius = radius ?? ref.read(maxDistanceProvider);
    final useCase = ref.read(searchNearbyPlacesUseCaseProvider);
    final result = await useCase.execute(
      language: language,
      radius: effectiveRadius,
    );
    ref.read(userLocationProvider.notifier).state = result.userLocation;
    return result.places;
  }

  Future<void> search(String query) async {
    final language = ref.read(currentLanguageProvider);

    if (query.isEmpty) {
      state = const AsyncValue.loading();
      state = await AsyncValue.guard(() => _loadNearbyPlaces());
      return;
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(placesRepositoryProvider);
      return repository.searchPlaces(query, language: language);
    });
  }

  /// 強制重新整理（忽略快取），可傳入新的搜尋半徑
  Future<void> refresh({double? radius}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadNearbyPlaces(radius: radius));
  }
}

/// 搜尋列的即時建議。查詢字串＋語言一起當 family key，`autoDispose` 讓離開
/// 畫面後自動清掉——建議清單沒有跨畫面重用的價值。
///
/// 語言由呼叫端傳入，不讀 `currentLanguageProvider`——後者的初始值是作業
/// 系統語言，在使用者第一次進到 `/map` 之前都不會跟 EasyLocalization 同步
/// （見 `HomeTopBar` 呼叫端的說明）。
final placeSuggestionsProvider = FutureProvider.autoDispose
    .family<List<String>, ({String query, Language language})>((
      ref,
      key,
    ) async {
      final trimmed = key.query.trim();
      if (trimmed.isEmpty) return const [];
      final repository = ref.watch(placesRepositoryProvider);
      return repository.suggestPlaceNames(trimmed, language: key.language);
    });
