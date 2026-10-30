import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:siromix/omr.dart';
import 'package:siromix/data.dart';

void main() {
  final reference = File('assets/templates/abcd-10-v1.png').readAsBytesSync();
  Uint8List marked({
    bool faint = false,
    bool multiple = false,
    bool rotate = false,
  }) {
    var image = img.decodePng(reference)!;
    void dot(double x, double y, {bool weak = false}) => img.fillCircle(
      image,
      x: x.round(),
      y: y.round(),
      radius: 8,
      color: img.ColorRgb8(weak ? 165 : 20, weak ? 165 : 20, weak ? 165 : 20),
    );
    const letters = 'ABCDABCDAB';
    for (var i = 0; i < 10; i++) {
      dot(
        102 + TenSheetGeometry.answerX['ABCD'.indexOf(letters[i])],
        120 + TenSheetGeometry.answerY(i),
        weak: faint && i == 6,
      );
    }
    if (multiple) {
      dot(102 + TenSheetGeometry.answerX[0], 120 + TenSheetGeometry.answerY(3));
    }
    const candidate = '001286', code = '132';
    for (var i = 0; i < 6; i++) {
      dot(
        102 + TenSheetGeometry.candidateX[i],
        120 + TenSheetGeometry.digitY(int.parse(candidate[i])),
      );
    }
    for (var i = 0; i < 3; i++) {
      dot(
        102 + TenSheetGeometry.codeX[i],
        120 + TenSheetGeometry.digitY(int.parse(code[i])),
      );
    }
    if (rotate) image = img.copyRotate(image, angle: 90);
    return Uint8List.fromList(img.encodePng(image));
  }

  test('blank PDF reference is not mistaken for filled A/B/C/D letters', () {
    final r = recognizeTenSheet({'photo': reference, 'reference': reference});
    expect(r.answers.every((a) => a.state == MarkState.blank), true);
    expect(r.candidateText, '??????');
    expect(r.codeText, '???');
  });
  test(
    'filled bubbles and digit fields read exactly, retaining leading zeroes',
    () {
      final r = recognizeTenSheet({'photo': marked(), 'reference': reference});
      expect(r.answers.map((a) => a.answer).join(), 'ABCDABCDAB');
      expect(r.candidateText, '001286');
      expect(r.codeText, '132');
      expect(r.answerCrops.length, 10);
    },
  );
  test(
    'rotation is normalized and multiple/faint marks remain distinguishable',
    () {
      final r = recognizeTenSheet({
        'photo': marked(faint: true, multiple: true, rotate: true),
        'reference': reference,
      });
      expect(r.answers[3].state, MarkState.multiple);
      expect(r.answers[6].state, MarkState.uncertain);
      expect(r.candidateText, '001286');
      expect(r.codeText, '132');
    },
  );
  test(
    'missing markers reject unrelated images rather than returning a score',
    () {
      final bytes = Uint8List.fromList(
        img.encodePng(
          img.Image(width: 800, height: 1100)
            ..clear(img.ColorRgb8(255, 255, 255)),
        ),
      );
      expect(
        () => recognizeTenSheet({'photo': bytes, 'reference': reference}),
        throwsA(isA<OmrException>()),
      );
    },
  );
  test(
    'independent skewed JPEG fixture preserves answers and identity fields',
    () {
      final r = recognizeTenSheet({
        'photo': File('test/fixtures/ten-132-perspective.jpg')
            .readAsBytesSync(),
        'reference': reference,
      });
      expect(r.candidateText, '001286');
      expect(r.codeText, '132');
      expect(r.answers.map((a) => a.answer).join(), 'ABCDABCDAB');
    },
  );
}
