import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siromix/data.dart';
import 'package:siromix/main.dart';

class MemoryStorage implements LocalStorage {
  String? value;
  bool fail = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String v) async {
    if (fail) throw StateError('disk unavailable');
    value = v;
  }
}

void main() {
  const path = ['2026 – 2027', 'Giữa học kì I', '6', 'Toán'];
  test(
    'save/reopen preserves context, codes and individual decimal points',
    () async {
      final disk = MemoryStorage();
      final repo = ExamRepository(disk);
      await repo.load();
      await repo.update((d) {
        d.add(path.take(1).toList(), path[1]);
        d.add(path.take(2).toList(), path[2]);
        d.add(path.take(3).toList(), path[3]);
        d.addCode(path, '001');
        final key = d.codes(path)['001']!.copy();
        key.count = 2;
        key.answers[0] = 'B';
        key.answers[1] = 'D';
        key.points[0] = 0.1;
        key.points[1] = 1.75;
        d.saveKey(path, '001', key);
        d.addCode([...path.take(2), '7', 'Toán'], '001');
      });
      final reopened = ExamRepository(disk);
      await reopened.load();
      final key = reopened.data.codes(path)['001']!;
      expect(key.count, 2);
      expect(key.answers.take(2), ['B', 'D']);
      expect(key.total, closeTo(1.85, .000001));
      expect(
        reopened.data.codes([...path.take(2), '7', 'Toán'])['001']!.complete,
        false,
      );
      expect(() => reopened.data.addCode(path, '001'), throwsFormatException);
    },
  );
  test('failed persistence leaves last committed state intact', () async {
    final disk = MemoryStorage();
    final repo = ExamRepository(disk);
    await repo.load();
    await repo.update((d) => d.add(path.take(1).toList(), 'A'));
    disk.fail = true;
    await expectLater(
      repo.update((d) => d.add(path.take(1).toList(), 'B')),
      throwsStateError,
    );
    expect(repo.data.children(path.take(1).toList()), ['A']);
    expect(ExamData.decode(disk.value!).children(path.take(1).toList()), ['A']);
  });
  test(
    'uncertain marks block confirmation; blank/multiple always score zero',
    () {
      final key = ExamKey(count: 4);
      key.answers.setRange(0, 4, ['A', 'B', 'C', 'D']);
      key.points.setRange(0, 4, [1, 2, 3, 4]);
      final result = GradeResult(key, [
        const ResponseMark(MarkState.single, 'A'),
        const ResponseMark(MarkState.blank),
        const ResponseMark(MarkState.multiple),
        const ResponseMark(MarkState.uncertain),
      ]);
      expect(result.score, 1);
      expect(result.invalid, 2);
      expect(result.canConfirm, false);
      result.responses[3] = const ResponseMark(MarkState.single, 'D');
      expect(result.score, 5);
      expect(result.canConfirm, true);
    },
  );
  test(
    'invalid or future storage versions fail without resetting saved data',
    () async {
      final disk = MemoryStorage()..value = '{"version":99}';
      await expectLater(ExamRepository(disk).load(), throwsFormatException);
      expect(disk.value, '{"version":99}');
    },
  );
  testWidgets('light home opens exam management and retains approved text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      SiroMixApp(repository: ExamRepository(MemoryStorage())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chức năng'), findsOneWidget);
    expect(find.text('Chấm nhanh. Dạy trọn tâm.'), findsNothing);
    expect(
      Theme.of(tester.element(find.text('Chức năng'))).brightness,
      Brightness.light,
    );
    await tester.tap(find.text('Chấm bài trắc nghiệm'));
    await tester.pumpAndSettle();
    expect(find.text('Kì thi của bạn'), findsOneWidget);
    await tester.tap(find.text('Tạo kì thi'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Kiểm tra thử');
    await tester.tap(find.text('Tạo').last);
    await tester.pumpAndSettle();
    expect(find.text('Khối học'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
  });
  testWidgets('editor preserves points and answers across pages at 320px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    ExamKey? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: KeyEditor(
          contextPath: path,
          code: '132',
          original: ExamKey(),
          onSave: (k) async {
            saved = k;
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Reduce to one question and enter an explicit per-question score.
    await tester.enterText(find.byType(TextField).at(0), '1');
    await tester.pumpAndSettle();
    await tester.tap(find.text('B').first);
    await tester.pumpAndSettle();
    final point = find.byKey(const ValueKey('points-0'));
    await tester.ensureVisible(point);
    await tester.enterText(point, '1,75');
    await tester.pumpAndSettle();
    final save = find.text('Lưu cấu hình đề');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(saved?.points[0], 1.75);
    expect(saved?.answers[0], 'B');
    expect(saved?.count, 1);
  });

  testWidgets(
    'common points update all pages immediately and save individual overrides',
    (t) async {
      t.view.physicalSize = const Size(360, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final original = ExamKey(
        templateId: 'legacy-abcd-30',
        count: 11,
        answers: List.filled(30, 'A'),
      );
      original.points[0] = 4;
      ExamKey? saved;
      await t.pumpWidget(
        MaterialApp(
          home: KeyEditor(
            contextPath: path,
            code: '132',
            original: original,
            onSave: (k) async {
              saved = k;
              return true;
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      final common = find.widgetWithText(TextField, 'Điểm chung mỗi câu');
      Future<void> enter(String value) async {
        await t.ensureVisible(common);
        await t.enterText(common, value);
        await t.pumpAndSettle();
      }

      String point(int i) => t
          .widget<TextField>(find.byKey(ValueKey('points-$i')))
          .controller!
          .text;
      await enter('0,5');
      expect(point(0), '0,5');
      expect(find.textContaining('Tổng điểm: 5,50'), findsOneWidget);
      await enter('');
      expect(point(0), '0,5');
      await enter('-1');
      expect(point(0), '0,5');
      await enter('NaN');
      expect(point(0), '0,5');
      await enter('0');
      expect(point(0), '0');
      expect(find.textContaining('Tổng điểm: 0,00'), findsOneWidget);
      await enter('0,75');
      final next = find.text('11–11');
      await t.ensureVisible(next);
      await t.tap(next);
      await t.pumpAndSettle();
      expect(point(10), '0,75');
      final last = find.byKey(const ValueKey('points-10'));
      await t.ensureVisible(last);
      await t.enterText(last, '2');
      await t.pumpAndSettle();
      final save = find.text('Lưu cấu hình đề');
      await t.ensureVisible(save);
      await t.tap(save);
      await t.pumpAndSettle();
      final reopened = ExamKey.fromJson(saved!.toJson());
      expect(reopened.common, .75);
      expect(reopened.points.take(10), everyElement(.75));
      expect(reopened.points[10], 2);
      expect(reopened.total, 9.5);
      expect(original.points[0], 4);
    },
  );
}
