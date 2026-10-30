// ignore_for_file: avoid_print
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:siromix/omr.dart';

void main() {
  test('diagnose compact real photo', () {
    final input = {
      'photo': File('test/fixtures/compact-132-real.png').readAsBytesSync(),
      'reference': File('assets/templates/abcd-40-compact-v1.png')
          .readAsBytesSync(),
    };
    final r = recognizeCompactSheet(input);
    File('build/compact-real-aligned.png').writeAsBytesSync(r.aligned);
    print(r.code.map((m) => '${m.state.name}:${m.value}'));
    print(r.answers.map((m) => '${m.state.name}:${m.answer}').toList());
  });
}
