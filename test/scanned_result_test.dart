import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:siromix/data.dart';
import 'package:siromix/omr.dart';
import 'package:siromix/scan.dart';

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
      expect(reopened.data.papers.single.candidate, '');
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
  for (final scenario in [(400.0, 1.0), (320.0, 1.8)]) {
    testWidgets(
      'response crops remain matched to rows at ${scenario.$1}px and text scale ${scenario.$2}',
      (t) async {
        t.view.physicalSize = Size(scenario.$1, 1400);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final r = await repo();
        final scan = read(uncertain: false);
        Uint8List crop(int shade) => Uint8List.fromList(
          img.encodePng(
            img.Image(width: 205, height: 46)
              ..clear(img.ColorRgb8(shade, shade, shade)),
          ),
        );
        final first = crop(190), second = crop(230);
        scan.answerCrops[0] = first;
        scan.answerCrops[1] = second;
        await t.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scenario.$2)),
              child: child!,
            ),
            home: ScannedResult(repository: r, contextPath: path, read: scan),
          ),
        );
        await t.pumpAndSettle();
        for (var i = 0; i < 2; i++) {
          final thumb = find.byKey(ValueKey('answer-thumbnail-$i'));
          await t.scrollUntilVisible(
            thumb,
            300,
            scrollable: find.byType(Scrollable).first,
          );
          await t.pumpAndSettle();
          final image = t.widget<Image>(thumb);
          expect(
            (image.image as MemoryImage).bytes,
            same(i == 0 ? first : second),
          );
          expect(image.semanticLabel, 'Ảnh đáp án câu ${i + 1}');
          expect(t.takeException(), isNull);
        }
        final row = find.byKey(const ValueKey('answer-row-1'));
        final review = find.descendant(of: row, matching: find.text('Xem lại'));
        await t.ensureVisible(review);
        await t.tap(review);
        await t.pumpAndSettle();
        expect(find.text('Phiếu thực tế tô đáp án nào?'), findsOneWidget);
        await t.tap(find.widgetWithText(OutlinedButton, 'D'));
        await t.pumpAndSettle();
        expect(find.text('Câu 2 - Chọn D'), findsOneWidget);
        expect(
          (t
                      .widget<Image>(
                        find.byKey(const ValueKey('answer-thumbnail-1')),
                      )
                      .image
                  as MemoryImage)
              .bytes,
          same(second),
        );
        expect(r.data.papers, isEmpty);
        expect(t.takeException(), isNull);
      },
    );
  }
}
