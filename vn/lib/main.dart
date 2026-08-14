import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lorescape_vn/src/visual_novel/presentation/play/layout.dart';
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
    return MaterialApp(
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
      home: const Scaffold(body: Center(child: Text('龐貝 79'))),
    );
  }
}
