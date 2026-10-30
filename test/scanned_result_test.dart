import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:siromix/data.dart';
import 'package:siromix/omr.dart';
import 'package:siromix/scan.dart';
import 'package:siromix/history.dart';

import 'widget_test.dart' show MemoryStorage;

void main() {
  const path = ['2026 – 2027', 'Kì thi', '6', 'Toán'];
  final picture = Uint8List.fromList(
    img.encodePng(
      img.Image(width: 10, height: 10)..clear(img.ColorRgb8(255, 255, 255)),
    ),
  );
  OmrRead read({String code = '132', bool uncertain = true}) => OmrRead(
    answers: [
      const ResponseMark(MarkState.single, 'A'),
      ResponseMark(uncertain ? MarkState.uncertain : MarkState.single, 'B'),
      ...List.filled(8, const ResponseMark(MarkState.blank)),
    ],
    candidate: '001286'
        .split('')
        .map((d) => DigitReading(d, MarkState.single))
        .toList(),
    code: code.split('').map((d) => DigitReading(d, MarkState.single)).toList(),
    aligned: picture,
    answerCrops: List.filled(10, picture),
    candidateCrop: picture,
    codeCrop: picture,
  );
  Future<ExamRepository> repo() async {
    final r = ExamRepository(MemoryStorage());
    await r.load();
    await r.update((d) {
      d.addCode(path, '132');
      final k = d.codes(path)['132']!.copy();
      k.count = 2;
      k.answers[0] = 'A';
      k.answers[1] = 'B';
      k.points[0] = 1;
      k.points[1] = 2;
      d.saveKey(path, '132', k);
    });
    return r;
  }

  testWidgets(
    'answer-only mode locks the preselected code, saves unknown SBD and shows it in history',
    (t) async {
      t.view.physicalSize = const Size(400, 1500);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final r = await repo();
      await r.update((d) {
        d.addCode(path, 'TN-A');
        final k = d.codes(path)['132']!.copy();
        k.answers[0] = 'C';
        k.answers[1] = 'D';
        d.saveKey(path, 'TN-A', k);
      });
      await t.pumpWidget(
        MaterialApp(
          home: ScannedResult(
            repository: r,
            contextPath: path,
            read: read(uncertain: false),
            fixedCode: 'TN-A',
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Số báo danh: Không xác định'), findsOneWidget);
      expect(find.text('Mã đề đã chọn: TN-A'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(find.text('Ảnh số báo danh và mã đề'), findsNothing);
      expect(r.data.counters, isEmpty);
      final confirm = find.widgetWithText(FilledButton, 'Xác nhận điểm');
      await t.ensureVisible(confirm);
      await t.tap(confirm);
      await t.pumpAndSettle();
      final paper = r.data.papers.single;
      expect(paper.code, 'TN-A');
      expect(paper.candidate, '');
      expect(paper.number, 1);
      expect(paper.grade.score, 0);
      expect(find.text('Bài số 1'), findsOneWidget);
      expect(find.text('Xác nhận điểm'), findsNothing);
      expect(r.data.papers.length, 1);
      final reopened = ExamRepository(r.storage);
      await reopened.load();
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistoryView(repository: reopened, path: path),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'không xác định');
      await t.pumpAndSettle();
      expect(find.text('1 bài đã chấm'), findsOneWidget);
      await t.tap(find.text('Bài số 1 · SBD Không xác định'));
      await t.pumpAndSettle();
      expect(find.text('SBD Không xác định · Mã đề TN-A'), findsOneWidget);
    },
  );
  testWidgets(
    'missing preselected key never falls back to a detected key in answer-only mode',
    (t) async {
      final r = await repo();
      await t.pumpWidget(
        MaterialApp(
          home: ScannedResult(
            repository: r,
            contextPath: path,
            read: read(uncertain: false),
            fixedCode: 'missing',
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Xác nhận điểm'), findsNothing);
      expect(
        find.textContaining('Mã đề đã chọn không còn hợp lệ'),
        findsOneWidget,
      );
      expect(r.data.papers, isEmpty);
      expect(r.data.counters, isEmpty);
    },
  );
  testWidgets(
    'answer-only uncertain marks still block confirmation; retake saves nothing',
    (t) async {
      t.view.physicalSize = const Size(400, 1500);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final r = await repo();
      bool? outcome;
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  outcome = await Navigator.push<bool>(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => ScannedResult(
                        repository: r,
                        contextPath: path,
                        read: read(),
                        fixedCode: '132',
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      final confirm = find.widgetWithText(FilledButton, 'Xác nhận điểm');
      await t.ensureVisible(confirm);
      expect(t.widget<FilledButton>(confirm).onPressed, isNull);
      final retake = find.text('Chụp lại đáp án');
      await t.ensureVisible(retake);
      await t.tap(retake);
      await t.pumpAndSettle();
      expect(outcome, false);
      expect(r.data.papers, isEmpty);
      expect(r.data.counters, isEmpty);
    },
  );
  testWidgets(
    'full-sheet mode still requires six-digit SBD and never treats a missing SBD as anonymous',
    (t) async {
      t.view.physicalSize = const Size(400, 1500);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final r = await repo(), original = read(uncertain: false);
      final missing = OmrRead(
        answers: original.answers,
        candidate: const [],
        code: original.code,
        aligned: picture,
        answerCrops: original.answerCrops,
        candidateCrop: picture,
        codeCrop: picture,
      );
      await t.pumpWidget(
        MaterialApp(
          home: ScannedResult(repository: r, contextPath: path, read: missing),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(TextFormField), findsOneWidget);
      final confirm = find.widgetWithText(FilledButton, 'Xác nhận điểm');
      await t.ensureVisible(confirm);
      await t.tap(confirm);
      await t.pumpAndSettle();
      expect(r.data.papers, isEmpty);
      expect(r.data.counters, isEmpty);
      final field = find.byType(TextFormField);
      await t.ensureVisible(field);
      expect(find.text('Nhập đủ 6 chữ số theo phiếu.'), findsOneWidget);
    },
  );
  testWidgets(
    'uncertain responses gate final score and allocate paper number only on confirm',
    (t) async {
      t.view.physicalSize = const Size(400, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final r = await repo();
      await t.pumpWidget(
        MaterialApp(
          home: ScannedResult(repository: r, contextPath: path, read: read()),
        ),
      );
      await t.pumpAndSettle();
      expect(r.data.counters, isEmpty);
      final confirm = find.widgetWithText(FilledButton, 'Xác nhận điểm');
      await t.ensureVisible(confirm);
      expect(t.widget<FilledButton>(confirm).onPressed, isNull);
      final review = find.text('Kiểm tra');
      await t.ensureVisible(review);
      await t.tap(review);
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(OutlinedButton, 'B'));
      await t.pumpAndSettle();
      await t.ensureVisible(confirm);
      await t.tap(confirm);
      await t.pumpAndSettle();
      expect(r.data.counters.values.single, 1);
      expect(find.text('Bài số 1'), findsOneWidget);
      final reopened = ExamRepository(r.storage);
      await reopened.load();
      expect(reopened.data.counters.values.single, 1);
      expect(reopened.data.papers.single.candidate, '001286');
      expect(reopened.data.papers.single.grade.score, 3);
    },
  );
  testWidgets('unknown detected code cannot silently use another key', (
    t,
  ) async {
    final r = await repo();
    await t.pumpWidget(
      MaterialApp(
        home: ScannedResult(
          repository: r,
          contextPath: path,
          read: read(code: '999', uncertain: false),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Xác nhận điểm'), findsNothing);
    expect(r.data.counters, isEmpty);
    expect(find.textContaining('Mã đề đọc được: 999'), findsOneWidget);
  });

  testWidgets(
    'review compares the chosen answer and key with distinct states at 320px',
    (t) async {
      t.view.physicalSize = const Size(320, 1800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final r = await repo();
      await r.update((d) {
        final k = d.codes(path)['132']!.copy();
        k.count = 5;
        k.answers.setRange(0, 5, ['A', 'C', 'C', 'D', 'A']);
        d.saveKey(path, '132', k);
      });
      final scan = read(uncertain: false);
      scan.answers[3] = const ResponseMark(MarkState.multiple);
      scan.answers[4] = const ResponseMark(MarkState.uncertain, 'A');
      await t.pumpWidget(
        MaterialApp(
          home: ScannedResult(repository: r, contextPath: path, read: scan),
        ),
      );
      await t.pumpAndSettle();
      final expected = [
        ('Câu 1 - Chọn A', 'Đáp án đúng: A · Đúng', const Color(0xffe7f5e9)),
        ('Câu 2 - Chọn B', 'Đáp án đúng: C · Sai', const Color(0xffffebee)),
        (
          'Câu 3 - Bỏ trống · 0 điểm',
          'Đáp án đúng: C · Sai',
          const Color(0xffffebee),
        ),
        (
          'Câu 4 - Nhiều đáp án · 0 điểm',
          'Đáp án đúng: D · Sai',
          const Color(0xffffebee),
        ),
        (
          'Câu 5 - Cần kiểm tra',
          'Đáp án đúng: A · Cần kiểm tra',
          const Color(0xfffff5db),
        ),
      ];
      for (var i = 0; i < expected.length; i++) {
        final row = find.byKey(ValueKey('answer-row-$i'));
        await t.ensureVisible(row);
        await t.pumpAndSettle();
        expect(
          find.descendant(of: row, matching: find.text(expected[i].$1)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: row, matching: find.text(expected[i].$2)),
          findsOneWidget,
        );
        expect(
          (t.widget<Container>(row).decoration as BoxDecoration).color,
          expected[i].$3,
        );
      }
      expect(t.takeException(), isNull);
      expect(r.data.counters, isEmpty);
    },
  );

  testWidgets(
    'manual correction and changing keys refresh comparison and color',
    (t) async {
      t.view.physicalSize = const Size(360, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final r = await repo();
      await r.update((d) {
        d.addCode(path, '246');
        final k = d.codes(path)['132']!.copy();
        k.answers[0] = 'C';
        d.saveKey(path, '246', k);
      });
      await t.pumpWidget(
        MaterialApp(
          home: ScannedResult(
            repository: r,
            contextPath: path,
            read: read(uncertain: false),
          ),
        ),
      );
      await t.pumpAndSettle();
      final row = find.byKey(const ValueKey('answer-row-0'));
      final review = find.descendant(of: row, matching: find.text('Xem lại'));
      await t.ensureVisible(review);
      await t.tap(review);
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(OutlinedButton, 'C'));
      await t.pumpAndSettle();
      expect(find.text('Câu 1 - Chọn C'), findsOneWidget);
      expect(find.text('Đáp án đúng: A · Sai'), findsOneWidget);
      expect(
        (t.widget<Container>(row).decoration as BoxDecoration).color,
        const Color(0xffffebee),
      );
      final codes = find.byType(DropdownButtonFormField<String>);
      await t.ensureVisible(codes);
      await t.tap(codes);
      await t.pumpAndSettle();
      await t.tap(find.text('246').last);
      await t.pumpAndSettle();
      await t.ensureVisible(row);
      expect(find.text('Đáp án đúng: C · Đúng'), findsOneWidget);
      expect(
        (t.widget<Container>(row).decoration as BoxDecoration).color,
        const Color(0xffe7f5e9),
      );
      expect(r.data.counters, isEmpty);
    },
  );

  testWidgets(
    'Home from unconfirmed scan requires discard and saves no paper',
    (t) async {
      final r = await repo();
      var home = false;
      await t.pumpWidget(
        MaterialApp(
          home: ScannedResult(
            repository: r,
            contextPath: path,
            read: read(uncertain: false),
            onHome: () => home = true,
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Trang chủ'));
      await t.pumpAndSettle();
      expect(home, false);
      expect(find.text('Dữ liệu chưa được lưu'), findsOneWidget);
      await t.tap(find.text('Tiếp tục kiểm tra'));
      await t.pumpAndSettle();
      expect(home, false);
      await t.tap(find.text('Trang chủ'));
      await t.pumpAndSettle();
      await t.tap(find.text('Bỏ và rời đi'));
      await t.pumpAndSettle();
      expect(home, true);
      expect(r.data.papers, isEmpty);
      expect(r.data.counters, isEmpty);
    },
  );
}
