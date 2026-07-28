import 'package:context_app/features/explore/data/services/hive_places_cache_service.dart';
import 'package:context_app/features/explore/domain/models/place.dart';
import 'package:context_app/features/explore/domain/models/place_location.dart';
import 'package:context_app/features/explore/domain/repositories/places_repository.dart';
import 'package:context_app/features/settings/domain/models/language.dart';

/// 使用 Decorator 模式包裝 PlacesRepository，添加快取功能
///
/// 此類別透過快取機制減少 API 呼叫次數：
/// - 若快取未過期且使用者位置未大幅移動，直接回傳快取資料
/// - 快取以語言為 key，切換語言後會從 API 重新取得對應語言的資料
/// - 否則呼叫底層 Repository 取得新資料並更新快取
class CachingPlacesRepository implements PlacesRepository {
  final PlacesRepository _delegate;
  final HivePlacesCacheService _cacheService;

  CachingPlacesRepository(this._delegate, this._cacheService);

  @override
  Future<List<Place>> getNearbyPlaces(
    PlaceLocation location, {
    required Language language,
    required double radius,
  }) async {
    final lang = _langKey(language);
    final shouldRefresh = await _cacheService.shouldRefresh(location, lang);

    if (!shouldRefresh) {
      final cachedPlaces = await _cacheService.getCachedPlaces(lang);
      if (cachedPlaces != null && cachedPlaces.isNotEmpty) {
        return cachedPlaces;
      }
    }

    final places = await _delegate.getNearbyPlaces(
      location,
      language: language,
      radius: radius,
    );

    await _cacheService.cachePlaces(places, lang);
    await _cacheService.saveLastSearchLocation(location, lang);

    return places;
  }

  @override
  Future<List<Place>> searchPlaces(String query, {required Language language}) {
    return _delegate.searchPlaces(query, language: language);
  }

  @override
  Future<Place?> getPlaceById(String placeId, {required Language language}) {
    return _delegate.getPlaceById(placeId, language: language);
  }

  @override
  Future<List<String>> suggestPlaceNames(
    String query, {
    required Language language,
  }) => _delegate.suggestPlaceNames(query, language: language);

  String _langKey(Language language) =>
      language.code.split('-').first.toLowerCase();
}
