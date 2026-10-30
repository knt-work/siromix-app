import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siromix/data.dart';
import 'package:siromix/history.dart';
import 'package:siromix/profile.dart';

import 'widget_test.dart' show MemoryStorage;

const path = ['2026 – 2027', 'Kì thi', '6', 'Toán'];
Future<ExamRepository> repository([MemoryStorage? storage]) async {
  final r = ExamRepository(storage ?? MemoryStorage());
  await r.load();
  await r.update((d) {
    d.addCode(path, '132');
    final k = d.codes(path)['132']!.copy();
    k.count = 2;
    k.answers.setRange(0, 2, ['A', 'B']);
    k.points.setRange(0, 2, [1, 2]);
    d.saveKey(path, '132', k);
  });
  return r;
}

void confirm(ExamData d, [String candidate = '001286']) => d.confirmPaper(
  path: path,
  candidate: candidate,
  code: '132',
  responses: const [
    ResponseMark(MarkState.single, 'A'),
    ResponseMark(MarkState.blank),
  ],
);

class Documents implements BackupDocuments {
  String? content;
  bool cancelled = false;
  @override
  Future<bool> save(String value) async {
    content = value;
    return !cancelled;
  }

  @override
  Future<String?> open() async => cancelled ? null : content;
}

void main() {
  test(
    'new and migrated profiles have stable identities across reopen',
    () async {
      final disk = MemoryStorage(), r = ExamRepository(MemoryStorage());
      await r.load();
      final old = ExamData.empty().encode();
      final j = jsonDecode(old) as Map<String, dynamic>;
      j['version'] = 2;
      j.remove('profile');
      j.remove('papers');
      disk.value = jsonEncode(j);
      final migrated = ExamRepository(disk);
      await migrated.load();
      final reopened = ExamRepository(disk);
      await reopened.load();
      expect(reopened.data.profile.id, migrated.data.profile.id);
      expect(reopened.data.children([]), migrated.data.children([]));
      final fresh = ExamRepository(r.storage);
      await fresh.load();
      expect(fresh.data.profile.id, r.data.profile.id);
    },
  );
  test(
    'confirmation persists immutable key snapshot and paper identity',
    () async {
      final r = await repository();
      await r.update(confirm);
      await r.update((d) {
        final k = d.codes(path)['132']!.copy();
        k.answers[0] = 'D';
        k.points[0] = 9;
        d.saveKey(path, '132', k);
      });
      final again = ExamRepository(r.storage);
      await again.load();
      final paper = again.data.papers.single;
      expect(paper.candidate, '001286');
      expect(paper.number, 1);
      expect(paper.grade.score, 1);
      expect(paper.key.answers[0], 'A');
      expect(paper.ownerId, again.data.profile.id);
      await again.update(confirm);
      expect(again.data.papers.last.number, 2);
    },
  );
  test(
    'failed and uncertain confirmation writes neither history nor counter',
    () async {
      final disk = MemoryStorage(), r = await repository(disk);
      disk.fail = true;
      await expectLater(r.update(confirm), throwsStateError);
      expect(r.data.papers, isEmpty);
      expect(r.data.counters, isEmpty);
      disk.fail = false;
      await expectLater(
        r.update(
          (d) => d.confirmPaper(
            path: path,
            candidate: '001286',
            code: '132',
            responses: const [
              ResponseMark(MarkState.uncertain),
              ResponseMark(MarkState.blank),
            ],
          ),
        ),
        throwsFormatException,
      );
      expect(r.data.counters, isEmpty);
      await r.update(confirm);
      expect(r.data.papers.single.number, 1);
    },
  );
  test(
    'backup roundtrip restores profile, keys, history and next counter',
    () async {
      final r = await repository();
      await r.update(confirm);
      await r.update(
        (d) => d.profile = UserProfile(
          id: d.profile.id,
          name: 'Cô An',
          school: 'THCS',
          email: 'an@example.com',
        ),
      );
      final backup = BackupFile.decode(BackupFile(r.data).encode());
      final target = ExamRepository(MemoryStorage());
      await target.load();
      await target.restore(backup);
      final restored = ExamRepository(target.storage);
      await restored.load();
      expect(restored.data.profile.name, 'Cô An');
      expect(restored.data.profile.id, r.data.profile.id);
      expect(restored.data.papers.single.grade.score, 1);
      await restored.update(confirm);
      expect(restored.data.papers.last.number, 2);
    },
  );
  test('malformed backups and inconsistent counters are rejected', () async {
    final r = await repository();
    await r.update(confirm);
    final raw = jsonDecode(BackupFile(r.data).encode()) as Map<String, dynamic>;
    raw['data']['counters'].clear();
    expect(() => BackupFile.decode(jsonEncode(raw)), throwsFormatException);
    expect(
      () => BackupFile.decode('{"format":"other","version":1}'),
      throwsFormatException,
    );
    expect(() => BackupFile.decode('{bad'), throwsFormatException);
    final duplicate = jsonDecode(r.data.encode()) as Map<String, dynamic>;
    duplicate['papers'].add(duplicate['papers'][0]);
    expect(() => ExamData.decode(jsonEncode(duplicate)), throwsFormatException);
  });
  test(
    'failed restore retains every existing value and remains usable',
    () async {
      final disk = MemoryStorage(), r = await repository(disk);
      final before = r.data.encode();
      final source = await repository();
      await source.update(confirm);
      disk.fail = true;
      await expectLater(r.restore(BackupFile(source.data)), throwsStateError);
      expect(r.data.encode(), before);
      disk.fail = false;
      await r.update(confirm);
      expect(r.data.papers.single.number, 1);
    },
  );
  testWidgets('history filters by context and SBD and opens saved details', (
    t,
  ) async {
    final r = await repository();
    await r.update(confirm);
    await r.update((d) => confirm(d, '008888'));
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HistoryView(repository: r, path: path),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('2 bài đã chấm'), findsOneWidget);
    await t.enterText(find.byType(TextField), '008888');
    await t.pumpAndSettle();
    expect(find.text('1 bài đã chấm'), findsOneWidget);
    expect(find.text('Bài số 1 · SBD 001286'), findsNothing);
    await t.tap(find.text('Bài số 2 · SBD 008888'));
    await t.pumpAndSettle();
    expect(find.text('Chi tiết bài chấm'), findsOneWidget);
    expect(find.text('Câu 1 - Chọn A'), findsOneWidget);
    expect(find.text('Đáp án đúng: A · Đúng'), findsOneWidget);
  });
  testWidgets(
    'profile saves locally without changing identity; exports saved values',
    (t) async {
      t.view.physicalSize = const Size(400, 1800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final r = await repository(), docs = Documents();
      await r.update(
        (d) => d.profile = UserProfile(id: d.profile.id, school: 'Đơn vị cũ'),
      );
      final id = r.data.profile.id;
      await t.pumpWidget(
        MaterialApp(
          home: ProfilePage(repository: r, documents: docs),
        ),
      );
      await t.pumpAndSettle();
      final unit = find.byKey(const ValueKey('profile-unit'));
      expect(t.widget<TextFormField>(unit).controller!.text, 'Đơn vị cũ');
      await t.enterText(unit, '  THCS Nguyễn Trãi  ');
      await t.enterText(find.byType(TextFormField).at(0), 'Cô An');
      await t.tap(find.text('Lưu hồ sơ'));
      await t.pumpAndSettle();
      expect(r.data.profile.name, 'Cô An');
      expect(r.data.profile.school, 'THCS Nguyễn Trãi');
      expect(r.data.profile.id, id);
      final export = find.text('Sao lưu dữ liệu');
      await t.ensureVisible(export);
      await t.tap(export);
      await t.pumpAndSettle();
      expect(BackupFile.decode(docs.content!).data.profile.name, 'Cô An');
      expect(
        BackupFile.decode(docs.content!).data.profile.school,
        'THCS Nguyễn Trãi',
      );
      final reopened = ExamRepository(r.storage);
      await reopened.load();
      expect(reopened.data.profile.school, 'THCS Nguyễn Trãi');
    },
  );
  testWidgets('restore previews contents and cancel leaves data untouched', (
    t,
  ) async {
    t.view.physicalSize = const Size(400, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final r = await repository(), docs = Documents();
    final before = r.data.encode();
    docs.content = BackupFile(r.data).encode();
    await t.pumpWidget(
      MaterialApp(
        home: ProfilePage(repository: r, documents: docs),
      ),
    );
    await t.pumpAndSettle();
    final restore = find.text('Khôi phục từ file');
    await t.ensureVisible(restore);
    await t.tap(restore);
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('Khôi phục dữ liệu?'), findsOneWidget);
    await t.tap(find.text('Hủy'));
    await t.pumpAndSettle();
    expect(r.data.encode(), before);
    docs.content = 'bad';
    await t.tap(restore);
    await t.pumpAndSettle();
    expect(find.textContaining('File không hợp lệ'), findsOneWidget);
    expect(r.data.encode(), before);
  });

  testWidgets('confirmed restore closes profile only after a durable write', (
    t,
  ) async {
    t.view.physicalSize = const Size(400, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final r = await repository(),
        source = await repository(),
        docs = Documents();
    await source.update(confirm);
    docs.content = BackupFile(source.data).encode();
    bool? restored;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              child: const Text('Open'),
              onPressed: () async {
                restored = await Navigator.push<bool>(
                  ctx,
                  MaterialPageRoute<bool>(
                    builder: (_) => ProfilePage(repository: r, documents: docs),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    final restore = find.text('Khôi phục từ file');
    await t.ensureVisible(restore);
    await t.tap(restore);
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text('Thay thế và khôi phục'));
    await t.pumpAndSettle();
    expect(restored, true);
    expect(find.text('Open'), findsOneWidget);
    expect(r.data.papers.single.candidate, '001286');
    final reopened = ExamRepository(r.storage);
    await reopened.load();
    expect(reopened.data.papers.length, 1);
  });
  testWidgets('history excludes other subjects even when candidate matches', (
    t,
  ) async {
    final r = await repository();
    await r.update(confirm);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HistoryView(
            repository: r,
            path: const ['2026 – 2027', 'Kì thi', '6', 'Văn'],
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('0 bài đã chấm'), findsOneWidget);
    expect(find.text('Bài số 1 · SBD 001286'), findsNothing);
  });
}
