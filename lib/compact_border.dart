part of 'omr.dart';

// Outer ink strokes measured on the NTL reference, relative to its corner
// marker centers. The border is outside the coordinate system used for bubbles.
const _compactBorderCorners = [
  math.Point(-32.0, -35.0),
  math.Point(1120.0, -35.0),
  math.Point(1120.0, 1627.0),
  math.Point(-32.0, 1627.0),
];

class _CompactBorderLine {
  const _CompactBorderLine(this.slope, this.intercept, this.votes);
  final double slope, intercept;
  final int votes;
}

// Vote for long, nearly horizontal or vertical dark strokes. Broken segments
// still vote for the same line. Coordinates are returned in source pixels.
List<_CompactBorderLine> _compactBorderLines(
  _Gray source, {
  required bool vertical,
}) {
  final step = math.max(source.width, source.height) / 520;
  final along = ((vertical ? source.height : source.width) / step).floor();
  final across = ((vertical ? source.width : source.height) / step).floor();
  final margin = along ~/ 2;
  final bins = across + 2 * margin;
  final peaks = <_CompactBorderLine>[];
  final ink = <math.Point<int>>[];
  double sample(int a, int b) =>
      vertical ? source.at(b * step, a * step) : source.at(a * step, b * step);
  for (var a = 2; a < along - 2; a++) {
    for (var b = 2; b < across - 2; b++) {
      final value = sample(a, b);
      if (value < 156 &&
          math.max(sample(a, b - 2), sample(a, b + 2)) - value > 30) {
        ink.add(math.Point(a, b));
      }
    }
  }
  for (var angle = -20; angle <= 20; angle++) {
    final slope = math.tan(angle * math.pi / 180);
    final counts = Int32List(bins);
    for (final p in ink) {
      counts[(p.y - slope * p.x).round() + margin]++;
    }
    for (var i = 1; i < bins - 1; i++) {
      final votes = counts[i];
      if (votes >= along * .16 &&
          votes >= counts[i - 1] &&
          votes > counts[i + 1]) {
        peaks.add(_CompactBorderLine(slope, (i - margin) * step, votes));
      }
    }
  }
  peaks.sort((a, b) => b.votes.compareTo(a.votes));
  final selected = <_CompactBorderLine>[];
  final middle = along * step / 2;
  for (final line in peaks) {
    if (selected.any(
      (other) =>
          (line.slope - other.slope).abs() < .10 &&
          (line.intercept -
                      other.intercept +
                      (line.slope - other.slope) * middle)
                  .abs() <
              step * 4,
    )) {
      continue;
    }
    selected.add(line);
    if (selected.length == 8) break;
  }
  return selected;
}

math.Point<double> _compactBorderIntersection(
  _CompactBorderLine horizontal,
  _CompactBorderLine vertical,
) {
  final x =
      (vertical.intercept + vertical.slope * horizontal.intercept) /
      (1 - vertical.slope * horizontal.slope);
  return math.Point(x, horizontal.intercept + horizontal.slope * x);
}

bool _compactBorderHasInk(
  _Gray source,
  math.Point<double> a,
  math.Point<double> b,
) {
  final edge = b - a;
  final normal = math.Point(-edge.y, edge.x) * (1 / edge.magnitude);
  final tolerance = math.max(source.width, source.height) * .004;
  var hits = 0;
  for (var i = 1; i < 32; i++) {
    final p = a + edge * (i / 32);
    for (var offset = -2; offset <= 2; offset++) {
      final q = p + normal * (offset * tolerance / 2);
      if (source.at(q.x, q.y) < 150) {
        hits++;
        break;
      }
    }
  }
  return hits >= 19;
}

_CompactAlignment? _compactBorderAlignment(_Gray source, _Gray markerImage) {
  final horizontal = _compactBorderLines(source, vertical: false);
  final vertical = _compactBorderLines(source, vertical: true);
  final markers = _markers(
    markerImage,
    minimumSize: 6,
    maximumCandidates: 60,
    minimumFill: .48,
  );
  _CompactAlignment? best;
  var bestCost = double.infinity;
  for (var i = 0; i < horizontal.length; i++) {
    for (var j = i + 1; j < horizontal.length; j++) {
      for (var k = 0; k < vertical.length; k++) {
        for (var l = k + 1; l < vertical.length; l++) {
          final frame = [
            _compactBorderIntersection(horizontal[i], vertical[k]),
            _compactBorderIntersection(horizontal[i], vertical[l]),
            _compactBorderIntersection(horizontal[j], vertical[l]),
            _compactBorderIntersection(horizontal[j], vertical[k]),
          ];
          if (frame.any(
            (p) =>
                p.x < 0 ||
                p.x >= source.width ||
                p.y < 0 ||
                p.y >= source.height,
          )) {
            continue;
          }
          final edges = List.generate(4, (n) => frame[(n + 1) % 4] - frame[n]);
          final cross = List.generate(4, (n) {
            final a = edges[n], b = edges[(n + 1) % 4];
            return a.x * b.y - a.y * b.x;
          });
          if (!(cross.every((v) => v > 0) || cross.every((v) => v < 0))) {
            continue;
          }
          if (cross.reduce((a, b) => a + b).abs() / 4 <
              source.width * source.height * .16) {
            continue;
          }
          if (!List.generate(
            4,
            (n) => _compactBorderHasInk(source, frame[n], frame[(n + 1) % 4]),
          ).every((supported) => supported)) {
            continue;
          }
          if (cross.first < 0) frame.setAll(0, frame.reversed.toList());

          for (var turn = 0; turn < 4; turn++) {
            final corners = List.generate(4, (n) => frame[(turn + n) % 4]);
            final h = _homography(corners, sourcePoints: _compactBorderCorners);
            final inverse = _homography(
              _compactBorderCorners,
              sourcePoints: corners,
            );
            final projected = markers
                .map((m) => _compactProject(inverse, m.x, m.y))
                .toList();
            var cost = 0.0;
            var upper = 0, middle = 0, lower = 0;
            final observed = <math.Point<double>>[];
            const expected = [
              ...CompactSheetGeometry.corners,
              ...CompactSheetGeometry.markers,
            ];
            for (var n = 0; n < expected.length; n++) {
              var nearest = expected[n];
              var distance = 30.0;
              var found = false;
              for (final point in projected) {
                final delta = point.distanceTo(expected[n]);
                if (delta < distance) {
                  nearest = point;
                  distance = delta;
                  found = true;
                }
              }
              observed.add(nearest);
              cost += distance * distance;
              if (found && n >= 6) {
                if (n < 8) {
                  upper++;
                } else if (n < 10) {
                  middle++;
                } else {
                  lower++;
                }
              }
            }
            // An arbitrary rectangle must not match. Require internal evidence
            // near the code, between the answer blocks and below the bottom rows.
            if (upper > 0 &&
                middle > 0 &&
                lower > 0 &&
                upper + middle + lower >= 4 &&
                cost < bestCost) {
              best = _CompactAlignment(h, observed);
              bestCost = cost;
            }
          }
        }
      }
    }
  }
  return best;
}

// Fit one small translation to the printed rings in each ten-row block.
// Evaluate the whole block so a filled bubble or ink spot cannot pull its
// own reading position toward darker pixels.
math.Point<int> _compactBorderBlockOffset(_Gray image, int firstRow) {
  const directions = [
    math.Point(1.0, 0.0),
    math.Point(-1.0, 0.0),
    math.Point(0.0, 1.0),
    math.Point(0.0, -1.0),
    math.Point(.7071, .7071),
    math.Point(-.7071, .7071),
    math.Point(.7071, -.7071),
    math.Point(-.7071, -.7071),
  ];
  var best = const math.Point(0, 0);
  var bestScore = double.negativeInfinity;
  for (var dy = -10; dy <= 10; dy += 2) {
    for (var dx = -10; dx <= 10; dx += 2) {
      var score = 0.0;
      for (var row = firstRow; row < firstRow + 10; row += 2) {
        final y = CompactSheetGeometry.answerY(row) + dy;
        for (final center in CompactSheetGeometry.answerX(row)) {
          final x = center + dx;
          for (final d in directions) {
            score +=
                image.at(x + 22 * d.x, y + 22 * d.y) -
                image.at(x + 16 * d.x, y + 16 * d.y);
          }
        }
      }
      // Prefer the original estimate when two offsets have similar evidence.
      score -= 10 * (dx.abs() + dy.abs());
      if (score > bestScore) {
        bestScore = score;
        best = math.Point(dx, dy);
      }
    }
  }
  if (bestScore < 8 * 20 * 5) {
    throw const OmrException(
      'Chưa thấy rõ các ô đáp án của phiếu NTL. Giữ phiếu phẳng và chụp lại.',
    );
  }
  return best;
}
