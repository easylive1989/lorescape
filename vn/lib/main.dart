import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/play/layout.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/vn_router.dart';
import 'package:lorescape_vn/src/visual_novel/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: <Override>[sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const VnApp(),
    ),
  );
}

class VnApp extends StatelessWidget {
  const VnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '龐貝 79',
      // 沒給 seed，Material 3 會發預設的紫——跟龐貝壁畫色調（暖灰、赭、奶油白）
      // 直接打架。用 VnColors.ochre 當 seed，讓之後每個 Material 元件（首頁、
      // 設定、結局收藏……）都跟著這套配色走，不必逐一客製化。
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: VnColors.ochre,
          brightness: Brightness.dark,
        ),
      ),
      routerConfig: buildVnRouter(),
      // 這個 App 只設計給手機直式。web／桌面上視窗可能是任意比例的寬螢幕，
      // 用 AspectRatio 把內容鎖在 9:16、置中，兩側留黑模擬手機邊框，避免
      // 版面在寬螢幕上被拉伸變形。
      builder: (context, child) => ColoredBox(
        color: const Color(0xFF000000),
        child: Center(
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: ClipRect(child: child),
          ),
        ),
      ),
    );
  }
}
