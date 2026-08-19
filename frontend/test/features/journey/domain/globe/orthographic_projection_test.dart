import 'package:context_app/features/journey/domain/globe/globe_rotation.dart';
import 'package:context_app/features/journey/domain/globe/orthographic_projection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

const _center = Offset(100, 100);
const _radius = 100.0;

OrthographicProjection _projectionFacing(LatLng point) =>
    OrthographicProjection(
      rotation: GlobeRotation.facing(point, tilt: 0),
      center: _center,
      radius: _radius,
    );

void main() {
  test(
    'given a rotation facing a point, '
    'when projecting that point, '
    'then it lands on the canvas centre',
    () {
      final projection = _projectionFacing(const LatLng(41.9, 12.45));

      final offset = projection.project(const LatLng(41.9, 12.45));

      expect(offset, isNotNull);
      expect(offset!.dx, closeTo(_center.dx, 0.001));
      expect(offset.dy, closeTo(_center.dy, 0.001));
    },
  );

  test(
    'given a rotation facing the prime meridian on the equator, '
    'when projecting a point due north, '
    'then it lands above the centre on screen',
    () {
      final projection = _projectionFacing(const LatLng(0, 0));

      final offset = projection.project(const LatLng(45, 0))!;

      expect(offset.dx, closeTo(_center.dx, 0.001));
      expect(offset.dy, lessThan(_center.dy));
    },
  );

  test(
    'given a rotation facing the prime meridian on the equator, '
    'when projecting a point due east, '
    'then it lands to the right of the centre',
    () {
      final projection = _projectionFacing(const LatLng(0, 0));

      final offset = projection.project(const LatLng(0, 45))!;

      expect(offset.dx, greaterThan(_center.dx));
      expect(offset.dy, closeTo(_center.dy, 0.001));
    },
  );

  test(
    'given a point on the far hemisphere, '
    'when projecting it, '
    'then it is reported invisible and projects to null',
    () {
      final projection = _projectionFacing(const LatLng(0, 0));

      expect(projection.isVisible(const LatLng(0, 179)), isFalse);
      expect(projection.project(const LatLng(0, 179)), isNull);
    },
  );

  test(
    'given a point exactly on the horizon, '
    'when projecting it, '
    'then it lands on the globe rim',
    () {
      final projection = _projectionFacing(const LatLng(0, 0));

      final offset = projection.project(const LatLng(0, 90))!;

      expect((offset - _center).distance, closeTo(_radius, 0.001));
    },
  );

  test(
    'given a rotation facing a point with a tilt, '
    'when reading the view centre, '
    'then the centre sits north of the focused point by the tilt',
    () {
      final rotation = GlobeRotation.facing(const LatLng(30, 120), tilt: 8);

      expect(rotation.viewCenter.latitude, closeTo(22, 0.001));
      expect(rotation.viewCenter.longitude, closeTo(120, 0.001));
    },
  );

  test(
    'given two rotations across the antimeridian, '
    'when interpolating halfway, '
    'then it takes the short way round',
    () {
      const from = GlobeRotation(170, 0);
      const to = GlobeRotation(-170, 0);

      final mid = from.lerpTo(to, 0.5);

      expect(mid.lambda, closeTo(180, 0.001));
    },
  );

  test(
    'given a rotation beyond the tilt limit, '
    'when clamping it, '
    'then phi is capped at 78 degrees',
    () {
      expect(const GlobeRotation(0, 120).clampedPhi().phi, 78);
      expect(const GlobeRotation(0, -120).clampedPhi().phi, -78);
    },
  );
}
