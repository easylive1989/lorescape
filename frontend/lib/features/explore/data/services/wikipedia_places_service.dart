import 'dart:convert';

import 'package:context_app/core/errors/app_error.dart';
import 'package:context_app/features/explore/data/dto/wiki_geo_search_result_dto.dart';
import 'package:context_app/features/explore/data/dto/wikidata_entity_dto.dart';
import 'package:context_app/features/explore/domain/errors/place_error.dart';
import 'package:http/http.dart' as http;

/// Thin HTTP wrapper around the Wikipedia GeoSearch API.
///
/// Inject an [http.Client] for testing; production code uses the default.
class WikipediaPlacesService {
  static const String _userAgent =
      'InstantExplore/1.0 (https://instant-explore.app;'
      ' support@instant-explore.app)';
  static const int _thumbSize = 400;

  final http.Client _client;

  WikipediaPlacesService({http.Client? client})
    : _client = client ?? http.Client();

  /// Searches Wikipedia for articles near [lat]/[lon] within [radiusMeters].
  ///
  /// [wikiLang] selects the language edition (e.g. `'en'`, `'zh'`).
  /// Returns an empty list when no pages are found.
  /// Throws [AppError] with [PlaceError.searchFailed] on a non-200 response.
  Future<List<WikiGeoSearchResultDto>> geoSearch({
    required double lat,
    required double lon,
    required double radiusMeters,
    required String wikiLang,
    int limit = 10,
  }) async {
    final uri = Uri.https('$wikiLang.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'generator': 'geosearch',
      'ggscoord': '$lat|$lon',
      'ggsradius': radiusMeters.toInt().toString(),
      'ggslimit': limit.toString(),
      'prop': 'pageimages|coordinates|pageprops',
      'pithumbsize': '$_thumbSize',
      'ppprop': 'wikibase_item',
      'format': 'json',
    });

    final response = await _client.get(
      uri,
      headers: {'User-Agent': _userAgent},
    );

    if (response.statusCode != 200) {
      throw AppError(
        type: PlaceError.searchFailed,
        message: 'Wikipedia GeoSearch failed',
        context: {'status_code': response.statusCode},
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final pages = (data['query'] as Map?)?['pages'];
    if (pages is! Map) return const [];

    final results = <WikiGeoSearchResultDto>[];
    for (final page in pages.values) {
      if (page is! Map) continue;
      final dto = WikiGeoSearchResultDto.fromPage(
        Map<String, dynamic>.from(page),
      );
      if (dto != null) results.add(dto);
    }
    return results;
  }

  /// Searches Wikipedia articles by [query] text using generator=search.
  ///
  /// [wikiLang] selects the language edition (e.g. `'en'`, `'zh'`).
  /// Returns an empty list when no pages are found.
  /// Throws [AppError] with [PlaceError.searchFailed] on a non-200 response.
  Future<List<WikiGeoSearchResultDto>> searchByText(
    String query, {
    required String wikiLang,
    int limit = 10,
  }) async {
    final uri = Uri.https('$wikiLang.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'generator': 'search',
      'gsrsearch': query,
      'gsrlimit': limit.toString(),
      'prop': 'pageimages|coordinates|pageprops',
      'pithumbsize': '$_thumbSize',
      'ppprop': 'wikibase_item',
      'format': 'json',
    });

    final response = await _client.get(
      uri,
      headers: {'User-Agent': _userAgent},
    );

    if (response.statusCode != 200) {
      throw AppError(
        type: PlaceError.searchFailed,
        message: 'Wikipedia text search failed',
        context: {'status_code': response.statusCode},
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final pages = (data['query'] as Map?)?['pages'];
    if (pages is! Map) return const [];

    final results = <WikiGeoSearchResultDto>[];
    for (final page in pages.values) {
      if (page is! Map) continue;
      final dto = WikiGeoSearchResultDto.fromPage(
        Map<String, dynamic>.from(page),
      );
      if (dto != null) results.add(dto);
    }
    return results;
  }

  /// 標題自動完成，給首頁搜尋列的即時建議用。
  ///
  /// 用 `action=opensearch`——它只回標題陣列，比 `generator=search` 輕得多，
  /// 打字每一下都打得起。失敗時回空陣列而不是丟例外：建議清單消失比跳錯誤
  /// 對使用者干擾小。
  Future<List<String>> suggestTitles(
    String query, {
    required String wikiLang,
    int limit = 5,
  }) async {
    final uri = Uri.https('$wikiLang.wikipedia.org', '/w/api.php', {
      'action': 'opensearch',
      'search': query,
      'limit': limit.toString(),
      'namespace': '0',
      'format': 'json',
    });

    try {
      final response = await _client.get(
        uri,
        headers: {'User-Agent': _userAgent},
      );
      if (response.statusCode != 200) return const [];
      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.length < 2) return const [];
      final titles = decoded[1];
      if (titles is! List) return const [];
      return titles.whereType<String>().toList();
    } catch (_) {
      return const [];
    }
  }

  static const int _batchSize = 50;

  /// Batch-fetches Wikidata entities by id.
  ///
  /// Chunks requests of more than [_batchSize] ids into multiple calls.
  Future<Map<String, WikidataEntityDto>> fetchEntities(List<String> ids) async {
    if (ids.isEmpty) return const {};

    final result = <String, WikidataEntityDto>{};
    for (var i = 0; i < ids.length; i += _batchSize) {
      final chunk = ids.sublist(
        i,
        i + _batchSize > ids.length ? ids.length : i + _batchSize,
      );
      result.addAll(await _fetchEntityChunk(chunk));
    }
    return result;
  }

  Future<Map<String, WikidataEntityDto>> _fetchEntityChunk(
    List<String> ids,
  ) async {
    final uri = Uri.https('www.wikidata.org', '/w/api.php', {
      'action': 'wbgetentities',
      'ids': ids.join('|'),
      'props': 'claims',
      'format': 'json',
    });

    final response = await _client.get(
      uri,
      headers: {'User-Agent': _userAgent},
    );

    if (response.statusCode != 200) {
      throw AppError(
        type: PlaceError.searchFailed,
        message: 'Wikidata wbgetentities failed',
        context: {'status_code': response.statusCode},
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final entities = data['entities'];
    if (entities is! Map) return const {};

    final result = <String, WikidataEntityDto>{};
    for (final entry in entities.entries) {
      final value = entry.value;
      if (value is! Map) continue;
      result[entry.key] = WikidataEntityDto.fromEntity(
        Map<String, dynamic>.from(value),
      );
    }
    return result;
  }

  /// Fetches a Wikidata entity by id plus the associated wiki page info
  /// (title, coordinates, thumbnail) via the matching sitelink.
  ///
  /// Returns null if the entity has no sitelink on the requested wiki and
  /// no fallback sitelink was found.
  Future<WikiEntityWithPage?> fetchEntityById(
    String wikidataId, {
    required String wikiLang,
  }) async {
    final uri = Uri.https('www.wikidata.org', '/w/api.php', {
      'action': 'wbgetentities',
      'ids': wikidataId,
      'props': 'claims|sitelinks',
      'format': 'json',
    });

    final response = await _client.get(
      uri,
      headers: {'User-Agent': _userAgent},
    );
    if (response.statusCode != 200) {
      throw AppError(
        type: PlaceError.searchFailed,
        message: 'Wikidata wbgetentities failed',
        context: {'status_code': response.statusCode},
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final entityRaw = (data['entities'] as Map?)?[wikidataId];
    if (entityRaw is! Map) return null;

    final entity = WikidataEntityDto.fromEntity(
      Map<String, dynamic>.from(entityRaw),
    );
    final sitelinks = entityRaw['sitelinks'];
    if (sitelinks is! Map) return null;

    // Prefer the user's language, fall back to enwiki.
    final langKey = '${wikiLang}wiki';
    final Map? link = (sitelinks[langKey] ?? sitelinks['enwiki']) as Map?;
    if (link == null) return null;
    final title = link['title'];
    if (title is! String) return null;

    final effectiveLang = link['site'] == 'enwiki' ? 'en' : wikiLang;

    final dto = await _fetchPageByTitle(title, wikiLang: effectiveLang);
    if (dto == null) return null;

    return WikiEntityWithPage(dto: dto, entity: entity);
  }

  Future<WikiGeoSearchResultDto?> _fetchPageByTitle(
    String title, {
    required String wikiLang,
  }) async {
    final uri = Uri.https('$wikiLang.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'titles': title,
      'prop': 'pageimages|coordinates|pageprops',
      'pithumbsize': '$_thumbSize',
      'ppprop': 'wikibase_item',
      'format': 'json',
    });

    final response = await _client.get(
      uri,
      headers: {'User-Agent': _userAgent},
    );
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final pages = (data['query'] as Map?)?['pages'];
    if (pages is! Map) return null;
    for (final page in pages.values) {
      if (page is! Map) continue;
      final dto = WikiGeoSearchResultDto.fromPage(
        Map<String, dynamic>.from(page),
      );
      if (dto != null) return dto;
    }
    return null;
  }

  /// Resolves Wikidata [ids] to Wikipedia page DTOs in the same order.
  ///
  /// Looks up each entity's sitelink for [wikiLang] (falling back to
  /// `enwiki`) and fetches the corresponding Wikipedia article info in
  /// batches. Ids without a usable sitelink are silently skipped.
  Future<List<WikiGeoSearchResultDto>> fetchPagesByWikidataIds(
    List<String> ids, {
    required String wikiLang,
  }) async {
    if (ids.isEmpty) return const [];

    final titlesByLang = await _resolveSitelinkTitles(ids, wikiLang: wikiLang);
    if (titlesByLang.isEmpty) return const [];

    final dtosByQid = <String, WikiGeoSearchResultDto>{};
    for (final entry in titlesByLang.entries) {
      final titles = entry.value.values.toSet().toList();
      final dtos = await _fetchPagesByTitles(titles, wikiLang: entry.key);
      for (final dto in dtos) {
        final qid = dto.wikidataId;
        if (qid != null) dtosByQid.putIfAbsent(qid, () => dto);
      }
    }

    final result = <WikiGeoSearchResultDto>[];
    for (final id in ids) {
      final dto = dtosByQid[id];
      if (dto != null) result.add(dto);
    }
    return result;
  }

  Future<Map<String, Map<String, String>>> _resolveSitelinkTitles(
    List<String> ids, {
    required String wikiLang,
  }) async {
    final preferred = <String, String>{};
    final fallback = <String, String>{};

    for (var i = 0; i < ids.length; i += _batchSize) {
      final chunk = ids.sublist(
        i,
        i + _batchSize > ids.length ? ids.length : i + _batchSize,
      );
      final raw = await _fetchSitelinksChunk(chunk);
      raw.forEach((qid, sitelinks) {
        final preferredTitle = sitelinks['${wikiLang}wiki'];
        if (preferredTitle != null) {
          preferred[qid] = preferredTitle;
          return;
        }
        final enTitle = sitelinks['enwiki'];
        if (enTitle != null) fallback[qid] = enTitle;
      });
    }

    final result = <String, Map<String, String>>{};
    if (preferred.isNotEmpty) result[wikiLang] = preferred;
    if (fallback.isNotEmpty) result['en'] = fallback;
    return result;
  }

  Future<Map<String, Map<String, String>>> _fetchSitelinksChunk(
    List<String> ids,
  ) async {
    final uri = Uri.https('www.wikidata.org', '/w/api.php', {
      'action': 'wbgetentities',
      'ids': ids.join('|'),
      'props': 'sitelinks',
      'format': 'json',
    });

    final response = await _client.get(
      uri,
      headers: {'User-Agent': _userAgent},
    );
    if (response.statusCode != 200) {
      throw AppError(
        type: PlaceError.searchFailed,
        message: 'Wikidata sitelinks lookup failed',
        context: {'status_code': response.statusCode},
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final entities = data['entities'];
    if (entities is! Map) return const {};

    final result = <String, Map<String, String>>{};
    for (final entry in entities.entries) {
      final value = entry.value;
      if (value is! Map) continue;
      final sitelinks = value['sitelinks'];
      if (sitelinks is! Map) continue;
      final perWiki = <String, String>{};
      for (final sitelink in sitelinks.entries) {
        final link = sitelink.value;
        if (link is! Map) continue;
        final title = link['title'];
        if (title is String) perWiki[sitelink.key as String] = title;
      }
      if (perWiki.isNotEmpty) result[entry.key as String] = perWiki;
    }
    return result;
  }

  Future<List<WikiGeoSearchResultDto>> _fetchPagesByTitles(
    List<String> titles, {
    required String wikiLang,
  }) async {
    if (titles.isEmpty) return const [];

    final results = <WikiGeoSearchResultDto>[];
    for (var i = 0; i < titles.length; i += _batchSize) {
      final chunk = titles.sublist(
        i,
        i + _batchSize > titles.length ? titles.length : i + _batchSize,
      );
      results.addAll(await _fetchPagesByTitlesChunk(chunk, wikiLang: wikiLang));
    }
    return results;
  }

  Future<List<WikiGeoSearchResultDto>> _fetchPagesByTitlesChunk(
    List<String> titles, {
    required String wikiLang,
  }) async {
    final uri = Uri.https('$wikiLang.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'titles': titles.join('|'),
      'prop': 'pageimages|coordinates|pageprops',
      'pithumbsize': '$_thumbSize',
      'ppprop': 'wikibase_item',
      'format': 'json',
    });

    final response = await _client.get(
      uri,
      headers: {'User-Agent': _userAgent},
    );
    if (response.statusCode != 200) {
      throw AppError(
        type: PlaceError.searchFailed,
        message: 'Wikipedia titles lookup failed',
        context: {'status_code': response.statusCode},
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final pages = (data['query'] as Map?)?['pages'];
    if (pages is! Map) return const [];

    final out = <WikiGeoSearchResultDto>[];
    for (final page in pages.values) {
      if (page is! Map) continue;
      final dto = WikiGeoSearchResultDto.fromPage(
        Map<String, dynamic>.from(page),
      );
      if (dto != null) out.add(dto);
    }
    return out;
  }
}

/// Combined result of [WikipediaPlacesService.fetchEntityById].
class WikiEntityWithPage {
  final WikiGeoSearchResultDto dto;
  final WikidataEntityDto entity;

  const WikiEntityWithPage({required this.dto, required this.entity});
}
