import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siromix/data.dart';
import 'package:siromix/main.dart';
import 'package:siromix/scan_flow.dart';

import 'widget_test.dart' show MemoryStorage;

void main() {
  test('schema 4 results migrate without loss and older schemas cannot introduce unknown candidates', () async {
    final r = ExamRepository(MemoryStorage());
    await r.load();
    final path = [r.data.children([]).first, 'Migration', '6', 'Toán'];
    await r.update((d) {
      d.addCode(path, '132');
      final k = d.codes(path)['132']!.copy();
      k.count = 1;
      k.answers[0] = 'A';
      d.saveKey(path, '132', k);
      d.confirmPaper(
        path: path,
        candidate: '001286',
        code: '132',
        responses: [const ResponseMark(MarkState.single, 'A')],
      );
    });
    final old = jsonDecode(r.data.encode()) as Map<String, dynamic>;
    old['version'] = 4;
    final disk = MemoryStorage()..value = jsonEncode(old);
    final migrated = ExamRepository(disk);
    await migrated.load();
    expect(migrated.data.papers.single.id, r.data.papers.single.id);
    expect(migrated.data.papers.single.candidate, '001286');
    expect(migrated.data.profile.id, r.data.profile.id);
    expect(migrated.data.counters, r.data.counters);
    expect(jsonDecode(disk.value!)['version'], 7);
    old['papers'][0]['candidate'] = '';
    expect(() => ExamData.decode(jsonEncode(old)), throwsFormatException);
    old['version'] = 5;
    expect(
      ExamData.decode(jsonEncode(old)).papers.single.candidateLabel,
      'Không xác định',
    );
  });
  testWidgets('full-only chooser keeps cancellation inert', (t) async {
    ScanMode? chosen;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () async {
                chosen = await chooseScanMode(ctx);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    expect(find.text('Quét toàn phiếu'), findsOneWidget);
    expect(find.text('Chỉ quét đáp án'), findsNothing);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(chosen, isNull);
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('choose-full')));
    await t.pumpAndSettle();
    expect(chosen, ScanMode.full);
  });
  testWidgets('Home from dirty editor requires discard confirmation', (
    t,
  ) async {
    t.view.physicalSize = const Size(400, 1300);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    var home = false, saves = 0;
    await t.pumpWidget(
      MaterialApp(
        home: KeyEditor(
          contextPath: const ['2026 – 2027', 'Kì thi', '6', 'Toán'],
          code: '132',
          original: ExamKey(),
          onHome: () => home = true,
          onSave: (k) async {
            saves++;
            return true;
          },
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.enterText(
      find.widgetWithText(TextField, 'Điểm chung mỗi câu'),
      '1',
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Trang chủ'));
    await t.pumpAndSettle();
    expect(home, false);
    expect(find.text('Cấu hình chưa được lưu'), findsOneWidget);
    await t.tap(find.text('Tiếp tục chỉnh sửa'));
    await t.pumpAndSettle();
    expect(home, false);
    await t.tap(find.text('Trang chủ'));
    await t.pumpAndSettle();
    await t.tap(find.text('Bỏ thay đổi'));
    await t.pumpAndSettle();
    expect(home, true);
    expect(saves, 0);
  });
}
