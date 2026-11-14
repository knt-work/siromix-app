part of 'omr.dart';

// Derived from the actual vector PDF supplied by the user, not the differently
// sized QM variants on the web. Units: 2x PDF points, origin at outer TL marker.
class QmSheetGeometry {
  static const width = 1053, height = 1485;
  static math.Point<double> point(double x, double y) => math.Point(
    ((x - 34.16) * 2).clamp(0.0, 1053.0),
    ((y - 49.74) * 2).clamp(0.0, 1485.0),
  );
  static const corners = [
    math.Point(0.0, 0.0),
    math.Point(1053.0, 0.0),
    math.Point(1053.0, 1485.0),
    math.Point(0.0, 1485.0),
  ];
  static final markers = [
    point(416.3, 97.5),
    point(505.46, 97.5),
    point(416.3, 268.26),
    point(505.46, 268.26),
    point(34.1, 281.94),
    point(560.54, 281.94),
    point(34.1, 457.38),
    point(560.54, 457.38),
    point(34.1, 568.02),
    point(560.54, 568.02),
    point(297.38, 792.06),
    point(165.74, 281.94),
    point(297.38, 281.94),
    point(165.74, 457.38),
    point(297.38, 457.38),
    point(428.9, 457.38),
    point(121.82, 568.02),
    point(165.74, 568.02),
    point(209.54, 568.02),
    point(297.38, 568.02),
    point(385.1, 568.02),
    point(428.9, 568.02),
    point(472.82, 568.02),
    point(121.82, 792.06),
    point(209.54, 792.06),
    point(385.1, 792.06),
    point(472.82, 792.06),
  ];
  static const xs = [
    [65.06, 92.54, 120.02, 147.5],
    [196.7, 224.18, 251.66, 279.02],
    [328.34, 355.7, 383.18, 410.66],
    [459.86, 487.34, 514.82, 542.3],
  ];
  static const oneY = [
    317.82,
    330.66,
    343.5,
    356.34,
    369.06,
    381.9,
    394.74,
    407.58,
    420.42,
    433.26,
  ];
  static const twoY = [509.46, 522.3, 535.14, 547.98];
  static const digitsY = [
    651.3,
    664.14,
    676.98,
    689.82,
    702.66,
    715.5,
    728.34,
    741.06,
    753.9,
    766.74,
  ];
  static const shortX = [
    [65.06, 77.9, 90.74, 103.58],
    [152.9, 165.62, 178.46, 191.3],
    [240.62, 253.46, 266.18, 279.02],
    [328.34, 341.18, 353.9, 366.74],
    [416.06, 428.9, 441.74, 454.46],
    [503.78, 516.62, 529.46, 542.3],
  ];
}

// Fixed triangulation of the PDF marker centers. Local residual correction
// follows gently curved paper without moving bubbles to the darkest nearby ink.
class _QmAlignment {
  _QmAlignment(this.h, List<math.Point<double>> observed) {
    final canonical = [...QmSheetGeometry.corners, ...QmSheetGeometry.markers];
    for (final indices in const [
      [0, 1, 4],
      [1, 4, 5],
      [4, 5, 7],
      [4, 6, 7],
      [1, 5, 9],
      [5, 7, 9],
      [7, 9, 11],
      [0, 4, 15],
      [0, 8, 15],
      [4, 6, 16],
      [4, 15, 16],
      [8, 10, 17],
      [8, 15, 17],
      [15, 16, 18],
      [15, 17, 18],
      [6, 7, 19],
      [7, 11, 19],
      [6, 16, 19],
      [16, 18, 19],
      [10, 12, 20],
      [10, 17, 20],
      [17, 20, 21],
      [17, 18, 22],
      [17, 21, 22],
      [18, 22, 23],
      [18, 19, 24],
      [18, 23, 24],
      [19, 24, 25],
      [11, 13, 26],
      [11, 19, 26],
      [19, 25, 26],
      [3, 12, 27],
      [12, 20, 27],
      [20, 21, 27],
      [22, 23, 28],
      [14, 23, 28],
      [21, 22, 28],
      [21, 27, 28],
      [14, 23, 29],
      [23, 24, 29],
      [24, 25, 29],
      [2, 13, 30],
      [13, 26, 30],
      [25, 26, 30],
      [25, 29, 30],
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

_Gray _qmWarp(_Gray source, _QmAlignment alignment) {
  const width = QmSheetGeometry.width, height = QmSheetGeometry.height;
  final pixels = Uint8List(width * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      math.Point<double>? mapped;
      for (final triangle in alignment.mesh) {
        mapped = triangle.map(x.toDouble(), y.toDouble());
        if (mapped != null) break;
      }
      final p = mapped ?? math.Point(x.toDouble(), y.toDouble());
      pixels[y * width + x] = _sample(
        source,
        alignment.h,
        p.x,
        p.y,
      ).round().clamp(0, 255);
    }
  }
  return _Gray(width, height, pixels);
}

_QmAlignment _qmAlignment(
  _Gray gray, {
  int minimumSize = 5,
  double minimumArea = .16,
}) {
  final candidates = _markers(
    gray,
    minimumSize: minimumSize,
    maximumCandidates: 60,
    minimumFill: .70,
  );
  final cornerCandidates = candidates.take(10).toList();
  _QmAlignment? best;
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
              sourcePoints: QmSheetGeometry.corners,
            );
            final inverse = _homography(
              QmSheetGeometry.corners,
              sourcePoints: points,
            );
            final used = group.toSet();
            final observed = <math.Point<double>>[...QmSheetGeometry.corners];
            var cost = 0.0;
            final cornerArea =
                group.fold<double>(0, (sum, m) => sum + m.area) / 4;
            for (
              var index = 0;
              index < QmSheetGeometry.markers.length;
              index++
            ) {
              final expected = QmSheetGeometry.markers[index];
              _Marker? nearest;
              math.Point<double>? located;
              var distance = 32.0 * 32.0;
              for (final candidate in candidates) {
                if (used.contains(candidate)) continue;
                // QM interior markers are smaller than the four outer corners.
                final ratio = candidate.area / cornerArea;
                if (ratio < .10 || ratio > 1.2) {
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
              if (nearest == null) {
                if (index < 11) break;
                // Additional controls are optional; retain the projective estimate
                // when a small printed marker is damaged or too faint.
                observed.add(expected);
                cost += 32 * 32;
                continue;
              }
              used.add(nearest);
              observed.add(located!);
              cost += distance;
            }
            if (observed.length == 4 + QmSheetGeometry.markers.length &&
                cost < bestCost) {
              best = _QmAlignment(h, observed);
              bestCost = cost;
            }
          }
        }
      }
    }
  }
  if (best == null) {
    throw const OmrException(
      'Không khớp mẫu QM2025 A4. Chụp trọn phiếu, lấy đủ bốn mốc góc ngoài cùng, giữ phiếu phẳng và đủ sáng.',
    );
  }
  return best;
}

OmrRead recognizeQmSheet(Map<String, Object> input) {
  final source = _load(input['photo']! as Uint8List),
      ref = _load(input['reference']! as Uint8List);
  _QmAlignment alignment;
  try {
    alignment = _qmAlignment(source);
  } on OmrException {
    alignment = _qmAlignment(_lightingCorrectedMarkerImage(source));
  }
  final aligned = _qmWarp(source, alignment);
  final baseline = _qmWarp(ref, _qmAlignment(ref));
  // Sample paper beyond the circle outline. The former 8-10 px annulus
  // crossed larger Part I outlines and falsely triggered the dark-photo guard.
  double score(math.Point<double> p, {int radius = 3}) =>
      _density(
        aligned,
        p.x,
        p.y,
        coreRadius: radius,
        backgroundInner: 12,
        backgroundOuter: 14,
      ) -
      _density(
        baseline,
        p.x,
        p.y,
        coreRadius: radius,
        backgroundInner: 12,
        backgroundOuter: 14,
      );

  ResponseMark read(
    List<math.Point<double>> points,
    List<String> labels, {
    bool reviewCompetingAnswers = false,
  }) {
    try {
      final differences = points.map(score).toList();
      if (!reviewCompetingAnswers) return _classify(differences, labels);
      return _classifyAnswer(
        differences,
        labels,
        hasDistributedFill: (i) {
          const offsets = [
            math.Point(-1.0, 0.0),
            math.Point(1.0, 0.0),
            math.Point(0.0, -1.0),
            math.Point(0.0, 1.0),
          ];
          return offsets.every(
            (offset) => score(points[i] + offset, radius: 2) >= _minimumFill,
          );
        },
      );
    } on OmrException {
      return const ResponseMark(MarkState.uncertain);
    }
  }

  final answers = <ResponseMark>[];
  final crops = <Uint8List>[];
  Uint8List crop(double x, double y, double w, double h) {
    final p = QmSheetGeometry.point(x, y);
    return _png(
      aligned,
      x: p.x.round(),
      y: p.y.round(),
      width: (w * 2).round(),
      height: (h * 2).round(),
    );
  }

  for (var i = 0; i < 40; i++) {
    final xs = QmSheetGeometry.xs[i ~/ 10], y = QmSheetGeometry.oneY[i % 10];
    answers.add(
      read(xs.map((x) => QmSheetGeometry.point(x, y)).toList(), [
        'A',
        'B',
        'C',
        'D',
      ], reviewCompetingAnswers: true),
    );
    crops.add(crop(xs.first - 8, y - 7, 99, 14));
  }
  for (var i = 0; i < 8; i++) {
    final xs = QmSheetGeometry.xs[i ~/ 2].skip((i % 2) * 2).take(2).toList();
    final ideas = QmSheetGeometry.twoY
        .map(
          (y) => read(xs.map((x) => QmSheetGeometry.point(x, y)).toList(), [
            'T',
            'F',
          ]),
        )
        .toList();
    final text = ideas
        .map(
          (m) => switch (m.state) {
            MarkState.single => m.answer,
            MarkState.blank => '_',
            MarkState.multiple => 'X',
            MarkState.uncertain => '?',
          },
        )
        .join();
    answers.add(
      ideas.any((m) => m.state == MarkState.uncertain)
          ? ResponseMark(MarkState.uncertain, text)
          : ideas.any((m) => m.state == MarkState.single)
          ? ResponseMark(MarkState.single, text)
          : ResponseMark(
              ideas.every((m) => m.state == MarkState.blank)
                  ? MarkState.blank
                  : MarkState.multiple,
            ),
    );
    crops.add(crop(xs.first - 8, 500, 44, 56));
  }
  for (var i = 0; i < 6; i++) {
    final chars = <ResponseMark>[];
    for (var col = 0; col < 4; col++) {
      final labels = [
        if (col == 0) '-',
        if (col == 1 || col == 2) ',',
        for (var d = 0; d < 10; d++) '$d',
      ];
      final ys = [
        if (col == 0) 625.74,
        if (col == 1 || col == 2) 638.58,
        ...QmSheetGeometry.digitsY,
      ];
      chars.add(
        read(
          ys
              .map(
                (y) => QmSheetGeometry.point(QmSheetGeometry.shortX[i][col], y),
              )
              .toList(),
          labels,
        ),
      );
    }
    final text = chars
        .map((m) => m.state == MarkState.single ? m.answer : ' ')
        .join()
        .trim();
    final state = chars.any((m) => m.state == MarkState.uncertain)
        ? MarkState.uncertain
        : chars.any((m) => m.state == MarkState.multiple)
        ? MarkState.multiple
        : chars.every((m) => m.state == MarkState.blank)
        ? MarkState.blank
        : fitsNumberGrid(text)
        ? MarkState.single
        : MarkState.uncertain;
    answers.add(ResponseMark(state, state == MarkState.single ? text : ''));
    crops.add(crop(QmSheetGeometry.shortX[i][0] - 7, 615, 54, 160));
  }
  final code = [520.34, 530.90, 541.34].map((x) {
    try {
      return _classifyDigit(
        List.generate(_digitLabels.length, (n) {
          return score(QmSheetGeometry.point(x, 115.86 + 14.88 * n));
        }),
      );
    } on OmrException {
      return const DigitReading('?', MarkState.uncertain);
    }
  }).toList();
  final candidate = [432.02, 442.58, 453.02, 463.58, 474.02, 484.58].map((x) {
    final mark = read(
      List.generate(10, (n) => QmSheetGeometry.point(x, 115.86 + 14.88 * n)),
      List.generate(10, (n) => '$n'),
    );
    return DigitReading(
      mark.state == MarkState.single ? mark.answer : '?',
      mark.state,
    );
  }).toList();
  return OmrRead(
    answers: answers,
    candidate: candidate,
    code: code,
    aligned: _png(aligned),
    candidateCrop: crop(423, 108, 70, 151),
    codeCrop: crop(511, 108, 39, 151),
    answerCrops: crops,
  );
}

FrameProbe probeQmSheet(Map<String, Object> input) {
  final w = input['width'] as int,
      h = input['height'] as int,
      bytes = input['pixels'] as Uint8List;
  final missing = FrameProbe(found: false, width: w, height: h);
  if (w < 20 || h < 20 || bytes.length != w * h) return missing;
  try {
    final alignment = _qmAlignment(
      _Gray(w, h, bytes),
      minimumSize: 3,
      minimumArea: .10,
    );
    return FrameProbe(
      found: true,
      width: w,
      height: h,
      corners: QmSheetGeometry.corners.map((p) {
        final q = _compactProject(alignment.h, p.x, p.y);
        return math.Point(q.x / w, q.y / h);
      }).toList(),
    );
  } on OmrException {
    return missing;
  }
}
