import 'package:lorescape_vn/src/visual_novel/domain/cursor.dart';

enum PlayStatus { playing, choosing, ended }

final class SpriteOnStage {
  const SpriteOnStage({required this.who, required this.sprite, this.filter});
  final String who;
  final String sprite;
  final String? filter;
}

final class PlayState {
  const PlayState({
    required this.cursor,
    required this.vars,
    required this.stage,
    required this.status,
    this.bgmId,
    this.endingId,
  });

  final Cursor cursor;
  final Map<String, Object?> vars;

  /// 台上的立繪，最多 2 個（實測：單人 223 次、雙人 6 次、無三人）。
  final List<SpriteOnStage> stage;
  final PlayStatus status;
  final String? bgmId;
  final String? endingId;

  String get readKey => cursor.readKey;

  PlayState copyWith({
    Cursor? cursor,
    Map<String, Object?>? vars,
    List<SpriteOnStage>? stage,
    PlayStatus? status,
    String? bgmId,
    bool clearBgm = false,
    String? endingId,
  }) {
    return PlayState(
      cursor: cursor ?? this.cursor,
      vars: vars ?? this.vars,
      stage: stage ?? this.stage,
      status: status ?? this.status,
      bgmId: clearBgm ? null : (bgmId ?? this.bgmId),
      endingId: endingId ?? this.endingId,
    );
  }
}
