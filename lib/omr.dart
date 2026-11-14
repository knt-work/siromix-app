import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'data.dart';

part 'compact_omr.dart';
part 'compact_border.dart';
part 'qm_omr.dart';

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

enum AnswerReviewReason { faint, competing, unevenFill, darkPaper }

class AnswerReviewDetail {
  const AnswerReviewDetail(this.reason, this.scores);

  final AnswerReviewReason reason;
  final List<double> scores;
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
    this.answerReviewDetails = const {},
  });
  final List<ResponseMark> answers;
  final List<DigitReading> candidate, code;
  final Uint8List aligned, candidateCrop, codeCrop;
  final List<Uint8List> answerCrops;
  final Map<int, AnswerReviewDetail> answerReviewDetails;
  String get candidateText => candidate.map((v) => v.value).join();
  String get codeText => code.map((v) => v.value).join();
  bool get candidateClear =>
      candidate.length == 6 &&
      candidate.every((v) => v.state == MarkState.single);
  bool get codeClear =>
      code.length == 3 && code.every((v) => v.state == MarkState.single);
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

// Estimate paper brightness in tiles using the 90th percentile. Interpolate
// across tile centers so the correction does not create seams for the marker
// detector. The bounded stretch recovers washed-out ink without binarizing it.
_Gray _lightingCorrectedMarkerImage(_Gray source) {
  final width = source.width, height = source.height;
  final tileSize = math.max(32, (math.max(width, height) / 24).round());
  final columns = (width / tileSize).ceil();
  final rows = (height / tileSize).ceil();
  final paper = Uint8List(columns * rows);
  final histogram = Int32List(256);
  for (var row = 0; row < rows; row++) {
    final top = row * height ~/ rows, bottom = (row + 1) * height ~/ rows;
    for (var col = 0; col < columns; col++) {
      final left = col * width ~/ columns, right = (col + 1) * width ~/ columns;
      histogram.fillRange(0, histogram.length, 0);
      var samples = 0;
      for (var y = top; y < bottom; y += 3) {
        for (var x = left; x < right; x += 3) {
          histogram[source.pixels[y * width + x]]++;
          samples++;
        }
      }
      var brightness = 255;
      var brightSamples = histogram[brightness];
      while (brightSamples * 10 < samples) {
        brightSamples += histogram[--brightness];
      }
      paper[row * columns + col] = brightness;
    }
  }

  final pixels = Uint8List(source.pixels.length);
  for (var y = 0; y < height; y++) {
    final gridY = ((y + .5) * rows / height - .5).clamp(0.0, rows - 1.0);
    final top = gridY.floor() * columns, bottom = gridY.ceil() * columns;
    final dy = gridY - gridY.floor();
    for (var x = 0; x < width; x++) {
      final gridX = ((x + .5) * columns / width - .5).clamp(0.0, columns - 1.0);
      final left = gridX.floor(), right = gridX.ceil(), dx = gridX - left;
      final upper = paper[top + left] * (1 - dx) + paper[top + right] * dx;
      final lower =
          paper[bottom + left] * (1 - dx) + paper[bottom + right] * dx;
      final background = upper * (1 - dy) + lower * dy;
      final index = y * width + x;
      pixels[index] = (235 - 1.9 * (background - source.pixels[index]))
          .round()
          .clamp(0, 255);
    }
  }
  return _Gray(width, height, pixels);
}

List<_Marker> _markers(
  _Gray gray, {
  int minimumSize = 9,
  int maximumCandidates = 16,
  double minimumFill = .80,
}) {
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
        tail / (w * h) > minimumFill) {
      found.add(_Marker((minX + maxX) / 2, (minY + maxY) / 2, tail));
    }
  }
  found.sort((a, b) => b.area.compareTo(a.area));
  return found.take(maximumCandidates).toList();
}

// Solve a homography mapping canonical coordinates to the photographed sheet.
List<double> _homography(
  List<math.Point<double>> dst, {
  required List<math.Point<double>> sourcePoints,
}) {
  final src = sourcePoints;
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

double _density(
  _Gray g,
  double x,
  double y, {
  int coreRadius = 6,
  int backgroundInner = 13,
  int backgroundOuter = 15,
}) {
  final bg = <double>[];
  for (var dy = -backgroundOuter; dy <= backgroundOuter; dy += 2) {
    for (var dx = -backgroundOuter; dx <= backgroundOuter; dx += 2) {
      final r = dx * dx + dy * dy;
      if (r >= backgroundInner * backgroundInner &&
          r <= backgroundOuter * backgroundOuter) {
        bg.add(g.at(x + dx, y + dy));
      }
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
  for (var dy = -coreRadius; dy <= coreRadius; dy++) {
    for (var dx = -coreRadius; dx <= coreRadius; dx++) {
      if (dx * dx + dy * dy <= coreRadius * coreRadius) {
        sum += (1 - g.at(x + dx, y + dy) / white).clamp(0, 1);
        n++;
      }
    }
  }
  return sum / n;
}

const _possibleMark = .065;
const _clearMark = .33;
const _answerLead = .20;
const _minimumFill = .16;

ResponseMark _classifyAnswer(
  List<double> scores,
  List<String> labels, {
  required bool Function(int index) hasDistributedFill,
  bool checkClearFill = false,
  void Function(AnswerReviewReason reason)? onReview,
}) {
  final mark = _classify(scores, labels, reviewCompetingAnswers: true);
  final hasClearMark = scores.any((score) => score >= _clearMark);
  final light = mark.state == MarkState.uncertain && !hasClearMark
      ? _isolatedLightMark(scores)
      : null;
  if (light != null || (checkClearFill && mark.state == MarkState.single)) {
    final index = light ?? labels.indexOf(mark.answer);
    if (hasDistributedFill(index)) {
      return ResponseMark(MarkState.single, labels[index]);
    }
    onReview?.call(AnswerReviewReason.unevenFill);
    return const ResponseMark(MarkState.uncertain);
  }
  if (mark.state == MarkState.uncertain) {
    onReview?.call(
      hasClearMark ? AnswerReviewReason.competing : AnswerReviewReason.faint,
    );
  }
  return mark;
}

int? _isolatedLightMark(List<double> scores) {
  const minimumScore = .20, minimumLead = .14;
  final candidate = scores.indexWhere((score) => score >= minimumScore);
  if (candidate < 0) return null;
  for (var i = 0; i < scores.length; i++) {
    if (i != candidate &&
        (scores[i] > _possibleMark ||
            scores[candidate] - scores[i] < minimumLead)) {
      return null;
    }
  }
  return candidate;
}

final _digitLabels = List.generate(10, (i) => '$i');

DigitReading _classifyDigit(List<double> core, {List<double>? sides}) {
  final scores = sides == null
      ? core
      : List.generate(core.length, (i) => math.min(core[i], sides[i]));
  final mark = _classify(scores, _digitLabels);
  // A solid mark can coexist with weak artifacts in other bubbles.
  if (mark.state == MarkState.uncertain) {
    final filled = scores.indexWhere((score) => score >= .50);
    if (filled >= 0 &&
        core.indexed.every((entry) => entry.$1 == filled || entry.$2 < .12)) {
      return DigitReading(_digitLabels[filled], MarkState.single);
    }
  }
  return DigitReading(
    mark.state == MarkState.single ? mark.answer : '?',
    mark.state,
  );
}

ResponseMark _classify(
  List<double> differences,
  List<String> labels, {
  bool reviewCompetingAnswers = false,
}) {
  final sure = <int>[], possible = <int>[];
  for (var i = 0; i < differences.length; i++) {
    if (differences[i] >= _clearMark) sure.add(i);
    if (differences[i] > _possibleMark) possible.add(i);
  }
  if (possible.isEmpty) return const ResponseMark(MarkState.blank);
  if (sure.length == 1) {
    final winner = sure.single;
    if (possible.length == 1 ||
        (reviewCompetingAnswers &&
            possible.every(
              (other) =>
                  other == winner ||
                  differences[winner] - differences[other] >= _answerLead,
            ))) {
      return ResponseMark(MarkState.single, labels[winner]);
    }
  }
  if (!reviewCompetingAnswers &&
      sure.length >= 2 &&
      sure.length == possible.length) {
    return const ResponseMark(MarkState.multiple);
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
