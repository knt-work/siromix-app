import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:siromix/data.dart';
import 'package:siromix/templates.dart';

import 'uneven_lighting.dart';

import 'package:siromix/omr.dart';

import 'widget_test.dart' show MemoryStorage;

ExamKey qmKey() => ExamKey(
  count: 2,
  templateId: SheetTemplate.qm2025.id,
  answers: ['A', 'B', ...List.filled(38, '')],
  points: List.filled(40, .25),
  parts: QmParts(
    twoEnabled: true,
    threeEnabled: true,
    twoCount: 1,
    threeCount: 1,
    twoAnswers: ['TFTF', ...List.filled(7, '')],
    threeAnswers: ['1,50', ...List.filled(5, '')],
  ),
);
void main() {
  test('QM multipart totals, exact decimal comparison and nonlinear partial credit', () {
    final key = qmKey();
    expect(key.complete, true);
    expect(key.total, 2);
    final grade = GradeResult(key, [
      const ResponseMark(MarkState.single, 'A'),
      const ResponseMark(MarkState.blank),
      const ResponseMark(MarkState.single, 'TF_X'),
      const ResponseMark(MarkState.single, '1.5'),
    ]);
    expect(grade.earned(2), .25);
    expect(grade.score, 1);
    expect(grade.canConfirm, true);
    expect(grade.correct, 2);
    for (var n = 0; n <= 4; n++) {
      final value = List.generate(
        4,
        (i) => i < n ? 'TFTF'[i] : ('TFTF'[i] == 'T' ? 'F' : 'T'),
      ).join();
      final g = GradeResult(key, [
        const ResponseMark(MarkState.blank),
        const ResponseMark(MarkState.blank),
        ResponseMark(MarkState.single, value),
        const ResponseMark(MarkState.blank),
      ]);
      expect(g.earned(2), [0, .1, .25, .5, 1][n]);
    }
    for (final text in ['1,5', '1.50', '01.5']) {
      expect(normalizedNumber(text), '1.5');
    }
    expect(normalizedNumber('-0,0'), '0');
    expect(fitsNumberGrid('12345'), false);
    expect(fitsNumberGrid('.125'), false);
    expect(fitsNumberGrid('-.12'), true);
    expect(fitsNumberGrid('.5'), true);
    expect(normalizedNumber('1 5'), null);
    expect(normalizedNumber('1e2'), null);
  });
  test('inactive parts do not affect completeness, selection or points; copy is deep', () {
    final key = qmKey();
    key.parts.twoEnabled = false;
    key.parts.threeEnabled = false;
    key.parts.twoAnswers[0] = '';
    key.parts.threeAnswers[0] = '';
    expect(key.complete, true);
    expect(key.questionCount, 2);
    expect(key.scanIndices, [0, 1]);
    expect(key.total, .5);
    final copy = key.copy();
    copy.parts.twoAnswers[0] = 'TTTT';
    expect(key.parts.twoAnswers[0], '');
    key.parts.twoEnabled = true;
    expect(key.complete, false);
  });
  test('QM key snapshots survive reopen, backup and key edits; numbering continues', () async {
    final disk = MemoryStorage(), repo = ExamRepository(MemoryStorage());
    await repo.load();
    const path = ['2026 – 2027', 'Kì thi', '6', 'Toán'];
    await repo.update((d) {
      d.addCode(path, '132');
      d.saveKey(path, '132', qmKey());
      d.confirmPaper(
        path: path,
        candidate: '',
        candidateUnknown: true,
        code: '132',
        responses: [
          const ResponseMark(MarkState.single, 'A'),
          const ResponseMark(MarkState.single, 'B'),
          const ResponseMark(MarkState.single, 'TFT_'),
          const ResponseMark(MarkState.single, '1.5'),
        ],
      );
    });
    final before = repo.data.papers.single.grade.score;
    expect(before, 1.5);
    await repo.update((d) {
      final key = d.codes(path)['132']!.copy()..parts.rates[3] = .75;
      d.saveKey(path, '132', key);
    });
    expect(repo.data.papers.single.grade.score, before);
    disk.value = repo.data.encode();
    final reopen = ExamRepository(disk);
    await reopen.load();
    expect(reopen.data.papers.single.grade.score, before);
    expect(jsonDecode(disk.value!)['version'], 7);
    final backup = BackupFile.decode(BackupFile(reopen.data).encode());
    expect(backup.data.papers.single.key.parts.twoAnswers[0], 'TFTF');
  });
  final reference = File('assets/templates/qm2025-a4-v1.png').readAsBytesSync();
  Uint8List marked({
    bool rotate = false,
    bool ambiguous = false,
    bool weakMarks = false,
  }) {
    var image = img.decodePng(reference)!;
    void fill(double x, double y, {int radius = 6, int gray = 15}) =>
        img.fillCircle(
          image,
          x: (x * 2).round(),
          y: (y * 2).round(),
          radius: radius,
          color: img.ColorRgb8(gray, gray, gray),
        );
    for (var i = 0; i < 40; i++) {
      fill(
        QmSheetGeometry.xs[i ~/ 10][i % 4],
        QmSheetGeometry.oneY[i % 10],
        gray: weakMarks && i == 0 ? 190 : 15,
      );
    }
    for (var i = 0; i < 8; i++) {
      for (var j = 0; j < 4; j++) {
        fill(
          QmSheetGeometry.xs[i ~/ 2][(i % 2) * 2 + j % 2],
          QmSheetGeometry.twoY[j],
        );
      }
    }
    for (var i = 0; i < 6; i++) {
      fill(QmSheetGeometry.shortX[i][0], QmSheetGeometry.digitsY[1]);
      fill(QmSheetGeometry.shortX[i][1], 638.58);
      fill(QmSheetGeometry.shortX[i][2], QmSheetGeometry.digitsY[5]);
    }
    for (var i = 0; i < 3; i++) {
      fill(
        [520.34, 530.9, 541.34][i],
        115.86 + 14.88 * [2, 0, 9][i],
        radius: 5,
      );
    }
    if (ambiguous) {
      fill(QmSheetGeometry.xs[0][1], QmSheetGeometry.oneY[0]);
      fill(QmSheetGeometry.xs[0][2], QmSheetGeometry.oneY[1], gray: 205);
    }
    if (weakMarks) {
      fill(520.34, 115.86 + 14.88 * 6, radius: 5, gray: 230);
      fill(530.9, 115.86 + 14.88 * 6, radius: 5, gray: 210);
    }
    if (rotate) image = img.copyRotate(image, angle: 90);
    return Uint8List.fromList(img.encodeJpg(image, quality: 92));
  }

  test('QM blank sheet reads blanks and requires a code', () {
    final r = recognizeQmSheet({'photo': reference, 'reference': reference});
    expect(r.answers.length, 54);
    expect(r.answers.every((m) => m.state == MarkState.blank), true);
    expect(r.codeClear, false);
  });
  test('QM uses common ABCD and digit confidence rules', () {
    final result = recognizeQmSheet({
      'photo': marked(weakMarks: true),
      'reference': reference,
    });
    expect(result.answers.first.state, MarkState.single);
    expect(result.answers.first.answer, 'A');
    expect(result.codeText, '2?9');
    expect(result.code[1].state, MarkState.uncertain);
  });
  test('QM reads all question groups, three-digit code, true/false and decimal columns', () {
    final r = recognizeQmSheet({'photo': marked(), 'reference': reference});
    expect(r.codeText, '209');
    expect(r.codeClear, true);
    expect(
      r.answers.take(40).map((v) => v.answer).join(),
      List.generate(40, (i) => 'ABCD'[i % 4]).join(),
    );
    expect(
      r.answers.skip(40).take(8).map((v) => v.answer),
      everyElement('TFTF'),
    );
    expect(r.answers.skip(48).map((v) => v.answer), everyElement('1,5'));
    expect(r.answerCrops.length, 54);
  });
  test('QM aligns a washed-out strip and reads all answer sections', () {
    final result = recognizeQmSheet({
      'photo': withUnevenLighting(marked()),
      'reference': reference,
    });
    expect(result.codeText, '209');
    expect(result.codeClear, true);
    expect(
      result.answers.take(40).map((mark) => mark.answer).join(),
      List.generate(40, (i) => 'ABCD'[i % 4]).join(),
    );
    expect(
      result.answers.skip(40).take(8).map((mark) => mark.answer),
      everyElement('TFTF'),
    );
    expect(
      result.answers.skip(48).map((mark) => mark.answer),
      everyElement('1,5'),
    );
  });
  test('QM rotation/JPEG, live probe and competing ABCD marks', () {
    final bytes = marked(rotate: true, ambiguous: true);
    final r = recognizeQmSheet({'photo': bytes, 'reference': reference});
    expect(r.codeText, '209');
    expect(r.answers[0].state, MarkState.uncertain);
    expect(r.answers[1].state, MarkState.single);
    expect(r.answers[1].answer, 'B');
    expect(r.answers[48].answer, '1,5');
    final image = img.copyResize(img.decodeImage(bytes)!, width: 800);
    final pixels = Uint8List(image.width * image.height);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        pixels[y * image.width + x] = image.getPixel(x, y).luminance.round();
      }
    }
    expect(
      probeQmSheet({
        'width': image.width,
        'height': image.height,
        'pixels': pixels,
      }).found,
      true,
    );
  });
  test('QM numeric reader supports signs, decimals, leading blanks and all four columns', () {
    final image = img.decodePng(reference)!;
    final expected = ['-1,5', '0,25', '1234', '1.50', '-123', '.5'];
    for (var q = 0; q < 6; q++) {
      final value = expected[q].replaceAll('.', ',');
      final offset = value.startsWith(',') ? 1 : 0;
      for (var n = 0; n < value.length; n++) {
        final col = offset + n, c = value[n];
        final y = c == '-'
            ? 625.74
            : c == ','
            ? 638.58
            : QmSheetGeometry.digitsY[int.parse(c)];
        img.fillCircle(
          image,
          x: (QmSheetGeometry.shortX[q][col] * 2).round(),
          y: (y * 2).round(),
          radius: 6,
          color: img.ColorRgb8(15, 15, 15),
        );
      }
    }
    final r = recognizeQmSheet({
      'photo': Uint8List.fromList(img.encodeJpg(image, quality: 90)),
      'reference': reference,
    });
    for (var i = 0; i < 6; i++) {
      expect(r.answers[48 + i].state, MarkState.single, reason: 'short $i');
      expect(
        normalizedNumber(r.answers[48 + i].answer),
        normalizedNumber(expected[i]),
      );
    }
  });
  test(
    'QM blank or missing markers cannot be accepted as another supported sheet',
    () {
      expect(
        () => recognizeQmSheet({
          'photo': File('assets/templates/abcd-40-compact-v1.png')
              .readAsBytesSync(),
          'reference': reference,
        }),
        throwsA(isA<OmrException>()),
      );
    },
  );
}
