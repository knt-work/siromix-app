// ignore_for_file: avoid_print
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:siromix/omr.dart';

void main() {
  test('diagnose compact real photos', () {
    final reference = File('assets/templates/abcd-40-compact-v1.png')
        .readAsBytesSync();
    File('build/compact-baseline-aligned.png').writeAsBytesSync(
      recognizeCompactSheet({'photo': reference, 'reference': reference})
          .aligned,
    );
    for (final code in ['132', '209']) {
      if (!File('test/fixtures/compact-$code-real.png').existsSync()) continue;
      final r = recognizeCompactSheet({
        'photo': File('test/fixtures/compact-$code-real.png').readAsBytesSync(),
        'reference': reference,
      });
      File('build/compact-$code-aligned.png').writeAsBytesSync(r.aligned);
      print(
        '$code: ${r.code.map((v) => '${v.state.name}:${v.value}').toList()}',
      );
    }
  });
}
