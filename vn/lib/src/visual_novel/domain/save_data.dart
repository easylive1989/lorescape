import 'package:lorescape_vn/src/visual_novel/domain/cursor.dart';
import 'package:lorescape_vn/src/visual_novel/domain/play_state.dart';

/// 規範 §6 的存檔格式，外加 `stage`。
///
/// 規範原本只存 cursor 與 vars，但台上有誰是 show/hide 累積出來的副作用，
/// 讀檔時若靠「從場開頭重跑一次」還原，那些 if 會用**存檔當下的**變數重新
/// 求值，可能走進與當初不同的分支。直接把台上狀態存下來就沒有這個問題。
final class SaveData {
  const SaveData({
    required this.storyId,
    required this.cursor,
    required this.vars,
    required this.stage,
    required this.updatedAt,
    this.bgmId,
  });

  factory SaveData.from(String storyId, PlayState state, DateTime now) => SaveData(
        storyId: storyId,
        cursor: state.cursor,
        vars: state.vars,
        stage: state.stage,
        bgmId: state.bgmId,
        updatedAt: now,
      );

  factory SaveData.fromJson(Map<String, dynamic> json) {
    final cursorJson = json['cursor'] as Map<String, dynamic>;
    return SaveData(
      storyId: json['storyId'] as String,
      cursor: Cursor.fromTokens(
        cursorJson['sceneId'] as String,
        (cursorJson['path'] as List<dynamic>).cast<String>(),
      ),
      vars: Map<String, Object?>.from(json['vars'] as Map<String, dynamic>),
      stage: ((json['stage'] as List<dynamic>?) ?? const <dynamic>[])
          .map((e) => e as Map<String, dynamic>)
          .map(
            (e) => SpriteOnStage(
              who: e['who'] as String,
              sprite: e['sprite'] as String,
              filter: e['filter'] as String?,
            ),
          )
          .toList(),
      bgmId: json['bgmId'] as String?,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  final String storyId;
  final Cursor cursor;
  final Map<String, Object?> vars;
  final List<SpriteOnStage> stage;
  final String? bgmId;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'storyId': storyId,
        'cursor': <String, dynamic>{'sceneId': cursor.sceneId, 'path': cursor.toTokens()},
        'vars': vars,
        'stage': <Map<String, dynamic>>[
          for (final sprite in stage)
            <String, dynamic>{
              'who': sprite.who,
              'sprite': sprite.sprite,
              if (sprite.filter != null) 'filter': sprite.filter,
            },
        ],
        if (bgmId != null) 'bgmId': bgmId,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  PlayState toPlayState() => PlayState(
        cursor: cursor,
        vars: vars,
        stage: stage,
        status: PlayStatus.playing,
        bgmId: bgmId,
      );
}
