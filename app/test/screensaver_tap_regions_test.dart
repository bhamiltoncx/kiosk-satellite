import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_satellite/managers/screensaver/tap_regions.dart';

/// The rects a dashboard page marks as its own on the screensaver: the
/// page measures them in CSS pixels, the screensaver compares screen
/// pixels, and the visual viewport the page reports alongside is the
/// whole conversion (the Zoom level is its initial scale).
void main() {
  Map<String, Object?> rect(num left, num top, num width, num height) => {
    'left': left,
    'top': top,
    'width': width,
    'height': height,
  };

  test('maps CSS px through the viewport scale and offset', () {
    expect(
      parseTapRegions({
        'rects': [rect(10, 20, 30, 40)],
        'viewport': {'scale': 1.5, 'offsetLeft': 4, 'offsetTop': 0},
      }),
      [const Rect.fromLTWH(9, 30, 45, 60)],
    );
  });

  test('no viewport means 1:1', () {
    expect(
      parseTapRegions({
        'rects': [rect(10, 20, 30, 40)],
      }),
      [const Rect.fromLTWH(10, 20, 30, 40)],
    );
    expect(
      parseTapRegions({
        'rects': [rect(10, 20, 30, 40)],
        'viewport': null,
      }),
      [const Rect.fromLTWH(10, 20, 30, 40)],
    );
  });

  test('an empty list is valid and clears', () {
    expect(parseTapRegions({'rects': <Object?>[]}), isEmpty);
    expect(parseTapRegions({'rects': <Object?>[]}), isNotNull);
  });

  test('rejects more than 16 regions', () {
    List<Object?> many(int n) => [for (var i = 0; i < n; i++) rect(i, 0, 1, 1)];
    expect(maxTapRegions, 16);
    expect(parseTapRegions({'rects': many(17)}), isNull);
    expect(parseTapRegions({'rects': many(16)}), hasLength(16));
  });

  test('rejects non-finite, zero and negative sizes', () {
    for (final bad in [
      rect(double.nan, 0, 1, 1),
      rect(0, double.infinity, 1, 1),
      rect(0, 0, 0, 1),
      rect(0, 0, 1, -1),
    ]) {
      expect(
        parseTapRegions({
          'rects': [bad],
        }),
        isNull,
        reason: '$bad',
      );
    }
  });

  test('rejects malformed shapes', () {
    final good = rect(0, 0, 1, 1);
    for (final bad in <Object?>[
      null,
      'rects',
      {'rects': 'nope'},
      {
        'rects': [1],
      },
      {
        'rects': [
          {'left': 0, 'top': 0, 'width': 1},
        ],
      },
      {
        'rects': [
          {'left': '0', 'top': 0, 'width': 1, 'height': 1},
        ],
      },
      {
        'rects': [good],
        'viewport': {'scale': 0, 'offsetLeft': 0, 'offsetTop': 0},
      },
      {
        'rects': [good],
        'viewport': {'scale': double.nan, 'offsetLeft': 0, 'offsetTop': 0},
      },
      {
        'rects': [good],
        'viewport': {'scale': 1, 'offsetLeft': double.nan, 'offsetTop': 0},
      },
      {
        'rects': [good],
        'viewport': 'zoomed',
      },
    ]) {
      expect(parseTapRegions(bad), isNull, reason: '$bad');
    }
  });
}
