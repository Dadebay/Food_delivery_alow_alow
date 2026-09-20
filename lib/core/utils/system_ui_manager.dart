import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Keeps Android's navigation bar hidden, so the app owns the whole screen
/// and our own bottom tab bar sits at the very bottom edge instead of
/// floating above the system's three buttons.
///
/// [SystemUiMode.manual] hides the bar, but a swipe from the bottom edge
/// brings it back *and leaves it there* — Android only re-hides it by
/// itself in the immersive modes, and those also take the status bar with
/// them, which the design keeps (the green app bar runs under it). So the
/// bar coming back is detected and the mode re-applied a few seconds later.
///
/// [SystemChrome.setSystemUIChangeCallback] is not an option here: with
/// [SystemUiMode.manual] it only fires when *every* overlay is hidden.
class SystemUiManager with WidgetsBindingObserver {
  SystemUiManager({this.hideDelay = const Duration(seconds: 3)});

  /// How long the bar stays visible after the user swipes it up. Long enough
  /// to actually press a system button, short enough that the app does not
  /// keep a gap it never uses.
  final Duration hideDelay;

  Timer? _timer;

  /// Applies the mode and starts watching for the bar coming back.
  Future<void> start() async {
    WidgetsBinding.instance.addObserver(this);
    await apply();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  /// Status bar stays, navigation bar goes. A no-op on iOS, which has no
  /// navigation bar to hide.
  Future<void> apply() => SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.top],
  );

  @override
  void didChangeMetrics() {
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    if (view == null) return;
    handleBottomPadding(view.viewPadding.bottom);
  }

  /// A bottom padding above zero means the navigation bar is on screen
  /// again. Exposed so the behaviour can be tested without a device.
  void handleBottomPadding(double bottomPadding) {
    if (bottomPadding <= 0) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    // Already counting down; don't restart on every metrics tick.
    if (_timer?.isActive ?? false) return;
    _timer = Timer(hideDelay, apply);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from another app — or from the camera, the share sheet, a
    // phone call — restores the system bars.
    if (state == AppLifecycleState.resumed) unawaited(apply());
  }
}
