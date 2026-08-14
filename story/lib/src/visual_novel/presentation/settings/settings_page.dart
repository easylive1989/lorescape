import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lorescape_story/src/visual_novel/presentation/play/layout.dart';
import 'package:lorescape_story/src/visual_novel/providers.dart';

/// 設定頁：文字速度與字級，兩個 Slider。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  static const ValueKey<String> textSpeedSliderKey = ValueKey<String>(
    'settings-text-speed',
  );
  static const ValueKey<String> fontScaleSliderKey = ValueKey<String>(
    'settings-font-scale',
  );

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  // 拖曳中的暫存值：本地 state 先跟著手指跑，onChangeEnd 才寫進
  // SharedPreferences，不然拖一次會打好幾十次 I/O。
  double? _textSpeed;
  double? _fontScale;

  @override
  Widget build(BuildContext context) {
    final SaveStore store = ref.watch(saveStoreProvider);
    final double textSpeed = _textSpeed ??= store.textSpeed();
    final double fontScale = _fontScale ??= store.fontScale();

    return Scaffold(
      backgroundColor: VnColors.backdrop,
      appBar: AppBar(
        title: const Text('設定'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          // 數字是「每個字幾毫秒」，所以往左拉（值變小）＝ 變快。
          Text(
            '文字速度（${textSpeed.round()} ms／字）',
            style: const TextStyle(color: VnColors.body),
          ),
          Slider(
            key: SettingsPage.textSpeedSliderKey,
            value: textSpeed,
            min: 4,
            max: 60,
            onChanged: (value) => setState(() => _textSpeed = value),
            onChangeEnd: store.setTextSpeed,
          ),
          const SizedBox(height: 24),
          Text(
            '字級（${fontScale.toStringAsFixed(2)}×）',
            style: const TextStyle(color: VnColors.body),
          ),
          Slider(
            key: SettingsPage.fontScaleSliderKey,
            value: fontScale,
            min: 0.8,
            // 上限 1.2 不是隨手訂的：實測 390×844 下，最長的 57 字台詞在
            // 1.4× 會排成 5 行、需要 230px，而對話框的可用高度只有
            // 200.9px——Flutter 會直接把第 5 行裁掉，沒有例外也沒有黃黑
            // 斜紋，玩家就是少看到一行字。1.2× 是 4 行 160px，仍在框內。
            max: 1.2,
            onChanged: (value) => setState(() => _fontScale = value),
            onChangeEnd: store.setFontScale,
          ),
        ],
      ),
    );
  }
}
