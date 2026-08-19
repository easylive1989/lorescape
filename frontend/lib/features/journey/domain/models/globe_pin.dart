import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

/// 地球儀上的一個釘點。
class GlobePin extends Equatable {
  const GlobePin({
    required this.id,
    required this.coordinate,
    required this.label,
  });

  /// 對應的每日故事識別碼（用發布日期字串即可）。
  final String id;
  final LatLng coordinate;

  /// 顯示在點旁邊或紙卡 chip 上的地名。
  final String label;

  @override
  List<Object?> get props => [id, coordinate, label];
}
