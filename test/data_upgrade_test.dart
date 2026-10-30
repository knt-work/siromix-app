import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:siromix/data.dart';
import 'package:siromix/templates.dart';

import 'widget_test.dart' show MemoryStorage;

void main() {
  const context = ['2026 – 2027', 'Kì thi', '6', 'Toán'];
  test(
    'version 1 keys retain all thirty answers and points under legacy template',
    () {
      final answers = List.generate(30, (i) => 'ABCD'[i % 4]);
      final raw = jsonEncode({
        'version': 1,
        'catalogs': {
          jsonEncode(context): ['132'],
        },
        'keys': {
          jsonEncode([...context, '132']): {
            'count': 30,
            'common': .25,
            'answers': answers,
            'points': List.generate(30, (i) => i + .5),
          },
        },
      });
      final d = ExamData.decode(raw), key = d.codes(context)['132']!;
      expect(key.templateId, SheetTemplate.legacy.id);
      expect(key.count, 30);
      expect(key.answers, answers);
      expect(key.points.last, 29.5);
      expect(ExamData.decode(d.encode()).codes(context)['132']!.count, 30);
    },
  );
  test(
    'new keys use ten-question template and reject out-of-capacity stored keys',
    () {
      final d = ExamData.empty();
      d.addCode(context, '132');
      final key = d.codes(context)['132']!;
      expect(key.count, 10);
      expect(key.template.readable, true);
      final raw = key.toJson()..['count'] = 11;
      expect(() => ExamKey.fromJson(raw), throwsFormatException);
      final unknown = key.toJson()..['templateVersion'] = 999;
      expect(() => ExamKey.fromJson(unknown), throwsFormatException);
    },
  );
  test(
    'paper numbers persist, isolate subjects, and serialize concurrent commits',
    () async {
      final disk = MemoryStorage(), repo = ExamRepository(MemoryStorage());
      final actual = ExamRepository(disk);
      await actual.load();
      await repo.load();
      final allocated = <int>[];
      await Future.wait(
        List.generate(
          3,
          (_) => actual.update((d) => allocated.add(d.nextPaper(context))),
        ),
      );
      expect(allocated, [1, 2, 3]);
      final reopened = ExamRepository(disk);
      await reopened.load();
      late int next, other;
      await reopened.update((d) {
        next = d.nextPaper(context);
        other = d.nextPaper([...context.take(3), 'Vật lí']);
      });
      expect(next, 4);
      expect(other, 1);
      disk.fail = true;
      await expectLater(
        reopened.update((d) => d.nextPaper(context)),
        throwsStateError,
      );
      disk.fail = false;
      await reopened.update((d) => next = d.nextPaper(context));
      expect(next, 5);
    },
  );
}
