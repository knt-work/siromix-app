import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'data.dart';

class OmrException implements Exception {
  const OmrException(this.message);
  final String message;
  @override
  String toString() => message;
}

class DigitReading {
  const DigitReading(this.value, this.state);
  final String value;
  final MarkState state;
}

class OmrRead {
  const OmrRead({
    required this.answers,
    required this.candidate,
    required this.code,
    required this.aligned,
    required this.answerCrops,
    required this.candidateCrop,
    required this.codeCrop,
  });
  final List<ResponseMark> answers;
  final List<DigitReading> candidate, code;
  final Uint8List aligned, candidateCrop, codeCrop;
  final List<Uint8List> answerCrops;
  String get candidateText => candidate.map((v) => v.value).join();
  String get codeText => code.map((v) => v.value).join();
  bool get candidateClear =>
      candidate.length == 6 &&
      candidate.every((v) => v.state == MarkState.single);
  bool get codeClear =>
      code.length == 3 && code.every((v) => v.state == MarkState.single);
}

// Coordinates use the quadrilateral defined by the four outer marker centers.
// Source render: 1272x1800, centers approximately (102,120) and (1169,1669).
class TenSheetGeometry {
  static const width = 1067, height = 1549;
  static const answerX = [109.0, 142.0, 175.0, 208.0];
  static double answerY(int row) => 490.0 + row * 33.1;
  static const candidateX = [638.0, 671.0, 704.0, 737.0, 770.0, 803.0];
  static const codeX = [903.0, 936.0, 969.0];
  static double digitY(int n) => 59.5 + n * 33.15;
  static const localMarkers = [
    math.Point(76.0, 456.0),
    math.Point(275.0, 456.0),
    math.Point(76.0, 820.0),
    math.Point(275.0, 820.0),
    math.Point(605.0, 26.5),
    math.Point(605.0, 390.5),
    math.Point(871.0, 26.5),
    math.Point(871.0, 390.5),
  ];
}

class _Gray {
  _Gray(this.width, this.height, this.pixels);
  final int width, height;
  final Uint8List pixels;
  factory _Gray.fromImage(img.Image image) {
    final bytes = Uint8List(image.width * image.height);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        bytes[y * image.width + x] =
            ((p.r * 299 + p.g * 587 + p.b * 114) / 1000).round();
      }
    }
    return _Gray(image.width, image.height, bytes);
  }
  double at(double x, double y) {
    if (x < 0 || y < 0 || x >= width - 1 || y >= height - 1) return 255;
    final ix = x.floor(), iy = y.floor();
    final dx = x - ix, dy = y - iy;
    return pixels[iy * width + ix] * (1 - dx) * (1 - dy) +
        pixels[iy * width + ix + 1] * dx * (1 - dy) +
        pixels[(iy + 1) * width + ix] * (1 - dx) * dy +
        pixels[(iy + 1) * width + ix + 1] * dx * dy;
  }
}

class _Marker {
  _Marker(this.x, this.y, this.area);
  final double x, y;
  final int area;
}

List<_Marker> _markers(_Gray gray, {int minimumSize = 9}) {
  final seen = Uint8List(gray.pixels.length),
      queue = Int32List(gray.pixels.length);
  final found = <_Marker>[];
  for (var index = 0; index < gray.pixels.length; index++) {
    if (seen[index] != 0 || gray.pixels[index] > 100) continue;
    var head = 0, tail = 1;
    queue[0] = index;
    seen[index] = 1;
    var minX = gray.width, maxX = 0, minY = gray.height, maxY = 0;
    while (head < tail) {
      final v = queue[head++], x = v % gray.width, y = v ~/ gray.width;
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
      for (final n in [
        if (x > 0) v - 1,
        if (x < gray.width - 1) v + 1,
        if (y > 0) v - gray.width,
        if (y < gray.height - 1) v + gray.width,
      ]) {
        if (seen[n] == 0 && gray.pixels[n] <= 100) {
          seen[n] = 1;
          queue[tail++] = n;
        }
      }
    }
    final w = maxX - minX + 1, h = maxY - minY + 1;
    if (w >= minimumSize &&
        h >= minimumSize &&
        w < gray.width * .13 &&
        h < gray.height * .13 &&
        w / h > .55 &&
        w / h < 1.8 &&
        tail / (w * h) > .80) {
      found.add(_Marker((minX + maxX) / 2, (minY + maxY) / 2, tail));
    }
  }
  found.sort((a, b) => b.area.compareTo(a.area));
  return found.take(16).toList();
}

// Solve a homography mapping canonical coordinates to the photographed sheet.
List<double> _homography(
  List<math.Point<double>> dst, {
  List<math.Point<double>>? sourcePoints,
}) {
  const w = TenSheetGeometry.width * 1.0, h = TenSheetGeometry.height * 1.0;
  final src =
      sourcePoints ??
      const [
        math.Point(0.0, 0.0),
        math.Point(w, 0.0),
        math.Point(w, h),
        math.Point(0.0, h),
      ];
  final a = List.generate(8, (_) => List<double>.filled(9, 0));
  for (var i = 0; i < 4; i++) {
    final x = src[i].x, y = src[i].y, u = dst[i].x, v = dst[i].y;
    a[2 * i] = [x, y, 1, 0, 0, 0, -u * x, -u * y, u];
    a[2 * i + 1] = [0, 0, 0, x, y, 1, -v * x, -v * y, v];
  }
  for (var c = 0; c < 8; c++) {
    var pivot = c;
    for (var r = c + 1; r < 8; r++) {
      if (a[r][c].abs() > a[pivot][c].abs()) pivot = r;
    }
    if (a[pivot][c].abs() < 1e-8) {
      throw const OmrException(
        'Không căn chỉnh được phiếu. Vui lòng chụp lại.',
      );
    }
    final temp = a[c];
    a[c] = a[pivot];
    a[pivot] = temp;
    final scale = a[c][c];
    for (var j = c; j < 9; j++) {
      a[c][j] /= scale;
    }
    for (var r = 0; r < 8; r++) {
      if (r == c) continue;
      final f = a[r][c];
      for (var j = c; j < 9; j++) {
        a[r][j] -= f * a[c][j];
      }
    }
  }
  return List.generate(8, (i) => a[i][8]);
}

double _sample(_Gray source, List<double> h, double x, double y) {
  final z = h[6] * x + h[7] * y + 1;
  if (z.abs() < 1e-8) return 255;
  return source.at(
    (h[0] * x + h[1] * y + h[2]) / z,
    (h[3] * x + h[4] * y + h[5]) / z,
  );
}

double _markerQuality(_Gray gray, List<double> h) {
  var dark = 0, total = 0;
  for (final p in TenSheetGeometry.localMarkers) {
    for (var dy = -4; dy <= 4; dy += 2) {
      for (var dx = -4; dx <= 4; dx += 2) {
        if (_sample(gray, h, p.x + dx, p.y + dy) < 110) dark++;
        total++;
      }
    }
  }
  return dark / total;
}

List<double> _findAlignment(
  _Gray gray, {
  int minimumMarkerSize = 9,
  double minimumAreaFraction = .23,
}) {
  final candidates = _markers(gray, minimumSize: minimumMarkerSize);
  if (candidates.length < 4) {
    throw const OmrException(
      'Không thấy đủ mốc đen. Chụp đủ bốn góc phiếu, đặt trên nền sáng.',
    );
  }
  List<double>? best;
  var bestQuality = .76;
  // Large outer squares are about twice the width of the internal markers.
  for (var a = 0; a < candidates.length - 3; a++) {
    for (var b = a + 1; b < candidates.length - 2; b++) {
      for (var c = b + 1; c < candidates.length - 1; c++) {
        for (var d = c + 1; d < candidates.length; d++) {
          final group = [
            candidates[a],
            candidates[b],
            candidates[c],
            candidates[d],
          ];
          if (group.first.area > group.last.area * 3.5) continue;
          final cx = group.fold<double>(0, (s, p) => s + p.x) / 4,
              cy = group.fold<double>(0, (s, p) => s + p.y) / 4;
          group.sort(
            (p, q) => math
                .atan2(p.y - cy, p.x - cx)
                .compareTo(math.atan2(q.y - cy, q.x - cx)),
          );
          double area = 0;
          for (var i = 0; i < 4; i++) {
            final p = group[i], q = group[(i + 1) % 4];
            area += p.x * q.y - q.x * p.y;
          }
          if (area.abs() / 2 < gray.width * gray.height * minimumAreaFraction) {
            continue;
          }
          for (var rotation = 0; rotation < 4; rotation++) {
            final points = List.generate(4, (i) {
              final p = group[(i + rotation) % 4];
              return math.Point(p.x, p.y);
            });
            final h = _homography(points), quality = _markerQuality(gray, h);
            if (quality > bestQuality) {
              bestQuality = quality;
              best = h;
            }
          }
        }
      }
    }
  }
  if (best == null) {
    throw const OmrException(
      'Phiếu không khớp mẫu 10 câu hoặc ảnh chưa rõ. Kiểm tra loại phiếu và chụp lại.',
    );
  }
  return best;
}

_Gray _load(Uint8List bytes) {
  var image = img.decodeImage(bytes);
  if (image == null) {
    throw const OmrException('Không đọc được ảnh chụp. Vui lòng thử lại.');
  }
  image = img.bakeOrientation(image);
  if (math.max(image.width, image.height) > 2000) {
    image = img.copyResize(
      image,
      width: image.width >= image.height ? 2000 : null,
      height: image.height > image.width ? 2000 : null,
    );
  }
  return _Gray.fromImage(image);
}

_Gray _warp(_Gray source, List<double> h) {
  const w = TenSheetGeometry.width, hh = TenSheetGeometry.height;
  final data = Uint8List(w * hh);
  for (var y = 0; y < hh; y++) {
    for (var x = 0; x < w; x++) {
      data[y * w + x] = _sample(
        source,
        h,
        x * 1.0,
        y * 1.0,
      ).round().clamp(0, 255);
    }
  }
  return _Gray(w, hh, data);
}

double _density(_Gray g, double x, double y) {
  final bg = <double>[];
  for (var dy = -15; dy <= 15; dy += 2) {
    for (var dx = -15; dx <= 15; dx += 2) {
      final r = dx * dx + dy * dy;
      if (r >= 169 && r <= 225) bg.add(g.at(x + dx, y + dy));
    }
  }
  bg.sort();
  final white = bg[(bg.length * .85).floor()];
  if (white < 135) {
    throw const OmrException(
      'Ảnh quá tối hoặc có bóng đổ. Đặt phiếu ở nơi đủ sáng và chụp lại.',
    );
  }
  double sum = 0;
  var n = 0;
  for (var dy = -6; dy <= 6; dy++) {
    for (var dx = -6; dx <= 6; dx++) {
      if (dx * dx + dy * dy <= 36) {
        sum += (1 - g.at(x + dx, y + dy) / white).clamp(0, 1);
        n++;
      }
    }
  }
  return sum / n;
}

ResponseMark _classify(List<double> differences, List<String> labels) {
  final sure = <int>[], possible = <int>[];
  for (var i = 0; i < differences.length; i++) {
    if (differences[i] >= .33) sure.add(i);
    if (differences[i] > .065) possible.add(i);
  }
  if (possible.isEmpty) return const ResponseMark(MarkState.blank);
  if (sure.length >= 2 && sure.length == possible.length) {
    return const ResponseMark(MarkState.multiple);
  }
  if (sure.length == 1 && possible.length == 1) {
    return ResponseMark(MarkState.single, labels[sure.single]);
  }
  return const ResponseMark(MarkState.uncertain);
}

Uint8List _png(_Gray g, {int x = 0, int y = 0, int? width, int? height}) {
  final w = width ?? g.width, hh = height ?? g.height;
  final image = img.Image(width: w, height: hh, numChannels: 1);
  for (var yy = 0; yy < hh; yy++) {
    for (var xx = 0; xx < w; xx++) {
      final v = g.pixels[(y + yy) * g.width + x + xx];
      image.setPixelRgb(xx, yy, v, v, v);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

// Runs in a background isolate via compute(). Only image bytes cross the boundary.
OmrRead recognizeTenSheet(Map<String, Uint8List> input) {
  final source = _load(input['photo']!), reference = _load(input['reference']!);
  final aligned = _warp(source, _findAlignment(source));
  final baseline = _warp(reference, _findAlignment(reference));
  double delta(double x, double y) =>
      _density(aligned, x, y) - _density(baseline, x, y);
  final answers = List.generate(
    10,
    (i) => _classify(
      TenSheetGeometry.answerX
          .map((x) => delta(x, TenSheetGeometry.answerY(i)))
          .toList(),
      ['A', 'B', 'C', 'D'],
    ),
  );
  List<DigitReading> digits(List<double> xs) => xs.map((x) {
    final mark = _classify(
      List.generate(10, (i) => delta(x, TenSheetGeometry.digitY(i))),
      List.generate(10, (i) => '$i'),
    );
    return DigitReading(
      mark.state == MarkState.single ? mark.answer : '?',
      mark.state,
    );
  }).toList();
  return OmrRead(
    answers: answers,
    candidate: digits(TenSheetGeometry.candidateX),
    code: digits(TenSheetGeometry.codeX),
    aligned: _png(aligned),
    candidateCrop: _png(aligned, x: 615, y: 34, width: 213, height: 342),
    codeCrop: _png(aligned, x: 880, y: 34, width: 114, height: 342),
    answerCrops: List.generate(
      10,
      (i) => _png(
        aligned,
        x: 80,
        y: (TenSheetGeometry.answerY(i) - 17).round(),
        width: 155,
        height: 34,
      ),
    ),
  );
}

class FrameProbe {
  const FrameProbe({
    required this.found,
    required this.width,
    required this.height,
    this.corners = const [],
  });
  final bool found;
  final int width, height;
  // Normalized analysis-buffer coordinates, not screen coordinates.
  final List<math.Point<double>> corners;
}

FrameProbe probeTenSheet(Map<String, Object> input) {
  final width = input['width'] as int, height = input['height'] as int;
  final bytes = input['pixels'] as Uint8List;
  final missing = FrameProbe(found: false, width: width, height: height);
  if (width < 20 || height < 20 || bytes.length != width * height) {
    return missing;
  }
  final source = _Gray(width, height, bytes);
  try {
    final h = _findAlignment(
      source,
      minimumMarkerSize: 4,
      minimumAreaFraction: .12,
    );
    // Reject very dark page areas instead of showing a reassuring green guide.
    final whites = <double>[];
    for (final p in [
      const math.Point(400.0, 900.0),
      const math.Point(600.0, 700.0),
      const math.Point(400.0, 1300.0),
      const math.Point(800.0, 1300.0),
    ]) {
      final patch = <double>[];
      for (var dy = -3; dy <= 3; dy += 3) {
        for (var dx = -3; dx <= 3; dx += 3) {
          patch.add(_sample(source, h, p.x + dx, p.y + dy));
        }
      }
      patch.sort();
      whites.add(patch[patch.length ~/ 2]);
    }
    whites.sort();
    if (whites[1] < 145) return missing;
    final points = <math.Point<double>>[];
    for (final p in [
      const math.Point(0.0, 0.0),
      const math.Point(1067.0, 0.0),
      const math.Point(1067.0, 1549.0),
      const math.Point(0.0, 1549.0),
    ]) {
      final z = h[6] * p.x + h[7] * p.y + 1;
      if (z.abs() < 1e-8) return missing;
      points.add(
        math.Point(
          (h[0] * p.x + h[1] * p.y + h[2]) / z / width,
          (h[3] * p.x + h[4] * p.y + h[5]) / z / height,
        ),
      );
    }
    return FrameProbe(
      found: true,
      width: width,
      height: height,
      corners: points,
    );
  } on OmrException {
    return missing;
  }
}

enum SheetPart { candidate, code, answers }

extension SheetPartInfo on SheetPart {
  String get label => switch (this) {
    SheetPart.candidate => 'Số báo danh',
    SheetPart.code => 'Mã đề',
    SheetPart.answers => 'Đáp án',
  };
  // The complete printed rectangular border is the local alignment reference.
  List<double> get frame => switch (this) {
    SheetPart.candidate => [577, -2, 832, 419],
    SheetPart.code => [841, -2, 1002, 419],
    SheetPart.answers => [52, 429, 302, 841],
  };
  double get aspect => (frame[2] - frame[0]) / (frame[3] - frame[1]);
  List<math.Point<double>> get framePoints => [
    math.Point(frame[0], frame[1]),
    math.Point(frame[2], frame[1]),
    math.Point(frame[2], frame[3]),
    math.Point(frame[0], frame[3]),
  ];
  List<math.Point<double>> get markers => switch (this) {
    SheetPart.candidate => [
      const math.Point(605, 26.5),
      const math.Point(605, 390.5),
    ],
    SheetPart.code => [
      const math.Point(871, 26.5),
      const math.Point(871, 390.5),
    ],
    SheetPart.answers => TenSheetGeometry.localMarkers.take(4).toList(),
  };
  List<math.Point<double>> get bubbles => switch (this) {
    SheetPart.candidate => [
      for (final x in TenSheetGeometry.candidateX)
        for (var i = 0; i < 10; i++) math.Point(x, TenSheetGeometry.digitY(i)),
    ],
    SheetPart.code => [
      for (final x in TenSheetGeometry.codeX)
        for (var i = 0; i < 10; i++) math.Point(x, TenSheetGeometry.digitY(i)),
    ],
    SheetPart.answers => [
      for (final x in TenSheetGeometry.answerX)
        for (var i = 0; i < 10; i++) math.Point(x, TenSheetGeometry.answerY(i)),
    ],
  };
}

class PartRead {
  const PartRead({
    required this.part,
    required this.crop,
    this.digits = const [],
    this.answers = const [],
    this.answerCrops = const [],
  });
  final SheetPart part;
  final Uint8List crop;
  final List<DigitReading> digits;
  final List<ResponseMark> answers;
  final List<Uint8List> answerCrops;
  String get digitText => digits.map((d) => d.value).join();
}

// Find hollow rectangular printed frames independently of the four page corners.
// Extremal component points provide corner proposals; all proposals must then
// pass marker, ring-grid, white-space and complete-border checks for THIS part.
List<List<math.Point<double>>> _partFrames(_Gray g) {
  final seen = Uint8List(g.pixels.length), queue = Int32List(g.pixels.length);
  final frames = <List<math.Point<double>>>[];
  for (var index = 0; index < g.pixels.length; index++) {
    if (seen[index] != 0 || g.pixels[index] > 150) continue;
    var head = 0, tail = 1, minX = g.width, maxX = 0, minY = g.height, maxY = 0;
    final corners = List.filled(4, const math.Point<double>(0, 0));
    final scores = [
      double.infinity,
      -double.infinity,
      -double.infinity,
      double.infinity,
    ];
    queue[0] = index;
    seen[index] = 1;
    while (head < tail) {
      final n = queue[head++], x = n % g.width, y = n ~/ g.width;
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
      final sum = (x + y).toDouble(), diff = (x - y).toDouble();
      if (sum < scores[0]) {
        scores[0] = sum;
        corners[0] = math.Point(x.toDouble(), y.toDouble());
      }
      if (diff > scores[1]) {
        scores[1] = diff;
        corners[1] = math.Point(x.toDouble(), y.toDouble());
      }
      if (sum > scores[2]) {
        scores[2] = sum;
        corners[2] = math.Point(x.toDouble(), y.toDouble());
      }
      if (diff < scores[3]) {
        scores[3] = diff;
        corners[3] = math.Point(x.toDouble(), y.toDouble());
      }
      for (final next in [
        if (x > 0) n - 1,
        if (x < g.width - 1) n + 1,
        if (y > 0) n - g.width,
        if (y < g.height - 1) n + g.width,
      ]) {
        if (seen[next] == 0 && g.pixels[next] <= 150) {
          seen[next] = 1;
          queue[tail++] = next;
        }
      }
    }
    final w = maxX - minX + 1, h = maxY - minY + 1, area = w * h;
    if (w < 50 ||
        h < 50 ||
        area < g.width * g.height * .10 ||
        tail / area > .18 ||
        minX < 2 ||
        minY < 2 ||
        maxX >= g.width - 2 ||
        maxY >= g.height - 2) {
      continue;
    }
    if (corners.toSet().length == 4) frames.add(corners);
  }
  return frames.take(12).toList();
}

double _partQuality(_Gray g, List<double> h, SheetPart part) {
  var good = 0, total = 0;
  for (final p in part.markers) {
    for (final dy in [-3.0, 0.0, 3.0]) {
      for (final dx in [-3.0, 0.0, 3.0]) {
        total++;
        if (_sample(g, h, p.x + dx, p.y + dy) < 125) good++;
      }
    }
  }
  if (good / total < .88) return 0;
  var rings = 0, spaces = 0;
  final bubbles = part.bubbles;
  for (final p in bubbles) {
    // Missing columns may never become silently blank responses.
    for (final d in [
      const math.Point(-14.0, 0.0),
      const math.Point(14.0, 0.0),
      const math.Point(0.0, -14.0),
      const math.Point(0.0, 14.0),
    ]) {
      final x = p.x + d.x, y = p.y + d.y, z = h[6] * x + h[7] * y + 1;
      final u = (h[0] * x + h[1] * y + h[2]) / z,
          v = (h[3] * x + h[4] * y + h[5]) / z;
      if (!u.isFinite ||
          !v.isFinite ||
          u < 1 ||
          v < 1 ||
          u >= g.width - 1 ||
          v >= g.height - 1) {
        return 0;
      }
    }
    final hits = _ringHits(g, h, p);
    if (hits < 4) return 0;
    rings += hits;
    if (_sample(g, h, p.x + 15, p.y + 15) > 150) spaces++;
  }
  if (part == SheetPart.code) {
    // The first three SBD columns resemble a code. Reject a visible fourth
    // printed column rather than accepting a full six-column SBD region.
    var extra = 0;
    for (var row = 0; row < 10; row++) {
      if (_ringHits(g, h, math.Point(1002, TenSheetGeometry.digitY(row))) >=
          5) {
        extra++;
      }
    }
    if (extra >= 5) return 0;
  }
  if (part == SheetPart.answers) {
    // Four corner markers and a 4x10 grid are 180-degree symmetric. The
    // printed question-number strip distinguishes the left side without OCR.
    var numberedRows = 0;
    for (var row = 0; row < 10; row++) {
      var ink = 0;
      for (var dy = -7; dy <= 7; dy += 2) {
        for (var x = 64; x <= 83; x += 2) {
          if (_sample(g, h, x.toDouble(), TenSheetGeometry.answerY(row) + dy) <
              150) {
            ink++;
          }
        }
      }
      if (ink >= 4) numberedRows++;
    }
    if (numberedRows < 7) return 0;
  }
  final quality = rings / (bubbles.length * 8);
  return spaces / bubbles.length > .8 && quality > .64 ? quality : 0;
}

int _ringHits(_Gray g, List<double> h, math.Point<double> p) {
  var hits = 0;
  for (var i = 0; i < 8; i++) {
    final angle = i * math.pi / 4;
    var darkest = 255.0;
    for (final radius in [8.5, 10.5, 12.5]) {
      darkest = math.min(
        darkest,
        _sample(
          g,
          h,
          p.x + math.cos(angle) * radius,
          p.y + math.sin(angle) * radius,
        ),
      );
    }
    if (darkest < 185) hits++;
  }
  return hits;
}

List<List<double>> _markerPartPoses(_Gray g, SheetPart part) {
  final markers = _markers(g, minimumSize: 4).take(10).toList();
  final poses = <List<double>>[];
  if (part != SheetPart.answers) {
    final anchor = part.markers.first;
    for (var i = 0; i < markers.length; i++) {
      for (var j = 0; j < markers.length; j++) {
        if (i == j) continue;
        final p = markers[i], q = markers[j];
        if (p.area / q.area < .45 || p.area / q.area > 2.2) continue;
        final a = (q.y - p.y) / 364, b = (q.x - p.x) / 364;
        final scale = math.sqrt(a * a + b * b);
        if (scale * 364 < g.height * .15 || scale * 364 < g.width * .15) {
          continue;
        }
        for (final stretch in [1.0, .9, 1.1, .8, 1.2]) {
          for (final shear in [0.0, -.1, .1]) {
            final ux = a * stretch + b * shear, vx = -b * stretch + a * shear;
            poses.add([
              ux,
              b,
              p.x - ux * anchor.x - b * anchor.y,
              vx,
              a,
              p.y - vx * anchor.x - a * anchor.y,
              0,
              0,
            ]);
          }
        }
      }
    }
  } else {
    for (var a = 0; a < markers.length - 3; a++) {
      for (var b = a + 1; b < markers.length - 2; b++) {
        for (var c = b + 1; c < markers.length - 1; c++) {
          for (var d = c + 1; d < markers.length; d++) {
            final group = [markers[a], markers[b], markers[c], markers[d]];
            if (group.any(
              (p) =>
                  p.area / group.first.area < .45 ||
                  p.area / group.first.area > 2.2,
            )) {
              continue;
            }
            final cx = group.fold<double>(0, (v, p) => v + p.x) / 4,
                cy = group.fold<double>(0, (v, p) => v + p.y) / 4;
            group.sort(
              (p, q) => math
                  .atan2(p.y - cy, p.x - cx)
                  .compareTo(math.atan2(q.y - cy, q.x - cx)),
            );
            final src = [
              part.markers[0],
              part.markers[1],
              part.markers[3],
              part.markers[2],
            ];
            for (var r = 0; r < 4; r++) {
              try {
                poses.add(
                  _homography(
                    List.generate(
                      4,
                      (i) => math.Point(
                        group[(i + r) % 4].x,
                        group[(i + r) % 4].y,
                      ),
                    ),
                    sourcePoints: src,
                  ),
                );
              } on OmrException {
                continue;
              }
            }
          }
        }
      }
    }
  }
  return poses;
}

List<double> _findPartAlignment(_Gray g, SheetPart part) {
  List<double>? best;
  var quality = .64;
  for (final h in _markerPartPoses(g, part)) {
    final q = _partQuality(g, h, part);
    if (q > quality) {
      quality = q;
      best = h;
    }
  }
  // A visible rectangle can improve perspective fitting; it is optional.
  if (best != null) return best;
  for (final corners in _partFrames(g)) {
    for (var rotation = 0; rotation < 4; rotation++) {
      final points = List.generate(4, (i) => corners[(i + rotation) % 4]);
      final width = points[0].distanceTo(points[1]),
          height = points[1].distanceTo(points[2]);
      if (height < 1 ||
          width / height / part.aspect < .55 ||
          width / height / part.aspect > 1.8) {
        continue;
      }
      try {
        final h = _homography(points, sourcePoints: part.framePoints),
            q = _partQuality(g, h, part);
        if (q > quality) {
          quality = q;
          best = h;
        }
      } on OmrException {
        continue;
      }
    }
  }
  if (best == null) {
    throw OmrException(
      'Không nhận diện đúng vùng ${part.label.toLowerCase()}. Thấy đủ ${part == SheetPart.answers ? 4 : 2} mốc đen và toàn bộ ô tô của vùng này.',
    );
  }
  return best;
}

PartRead recognizeTenPart(Map<String, Object> input) {
  final part = SheetPart.values.byName(input['part'] as String);
  final source = _load(input['photo'] as Uint8List),
      reference = _load(input['reference'] as Uint8List);
  final aligned = _warp(source, _findPartAlignment(source, part));
  final baseline = _warp(reference, _findAlignment(reference));
  double delta(double x, double y) =>
      _density(aligned, x, y) - _density(baseline, x, y);
  final f = part.frame;
  final crop = _png(
    aligned,
    x: math.max(0, f[0].round()),
    y: math.max(0, f[1].round()),
    width: (f[2] - f[0]).round(),
    height: (f[3] - math.max(0, f[1])).round(),
  );
  if (part == SheetPart.answers) {
    return PartRead(
      part: part,
      crop: crop,
      answers: List.generate(
        10,
        (i) => _classify(
          TenSheetGeometry.answerX
              .map((x) => delta(x, TenSheetGeometry.answerY(i)))
              .toList(),
          ['A', 'B', 'C', 'D'],
        ),
      ),
      answerCrops: List.generate(
        10,
        (i) => _png(
          aligned,
          x: 80,
          y: (TenSheetGeometry.answerY(i) - 17).round(),
          width: 155,
          height: 34,
        ),
      ),
    );
  }
  final xs = part == SheetPart.candidate
      ? TenSheetGeometry.candidateX
      : TenSheetGeometry.codeX;
  return PartRead(
    part: part,
    crop: crop,
    digits: xs.map((x) {
      final m = _classify(
        List.generate(10, (i) => delta(x, TenSheetGeometry.digitY(i))),
        List.generate(10, (i) => '$i'),
      );
      return DigitReading(
        m.state == MarkState.single ? m.answer : '?',
        m.state,
      );
    }).toList(),
  );
}

FrameProbe probeTenPart(Map<String, Object> input) {
  final width = input['width'] as int, height = input['height'] as int;
  try {
    final part = SheetPart.values.byName(input['part'] as String);
    final h = _findPartAlignment(
      _Gray(width, height, input['pixels'] as Uint8List),
      part,
    );
    return FrameProbe(
      found: true,
      width: width,
      height: height,
      corners: part.framePoints.map((p) {
        final z = h[6] * p.x + h[7] * p.y + 1;
        return math.Point(
          (h[0] * p.x + h[1] * p.y + h[2]) / z / width,
          (h[3] * p.x + h[4] * p.y + h[5]) / z / height,
        );
      }).toList(),
    );
  } on OmrException {
    return FrameProbe(found: false, width: width, height: height);
  }
}
