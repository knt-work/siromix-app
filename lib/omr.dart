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
