import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:siromix/data.dart';
import 'package:siromix/main.dart';
import 'package:siromix/omr.dart';
import 'package:siromix/scan.dart';
import 'package:siromix/scan_flow.dart';
import 'package:siromix/templates.dart';

import 'widget_test.dart' show MemoryStorage;

void main() {
  final reference = File('assets/templates/abcd-40-compact-v1.png')
      .readAsBytesSync();
  Uint8List marked({
    bool rotate = false,
    bool faint = false,
    bool multiple = false,
    bool faintCode = false,
    bool doubleCode = false,
  }) {
    var image = img.decodePng(reference)!;
    void dot(double x, double y, {bool weak = false}) => img.fillCircle(
      image,
      x: (36.5 + x).round(),
      y: (43 + y).round(),
      radius: 10,
      color: img.ColorRgb8(weak ? 170 : 15, weak ? 170 : 15, weak ? 170 : 15),
    );
    for (var i = 0; i < 40; i++) {
      dot(
        CompactSheetGeometry.answerX(i)[i % 4],
        CompactSheetGeometry.answerY(i),
        weak: faint && i == 6,
      );
    }
    if (multiple) {
      dot(CompactSheetGeometry.answerX(3)[0], CompactSheetGeometry.answerY(3));
    }
    const code = '008';
    for (var i = 0; i < 3; i++) {
      dot(
        CompactSheetGeometry.codeX[i],
        CompactSheetGeometry.upperY[int.parse(code[i])],
        weak: faintCode && i == 1,
      );
    }
    if (doubleCode) {
      dot(CompactSheetGeometry.codeX[0], CompactSheetGeometry.upperY[1]);
    }
    if (rotate) image = img.copyRotate(image, angle: 90);
    return Uint8List.fromList(img.encodePng(image));
  }

  test('compact blank reference returns forty blank answers and no SBD', () {
    final r = recognizeCompactSheet({
      'photo': reference,
      'reference': reference,
    });
    expect(r.answers.length, 40);
    expect(r.answers.every((a) => a.state == MarkState.blank), true);
    expect(r.candidate, isEmpty);
    expect(r.codeText, '???');
  });
  test('compact reads all four groups and leading zero code', () {
    final r = recognizeCompactSheet({
      'photo': marked(),
      'reference': reference,
    });
    expect(
      r.answers.map((a) => a.answer).join(),
      List.generate(40, (i) => 'ABCD'[i % 4]).join(),
    );
    expect(r.codeText, '008');
    expect(r.answerCrops.length, 40);
  });
  test('compact handles rotation and requires review for faint marks', () {
    final r = recognizeCompactSheet({
      'photo': marked(rotate: true, faint: true, multiple: true),
      'reference': reference,
    });
    expect(r.codeText, '008');
    expect(r.answers[6].state, MarkState.uncertain);
    expect(r.answers[3].state, MarkState.multiple);
  });
  test('ten question sheet is rejected by compact reader', () {
    expect(
      () => recognizeCompactSheet({
        'photo': File('assets/templates/abcd-10-v1.png').readAsBytesSync(),
        'reference': reference,
      }),
      throwsA(isA<OmrException>()),
    );
  });
  test(
    'compact key and history round trip without changing ten-question keys',
    () {
      final old = ExamKey();
      expect(old.answers.length, 30);
      expect(old.template, SheetTemplate.ten);
      final key = ExamKey(templateId: SheetTemplate.compact.id, count: 40);
      for (var i = 0; i < 40; i++) {
        key.answers[i] = 'A';
      }
      expect(ExamKey.fromJson(key.toJson()).answers.length, 40);
      expect(
        () => ExamKey.fromJson(key.toJson()..['count'] = 41),
        throwsFormatException,
      );
      final d = ExamData.empty();
      const path = ['2026', 'Exam', '6', 'Math'];
      d.addCode(path, '008');
      d.saveKey(path, '008', key);
      d.confirmPaper(
        path: path,
        candidate: '',
        candidateUnknown: true,
        code: '008',
        responses: List.filled(40, const ResponseMark(MarkState.single, 'A')),
      );
      final restored = ExamData.decode(d.encode());
      expect(restored.papers.single.grade.score, 10);
      expect(restored.papers.single.candidate, '');
      expect(restored.codes(path)['008']!.count, 40);
    },
  );
  testWidgets(
    'compact disables answer-only option but keeps full scan enabled',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    chooseScanMode(context, template: SheetTemplate.compact),
                child: const Text('Choose'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Choose'));
      await t.pumpAndSettle();
      expect(
        t
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('choose-answers')),
            )
            .onPressed,
        isNull,
      );
      expect(
        t
            .widget<OutlinedButton>(find.byKey(const ValueKey('choose-full')))
            .onPressed,
        isNotNull,
      );
      expect(find.text('Không hỗ trợ với mẫu phiếu này.'), findsOneWidget);
    },
  );
  testWidgets(
    'compact uses scanned code, ignores questions past eight and saves unknown candidate',
    (t) async {
      t.view.physicalSize = const Size(400, 1500);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      const path = ['2026', 'Exam', '6', 'Math'];
      final repo = ExamRepository(MemoryStorage());
      await repo.load();
      await repo.update((d) {
        for (final code in ['008', '132']) {
          d.addCode(path, code);
          final k = ExamKey(templateId: SheetTemplate.compact.id, count: 8);
          for (var i = 0; i < 8; i++) {
            k.answers[i] = 'A';
          }
          d.saveKey(path, code, k);
        }
        d.addCode(path, 'OLD');
        final old = ExamKey(count: 1);
        old.answers[0] = 'A';
        d.saveKey(path, 'OLD', old);
      });
      final picture = Uint8List.fromList(
        img.encodePng(
          img.Image(width: 5, height: 5)..clear(img.ColorRgb8(255, 255, 255)),
        ),
      );
      final reading = OmrRead(
        answers: [
          ...List.filled(8, const ResponseMark(MarkState.single, 'A')),
          ...List.filled(32, const ResponseMark(MarkState.uncertain)),
        ],
        candidate: const [],
        code: '008'
            .split('')
            .map((d) => DigitReading(d, MarkState.single))
            .toList(),
        aligned: picture,
        answerCrops: List.filled(40, picture),
        candidateCrop: Uint8List(0),
        codeCrop: picture,
      );
      await t.pumpWidget(
        MaterialApp(
          home: ScannedResult(
            repository: repo,
            contextPath: path,
            read: reading,
            template: SheetTemplate.compact,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Số báo danh: Không xác định'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(
        t
            .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
            .items!
            .map((e) => e.value),
        ['008', '132'],
      );
      final confirm = find.widgetWithText(FilledButton, 'Xác nhận điểm');
      await t.scrollUntilVisible(confirm, 400);
      await t.tap(confirm);
      await t.pumpAndSettle();
      expect(repo.data.papers.single.code, '008');
      expect(repo.data.papers.single.candidate, '');
      expect(repo.data.papers.single.responses.length, 8);
      expect(repo.data.papers.single.grade.score, 2);
    },
  );
  test(
    'independent compact perspective JPEG reads forty responses and code',
    () {
      final read = recognizeCompactSheet({
        'photo': File('test/fixtures/compact-132-perspective.jpg')
            .readAsBytesSync(),
        'reference': reference,
      });
      expect(read.codeText, '132');
      expect(
        read.answers.map((v) => v.answer).join(),
        List.generate(40, (i) => 'ABCD'[i % 4]).join(),
      );
    },
  );
  test(
    'compact live probe matches template and missing corner is rejected',
    () {
      final image = img.copyResize(img.decodePng(reference)!, height: 700);
      final pixels = Uint8List(image.width * image.height);
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          pixels[y * image.width + x] = image.getPixel(x, y).luminance.round();
        }
      }
      expect(
        probeCompactSheet({
          'width': image.width,
          'height': image.height,
          'pixels': pixels,
        }).found,
        true,
      );
      final clipped = img.decodePng(reference)!;
      img.fillRect(
        clipped,
        x1: 0,
        y1: 0,
        x2: 65,
        y2: 70,
        color: img.ColorRgb8(255, 255, 255),
      );
      expect(
        () => recognizeCompactSheet({
          'photo': Uint8List.fromList(img.encodePng(clipped)),
          'reference': reference,
        }),
        throwsA(isA<OmrException>()),
      );
    },
  );
  testWidgets(
    'editor switches ten to compact and supports question forty without losing old values',
    (t) async {
      t.view.physicalSize = const Size(400, 1800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final old = ExamKey(count: 8);
      for (var i = 0; i < 8; i++) {
        old.answers[i] = 'A';
      }
      old.points[0] = 2;
      ExamKey? saved;
      await t.pumpWidget(
        MaterialApp(
          home: KeyEditor(
            contextPath: const ['2026', 'Exam', '6', 'Math'],
            code: '132',
            original: old,
            onSave: (v) async {
              saved = v;
              return true;
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byType(DropdownButtonFormField<String>));
      await t.pumpAndSettle();
      await t.tap(find.text(SheetTemplate.compact.name).last);
      await t.pumpAndSettle();
      final count = find.widgetWithText(TextField, 'Số câu · tối đa 40');
      await t.ensureVisible(count);
      await t.enterText(count, '40');
      await t.pumpAndSettle();
      final lastPage = find.text('31–40');
      await t.ensureVisible(lastPage);
      await t.tap(lastPage);
      await t.pumpAndSettle();
      final last = find.byKey(const ValueKey('points-39'));
      await t.scrollUntilVisible(
        last,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await t.enterText(last, '3');
      await t.pumpAndSettle();
      // Reduce the count again so the eight existing answers can be saved.
      await t.scrollUntilVisible(
        count,
        -500,
        scrollable: find.byType(Scrollable).first,
      );
      await t.enterText(count, '8');
      await t.pumpAndSettle();
      final save = find.text('Lưu cấu hình đề');
      await t.scrollUntilVisible(
        save,
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await t.tap(save);
      await t.pumpAndSettle();
      expect(saved!.template, SheetTemplate.compact);
      expect(saved!.count, 8);
      expect(saved!.answers.length, 40);
      expect(saved!.points[0], 2);
      expect(saved!.points[39], 3);
      expect(old.template, SheetTemplate.ten);
      expect(old.answers.length, 30);
    },
  );
  test('compact ambiguous digit marks still require manual checking', () {
    final faint = recognizeCompactSheet({
      'photo': marked(faintCode: true),
      'reference': reference,
    });
    expect(faint.code[1].state, MarkState.uncertain);
    expect(faint.codeClear, false);
    final multiple = recognizeCompactSheet({
      'photo': marked(doubleCode: true),
      'reference': reference,
    });
    expect(multiple.code[0].state, MarkState.multiple);
    expect(multiple.codeClear, false);
  });
}
