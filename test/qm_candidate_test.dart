import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:siromix/data.dart';
import 'package:siromix/main.dart';
import 'package:siromix/omr.dart';
import 'package:siromix/scan.dart';
import 'package:siromix/templates.dart';
import 'package:siromix/ui.dart';

import 'widget_test.dart' show MemoryStorage;

const candidatePath = ['2026 – 2027', 'Kì thi', '6', 'Toán'];
ExamKey candidateKey(bool enabled) => ExamKey(
  count: 1,
  templateId: SheetTemplate.qm2025.id,
  answers: ['A', ...List.filled(39, '')],
  parts: QmParts(scanCandidate: enabled),
);
void main() {
  final reference = File('assets/templates/qm2025-a4-v1.png').readAsBytesSync();
  Uint8List photo(String value, {bool faint = false, bool multiple = false}) {
    final im = img.decodePng(reference)!;
    const xs = [432.02, 442.58, 453.02, 463.58, 474.02, 484.58];
    for (var i = 0; i < value.length; i++) {
      if (value[i] == '_') continue;
      final digit = int.parse(value[i]);
      img.fillCircle(
        im,
        x: (xs[i] * 2).round(),
        y: ((115.86 + 14.88 * digit) * 2).round(),
        radius: 5,
        color: img.ColorRgb8(
          faint && i == 2 ? 210 : 15,
          faint && i == 2 ? 210 : 15,
          faint && i == 2 ? 210 : 15,
        ),
      );
    }
    if (multiple) {
      img.fillCircle(
        im,
        x: (xs[2] * 2).round(),
        y: ((115.86 + 14.88 * 9) * 2).round(),
        radius: 5,
        color: img.ColorRgb8(15, 15, 15),
      );
    }
    return Uint8List.fromList(img.encodeJpg(im, quality: 92));
  }

  test('QM candidate reader preserves six digits and leading zeroes', () {
    for (final value in ['001286', '012345', '678909']) {
      final read = recognizeQmSheet({
        'photo': photo(value),
        'reference': reference,
      });
      expect(read.candidateClear, true);
      expect(read.candidateText, value);
      expect(read.candidateCrop, isNotEmpty);
    }
  });
  test('QM missing, faint and multiple candidate columns cannot become a confident number', () {
    for (final input in [
      photo('00_286'),
      photo('001286', faint: true),
      photo('001286', multiple: true),
    ]) {
      final read = recognizeQmSheet({'photo': input, 'reference': reference});
      expect(read.candidateClear, false);
      expect(read.candidateText.contains('?'), true);
    }
  });
  test('schema 6 QM configurations migrate with candidate scanning off; numbering/history are retained', () async {
    final disk = MemoryStorage(), r = ExamRepository(MemoryStorage());
    await r.load();
    await r.update((d) {
      d.addCode(candidatePath, '132');
      d.saveKey(candidatePath, '132', candidateKey(false));
      d.confirmPaper(
        path: candidatePath,
        candidate: '',
        candidateUnknown: true,
        code: '132',
        responses: [const ResponseMark(MarkState.single, 'A')],
      );
    });
    final j = jsonDecode(r.data.encode()) as Map<String, dynamic>;
    j['version'] = 6;
    for (final key in (j['keys'] as Map).values) {
      (key['parts'] as Map).remove('scanCandidate');
    }
    for (final paper in j['papers'] as List) {
      (paper['key']['parts'] as Map).remove('scanCandidate');
    }
    disk.value = jsonEncode(j);
    final reopened = ExamRepository(disk);
    await reopened.load();
    expect(jsonDecode(disk.value!)['version'], 7);
    expect(
      reopened.data.codes(candidatePath)['132']!.parts.scanCandidate,
      false,
    );
    expect(reopened.data.papers.single.candidate, '');
    expect(reopened.data.counters.values.single, 1);
    final key = reopened.data.codes(candidatePath)['132']!.copy()
      ..parts.scanCandidate = true;
    await reopened.update((d) => d.saveKey(candidatePath, '132', key));
    await reopened.update(
      (d) => d.confirmPaper(
        path: candidatePath,
        candidate: '001286',
        code: '132',
        responses: [const ResponseMark(MarkState.single, 'A')],
      ),
    );
    final backup = BackupFile.decode(BackupFile(reopened.data).encode());
    expect(backup.data.papers.last.candidate, '001286');
    expect(backup.data.papers.last.number, 2);
    expect(backup.data.papers.first.key.parts.scanCandidate, false);
    expect(backup.data.papers.last.key.parts.scanCandidate, true);
    expect(
      () => backup.data.confirmPaper(
        path: candidatePath,
        candidate: '',
        candidateUnknown: true,
        code: '132',
        responses: [const ResponseMark(MarkState.single, 'A')],
      ),
      throwsFormatException,
    );
  });
  testWidgets('QM candidate toggle persists and can be switched back off', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 1700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    ExamKey? saved;
    await t.pumpWidget(
      MaterialApp(
        theme: siroTheme(),
        home: KeyEditor(
          contextPath: candidatePath,
          code: '132',
          original: candidateKey(false),
          onSave: (k) async {
            saved = k;
            return true;
          },
        ),
      ),
    );
    await t.pumpAndSettle();
    final toggle = find.byKey(const ValueKey('qm-toggle-candidate'));
    expect(t.widget<Switch>(toggle).value, false);
    await t.tap(toggle);
    await t.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Lưu cấu hình đề');
    await t.scrollUntilVisible(
      save,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(save);
    await t.pumpAndSettle();
    await t.tap(save);
    await t.pumpAndSettle();
    expect(saved!.parts.scanCandidate, true);
    await t.scrollUntilVisible(
      toggle,
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(toggle);
    await t.pumpAndSettle();
    await t.tap(toggle);
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      save,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(save);
    await t.pumpAndSettle();
    await t.tap(save);
    await t.pumpAndSettle();
    expect(saved!.parts.scanCandidate, false);
    expect(t.takeException(), isNull);
  });
  Future<ExamRepository> repository() async {
    final r = ExamRepository(MemoryStorage());
    await r.load();
    await r.update((d) {
      d.addCode(candidatePath, '132');
      d.saveKey(candidatePath, '132', candidateKey(false));
      d.addCode(candidatePath, '246');
      d.saveKey(candidatePath, '246', candidateKey(true));
    });
    return r;
  }

  OmrRead result({required bool clear, String code = '246'}) {
    final blank = recognizeQmSheet({
      'photo': reference,
      'reference': reference,
    });
    return OmrRead(
      answers: [
        const ResponseMark(MarkState.single, 'A'),
        ...List.filled(53, const ResponseMark(MarkState.blank)),
      ],
      candidate: clear
          ? '001286'
                .split('')
                .map((v) => DigitReading(v, MarkState.single))
                .toList()
          : List.filled(6, const DigitReading('?', MarkState.uncertain)),
      code: code
          .split('')
          .map((v) => DigitReading(v, MarkState.single))
          .toList(),
      aligned: blank.aligned,
      answerCrops: blank.answerCrops,
      candidateCrop: blank.candidateCrop,
      codeCrop: blank.codeCrop,
    );
  }

  testWidgets(
    'enabled candidate scanning blocks missing SBD until manually verified',
    (t) async {
      t.view.physicalSize = const Size(390, 1800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final r = await repository();
      await t.pumpWidget(
        MaterialApp(
          theme: siroTheme(),
          home: ScannedResult(
            repository: r,
            contextPath: candidatePath,
            read: result(clear: false),
            template: SheetTemplate.qm2025,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(TextFormField), findsOneWidget);
      final confirm = find.widgetWithText(FilledButton, 'Xác nhận điểm');
      await t.scrollUntilVisible(
        confirm,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await t.ensureVisible(confirm);
      await t.tap(confirm);
      await t.pumpAndSettle();
      expect(r.data.papers, isEmpty);
      final input = find.byType(TextFormField);
      await t.scrollUntilVisible(
        input,
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await t.ensureVisible(input);
      await t.enterText(input, '001286');
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        confirm,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await t.ensureVisible(confirm);
      await t.tap(confirm);
      await t.pumpAndSettle();
      expect(r.data.papers.single.candidate, '001286');
      expect(r.data.papers.single.key.parts.scanCandidate, true);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'selected key controls SBD policy when switching between enabled and disabled codes',
    (t) async {
      t.view.physicalSize = const Size(390, 1800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final r = await repository();
      await t.pumpWidget(
        MaterialApp(
          theme: siroTheme(),
          home: ScannedResult(
            repository: r,
            contextPath: candidatePath,
            read: result(clear: true, code: '132'),
            template: SheetTemplate.qm2025,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Số báo danh: Không xác định'), findsOneWidget);
      Future<void> choose(String value) async {
        final selector = find.byType(DropdownButtonFormField<String>);
        await t.ensureVisible(selector);
        await t.tap(selector);
        await t.pumpAndSettle();
        await t.tap(find.text(value).last);
        await t.pumpAndSettle();
      }

      await choose('246');
      expect(
        t.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
        '001286',
      );
      await choose('132');
      expect(find.byType(TextFormField), findsNothing);
      final confirm = find.widgetWithText(FilledButton, 'Xác nhận điểm');
      await t.scrollUntilVisible(
        confirm,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await t.ensureVisible(confirm);
      await t.tap(confirm);
      await t.pumpAndSettle();
      expect(r.data.papers.single.candidate, '');
      expect(r.data.papers.single.key.parts.scanCandidate, false);
      expect(t.takeException(), isNull);
    },
  );
}
