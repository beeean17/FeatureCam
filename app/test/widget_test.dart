import 'package:flutter_test/flutter_test.dart';

import 'package:feature_cam/app/feature_cam_app.dart';

void main() {
  testWidgets('FeatureCam opens camera shell', (WidgetTester tester) async {
    await tester.pumpWidget(const FeatureCamApp());

    expect(find.text('MODE'), findsOneWidget);
    await tester.tap(find.text('MODE'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('PHOTO'), findsOneWidget);
    expect(find.text('VIDEO'), findsOneWidget);
    expect(find.text('FISHEYE'), findsOneWidget);
    expect(find.text('PANORAMA'), findsOneWidget);
  });

  testWidgets('Fisheye mode shows lens guidance', (WidgetTester tester) async {
    await tester.pumpWidget(const FeatureCamApp());

    await tester.tap(find.text('MODE'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('FISHEYE'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('촬영 후 원 안쪽이 Fisheye로 처리됩니다'), findsOneWidget);
  });
}
