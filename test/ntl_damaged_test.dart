import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
}
