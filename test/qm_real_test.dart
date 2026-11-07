import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:siromix/camera_guidance.dart';
import 'package:siromix/data.dart';
import 'package:siromix/omr.dart';

// Photographs contain personal data and are intentionally not distributed.
// Place the seven local calibration photos at these ignored paths to rerun.
void main() {
  const codes = ['601', '421', '109', '168', '192', '103', '132'];
  const answers = [
    'BACDDDBACBACADDC',
    'DBCACDBACDDBAADB',
    'BCABBCACDBABCDCB',
    'BCACDDABCDBCACDD',
    'CCBCACDDBAABCDAA',
    'BCABDACC--BCABDD',
    'BCBACDABCDABCDBA',
  ];
  final reference = File('assets/templates/qm2025-a4-v1.png').readAsBytesSync();
  for (var index = 0; index < codes.length; index++) {
    final file = File('test/fixtures/qm-real/sample-0${index + 1}.jpg');
    test(
      'QM physical sample ${index + 1}: code, all responses and candidate policy',
      () {
        final result = recognizeQmSheet({
          'photo': file.readAsBytesSync(),
          'reference': reference,
        });
        expect(result.codeClear, true);
        expect(result.codeText, codes[index]);
        final expected = answers[index].replaceAll(' ', '');
        expect(expected.length, 16);
        for (var row = 0; row < 54; row++) {
          final mark = result.answers[row];
          if (row >= 16 || expected[row] == '-') {
            expect(mark.state, MarkState.blank, reason: 'row $row');
          } else {
            expect(mark.state, MarkState.single, reason: 'row $row');
            expect(mark.answer, expected[row], reason: 'row $row');
          }
        }
        // One source has secondary fill evidence: retain review rather than guess.
        expect(result.candidateClear, index != 2);
        expect(result.candidate.length, 6);
        if (index == 2) {
          expect(result.candidate[2].state, MarkState.uncertain);
        }
      },
      skip: !file.existsSync(),
    );
    test(
      'QM physical sample ${index + 1}: low-resolution live probe and framing',
      () {
        final image = img.copyResize(
          img.decodeImage(file.readAsBytesSync())!,
          height: 800,
        );
        final pixels = Uint8List(image.width * image.height);
        for (var y = 0; y < image.height; y++) {
          for (var x = 0; x < image.width; x++) {
            pixels[y * image.width + x] = image
                .getPixel(x, y)
                .luminance
                .round();
          }
        }
        final probe = probeQmSheet({
          'width': image.width,
          'height': image.height,
          'pixels': pixels,
        });
        expect(probe.found, true);
        final layout = CameraGuideLayout(
          Size(image.width.toDouble(), image.height.toDouble()),
          image.width / image.height,
          markerAspect: 1053 / 1485,
          guideFraction: .9,
        );
        expect(layout.containsSheet(probe, flexible: true), true);
      },
      skip: !file.existsSync(),
    );
  }
  final rotatedFile = File('test/fixtures/qm-real/sample-02.jpg');
  test('QM curved physical sheet remains readable after rotation and JPEG compression', () {
    final image = img.copyRotate(
      img.decodeImage(rotatedFile.readAsBytesSync())!,
      angle: 90,
    );
    final result = recognizeQmSheet({
      'photo': Uint8List.fromList(img.encodeJpg(image, quality: 88)),
      'reference': reference,
    });
    expect(result.codeText, codes[1]);
    expect(result.codeClear, true);
    expect(result.answers.take(16).map((m) => m.answer).join(), answers[1]);
  }, skip: !rotatedFile.existsSync());
}
