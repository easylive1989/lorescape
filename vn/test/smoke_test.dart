import 'package:flutter_test/flutter_test.dart';
import 'package:lorescape_vn/main.dart';

void main() {
  testWidgets('啟動時顯示景點包名稱', (tester) async {
    await tester.pumpWidget(const VnApp());
    expect(find.text('龐貝 79'), findsOneWidget);
  });
}
