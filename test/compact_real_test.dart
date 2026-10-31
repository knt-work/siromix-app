import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:siromix/data.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:siromix/omr.dart';

void main() {
  final skipPrivate209 = !File('test/fixtures/compact-209-real.png')
      .existsSync();
  test('real compact sheet reads code 132 and first eight responses', () {
    final r = recognizeCompactSheet({
      'photo': File('test/fixtures/compact-132-real.png').readAsBytesSync(),
      'reference': File('assets/templates/abcd-40-compact-v1.png')
          .readAsBytesSync(),
    });
    expect(r.codeText, '132');
    expect(r.codeClear, true);
    expect(r.answers.take(8).every((a) => a.state == MarkState.single), true);
    expect(
      r.answers.skip(8).take(2).every((a) => a.state == MarkState.blank),
      true,
    );
    expect(r.answers.take(8).map((a) => a.answer).join(), 'BCABDBAC');
  });
  test('real compact photo also works after rotation and JPEG encoding', () {
    final image = img.copyRotate(
      img.decodePng(
        File('test/fixtures/compact-132-real.png').readAsBytesSync(),
      )!,
      angle: 90,
    );
    final r = recognizeCompactSheet({
      'photo': Uint8List.fromList(img.encodeJpg(image, quality: 88)),
      'reference': File('assets/templates/abcd-40-compact-v1.png')
          .readAsBytesSync(),
    });
    expect(r.codeText, '132');
    expect(r.answers.take(8).map((a) => a.answer).join(), 'BCABDBAC');
  });
  test('real compact photo is found by the live low-resolution probe', () {
    final image = img.copyResize(
      img.decodePng(
        File('test/fixtures/compact-132-real.png').readAsBytesSync(),
      )!,
      height: 800,
    );
    final pixels = Uint8List(image.width * image.height);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        pixels[y * image.width + x] = image.getPixel(x, y).luminance.round();
      }
    }
    expect(
      probeCompactSheet({
        'width': image.width,
        'height': image.height,
        'pixels': pixels,
      }).found,
      true,
    );
  });
  test('209 source photo ignores confirmed printed-digit blur and reads all active answers', () {
    final r = recognizeCompactSheet({
      'photo': File('test/fixtures/compact-209-real.png').readAsBytesSync(),
      'reference': File('assets/templates/abcd-40-compact-v1.png')
          .readAsBytesSync(),
    });
    expect(r.codeText, '209');
    expect(r.codeClear, true);
    expect(r.answers.take(8).map((a) => a.answer).join(), 'ACBBCAAD');
    expect(r.answers.take(8).every((a) => a.state == MarkState.single), true);
  }, skip: skipPrivate209);
  test('209 printed-blur photo remains readable after rotation and JPEG compression', () {
    final image = img.copyRotate(
      img.decodePng(
        File('test/fixtures/compact-209-real.png').readAsBytesSync(),
      )!,
      angle: 90,
    );
    final r = recognizeCompactSheet({
      'photo': Uint8List.fromList(img.encodeJpg(image, quality: 88)),
      'reference': File('assets/templates/abcd-40-compact-v1.png')
          .readAsBytesSync(),
    });
    expect(r.codeText, '209');
    expect(r.codeClear, true);
  }, skip: skipPrivate209);
}
