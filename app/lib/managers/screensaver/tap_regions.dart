import 'dart:ui';

/// The most rects a page may mark. Enough for a handful of cards; few
/// enough that a page cannot tile the screen with them by accident.
const maxTapRegions = 16;

/// The page's `setScreensaverTapRegions` call as screen rects, or null
/// when it is malformed (the page then hears false and keeps what it had).
///
/// The page measures in CSS pixels against its layout viewport, what
/// getBoundingClientRect() answers; the injected script sends the visual
/// viewport alongside. Its scale is the whole conversion: the Zoom level
/// is the viewport's initial scale (viewport_zoom_script.dart), a pinch
/// multiplies into it, and one CSS pixel at scale 1 is one dp. The
/// dashboard WebView is exempt from Scale UI and sits at the screen's
/// origin while a screensaver is up, so its dp are the screen's logical
/// pixels. No viewport (an old engine) means scale 1 and no offset.
List<Rect>? parseTapRegions(Object? params) {
  if (params is! Map) return null;
  final rects = params['rects'];
  if (rects is! List || rects.length > maxTapRegions) return null;
  var scale = 1.0, offsetLeft = 0.0, offsetTop = 0.0;
  final viewport = params['viewport'];
  if (viewport != null) {
    if (viewport is! Map) return null;
    final s = _finite(viewport['scale']);
    final l = _finite(viewport['offsetLeft']);
    final t = _finite(viewport['offsetTop']);
    if (s == null || s <= 0 || l == null || t == null) return null;
    scale = s;
    offsetLeft = l;
    offsetTop = t;
  }
  final out = <Rect>[];
  for (final rect in rects) {
    if (rect is! Map) return null;
    final left = _finite(rect['left']);
    final top = _finite(rect['top']);
    final width = _finite(rect['width']);
    final height = _finite(rect['height']);
    if (left == null || top == null || width == null || height == null) {
      return null;
    }
    if (width <= 0 || height <= 0) return null;
    out.add(
      Rect.fromLTWH(
        (left - offsetLeft) * scale,
        (top - offsetTop) * scale,
        width * scale,
        height * scale,
      ),
    );
  }
  return out;
}

double? _finite(Object? value) =>
    value is num && value.isFinite ? value.toDouble() : null;
