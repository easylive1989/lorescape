import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lorescape_story/src/visual_novel/presentation/play/layout.dart';
import 'package:lorescape_story/src/visual_novel/presentation/vn_router.dart';
import 'package:lorescape_story/src/visual_novel/providers.dart';
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
      // 外框比例用**真實手機**（390:844 ≈ 0.462），不是 9:16（0.5625）。
      //
      // VnLayout 的字級跟寬度走（`W / 20`）、選項帶跟高度走（`0.45H`–`0.75H`），
      // 所以外框比例直接決定版面成不成立。9:16 在同樣高度下更寬（H=844 時
      // W=475），字級變 23.75，三顆選項按鈕要 255px，而選項帶只有 253px——
      // 差 2px 就溢出，一換行更慘。390:844 下字級 19.5、三顆 234px，餘裕 19px。
      //
      // 背景是 9:16 的圖，放進較窄的框只是多裁一點下緣——規範 §2 本來就說
      // 「螢幕更長時裁下緣，因為關鍵構圖都在上半部」。
      //
      // 這裡的 MediaQuery 覆寫讓「視窗尺寸」對框內任何東西都指向**可見框**
      // 而不是整個瀏覽器視窗——`AspectRatio` + `ClipRect` 只裁「畫出來」的
      // 範圍，不會動 MediaQuery。
      //
      // ⚠️ 但 `VnLayout` **不依賴這個覆寫**，也不准依賴：它由 `PlayPage` 內
      // 的 LayoutBuilder 量自己實際拿到的框。這個檔是 App 的薄殼，日後整包
      // 搬進另一個專案時不會跟著走——版面的正確性不能掛在一個搬家會消失的
      // 檔案上。（`test/…/play_page_test.dart` 的「版面跟著模組實際拿到的框
      // 走」那條就是守這件事：把播放頁塞進小於視窗的框，量對話框高度。）
      builder: (context, child) => LayoutBuilder(
        builder: (context, constraints) {
          const double aspect = 390 / 844;
          double width = constraints.maxWidth;
          double height = width / aspect;
          if (height > constraints.maxHeight) {
            height = constraints.maxHeight;
            width = height * aspect;
          }
          return ColoredBox(
            color: const Color(0xFF000000),
            child: Center(
              child: SizedBox(
                width: width,
                height: height,
                child: MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(size: Size(width, height)),
                  child: ClipRect(child: child),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
