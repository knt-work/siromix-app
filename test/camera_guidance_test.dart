import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:siromix/camera_guidance.dart';
import 'package:siromix/omr.dart';

void main() {
  const points = [
    math.Point(.164, .224),
    math.Point(.835, .224),
    math.Point(.835, .772),
    math.Point(.164, .772),
  ];
  FrameProbe frame(List<math.Point<double>> p, {int w = 1000, int h = 1778}) =>
      FrameProbe(found: true, width: w, height: h, corners: p);
  test(
    'luminance sampling respects YUV row/pixel padding and BGRA channels',
    () {
      final plane = Uint8List.fromList([
        10,
        0,
        20,
        0,
        30,
        0,
        40,
        0,
        99,
        99,
        50,
        0,
        60,
        0,
        70,
        0,
        80,
        0,
        99,
        99,
      ]);
      final packed = sampleLuminance(
        bytes: plane,
        width: 4,
        height: 2,
        rowStride: 10,
        pixelStride: 2,
      );
      expect(packed['pixels'], [10, 20, 30, 40, 50, 60, 70, 80]);
      final colors = sampleLuminance(
        bytes: Uint8List.fromList([0, 0, 255, 255, 255, 0, 0, 255]),
        width: 2,
        height: 1,
        rowStride: 8,
        pixelStride: 4,
        bgra: true,
      );
      expect(colors['pixels'], [76, 29]);
      expect(
        () => sampleLuminance(
          bytes: Uint8List(2),
          width: 4,
          height: 2,
          rowStride: 4,
        ),
        throwsFormatException,
      );
    },
  );
  test('guide coordinates stay inside the actual preview', () {
    final g = CameraGuideLayout(const Size(320, 426), 9 / 16);
    expect(g.preview.contains(g.target.topLeft), true);
    expect(g.preview.contains(g.target.bottomRight), true);
    expect(g.containsSheet(frame(points)), true);
  });
  test('portrait, sensor-rotated and differing analysis/preview ratios map consistently', () {
    final g = CameraGuideLayout(const Size(300, 400), 9 / 16);
    expect(g.containsSheet(frame(points)), true);
    final rotated = points.map((p) => math.Point(p.y, p.x)).toList();
    expect(g.containsSheet(frame(rotated, w: 1778, h: 1000)), true);
    final broader = points
        .map((p) => math.Point(.5 + (p.x - .5) * (.5625 / .75), p.y))
        .toList();
    expect(g.containsSheet(frame(broader, w: 750, h: 1000)), true);
  });
  test('off-guide and too-distant sheets cannot show green', () {
    final g = CameraGuideLayout(const Size(300, 400), 9 / 16);
    expect(
      g.containsSheet(
        frame(points.map((p) => math.Point(p.x - .2, p.y)).toList()),
      ),
      false,
    );
    expect(
      g.containsSheet(
        frame(const [
          math.Point(.45, .45),
          math.Point(.55, .45),
          math.Point(.55, .55),
          math.Point(.45, .55),
        ]),
      ),
      false,
    );
    expect(
      g.containsSheet(
        const FrameProbe(found: false, width: 1000, height: 1778),
      ),
      false,
    );
  });
  test('partial framing accepts offset complete field, rejects clipping and tiny fields', () {
    final g = CameraGuideLayout(const Size(300, 400), .75, markerAspect: .38);
    FrameProbe field(double left, double right, double top, double bottom) =>
        FrameProbe(
          found: true,
          width: 750,
          height: 1000,
          corners: [
            math.Point(left, top),
            math.Point(right, top),
            math.Point(right, bottom),
            math.Point(left, bottom),
          ],
        );
    final offset = field(.60, .91, .12, .84);
    expect(g.containsSheet(offset), false);
    expect(g.containsSheet(offset, flexible: true), true);
    expect(g.containsSheet(field(.8, 1.1, .1, .9), flexible: true), false);
    expect(g.containsSheet(field(.45, .50, .45, .50), flexible: true), false);
  });
  test('green needs two stable frames, disappears immediately on loss, and expires', () {
    final tracker = GuideTracker(), t = DateTime(2026);
    tracker.observe(true, t);
    expect(tracker.verdict, GuideVerdict.searching);
    tracker.observe(true, t.add(const Duration(milliseconds: 450)));
    expect(tracker.verdict, GuideVerdict.valid);
    tracker.observe(false, t.add(const Duration(milliseconds: 900)));
    expect(tracker.verdict, GuideVerdict.invalid);
    tracker.observe(true, t.add(const Duration(milliseconds: 1350)));
    expect(tracker.verdict, GuideVerdict.searching);
    tracker.observe(true, t.add(const Duration(milliseconds: 1800)));
    expect(tracker.verdict, GuideVerdict.valid);
    expect(tracker.expire(t.add(const Duration(seconds: 4))), true);
    expect(tracker.verdict, GuideVerdict.searching);
  });
  test(
    'live probe detects the supplied template without doing answer recognition',
    () {
      final reference = img.decodePng(
        File('assets/templates/abcd-10-v1.png').readAsBytesSync(),
      )!;
      final paper = img.copyResize(reference, width: 800);
      final scene = img.Image(width: 1000, height: 1778)
        ..clear(img.ColorRgb8(245, 245, 245));
      img.compositeImage(
        scene,
        paper,
        dstX: 100,
        dstY: (1778 - paper.height) ~/ 2,
      );
      final gray = Uint8List(scene.width * scene.height);
      for (var y = 0; y < scene.height; y++) {
        for (var x = 0; x < scene.width; x++) {
          gray[y * scene.width + x] = scene.getPixel(x, y).r.toInt();
        }
      }
      final input = sampleLuminance(
        bytes: gray,
        width: scene.width,
        height: scene.height,
        rowStride: scene.width,
      );
      final probe = probeTenSheet(input);
      expect(probe.found, true);
      expect(
        CameraGuideLayout(const Size(300, 400), 9 / 16).containsSheet(probe),
        true,
      );
      expect(
        probeTenSheet({'width': 100, 'height': 100, 'pixels': Uint8List(10000)})
            .found,
        false,
      );
    },
  );
}
