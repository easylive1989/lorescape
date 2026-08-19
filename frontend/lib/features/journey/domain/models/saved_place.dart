import 'package:context_app/features/explore/domain/models/place.dart';
import 'package:context_app/features/explore/domain/models/place_category.dart';
import 'package:context_app/features/explore/domain/models/place_location.dart';
import 'package:context_app/features/explore/domain/models/place_photo.dart';
import 'package:equatable/equatable.dart';

class SavedPlace extends Equatable {
  final String id;
  final String name;
  final String address;
  final String? imageUrl;

  /// 地點座標。舊記錄沒有存，所以是 nullable；兩者要嘛都有、要嘛都沒有。
  final double? latitude;
  final double? longitude;

  const SavedPlace({
    required this.id,
    required this.name,
    required this.address,
    this.imageUrl,
    this.latitude,
    this.longitude,
  });

  /// 還原成播放頁需要的 [Place]。
  ///
  /// 記錄只留了地點的識別資訊與封面圖，tags 與分類都沒存下來——播放頁只用到
  /// name / address / 照片，分類給 fallback 即可。座標則盡量用記錄裡的真實
  /// 值；舊記錄沒座標時才補 0。帶上封面圖是為了讓重聽時的 hero 顯示當初那張
  /// 照片，而不是分類圖示。
  Place toPlace() => Place(
    id: id,
    name: name,
    address: address,
    location: (latitude != null && longitude != null)
        ? PlaceLocation(latitude: latitude!, longitude: longitude!)
        : const PlaceLocation(latitude: 0, longitude: 0),
    tags: const [],
    photos: imageUrl != null
        ? [
            PlacePhoto(
              url: imageUrl!,
              width: 0,
              height: 0,
              attributions: const [],
            ),
          ]
        : const [],
    category: PlaceCategory.modernUrban,
  );

  @override
  List<Object?> get props => [id, name, address, imageUrl, latitude, longitude];
}
