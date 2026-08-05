import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:context_app/core/errors/app_error.dart';
import 'package:context_app/features/narration/domain/errors/narration_error.dart';
import 'package:context_app/features/narration/domain/models/story_hook.dart';
import 'package:http/http.dart' as http;

/// Result of a /narration/hooks call from the backend.
class HooksApiResult {
  final List<StoryHook> hooks;
  final bool insufficientSource;

  const HooksApiResult({required this.hooks, required this.insufficientSource});
}

/// Result of a narration call from the backend.
class NarrationApiResult {
  final String placeName;
  final String location;
  final String era;
  final List<String> paragraphs;
  final String pullQuote;
  final bool insufficientSource;

  const NarrationApiResult({
    required this.placeName,
    required this.location,
    required this.era,
    required this.paragraphs,
    required this.pullQuote,
    required this.insufficientSource,
  });

  /// Convenience: paragraphs joined with blank lines for TTS / display.
  String get text => paragraphs.join('\n\n');
}

/// Thin HTTP client for the backend narration endpoints.
///
/// Wraps `/narration` (long story) and `/narration/hooks` (2-3 angles).
class NarrationApiClient {
  final String baseUrl;
  final http.Client _httpClient;
  final Duration timeout;

  /// Supplies the current access token attached as `Authorization: Bearer`.
  ///
  /// Returns `null` when there is no session; the header is then omitted.
  final Future<String?> Function()? _accessToken;

  NarrationApiClient({
    required this.baseUrl,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 60),
    Future<String?> Function()? accessToken,
  }) : _httpClient = httpClient ?? http.Client(),
       _accessToken = accessToken;

  Future<HooksApiResult> fetchHooks({
    required String placeName,
    required String location,
    required String wikidataId,
    required String language,
  }) async {
    final body = {
      'place_name': placeName,
      'location': location,
      'wikidata_id': wikidataId,
      'language': language,
    };
    final data = await _post('/narration/hooks', body);
    final hooks = (data['hooks'] as List?) ?? const [];
    return HooksApiResult(
      hooks: hooks
          .whereType<Map>()
          .map((raw) {
            final map = raw.cast<String, dynamic>();
            return StoryHook(
              id: map['id'] as String,
              title: map['title'] as String,
              teaser: map['teaser'] as String,
            );
          })
          .toList(growable: false),
      insufficientSource: data['insufficient_source'] as bool? ?? false,
    );
  }

  Future<NarrationApiResult> fetchNarration({
    required String placeName,
    required String location,
    required String wikidataId,
    required String language,
    StoryHook? hook,
  }) async {
    final body = <String, dynamic>{
      'place_name': placeName,
      'location': location,
      'wikidata_id': wikidataId,
      'language': language,
      if (hook != null) 'hook': hook.toJson(),
    };
    final data = await _post('/narration', body);
    final paragraphs = (data['paragraphs'] as List?) ?? const [];
    return NarrationApiResult(
      placeName: data['place_name'] as String? ?? '',
      location: data['location'] as String? ?? '',
      era: data['era'] as String? ?? '',
      paragraphs: paragraphs.map((e) => e.toString()).toList(growable: false),
      pullQuote: data['pull_quote'] as String? ?? '',
      insufficientSource: data['insufficient_source'] as bool? ?? false,
    );
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    if (baseUrl.isEmpty) {
      throw const AppError(
        type: NarrationError.unknown,
        message: 'BACKEND_BASE_URL 未設定，無法呼叫故事服務',
      );
    }
    final uri = Uri.parse('$baseUrl$path');
    final token = await _accessToken?.call();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
    try {
      final response = await _httpClient
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
      }
      throw AppError(
        type: _errorTypeForStatus(response.statusCode),
        message: '後端故事服務回應錯誤 (${response.statusCode})',
        context: {
          'status_code': response.statusCode,
          'response_body': response.body,
        },
      );
    } on SocketException catch (e, stackTrace) {
      throw AppError(
        type: NarrationError.networkError,
        message: '網路連線失敗',
        originalException: e,
        stackTrace: stackTrace,
      );
    } on TimeoutException catch (e, stackTrace) {
      throw AppError(
        type: NarrationError.networkError,
        message: '連線逾時',
        originalException: e,
        stackTrace: stackTrace,
      );
    } on FormatException catch (e, stackTrace) {
      throw AppError(
        type: NarrationError.serverError,
        message: '後端回應格式錯誤',
        originalException: e,
        stackTrace: stackTrace,
      );
    } on AppError {
      rethrow;
    } catch (e, stackTrace) {
      throw AppError(
        type: NarrationError.unknown,
        message: '呼叫故事服務時發生未預期的錯誤',
        originalException: e,
        stackTrace: stackTrace,
      );
    }
  }
}

/// Maps a non-2xx backend status to a domain error type.
///
/// 402 was the backend's "daily free quota exhausted" signal. The paywall is
/// temporarily removed (ADR 0006) and the backend no longer returns 402, but
/// the mapping is kept in case a future paywall reuses the same status code.
NarrationError _errorTypeForStatus(int statusCode) => switch (statusCode) {
  400 => NarrationError.unknown,
  402 => NarrationError.freeQuotaExceeded,
  _ => NarrationError.serverError,
};
