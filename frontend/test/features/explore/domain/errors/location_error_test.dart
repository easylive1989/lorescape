import 'package:context_app/features/explore/domain/errors/location_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocationError', () {
    test(
      'given each value, then code follows the LOCATION_ prefix contract',
      () {
        expect(LocationError.serviceDisabled.code, 'LOCATION_SERVICEDISABLED');
        expect(
          LocationError.permissionDenied.code,
          'LOCATION_PERMISSIONDENIED',
        );
        expect(
          LocationError.permissionDeniedForever.code,
          'LOCATION_PERMISSIONDENIEDFOREVER',
        );
      },
    );
  });
}
