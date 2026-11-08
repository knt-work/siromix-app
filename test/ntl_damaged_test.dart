import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:siromix/data.dart';
import 'package:siromix/omr.dart';

void main() {
  final photo = File('test/fixtures/ntl-damaged-local.png');
  test(
    'damaged NTL reads clear marks and retains review for a smeared mark',
    () {
      final result = recognizeCompactSheet({
        'photo': photo.readAsBytesSync(),
        'reference': File('assets/templates/abcd-40-compact-v1.png')
            .readAsBytesSync(),
      });
      expect(result.codeClear, true);
      expect(result.codeText, '101');
      expect(
        result.answers.take(24).map((mark) => mark.answer).join(),
        'ABABCBDABBCABC BACACBDDAB'.replaceAll(' ', ''),
      );
      expect(result.answers[24].state, MarkState.uncertain);
      expect(result.answers[25].answer, 'C');
      expect(
        result.answers
            .skip(26)
            .every(
              (mark) =>
                  mark.state == MarkState.blank ||
                  mark.state == MarkState.uncertain,
            ),
        true,
      );
    },
    skip: !photo.existsSync(),
  );

  test('NTL border recovery reads a damaged photo with all four corner marks missing', () {
    final damaged = img.decodeImage(photo.readAsBytesSync())!;
    // Remove just the corner squares, leaving the long border and inner layout.
    for (final (x, y) in [(513, 434), (1480, 413), (1529, 1880), (572, 1932)]) {
      img.fillRect(
        damaged,
        x1: x - 20,
        y1: y - 20,
        x2: x + 20,
        y2: y + 20,
        color: img.ColorRgb8(208, 208, 208),
      );
    }
    final result = recognizeCompactSheet({
      'photo': img.encodePng(damaged),
      'reference': File('assets/templates/abcd-40-compact-v1.png')
          .readAsBytesSync(),
    });
    expect(result.codeClear, true);
    expect(result.codeText, '101');
    expect(
      result.answers.take(24).map((mark) => mark.answer).join(),
      'ABABCBDABBCABCBACACBDDAB',
    );
    expect(result.answers[24].state, MarkState.uncertain);
    expect(result.answers[25].answer, 'C');
  }, skip: !photo.existsSync());

  test('a strong rectangular border without NTL internals is rejected', () {
    final rectangle = img.Image(width: 640, height: 850);
    img.fill(rectangle, color: img.ColorRgb8(235, 235, 235));
    img.drawRect(
      rectangle,
      x1: 85,
      y1: 80,
      x2: 555,
      y2: 758,
      thickness: 6,
      color: img.ColorRgb8(20, 20, 20),
    );
    expect(
      () => recognizeCompactSheet({
        'photo': img.encodePng(rectangle),
        'reference': File('assets/templates/abcd-40-compact-v1.png')
            .readAsBytesSync(),
      }),
      throwsA(isA<OmrException>()),
    );
  });
}
