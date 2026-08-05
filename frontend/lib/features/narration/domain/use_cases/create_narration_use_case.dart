import 'package:context_app/features/explore/domain/models/place.dart';
import 'package:context_app/features/narration/domain/models/narration_content.dart';
import 'package:context_app/features/narration/domain/models/story_hook.dart';
import 'package:context_app/features/narration/domain/services/narration_service.dart';
import 'package:context_app/features/settings/domain/models/language.dart';
import 'package:context_app/features/usage/domain/repositories/usage_repository.dart';

/// 建立導覽用例
///
/// 負責生成導覽內容並組成 NarrationContent。
class CreateNarrationUseCase {
  final NarrationService _narrationService;
  final UsageRepository _usageRepository;

  CreateNarrationUseCase(this._narrationService, this._usageRepository);

  /// 執行用例：生成導覽內容
  ///
  /// [place] 地點資訊
  /// [hook] 使用者挑選的故事鉤子（可為 null，由模型自行挑選一條線索）
  /// [language] 語言
  ///
  /// The paywall is temporarily removed (ADR 0006): the backend no longer
  /// gates narration generation, and nothing returns 402. The local
  /// [UsageRepository] call below is now a vestigial local counter — it
  /// only increments a SharedPreferences value for display and never
  /// throws, so it cannot block generation.
  ///
  /// 可能拋出 AppError：
  /// - NarrationError.*: AI 服務相關錯誤（透傳）
  /// - NarrationError.contentGenerationFailed: 內容驗證失敗
  Future<NarrationContent> execute({
    required Place place,
    required Language language,
    StoryHook? hook,
  }) async {
    final result = await _narrationService.generateNarration(
      place: place,
      language: language,
      hook: hook,
    );

    final content = NarrationContent.create(
      result.text,
      language: language,
      grounding: result.grounding,
    );

    // Optimistic local display update only; the backend is the source of
    // truth for quota enforcement.
    await _usageRepository.consumeUsage();

    return content;
  }
}
