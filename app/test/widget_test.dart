import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_cam/app/feature_cam_app.dart';

void main() {
  testWidgets('FeatureCam opens camera shell', (WidgetTester tester) async {
    await _setPortraitSurface(tester);
    await tester.pumpWidget(const FeatureCamApp());

    final modeButton = find.byKey(const ValueKey('mode-button'));
    expect(modeButton, findsOneWidget);
    await tester.tap(modeButton);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('mode-photo')), findsOneWidget);
    expect(find.byKey(const ValueKey('mode-video')), findsOneWidget);
    expect(find.byKey(const ValueKey('mode-fisheye')), findsOneWidget);
    expect(find.byKey(const ValueKey('mode-panorama')), findsOneWidget);
  });

  testWidgets('Fisheye mode shows lens guidance', (WidgetTester tester) async {
    await _setPortraitSurface(tester);
    await tester.pumpWidget(const FeatureCamApp());

    await tester.tap(find.byKey(const ValueKey('mode-button')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('mode-fisheye')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('촬영 후 원 안쪽이 Fisheye로 처리됩니다'), findsOneWidget);
  });
}

Future<void> _setPortraitSurface(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}
