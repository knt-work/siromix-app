// Diagnostic CLI output, intentionally separate from application code.
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:siromix/omr.dart';

void main() {
  test('report supplied shadow examples without changing production algorithms', () {
    final reference = File('assets/templates/abcd-10-v1.png').readAsBytesSync();
    for (final prefix in [
      'test/fixtures/shadow-',
      'build/shadow-normalized-',
    ]) {
      for (final part in SheetPart.values) {
        try {
          final read = recognizeTenPart({
            'part': part.name,
            'reference': reference,
            'photo': File('$prefix${part.name}.png').readAsBytesSync(),
          });
          // Diagnostic only; not an accuracy assertion or accepted ground truth.
          print(
            '$prefix${part.name}: ${read.digitText} ${read.answers.map((m) => '${m.state.name}:${m.answer}').join(',')}',
          );
        } catch (e) {
          print('$prefix${part.name}: $e');
        }
      }
    }
  });
}
