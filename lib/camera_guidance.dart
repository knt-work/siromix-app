import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'omr.dart';

// Copy only a small luminance plane; never send CameraImage/native handles into
// an isolate. Row/pixel strides account for padded YUV and optional BGRA data.
Map<String, Object> sampleLuminance({
  required Uint8List bytes,
  required int width,
  required int height,
  required int rowStride,
  int pixelStride = 1,
  bool bgra = false,
  int longestEdge = 800,
}) {
  final scale = math.max(1.0, math.max(width, height) / longestEdge);
  final w = (width / scale).floor(), h = (height / scale).floor();
  if (w < 1 || h < 1 || rowStride < 1 || pixelStride < 1) {
    throw const FormatException('Invalid camera plane');
  }
  final pixels = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    final sy = (y * scale).floor();
    for (var x = 0; x < w; x++) {
      final i = sy * rowStride + (x * scale).floor() * pixelStride;
      if (i + (bgra ? 2 : 0) >= bytes.length) {
        throw const FormatException('Incomplete camera plane');
      }
      pixels[y * w + x] = bgra
          ? ((bytes[i] * 114 + bytes[i + 1] * 587 + bytes[i + 2] * 299) / 1000)
                .round()
          : bytes[i];
    }
  }
  return {'width': w, 'height': h, 'pixels': pixels};
}

class CameraGuideLayout {
  CameraGuideLayout(
    Size size,
    double imageAspect, {
    double markerAspect = 1067 / 1549,
  }) {
    var width = size.width, height = width / imageAspect;
    if (height > size.height) {
      height = size.height;
      width = height * imageAspect;
    }
    preview = Rect.fromLTWH(
      (size.width - width) / 2,
      (size.height - height) / 2,
      width,
      height,
    );
    var fw = width * .8, fh = fw / markerAspect;
    if (fh > height * .8) {
      fh = height * .8;
      fw = fh * markerAspect;
    }
    target = Rect.fromLTWH(
      (size.width - fw) / 2,
      (size.height - fh) / 2,
      fw,
      fh,
    );
  }
  late final Rect preview, target;

  bool containsSheet(FrameProbe frame, {bool flexible = false}) {
    if (!frame.found || frame.corners.length != 4) return false;
    final displayAspect = preview.width / preview.height;
    final swapAxes = (frame.width > frame.height) != (displayAspect > 1);
    final sourceAspect = swapAxes
        ? frame.height / frame.width
        : frame.width / frame.height;
    final points = frame.corners.map((p) {
      var u = swapAxes ? p.y : p.x, v = swapAxes ? p.x : p.y;
      // Align the analysis field of view to the centered preview crop when
      // CameraX supplies analysis and preview buffers with different ratios.
      if (sourceAspect > displayAspect) {
        u = (u - .5) / (displayAspect / sourceAspect) + .5;
      } else if (sourceAspect < displayAspect) {
        v = (v - .5) / (sourceAspect / displayAspect) + .5;
      }
      return Offset(
        preview.left + u * preview.width,
        preview.top + v * preview.height,
      );
    }).toList();
    // Partial-region guide is a framing suggestion, not marker-sized targets.
    // Accept a complete detected field anywhere inside the actual preview.
    final bounds = flexible
        ? preview.deflate(preview.shortestSide * .02)
        : target;
    final tolerance = flexible ? 0.0 : target.shortestSide * .04;
    if (points.any(
      (p) =>
          !p.dx.isFinite ||
          !p.dy.isFinite ||
          !bounds.inflate(tolerance).contains(p),
    )) {
      return false;
    }
    final xs = points.map((p) => p.dx), ys = points.map((p) => p.dy);
    // Tiny distant sheets can lie inside the guide but lack useful detail.
    return xs.reduce(math.max) - xs.reduce(math.min) >=
            target.width * (flexible ? .45 : .65) &&
        ys.reduce(math.max) - ys.reduce(math.min) >=
            target.height * (flexible ? .45 : .65);
  }
}

enum GuideVerdict { searching, valid, invalid, unavailable }

class GuideTracker {
  GuideVerdict verdict = GuideVerdict.searching;
  DateTime? lastFrame;
  int _hits = 0;
  static const lifetime = Duration(milliseconds: 1500);
  void reset() {
    verdict = GuideVerdict.searching;
    lastFrame = null;
    _hits = 0;
  }

  void unavailable() {
    reset();
    verdict = GuideVerdict.unavailable;
  }

  void observe(bool matches, DateTime frameTime) {
    if (lastFrame != null && frameTime.isBefore(lastFrame!)) return;
    if (lastFrame != null && frameTime.difference(lastFrame!) > lifetime) {
      _hits = 0;
    }
    lastFrame = frameTime;
    if (!matches) {
      _hits = 0;
      verdict = GuideVerdict.invalid;
      return;
    }
    _hits++;
    verdict = _hits >= 2 ? GuideVerdict.valid : GuideVerdict.searching;
  }

  bool expire(DateTime now) {
    if (lastFrame != null && now.difference(lastFrame!) > lifetime) {
      reset();
      return true;
    }
    return false;
  }
}
