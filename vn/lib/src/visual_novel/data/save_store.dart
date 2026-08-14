import 'dart:convert';

import 'package:lorescape_vn/src/visual_novel/domain/save_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class SaveStore {
  /// 存檔格式與現在的劇本對不上（改版後失效）時回 null，不得丟例外。
  SaveData? loadSave(String storyId);
  Future<void> writeSave(SaveData data);
  Future<void> clearSave(String storyId);

  /// 已讀節點，跨故事累積、以 [Cursor.readKey] 為 key。
  Set<String> readNodes();
  Future<void> markRead(String key);

  /// 收藏的結局，以 `<storyId>#<endingId>` 記錄，跨故事累積。
  Set<String> endingsSeen();
  Future<void> markEnding(String storyId, String endingId);

  /// 每字顯示間隔（毫秒），預設 28。
  double textSpeed();
  Future<void> setTextSpeed(double value);

  /// 字級縮放，預設 1.0。
  double fontScale();
  Future<void> setFontScale(double value);
}

/// 用 SharedPreferences 存讀檔、已讀進度、結局收藏與設定。
final class SharedPreferencesSaveStore implements SaveStore {
  SharedPreferencesSaveStore(this._prefs);

  static const String _readKey = 'vn.readNodes';
  static const String _endingsKey = 'vn.endingsSeen';
  static const String _textSpeedKey = 'vn.textSpeed';
  static const String _fontScaleKey = 'vn.fontScale';

  final SharedPreferences _prefs;

  String _saveKey(String storyId) => 'vn.save.$storyId';

  @override
  SaveData? loadSave(String storyId) {
    final raw = _prefs.getString(_saveKey(storyId));
    if (raw == null) return null;
    try {
      return SaveData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      // 劇本改版後舊存檔可能解不開；當成沒有存檔，不讓玩家卡在錯誤頁。
      return null;
    }
  }

  @override
  Future<void> writeSave(SaveData data) =>
      _prefs.setString(_saveKey(data.storyId), jsonEncode(data.toJson()));

  @override
  Future<void> clearSave(String storyId) =>
      _prefs.remove(_saveKey(storyId)).then((_) {});

  @override
  Set<String> readNodes() =>
      (_prefs.getStringList(_readKey) ?? const <String>[]).toSet();

  @override
  Future<void> markRead(String key) async {
    final current = readNodes();
    if (!current.add(key)) return;
    await _prefs.setStringList(_readKey, current.toList()..sort());
  }

  @override
  Set<String> endingsSeen() =>
      (_prefs.getStringList(_endingsKey) ?? const <String>[]).toSet();

  @override
  Future<void> markEnding(String storyId, String endingId) async {
    final current = endingsSeen();
    if (!current.add('$storyId#$endingId')) return;
    await _prefs.setStringList(_endingsKey, current.toList()..sort());
  }

  @override
  double textSpeed() => _prefs.getDouble(_textSpeedKey) ?? 28;

  @override
  Future<void> setTextSpeed(double value) =>
      _prefs.setDouble(_textSpeedKey, value);

  @override
  double fontScale() => _prefs.getDouble(_fontScaleKey) ?? 1.0;

  @override
  Future<void> setFontScale(double value) =>
      _prefs.setDouble(_fontScaleKey, value);
}
