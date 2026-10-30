part of 'omr.dart';

// This template is a raster embedded in the supplied PDF. Positions are measured
// individually: the original has small irregularities, not a perfectly even grid.
class CompactSheetGeometry {
  static const width = 1082, height = 1597;
  static const codeX = [459.0, 501.5, 546.5];
  static const upperY = [
    470.5,
    518.0,
    569.0,
    620.5,
    674.5,
    728.5,
    776.5,
    824.5,
    875.5,
    926.5,
  ];
  static const lowerY = [
    1031.5,
    1082.5,
    1136.0,
    1187.0,
    1235.0,
    1283.0,
    1337.0,
    1388.0,
    1439.0,
    1487.0,
  ];
  static const middleY = [
    1031.5,
    1084.5,
    1132.5,
    1183.5,
    1234.5,
    1285.5,
    1337.5,
    1388.5,
    1439.0,
    1490.0,
  ];
  static const rightY = [
    1031.0,
    1082.5,
    1136.5,
    1184.5,
    1235.5,
    1283.5,
    1334.5,
    1388.5,
    1436.5,
    1488.0,
  ];
  static List<double> answerX(int row) {
    if (row < 10) {
      return row == 9
          ? [723, 768.5, 813.5, 855.5]
          : [726.5, 771.5, 816.5, 858.5];
    }
    if (row < 20) return [186.5, 231, 276.5, 318.5];
    if (row < 30) return [456, 500.5, 545.5, 588];
    return [726.5, 771.5, 816.5, 858.5];
  }

  static double answerY(int row) => row < 10
      ? upperY[row]
      : row < 20
      ? lowerY[row - 10]
      : row < 30
      ? middleY[row - 20]
      : rightY[row - 30];
  static const markers = [
    math.Point(0.0, 798.0),
    math.Point(1082.0, 798.0),
    math.Point(409.0, 424.0),
    math.Point(678.0, 424.0),
    math.Point(408.0, 984.0),
    math.Point(678.0, 984.0),
    math.Point(408.0, 1545.0),
    math.Point(678.0, 1545.0),
  ];
  static const corners = [
    math.Point(0.0, 0.0),
    math.Point(1082.0, 0.0),
    math.Point(1082.0, 1597.0),
    math.Point(0.0, 1597.0),
  ];
}

_CompactAlignment _compactAlignment(
  _Gray gray, {
  int minimumSize = 9,
  double minimumArea = .16,
}) {
  final candidates = _markers(
    gray,
    minimumSize: minimumSize,
    maximumCandidates: 40,
    minimumFill: .70,
  );
  final cornerCandidates = candidates.take(10).toList();
  _CompactAlignment? best;
  var bestCost = double.infinity;
  for (var a = 0; a < cornerCandidates.length - 3; a++) {
    for (var b = a + 1; b < cornerCandidates.length - 2; b++) {
      for (var c = b + 1; c < cornerCandidates.length - 1; c++) {
        for (var d = c + 1; d < cornerCandidates.length; d++) {
          final group = [
            cornerCandidates[a],
            cornerCandidates[b],
            cornerCandidates[c],
            cornerCandidates[d],
          ];
          final areas = group.map((m) => m.area);
          if (areas.reduce(math.max) > areas.reduce(math.min) * 2.4) continue;
          final cx = group.fold<double>(0, (s, m) => s + m.x) / 4;
          final cy = group.fold<double>(0, (s, m) => s + m.y) / 4;
          group.sort(
            (p, q) => math
                .atan2(p.y - cy, p.x - cx)
                .compareTo(math.atan2(q.y - cy, q.x - cx)),
          );
          var convex = true;
          for (var i = 0; i < 4; i++) {
            final p = group[i], q = group[(i + 1) % 4], r = group[(i + 2) % 4];
            if ((q.x - p.x) * (r.y - q.y) - (q.y - p.y) * (r.x - q.x) <= 1) {
              convex = false;
            }
          }
          if (!convex) continue;
          var area = 0.0;
          for (var i = 0; i < 4; i++) {
            final p = group[i], q = group[(i + 1) % 4];
            area += p.x * q.y - q.x * p.y;
          }
          if (area.abs() / 2 < gray.width * gray.height * minimumArea) continue;
          for (var turn = 0; turn < 4; turn++) {
            final points = List.generate(4, (i) {
              final m = group[(i + turn) % 4];
              return math.Point(m.x, m.y);
            });
            final h = _homography(
              points,
              sourcePoints: CompactSheetGeometry.corners,
            );
            final inverse = _homography(
              CompactSheetGeometry.corners,
              sourcePoints: points,
            );
            final used = group.toSet();
            final observed = <math.Point<double>>[
              ...CompactSheetGeometry.corners,
            ];
            var cost = 0.0;
            final cornerArea =
                group.fold<double>(0, (sum, m) => sum + m.area) / 4;
            for (
              var index = 0;
              index < CompactSheetGeometry.markers.length;
              index++
            ) {
              final expected = CompactSheetGeometry.markers[index];
              _Marker? nearest;
              math.Point<double>? located;
              var distance = 32.0 * 32.0;
              for (final candidate in candidates) {
                if (used.contains(candidate)) continue;
                // Side markers share the corner size; internal squares are smaller.
                final ratio = candidate.area / cornerArea;
                if (index < 2
                    ? ratio < .45 || ratio > 1.8
                    : ratio < .15 || ratio > .9) {
                  continue;
                }
                final rectified = _compactProject(
                  inverse,
                  candidate.x,
                  candidate.y,
                );
                final delta = rectified - expected;
                final squared = delta.x * delta.x + delta.y * delta.y;
                if (squared < distance) {
                  nearest = candidate;
                  located = rectified;
                  distance = squared;
                }
              }
              if (nearest == null) break;
              used.add(nearest);
              observed.add(located!);
              cost += distance;
            }
            if (observed.length == 12 && cost < bestCost) {
              best = _CompactAlignment(h, observed);
              bestCost = cost;
            }
          }
        }
      }
    }
  }
  if (best == null) {
    throw const OmrException(
      'Không khớp mẫu phiếu gọn 40 câu. Chụp đủ bốn mốc góc ngoài cùng của khung trắc nghiệm, giữ ảnh rõ và đủ sáng.',
    );
  }
  return best;
}

OmrRead recognizeCompactSheet(Map<String, Uint8List> input) {
  final source = _load(input['photo']!), reference = _load(input['reference']!);
  final aligned = _compactWarp(source, _compactAlignment(source));
  final baseline = _compactWarp(reference, _compactAlignment(reference));
  ResponseMark read(
    List<math.Point<double>> points,
    List<String> labels, {
    bool digit = false,
  }) {
    try {
      final differences = points
          .map(
            (p) =>
                _compactDensity(aligned, p.x, p.y) -
                _compactDensity(baseline, p.x, p.y),
          )
          .toList();
      if (digit) {
        // A code column normally has nine unfilled circles. Estimate its
        // shared print/paper noise from the lower values, capped below the
        // faint-mark threshold; never select a digit just because it is darkest.
        final ordered = List<double>.of(differences)..sort();
        final noise = ordered[2].clamp(0.0, .04);
        for (var i = 0; i < differences.length; i++) {
          differences[i] -= noise;
        }
      }
      return _classify(differences, labels);
    } on OmrException {
      // A shadow on an unused question must not block grading active questions.
      // Darkness on active rows remains uncertain and requires teacher review.
      return const ResponseMark(MarkState.uncertain);
    }
  }

  final answers = List.generate(
    40,
    (i) => read(
      CompactSheetGeometry.answerX(i)
          .map((x) => math.Point(x, CompactSheetGeometry.answerY(i)))
          .toList(),
      ['A', 'B', 'C', 'D'],
    ),
  );
  final code = CompactSheetGeometry.codeX.map((x) {
    final mark = read(
      List.generate(10, (i) => math.Point(x, CompactSheetGeometry.upperY[i])),
      List.generate(10, (i) => '$i'),
      digit: true,
    );
    return DigitReading(
      mark.state == MarkState.single ? mark.answer : '?',
      mark.state,
    );
  }).toList();
  return OmrRead(
    answers: answers,
    candidate: const [],
    code: code,
    aligned: _png(aligned),
    candidateCrop: Uint8List(0),
    codeCrop: _png(aligned, x: 425, y: 390, width: 150, height: 570),
    answerCrops: List.generate(
      40,
      (i) => _png(
        aligned,
        x: (CompactSheetGeometry.answerX(i).first - 35).round(),
        y: (CompactSheetGeometry.answerY(i) - 23).round(),
        width: 205,
        height: 46,
      ),
    ),
  );
}

FrameProbe probeCompactSheet(Map<String, Object> input) {
  final width = input['width'] as int,
      height = input['height'] as int,
      bytes = input['pixels'] as Uint8List;
  final missing = FrameProbe(found: false, width: width, height: height);
  if (width < 20 || height < 20 || bytes.length != width * height) {
    return missing;
  }
  try {
    final alignment = _compactAlignment(
      _Gray(width, height, bytes),
      minimumSize: 4,
      minimumArea: .10,
    );
    final h = alignment.h;
    return FrameProbe(
      found: true,
      width: width,
      height: height,
      corners: CompactSheetGeometry.corners.map((p) {
        final z = h[6] * p.x + h[7] * p.y + 1;
        return math.Point(
          (h[0] * p.x + h[1] * p.y + h[2]) / z / width,
          (h[3] * p.x + h[4] * p.y + h[5]) / z / height,
        );
      }).toList(),
    );
  } on OmrException {
    return missing;
  }
}

math.Point<double> _compactProject(List<double> h, double x, double y) {
  final z = h[6] * x + h[7] * y + 1;
  return math.Point(
    (h[0] * x + h[1] * y + h[2]) / z,
    (h[3] * x + h[4] * y + h[5]) / z,
  );
}

// A flat homography alone cannot model a gently curved printed sheet. Match all
// twelve measured square centers first, then correct residuals on a fixed mesh
// in the rectified plane. The same procedure is applied to the blank baseline.
class _CompactAlignment {
  _CompactAlignment(this.h, List<math.Point<double>> observed) {
    const canonical = [
      ...CompactSheetGeometry.corners,
      ...CompactSheetGeometry.markers,
    ];
    for (final indices in const [
      [0, 1, 7],
      [0, 7, 6],
      [0, 6, 4],
      [4, 6, 8],
      [4, 8, 3],
      [3, 8, 10],
      [1, 5, 7],
      [5, 9, 7],
      [5, 2, 9],
      [2, 11, 9],
      [6, 7, 9],
      [6, 9, 8],
      [8, 9, 11],
      [8, 11, 10],
      [3, 10, 11],
      [3, 11, 2],
    ]) {
      mesh.add(
        _CompactTriangle(
          indices.map((i) => canonical[i]).toList(),
          indices.map((i) => observed[i]).toList(),
        ),
      );
    }
  }
  final List<double> h;
  final mesh = <_CompactTriangle>[];
}

class _CompactTriangle {
  _CompactTriangle(this.source, this.destination) {
    final a = source[0], b = source[1], c = source[2];
    denominator = (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y);
    minX = source.map((p) => p.x).reduce(math.min);
    maxX = source.map((p) => p.x).reduce(math.max);
    minY = source.map((p) => p.y).reduce(math.min);
    maxY = source.map((p) => p.y).reduce(math.max);
  }
  final List<math.Point<double>> source, destination;
  late final double denominator, minX, maxX, minY, maxY;
  math.Point<double>? map(double x, double y) {
    if (x < minX || x > maxX || y < minY || y > maxY) return null;
    final a = source[0], b = source[1], c = source[2];
    final u = ((b.y - c.y) * (x - c.x) + (c.x - b.x) * (y - c.y)) / denominator;
    final v = ((c.y - a.y) * (x - c.x) + (a.x - c.x) * (y - c.y)) / denominator;
    final w = 1 - u - v;
    if (u < -.000001 || v < -.000001 || w < -.000001) return null;
    return math.Point(
      u * destination[0].x + v * destination[1].x + w * destination[2].x,
      u * destination[0].y + v * destination[1].y + w * destination[2].y,
    );
  }
}

_Gray _compactWarp(_Gray source, _CompactAlignment alignment) {
  const width = CompactSheetGeometry.width,
      height = CompactSheetGeometry.height;
  final bytes = Uint8List(width * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      math.Point<double>? point;
      for (final triangle in alignment.mesh) {
        point = triangle.map(x.toDouble(), y.toDouble());
        if (point != null) break;
      }
      if (point == null) {
        throw const OmrException(
          'Không căn chỉnh được vùng phiếu. Giữ phiếu phẳng và chụp lại.',
        );
      }
      bytes[y * width + x] = _sample(
        source,
        alignment.h,
        point.x,
        point.y,
      ).round().clamp(0, 255);
    }
  }
  return _Gray(width, height, bytes);
}

// Measure paper outside the larger printed circles, not their dark outlines.
double _compactDensity(_Gray g, double x, double y) =>
    _density(g, x, y, coreRadius: 11, backgroundInner: 20, backgroundOuter: 23);
