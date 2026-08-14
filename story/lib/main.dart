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
      // ⚠️ 光靠 AspectRatio + ClipRect 鎖比例還不夠：那只裁「畫出來」的範圍，
      // `MediaQuery.sizeOf(context)`（`VnLayout.of` 就是用這個）在寬螢幕下
      // 拿到的仍然是**整個視窗**的大小，不是裁切後的可見框——寬螢幕視窗下
      // `VnLayout` 會拿視窗寬去算 `choiceInset`／`bodyFontSize`，插進裁切後
      // 窄得多的框裡，選項按鈕的可用寬度被吃到只剩一截、逐字換行（已實測重
      // 現：1510 寬視窗下選項帶量到的可見寬度不到 60px，換算回去正好等於
      // `視窗寬度*0.10*2` 那組數字吃掉了裁切框的絕大部分）。用 LayoutBuilder
      // 量出裁切框的實際像素大小，包一層 `MediaQuery`覆寫 `size`，讓
      // `VnLayout` 以下所有讀 `MediaQuery.sizeOf` 的地方看到的都是裁切後的
      // 框，不是外層視窗。
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
