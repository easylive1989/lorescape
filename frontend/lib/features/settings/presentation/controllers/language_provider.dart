import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:context_app/features/settings/domain/models/language.dart';

/// 當前應用語言 Provider
///
/// 這個 Provider 會被 Widget 層在 EasyLocalization 語言變化時更新
/// Controller 可以直接讀取這個 Provider 而不需要傳入語言參數
class LanguageNotifier extends Notifier<Language> {
  @override
  Language build() {
    // 初始值使用系統語言
    final locale = PlatformDispatcher.instance.locale;
    return languageFromLocaleTag(locale.toLanguageTag());
  }

  /// 更新當前語言（由 Widget 層在 EasyLocalization 語言變化時呼叫）
  void updateLanguage(String localeTag) {
    state = languageFromLocaleTag(localeTag);
  }
}
