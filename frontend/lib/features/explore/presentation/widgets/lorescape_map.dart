import 'package:context_app/app/config/lorescape_tokens.dart';
import 'package:context_app/features/explore/providers.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart' hide Theme;
import 'package:flutter/material.dart' as material show Theme;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

/// 世界地圖底圖，資料來自 OpenFreeMap 的 vector tiles。
///
/// 選型理由與授權義務見 `docs/adr/0005-map-tile-provider.md`。設計稿對應
/// `docs/design/project/app2/screens_explore.jsx` 的 `.map-el`。
///
/// [children] 疊在底圖之上（pin、polyline 等），由呼叫端提供。
///
/// [fitToPoints] 一旦從空變成有值，鏡頭會自動框住所有點。只框一次，之後
/// 不再干擾使用者操作。
class LorescapeMap extends ConsumerStatefulWidget {
  const LorescapeMap({
    super.key,
    this.mapController,
    this.initialCenter = _kFallbackCenter,
    this.initialZoom = 2,
    this.onMapReady,
    this.children = const [],
    this.fitToPoints = const [],
    this.attributionBottomInset = 0,
  });

  /// 世界視野的預設中心。實際開圖時通常會被 `fitBounds` 覆寫（見 T3），
  /// 這只是還沒有任何地點座標時的保底。
  static const LatLng _kFallbackCenter = LatLng(24.15, 120.66);

  /// 底圖 tile 的最大 zoom 是 14（見 OpenFreeMap TileJSON）。超過的層級由
  /// 渲染端放大既有 tile，仍可正常操作。
  static const double _kMinZoom = 2;
  static const double _kMaxZoom = 18;

  final MapController? mapController;
  final LatLng initialCenter;
  final double initialZoom;
  final VoidCallback? onMapReady;
  final List<Widget> children;
  final List<LatLng> fitToPoints;

  /// 出處角標距離底緣的距離。角標不得被任何浮層蓋掉——署名被蓋掉等同沒有
  /// 署名，是授權違規。呼叫端若在地圖上疊了貼底的浮層，要嘛用這個值把角標
  /// 推到浮層上方，要嘛確保浮層下方留有角標放得下的透空縫隙（探索頁的地點
  /// 卡片列走後者，幾何依據見 explore_screen.dart 傳這個參數處的註解）。
  /// 見 `docs/adr/0005-map-tile-provider.md`。
  final double attributionBottomInset;

  @override
  ConsumerState<LorescapeMap> createState() => _LorescapeMapState();
}

class _LorescapeMapState extends ConsumerState<LorescapeMap> {
  late final MapController _controller =
      widget.mapController ?? MapController();
  bool _mapReady = false;
  bool _hasFitted = false;

  /// 框景時的最大 zoom。**不要用設計稿的 6**：設計稿的假資料是全世界散布
  /// 的景點，maxZoom 6 是為了「框住整個世界時別放太大」；但真實資料全來自
  /// 使用者當前位置附近的 Wikipedia geosearch（預設 10km 內），套 zoom 6 會
  /// 讓所有 pin 縮成中心一個點。14 對應 tile 的最大原生層級（見 OpenFreeMap
  /// TileJSON），也是只有單一地點時的合理街區級 fallback。
  static const double _kFitMaxZoom = 14;
  static const EdgeInsets _kFitPadding = EdgeInsets.all(48);

  @override
  void didUpdateWidget(covariant LorescapeMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _fitIfNeeded();
  }

  void _fitIfNeeded() {
    if (_hasFitted || !_mapReady || widget.fitToPoints.isEmpty) return;
    _hasFitted = true;
    // 下一幀才動鏡頭：build 當下 FlutterMap 可能還沒完成第一次 layout。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.fitCamera(
        CameraFit.coordinates(
          coordinates: widget.fitToPoints,
          padding: _kFitPadding,
          maxZoom: _kFitMaxZoom,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = material.Theme.of(context).extension<LorescapeTokens>();
    final backgroundColor =
        tokens?.paperSunk ??
        material.Theme.of(context).colorScheme.surfaceContainerHighest;
    // 樣式與其版本一起等；版本用來隔離 tile 快取目錄。
    final styleAsync = ref.watch(mapStyleProvider);
    final styleVersion = ref.watch(mapStyleVersionProvider).valueOrNull;

    if (styleVersion == null) {
      return ColoredBox(color: backgroundColor, child: const SizedBox.expand());
    }

    return styleAsync.when(
      loading: () =>
          ColoredBox(color: backgroundColor, child: const SizedBox.expand()),
      error: (error, _) => _MapUnavailable(background: backgroundColor),
      data: (style) => FlutterMap(
        mapController: _controller,
        options: MapOptions(
          initialCenter: widget.initialCenter,
          initialZoom: widget.initialZoom,
          minZoom: LorescapeMap._kMinZoom,
          maxZoom: LorescapeMap._kMaxZoom,
          backgroundColor: backgroundColor,
          onMapReady: () {
            _mapReady = true;
            _fitIfNeeded();
            widget.onMapReady?.call();
          },
          interactionOptions: const InteractionOptions(
            // 不開 rotate：設計稿的浮層 header 與卡片列都假設地圖是正北向。
            flags:
                InteractiveFlag.drag |
                InteractiveFlag.flingAnimation |
                InteractiveFlag.pinchMove |
                InteractiveFlag.pinchZoom |
                InteractiveFlag.doubleTapZoom,
          ),
        ),
        children: [
          VectorTileLayer(
            theme: style.theme,
            sprites: style.sprites,
            tileProviders: style.providers,
            // 快取目錄依樣式版本隔離。`vector_map_tiles` 的快取 key 不含樣式
            // 身分且 TTL 30 天，不這樣切，改配色後既有使用者會繼續看到舊地圖
            // （2026-07-21 實測確認）。見 MapTileCacheService。
            //
            // 回傳型別刻意放寬成 dynamic：`cacheFolder` 宣告的 `Directory` 來自
            // vector_map_tiles 的條件式 import，在非 dart:io 平台是
            // `typedef Directory = String`，analyzer 會解析到那個 stub 而與
            // `dart:io` 的 Directory 對不起來。本 App 只出 iOS / Android，
            // 執行期一定是 dart:io 版本。
            cacheFolder: () async =>
                await ref
                        .read(mapTileCacheServiceProvider)
                        .folderForStyle(styleVersion)
                    as dynamic,
          ),
          ...widget.children,
          _AttributionBadge(bottomInset: widget.attributionBottomInset),
        ],
      ),
    );
  }
}

/// OpenFreeMap / OpenMapTiles / OpenStreetMap 的出處標示。
///
/// **這是授權義務，不是裝飾**：OpenFreeMap 要求顯示
/// `OpenFreeMap © OpenMapTiles Data from OpenStreetMap`，不得移除。文字是
/// 授權指定字樣，所以不進 i18n。完整出處與版權連結另外放在設定頁的「地圖
/// 資料來源」，這裡的角標是 OSM guideline 要求的「從地圖上直接可及」那一份。
///
/// 刻意畫在 [LorescapeMap] 內而不是呼叫端：任何用到這張底圖的畫面都會自動
/// 帶著署名，不會因為新畫面忘記加而違約。
class _AttributionBadge extends StatelessWidget {
  const _AttributionBadge({required this.bottomInset});

  final double bottomInset;

  static const String _text =
      'OpenFreeMap © OpenMapTiles Data from OpenStreetMap';

  @override
  Widget build(BuildContext context) {
    final tokens = material.Theme.of(context).extension<LorescapeTokens>();
    final paper = tokens?.paper ?? const Color(0xFFF7F1E6);
    final ink3 = tokens?.ink3 ?? const Color(0xFF918471);

    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ColoredBox(
          color: paper.withValues(alpha: 0.7),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            child: Text(
              _text,
              style: TextStyle(fontSize: 10, height: 1.2, color: ink3),
            ),
          ),
        ),
      ),
    );
  }
}

/// 底圖載入失敗時的替代畫面。地圖是探索頁的背景，失敗時不擋住上層 UI，
/// 只以紙色底加一行說明帶過。
class _MapUnavailable extends StatelessWidget {
  const _MapUnavailable({required this.background});

  final Color background;

  @override
  Widget build(BuildContext context) {
    final tokens = material.Theme.of(context).extension<LorescapeTokens>();
    return ColoredBox(
      color: background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'explore.map.unavailable'.tr(),
            textAlign: TextAlign.center,
            style: material.Theme.of(context).textTheme.bodyMedium?.copyWith(
              color:
                  tokens?.ink3 ??
                  material.Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
