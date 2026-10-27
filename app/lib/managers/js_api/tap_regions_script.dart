/// `kioskSatellite.setScreensaverTapRegions`: the rects go out with the
/// visual viewport they were measured in, since only that turns CSS pixels
/// into screen pixels (the Zoom level and any pinch are its scale). A pinch
/// or a scroll of the visual viewport moves the page under the regions, so
/// the last accepted ones are sent again with the new viewport. Validation
/// is the app's: the rects go out as given.
const tapRegionsScript = r'''
  var tapRegions = [];
  var tapViewportWatched = false;
  function tapViewport() {
    var v = window.visualViewport;
    return v ? {scale: v.scale, offsetLeft: v.offsetLeft, offsetTop: v.offsetTop} : null;
  }
  function sendTapRegions(rects) {
    return call('setScreensaverTapRegions', {rects: rects, viewport: tapViewport()});
  }
  function setScreensaverTapRegions(rects) {
    var v = window.visualViewport;
    if (v && !tapViewportWatched) {
      tapViewportWatched = true;
      var resend = function () {
        if (tapRegions.length) sendTapRegions(tapRegions);
      };
      v.addEventListener('resize', resend);
      v.addEventListener('scroll', resend);
    }
    return sendTapRegions(rects).then(function (ok) {
      if (ok === true) tapRegions = rects;
      return ok;
    });
  }
''';
