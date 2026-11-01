import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:filimu_plus/features/content_details/domain/device_form_factor.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  Future<void> expectDevice(
    WidgetTester tester, {
    required TargetPlatform platform,
    required Size size,
    required NavigationMode navigationMode,
    required String expected,
  }) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                size: size,
                navigationMode: navigationMode,
              ),
              child: Builder(
                builder: (context) => Text(
                  '${DeviceFormFactor.isTv(context)},'
                  '${DeviceFormFactor.isDesktop(context)},'
                  '${DeviceFormFactor.isMobile(context)}',
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text(expected), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  testWidgets('large Android touch displays are not classified as TVs',
      (tester) async {
    await expectDevice(
      tester,
      platform: TargetPlatform.android,
      size: const Size(1920, 1080),
      navigationMode: NavigationMode.traditional,
      expected: 'false,false,true',
    );
  });

  testWidgets('directional Android navigation selects the TV experience',
      (tester) async {
    await expectDevice(
      tester,
      platform: TargetPlatform.android,
      size: const Size(1280, 720),
      navigationMode: NavigationMode.directional,
      expected: 'true,false,false',
    );
  });

  testWidgets('narrow desktop windows stay desktop platforms', (tester) async {
    await expectDevice(
      tester,
      platform: TargetPlatform.windows,
      size: const Size(600, 800),
      navigationMode: NavigationMode.directional,
      expected: 'false,true,false',
    );
  });
}
