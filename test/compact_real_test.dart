import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:siromix/data.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:siromix/omr.dart';

void main() {
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
}
