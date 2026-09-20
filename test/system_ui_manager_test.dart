import 'package:food_delivery/core/utils/system_ui_manager.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  List<MethodCall> uiModeCalls() => calls
      .where((c) => c.method == 'SystemChrome.setEnabledSystemUIOverlays')
      .toList();

  testWidgets('re-hides the navigation bar after it is swiped back up', (
    tester,
  ) async {
    final manager = SystemUiManager(hideDelay: const Duration(seconds: 3));
    addTearDown(manager.dispose);

    await manager.start();
    expect(uiModeCalls(), hasLength(1), reason: 'applied once at startup');

    // The user swipes: the bar is on screen, so the window reports padding.
    manager.handleBottomPadding(48);
    await tester.pump(const Duration(seconds: 2));
    expect(uiModeCalls(), hasLength(1), reason: 'still within the grace period');

    await tester.pump(const Duration(seconds: 2));
    expect(uiModeCalls(), hasLength(2), reason: 'bar should be hidden again');
  });

  testWidgets('does nothing while the bar stays hidden', (tester) async {
    final manager = SystemUiManager(hideDelay: const Duration(seconds: 1));
    addTearDown(manager.dispose);

    await manager.start();
    manager.handleBottomPadding(0);
    await tester.pump(const Duration(seconds: 3));

    expect(uiModeCalls(), hasLength(1));
  });
}
