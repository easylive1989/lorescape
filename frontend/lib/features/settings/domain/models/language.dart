import 'package:equatable/equatable.dart';

class Language extends Equatable {
  final String code;

  const Language(this.code);

  /// 繁體中文
  static const traditionalChinese = Language('zh-TW');

  /// 英文
  static const english = Language('en-US');

  @override
  List<Object?> get props => [code];
}

/// 從 locale tag（例如 `'zh-TW'`、`'en-US'`）判斷對應的 [Language]。
///
/// 這是判定「中文 vs 英文」唯一的地方，供 [LanguageNotifier] 同步系統／
/// EasyLocalization 語言，也供其他 feature（例如首頁地球儀）把
/// `context.locale` 換算成 [Language] 時共用，避免各處各自複製一份
/// `startsWith('zh')` 判斷。
Language languageFromLocaleTag(String localeTag) {
  if (localeTag.startsWith('zh')) return Language.traditionalChinese;
  return Language.english;
}
