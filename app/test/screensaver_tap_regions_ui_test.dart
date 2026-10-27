import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/app_container.dart';
import 'package:kiosk_satellite/ui/screensaver_view.dart';
import 'package:kiosk_satellite/ui/ui_scale.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Home Assistant Dashboard screensaver's tap regions: a tap inside
/// one of the rects the page marked falls through the clear dismiss layer
/// to the dashboard and leaves the screensaver up, a tap anywhere else
/// still dismisses. A full-screen detector under the overlay stands in for
/// the dashboard's WebView.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const region = Rect.fromLTWH(100, 100, 200, 100);

  late AppContainer container;
  late int pageTaps;
  late DateTime now;

  Future<void> pump(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
    double uiScale = 1,
  }) async {
    SharedPreferences.setMockInitialValues({
      'ks.ha.url': 'http://ha.local:8123',
      'ks.ha.token': 'token',
      'ks.screensaver.mode': 'dashboard',
      ...prefs,
    });
    container = AppContainer();
    await container.settings.init();
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    pageTaps = 0;
    // The manager's clock, not the test's: its windows (a region touch,
    // the double-tap chain) read wall time, which the pumps below do not
    // move. Each tap moves it on.
    now = DateTime(2026, 10, 26, 12);
    container.screensaver.clock = () => now;
    await container.screensaver.start();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => UiScaler(scale: uiScale, child: child!),
        // The kiosk screen's raw Listener, which reports every finger on
        // its way down: a region tap must survive that report. Straight to
        // the manager, as its bus subscription would (this harness never
        // runs its init()).
        home: Listener(
          onPointerDown: (_) => container.screensaver.notifyActivity('touch'),
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => pageTaps++,
                ),
              ),
              ScreensaverOverlay(container: container),
            ],
          ),
        ),
      ),
    );
    // Set directly: this harness never runs the manager's init(), which
    // subscribes to the bridge's event (covered by its own tests).
    container.screensaver.tapRegions.value = const [region];
    await tester.pump();
    expect(container.screensaver.activeView.value, 'dashboard');
    expect(container.screensaver.liveTapRegions, [region]);
  }

  Future<void> tapAt(WidgetTester tester, Offset at) async {
    await tester.tapAt(at);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    now = now.add(const Duration(milliseconds: 200));
  }

  testWidgets('a tap inside a region reaches the page and leaves it up', (
    tester,
  ) async {
    await pump(tester);
    await tapAt(tester, const Offset(150, 150));
    expect(pageTaps, 1);
    expect(container.screensaver.isActive, isTrue);
  });

  testWidgets('a tap outside every region dismisses', (tester) async {
    await pump(tester);
    await tapAt(tester, const Offset(600, 400));
    expect(pageTaps, 0);
    expect(container.screensaver.isActive, isFalse);
  });

  testWidgets('region taps line up under Scale UI', (tester) async {
    // The regions are screen pixels; under Scale UI the layer's own
    // coordinates are not. Both points sit on opposite sides of the
    // region in the two spaces, so a layer comparing the wrong one fails.
    await pump(tester, uiScale: 1.25);
    await tapAt(tester, const Offset(110, 110));
    expect(pageTaps, 1);
    expect(container.screensaver.isActive, isTrue);
    await tapAt(tester, const Offset(320, 150));
    expect(container.screensaver.isActive, isFalse);
  });

  testWidgets('with Double tap to dismiss a region tap does not start the '
      'chain', (tester) async {
    await pump(tester, prefs: {'ks.screensaver.dashboard_double_tap': true});
    // Each tapAt is 200 ms on: inside the chain's 400 ms window.
    await tapAt(tester, const Offset(150, 150));
    await tapAt(tester, const Offset(600, 400));
    expect(container.screensaver.isActive, isTrue);
    expect(pageTaps, 2, reason: 'with no layer every tap reaches the page');
    // The tap off the regions was the chain's first: its double still
    // dismisses.
    await tapAt(tester, const Offset(600, 400));
    expect(container.screensaver.isActive, isFalse);
  });
}
