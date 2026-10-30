import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siromix/data.dart';
import 'package:siromix/history.dart';
import 'package:siromix/main.dart';

import 'widget_test.dart' show MemoryStorage;

Future<ExamRepository> seed({bool extra = false}) async {
  final r = ExamRepository(MemoryStorage());
  await r.load();
  final year = r.data.children([]).first;
  await r.update((d) {
    final paths = [
      [year, 'E-Delete', '6', 'Toán'],
      [year, 'E-Delete', '6', 'Lý'],
      [year, 'E-Delete', '7', 'Toán'],
      [year, 'E-Delete phụ', '6', 'Toán'],
      ['2090 – 2091', 'E-Delete', '6', 'Toán'],
    ];
    for (var i = 0; i < paths.length; i++) {
      final path = paths[i];
      for (var depth = 0; depth < 4; depth++) {
        final parent = path.take(depth).toList();
        if (!d.children(parent).contains(path[depth])) {
          d.add(parent, path[depth]);
        }
      }
      d.addCode(path, '132');
      final k = d.codes(path)['132']!.copy();
      k.count = 1;
      k.answers[0] = 'A';
      k.points[0] = 1;
      d.saveKey(path, '132', k);
      d.confirmPaper(
        path: path,
        candidate: '${i + 1}'.padLeft(6, '0'),
        code: '132',
        responses: [const ResponseMark(MarkState.single, 'A')],
      );
    }
    if (extra) {
      d.confirmPaper(
        path: paths.first,
        candidate: '008888',
        code: '132',
        responses: [const ResponseMark(MarkState.single, 'A')],
      );
      d.confirmPaper(
        path: paths.first,
        candidate: '',
        candidateUnknown: true,
        code: '132',
        responses: [const ResponseMark(MarkState.single, 'A')],
      );
    }
  });
  return r;
}

void main() {
  for (final depth in [2, 3, 4]) {
    test(
      'catalog cascade depth=$depth removes only the exact subtree and survives restart/backup',
      () async {
        final r = await seed(), year = r.data.children([]).first;
        final scope = [year, 'E-Delete', '6', 'Toán'].take(depth).toList();
        final remaining = r.data.papers
            .where((p) => !ExamData.pathStartsWith(p.path, scope))
            .map((p) => p.id)
            .toSet();
        if (depth == 2) {
          expect(r.data.deletionImpact(scope), (
            grades: 2,
            subjects: 3,
            keys: 3,
            papers: 3,
          ));
        }
        await r.update((d) => d.deleteCatalog(scope));
        expect(
          r.data.children(scope.take(depth - 1).toList()),
          isNot(contains(scope.last)),
        );
        expect(r.data.papers.map((p) => p.id).toSet(), remaining);
        expect(
          r.data.keys.keys.any(
            (k) => ExamData.pathStartsWith(
              List<String>.from(jsonDecode(k)),
              scope,
            ),
          ),
          false,
        );
        expect(
          r.data.counters.keys.any(
            (k) => ExamData.pathStartsWith(
              List<String>.from(jsonDecode(k)),
              scope,
            ),
          ),
          false,
        );
        expect(r.data.children([year]), contains('E-Delete phụ'));
        expect(
          r.data.codes(['2090 – 2091', 'E-Delete', '6', 'Toán']),
          contains('132'),
        );
        final reopened = ExamRepository(r.storage);
        await reopened.load();
        expect(reopened.data.papers.map((p) => p.id).toSet(), remaining);
        expect(
          BackupFile.decode(BackupFile(reopened.data).encode())
              .data
              .keys
              .length,
          r.data.keys.length,
        );
      },
    );
  }
  test(
    'invalid catalog scopes and mixed missing paper IDs never delete anything',
    () async {
      final r = await seed();
      final before = r.data.encode();
      for (final scope in [
        <String>[],
        [r.data.children([]).first],
        [r.data.children([]).first, 'missing'],
      ]) {
        await expectLater(
          r.update((d) => d.deleteCatalog(scope)),
          throwsFormatException,
        );
      }
      await expectLater(
        r.update((d) => d.deletePapers({r.data.papers.first.id, 'missing'})),
        throwsFormatException,
      );
      expect(r.data.encode(), before);
    },
  );
  test(
    'deleting result batches keeps counters and never reissues a used number',
    () async {
      final r = await seed(extra: true);
      final path = [r.data.children([]).first, 'E-Delete', '6', 'Toán'];
      final ids = r.data.papers
          .where((p) => p.path.join('/') == path.join('/'))
          .map((p) => p.id)
          .toSet();
      final counters = Map.of(r.data.counters);
      await r.update((d) => d.deletePapers(ids));
      expect(r.data.counters, counters);
      final reopened = ExamRepository(r.storage);
      await reopened.load();
      await reopened.update(
        (d) => d.confirmPaper(
          path: path,
          candidate: '',
          candidateUnknown: true,
          code: '132',
          responses: [const ResponseMark(MarkState.single, 'A')],
        ),
      );
      expect(reopened.data.papers.last.number, 4);
      expect(reopened.data.papers.length, 5);
    },
  );
  test(
    'failed disk writes leave catalog cascade and result deletion unchanged',
    () async {
      for (final cascade in [true, false]) {
        final r = await seed();
        final before = r.data.encode();
        final disk = r.storage as MemoryStorage;
        disk.fail = true;
        await expectLater(
          r.update(
            (d) => cascade
                ? d.deleteCatalog([d.children([]).first, 'E-Delete'])
                : d.deletePapers({d.papers.first.id}),
          ),
          throwsStateError,
        );
        expect(r.data.encode(), before);
        expect(disk.value, before);
      }
    },
  );
  for (final depth in [2, 3, 4]) {
    testWidgets(
      'catalog delete depth=$depth requires confirmation and cancel preserves everything',
      (t) async {
        t.view.physicalSize = const Size(400, 1300);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final r = await seed();
        final before = r.data.encode();
        final year = r.data.children([]).first;
        await t.pumpWidget(SiroMixApp(repository: r));
        await t.pumpAndSettle();
        await t.tap(find.text('Chấm bài trắc nghiệm'));
        await t.pumpAndSettle();
        if (depth >= 3) {
          await t.tap(find.text('E-Delete'));
          await t.pumpAndSettle();
        }
        if (depth >= 4) {
          await t.tap(find.text('6'));
          await t.pumpAndSettle();
        }
        final label = depth == 2
            ? 'Xóa kì thi E-Delete'
            : depth == 3
            ? 'Xóa khối 6'
            : 'Xóa môn thi Toán';
        final remove = find.byTooltip(label);
        await t.ensureVisible(remove);
        await t.tap(remove);
        await t.pumpAndSettle();
        expect(find.textContaining('Không thể hoàn tác'), findsOneWidget);
        expect(r.data.encode(), before);
        await t.tap(find.text('Hủy'));
        await t.pumpAndSettle();
        expect(r.data.encode(), before);
        await t.tap(remove);
        await t.pumpAndSettle();
        await t.tap(find.widgetWithText(FilledButton, 'Xóa'));
        await t.pumpAndSettle();
        final scope = [year, 'E-Delete', '6', 'Toán'].take(depth).toList();
        expect(
          r.data.papers.any((p) => ExamData.pathStartsWith(p.path, scope)),
          false,
        );
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'single result delete confirms, cancels safely and retains next number',
    (t) async {
      t.view.physicalSize = const Size(400, 1300);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final r = await seed(extra: true);
      final path = [r.data.children([]).first, 'E-Delete', '6', 'Toán'];
      final target = r.data.papers.first;
      final counters = Map.of(r.data.counters);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistoryView(repository: r, path: path),
          ),
        ),
      );
      await t.pumpAndSettle();
      final remove = find.byKey(ValueKey('paper-delete-${target.id}'));
      await t.ensureVisible(remove);
      await t.tap(remove);
      await t.pumpAndSettle();
      expect(find.text('Xóa bài số 1?'), findsOneWidget);
      expect(r.data.papers.length, 7);
      await t.tap(find.text('Hủy'));
      await t.pumpAndSettle();
      expect(r.data.papers.length, 7);
      await t.tap(remove);
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Xóa'));
      await t.pumpAndSettle();
      expect(r.data.papers.length, 6);
      expect(r.data.papers.any((p) => p.id == target.id), false);
      expect(r.data.counters, counters);
    },
  );
  testWidgets(
    'filtered batch deletes exactly selected IDs across searches and cancellation preserves selection',
    (t) async {
      t.view.physicalSize = const Size(360, 1300);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final r = await seed(extra: true);
      final path = [r.data.children([]).first, 'E-Delete', '6', 'Toán'];
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HistoryView(repository: r, path: path),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('history-select-mode')));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), '008888');
      await t.pumpAndSettle();
      await t.tap(find.text('Chọn tất cả đang hiển thị'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('history-delete-selected')));
      await t.pumpAndSettle();
      await t.tap(find.text('Hủy'));
      await t.pumpAndSettle();
      expect(r.data.papers.length, 7);
      expect(find.text('Đã chọn 1 bài'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'không xác định');
      await t.pumpAndSettle();
      await t.tap(find.text('Chọn tất cả đang hiển thị'));
      await t.pumpAndSettle();
      expect(find.text('Đã chọn 2 bài'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('history-delete-selected')));
      await t.pumpAndSettle();
      expect(find.text('Xóa 2 bài chấm?'), findsOneWidget);
      await t.tap(find.text('Xóa 2 bài'));
      await t.pumpAndSettle();
      expect(r.data.papers.length, 5);
      expect(r.data.papers.any((p) => p.candidate == '008888'), false);
      expect(r.data.papers.any((p) => p.candidate.isEmpty), false);
      expect(r.data.papers.any((p) => p.candidate == '000001'), true);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'failed batch delete keeps selected results; toolbar fits small large-text screens',
    (t) async {
      t.view.physicalSize = const Size(320, 568);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final r = await seed(extra: true);
      final path = [r.data.children([]).first, 'E-Delete', '6', 'Toán'];
      final before = r.data.encode();
      await t.pumpWidget(
        MaterialApp(
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(ctx)
                .copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!,
          ),
          home: Scaffold(
            appBar: AppBar(title: const Text('SiroMix')),
            bottomNavigationBar: const SizedBox(height: 60),
            body: HistoryView(repository: r, path: path),
          ),
        ),
      );
      await t.pumpAndSettle();
      final select = find.byKey(const ValueKey('history-select-mode'));
      await t.ensureVisible(select);
      await t.tap(select);
      await t.pumpAndSettle();
      final all = find.text('Chọn tất cả đang hiển thị');
      await t.ensureVisible(all);
      await t.tap(all);
      await t.pumpAndSettle();
      final remove = find.byKey(const ValueKey('history-delete-selected'));
      await t.ensureVisible(remove);
      await t.tap(remove);
      await t.pumpAndSettle();
      (r.storage as MemoryStorage).fail = true;
      await t.tap(find.text('Xóa 3 bài'));
      await t.pumpAndSettle();
      expect(r.data.encode(), before);
      expect(find.text('Đã chọn 3 bài'), findsOneWidget);
      expect(find.textContaining('Không thể xóa kết quả'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'changing history context clears old hidden selections and search',
    (t) async {
      final r = await seed(extra: true);
      final year = r.data.children([]).first;
      Widget screen(List<String> path) => MaterialApp(
        home: Scaffold(
          body: HistoryView(
            key: const ValueKey('history'),
            repository: r,
            path: path,
          ),
        ),
      );
      await t.pumpWidget(screen([year, 'E-Delete', '6', 'Toán']));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('history-select-mode')));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), '008888');
      await t.pumpAndSettle();
      await t.tap(find.text('Chọn tất cả đang hiển thị'));
      await t.pumpAndSettle();
      expect(find.text('Đã chọn 1 bài'), findsOneWidget);
      await t.pumpWidget(screen([year, 'E-Delete', '6', 'Lý']));
      await t.pumpAndSettle();
      expect(t.widget<TextField>(find.byType(TextField)).controller!.text, '');
      expect(
        find.byKey(const ValueKey('history-delete-selected')),
        findsNothing,
      );
      expect(find.text('1 bài đã chấm'), findsOneWidget);
      expect(r.data.papers.length, 7);
    },
  );
}
