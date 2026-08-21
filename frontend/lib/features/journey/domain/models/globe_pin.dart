import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

/// 地球儀上的一個釘點。
class GlobePin extends Equatable {
  const GlobePin({
    required this.id,
    required this.coordinate,
    required this.label,
  });

  /// 對應的旅程 id——點釘點就是選中書架上那本書。
  final String id;
  final LatLng coordinate;

  /// 顯示在點旁邊或紙卡 chip 上的旅程名稱。
  final String label;

  @override
  List<Object?> get props => [id, coordinate, label];
}
