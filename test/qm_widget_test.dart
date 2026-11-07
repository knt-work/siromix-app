import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siromix/data.dart';
import 'package:siromix/main.dart';
import 'package:siromix/qm_editor.dart';
import 'package:siromix/scan.dart';
import 'package:siromix/omr.dart';
import 'package:siromix/templates.dart';
import 'package:siromix/ui.dart';

import 'widget_test.dart' show MemoryStorage;
import 'qm_test.dart' show qmKey;

void main() {
  const path = ['2026 – 2027', 'Kì thi', '6', 'Toán'];
  testWidgets(
    'existing editor switches to integrated QM form without losing Part I',
    (t) async {
      t.view.physicalSize = const Size(390, 1700);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final key = ExamKey(count: 2)..answers.setRange(0, 2, ['A', 'B']);
      await t.pumpWidget(
        MaterialApp(
          theme: siroTheme(),
          home: KeyEditor(
            contextPath: path,
            code: '132',
            original: key,
            onSave: (_) async => true,
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byType(DropdownButtonFormField<String>));
      await t.pumpAndSettle();
      await t.tap(find.text('QM2025 A4').last);
      await t.pumpAndSettle();
      expect(find.byType(QmKeyEditor), findsOneWidget);
      expect(find.text('Phần I'), findsOneWidget);
      expect(find.text('Bắt buộc'), findsOneWidget);
      expect(
        t.widget<Switch>(find.byKey(const ValueKey('qm-toggle-2'))).value,
        false,
      );
      expect(
        t.widget<Switch>(find.byKey(const ValueKey('qm-toggle-3'))).value,
        false,
      );
      final common = find.byKey(const ValueKey('qm-p1'));
      await t.ensureVisible(common);
      await t.enterText(common, '0,5');
      await t.pumpAndSettle();
      final point = find.byKey(const ValueKey('qm-i0'));
      await t.scrollUntilVisible(
        point,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(t.widget<TextField>(point).controller!.text, '0,5');
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'QM keeps optional settings on toggles, propagates points and saves complete key',
    (t) async {
      t.view.physicalSize = const Size(390, 2200);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      ExamKey? saved;
      final key = qmKey();
      await t.pumpWidget(
        MaterialApp(
          theme: siroTheme(),
          home: KeyEditor(
            contextPath: path,
            code: '132',
            original: key,
            onSave: (k) async {
              saved = k;
              return true;
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      final two = find.byKey(const ValueKey('qm-toggle-2'));
      await t.ensureVisible(two);
      await t.tap(two);
      await t.pumpAndSettle();
      await t.tap(two);
      await t.pumpAndSettle();
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('qm-n2')))
            .controller!
            .text,
        '1',
      );
      await t.enterText(find.byKey(const ValueKey('qm-r4')), '2');
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('qm-p3')), '0,75');
      await t.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Lưu cấu hình đề');
      await t.scrollUntilVisible(
        save,
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await t.tap(save);
      await t.pumpAndSettle();
      expect(saved, isNotNull);
      expect(saved!.parts.rates, [0, .2, .5, 1, 2]);
      expect(saved!.parts.threePoints[0], .75);
      expect(saved!.parts.twoAnswers[0], 'TFTF');
      expect(saved!.complete, true);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'QM form at 320px and large text opens sections without layout overflow',
    (t) async {
      t.view.physicalSize = const Size(320, 700);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        MaterialApp(
          theme: siroTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: KeyEditor(
            contextPath: path,
            code: '132',
            original: qmKey(),
            onSave: (_) async => true,
          ),
        ),
      );
      await t.pumpAndSettle();
      final three = find.byKey(const ValueKey('qm-toggle-3'));
      await t.scrollUntilVisible(
        three,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await t.ensureVisible(three);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'result ignores inactive raw rows, reviews true/false ideas and persists numeric score',
    (t) async {
      t.view.physicalSize = const Size(390, 1500);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final repo = ExamRepository(MemoryStorage());
      await repo.load();
      final key = qmKey();
      await repo.update((d) {
        d.addCode(path, '132');
        d.saveKey(path, '132', key);
      });
      final bytes = File('assets/templates/qm2025-a4-v1.png').readAsBytesSync();
      final blank = recognizeQmSheet({'photo': bytes, 'reference': bytes});
      final answers = List<ResponseMark>.filled(
        54,
        const ResponseMark(MarkState.uncertain),
      );
      answers[0] = const ResponseMark(MarkState.single, 'A');
      answers[1] = const ResponseMark(MarkState.single, 'B');
      answers[40] = const ResponseMark(MarkState.uncertain, 'TFT?');
      answers[48] = const ResponseMark(MarkState.single, '1.5');
      final read = OmrRead(
        answers: answers,
        candidate: const [],
        code: const [
          DigitReading('1', MarkState.single),
          DigitReading('3', MarkState.single),
          DigitReading('2', MarkState.single),
        ],
        aligned: blank.aligned,
        answerCrops: blank.answerCrops,
        candidateCrop: blank.candidateCrop,
        codeCrop: blank.codeCrop,
      );
      await t.pumpWidget(
        MaterialApp(
          theme: siroTheme(),
          home: ScannedResult(
            repository: repo,
            contextPath: path,
            read: read,
            template: SheetTemplate.qm2025,
          ),
        ),
      );
      await t.pumpAndSettle();
      final row = find.byKey(const ValueKey('answer-row-40'));
      await t.scrollUntilVisible(
        row,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await t.ensureVisible(row);
      await t.pumpAndSettle();
      final review = find.descendant(
        of: row,
        matching: find.widgetWithText(TextButton, 'Kiểm tra'),
      );
      await t.tap(review);
      await t.pumpAndSettle();
      final sai = find.widgetWithText(ChoiceChip, 'Sai').last;
      await t.ensureVisible(sai);
      await t.tap(sai);
      await t.pumpAndSettle();
      final accept = find.widgetWithText(FilledButton, 'Xác nhận từng ý');
      await t.ensureVisible(accept);
      await t.tap(accept);
      await t.pumpAndSettle();
      final confirm = find.widgetWithText(FilledButton, 'Xác nhận điểm');
      await t.scrollUntilVisible(
        confirm,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await t.ensureVisible(confirm);
      await t.tap(confirm);
      await t.pumpAndSettle();
      expect(repo.data.papers.length, 1);
      expect(repo.data.papers.single.responses.length, 4);
      expect(repo.data.papers.single.grade.score, 2);
      expect(repo.data.papers.single.candidate, '');
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'inactive invalid scoring fields do not block saving and values restore on re-enable',
    (t) async {
      t.view.physicalSize = const Size(390, 2300);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      ExamKey? saved;
      await t.pumpWidget(
        MaterialApp(
          theme: siroTheme(),
          home: KeyEditor(
            contextPath: path,
            code: '132',
            original: qmKey(),
            onSave: (k) async {
              saved = k;
              return true;
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Cách tính điểm Đúng/Sai'));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('qm-r1')), '9');
      await t.pumpAndSettle();
      final two = find.byKey(const ValueKey('qm-toggle-2'));
      await t.ensureVisible(two);
      await t.tap(two);
      await t.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Lưu cấu hình đề');
      await t.scrollUntilVisible(
        save,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await t.tap(save);
      await t.pumpAndSettle();
      expect(saved, isNotNull);
      expect(saved!.parts.twoEnabled, false);
      expect(saved!.parts.rates, [0, .1, .25, .5, 1]);
      expect(saved!.parts.twoAnswers[0], 'TFTF');
    },
  );
  testWidgets('expanding numeric answers retains separate field scroll state', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 1700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        theme: siroTheme(),
        home: KeyEditor(
          contextPath: path,
          code: '132',
          original: qmKey(),
          onSave: (_) async => true,
        ),
      ),
    );
    await t.pumpAndSettle();
    final third = find.text('Đáp án & điểm · Phần III');
    await t.scrollUntilVisible(
      third,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(third);
    await t.pumpAndSettle();
    await t.drag(find.byType(ListView).first, const Offset(0, -200));
    await t.pumpAndSettle();
    await t.tap(third);
    await t.pumpAndSettle();
    final answer = find.byKey(const ValueKey('qm-s0'));
    await t.scrollUntilVisible(
      answer,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(answer);
    await t.enterText(answer, '-1,5');
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'all forty QM answers are on one continuous list without pagination',
    (t) async {
      t.view.physicalSize = const Size(390, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      ExamKey? saved;
      final original = ExamKey(
        templateId: 'qm2025-a4-40-8-6',
        count: 40,
        answers: List.filled(40, 'A'),
      );
      await t.pumpWidget(
        MaterialApp(
          theme: siroTheme(),
          home: KeyEditor(
            contextPath: path,
            code: '132',
            original: original,
            onSave: (key) async {
              saved = key;
              return true;
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(ChoiceChip), findsNothing);
      final last = find.byKey(const ValueKey('qm-i39'));
      await t.scrollUntilVisible(
        last,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await t.ensureVisible(last);
      await t.enterText(last, '2');
      await t.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Lưu cấu hình đề');
      await t.scrollUntilVisible(
        save,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await t.ensureVisible(save);
      await t.tap(save);
      await t.pumpAndSettle();
      expect(saved!.count, 40);
      expect(saved!.answers, everyElement('A'));
      expect(saved!.points[0], .25);
      expect(saved!.points[39], 2);
      expect(t.takeException(), isNull);
    },
  );
}
