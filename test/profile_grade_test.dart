import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siromix/administrative_units.dart';
import 'package:siromix/data.dart';
import 'package:siromix/profile.dart';
import 'package:siromix/grade_dialog.dart';
import 'package:siromix/main.dart';

import 'widget_test.dart' show MemoryStorage;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('offline catalog has unique codes, current names and correct parent mapping', () async {
    final c = AdministrativeCatalog.decode(
      File('assets/data/vn-admin.json').readAsStringSync(),
    );
    expect(c.provinces.length, 34);
    expect(c.provinces.expand((p) => c.wards(p.code)).length, 3321);
    expect(c.province('24')!.name, 'Thành phố Bắc Ninh');
    expect(c.province('22')!.name, 'Thành phố Quảng Ninh');
    expect(c.ward('01', '00004')!.name, 'Phường Ba Đình');
    expect(c.ward('79', '00004'), isNull);
    expect(administrativeSearch('PHƯỜNG Ba Đình'), 'phuong ba dinh');
  });
  test('version 3 migration preserves identity/history/counters/legacy school and adds empty address', () async {
    final disk = MemoryStorage(), r = ExamRepository(MemoryStorage());
    await r.load();
    final year = r.data.children([]).first;
    final path = [year, 'Migration QA', '6', 'Toán'];
    await r.update((d) {
      d.add([year], path[1]);
      d.add(path.take(2).toList(), '6');
      d.add(path.take(3).toList(), 'Toán');
      d.addCode(path, '132');
      final key = d.codes(path)['132']!;
      key.count = 1;
      key.answers[0] = 'A';
      d.confirmPaper(
        path: path,
        candidate: '000001',
        code: '132',
        responses: [const ResponseMark(MarkState.single, 'A')],
      );
    });
    final old = jsonDecode(r.data.encode()) as Map<String, dynamic>;
    old['version'] = 3;
    old['profile']['school'] = 'Trường cũ';
    for (final field in [
      'provinceCode',
      'provinceName',
      'wardCode',
      'wardName',
    ]) {
      old['profile'].remove(field);
    }
    disk.value = jsonEncode(old);
    final migrated = ExamRepository(disk);
    await migrated.load();
    expect(migrated.data.profile.id, r.data.profile.id);
    expect(migrated.data.profile.school, 'Trường cũ');
    expect(migrated.data.profile.provinceCode, '');
    expect(migrated.data.papers.single.id, r.data.papers.single.id);
    expect(
      migrated.data.papers.single.grade.score,
      r.data.papers.single.grade.score,
    );
    expect(migrated.data.counters, r.data.counters);
    expect(jsonDecode(disk.value!)['version'], 5);
    await migrated.update(
      (d) => d.profile = UserProfile(
        id: d.profile.id,
        name: 'Cô An',
        school: d.profile.school,
        provinceCode: '01',
        provinceName: 'Thành phố Hà Nội',
        wardCode: '00004',
        wardName: 'Phường Ba Đình',
        email: 'an@example.com',
      ),
    );
    final restored = BackupFile.decode(BackupFile(migrated.data).encode()).data;
    expect(restored.profile.wardCode, '00004');
    expect(restored.profile.school, 'Trường cũ');
    expect(restored.papers.single.id, r.data.papers.single.id);
    final reopen = ExamRepository(disk);
    await reopen.load();
    expect(reopen.data.profile.provinceCode, '01');
  });
  test('malformed address identifiers are rejected without accepting broken backups', () async {
    final r = ExamRepository(MemoryStorage());
    await r.load();
    final j = r.data.profile.toJson();
    j['wardCode'] = '00004';
    expect(() => UserProfile.fromJson(j), throwsFormatException);
    j['provinceCode'] = 'XX';
    expect(() => UserProfile.fromJson(j), throwsFormatException);
  });
  testWidgets(
    'profile has five fields, searchable cascading address, cancel and clear preserve consistency',
    (t) async {
      t.view.physicalSize = const Size(400, 1300);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final r = ExamRepository(MemoryStorage());
      await r.load();
      await t.runAsync(() => AdministrativeCatalog.load());
      await t.pumpWidget(MaterialApp(home: ProfilePage(repository: r)));
      await t.runAsync(() => Future<void>.delayed(Duration.zero));
      await t.pumpAndSettle();
      expect(find.text('Tên Hiển Thị'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Đơn vị'), findsOneWidget);
      expect(find.textContaining('Không bắt buộc để chấm bài'), findsNothing);
      expect(
        t
            .widget<InkWell>(find.byKey(const ValueKey('profile-Phường/Xã')))
            .onTap,
        isNull,
      );
      expect(
        t.widget<InkWell>(find.byKey(const ValueKey('profile-Tỉnh/TP'))).onTap,
        isNotNull,
      );
      await t.tap(find.byKey(const ValueKey('profile-Tỉnh/TP')));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('location-search')),
        'ha noi',
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Thành phố Hà Nội'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('profile-Phường/Xã')));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('location-search')),
        'ba dinh',
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Phường Ba Đình'));
      await t.pumpAndSettle();
      await t.tap(find.text('Lưu hồ sơ'));
      await t.pumpAndSettle();
      expect(r.data.profile.provinceCode, '01');
      expect(r.data.profile.wardCode, '00004');
      expect(
        t.widget<InkWell>(find.byKey(const ValueKey('profile-Tỉnh/TP'))).onTap,
        isNotNull,
      );
      await t.tap(find.byKey(const ValueKey('profile-Tỉnh/TP')));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Đóng'));
      await t.pumpAndSettle();
      expect(find.text('Phường Ba Đình'), findsOneWidget);
      expect(
        t.widget<InkWell>(find.byKey(const ValueKey('profile-Tỉnh/TP'))).onTap,
        isNotNull,
      );
      await t.tap(find.byKey(const ValueKey('profile-Tỉnh/TP')));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('location-search')),
        'ho chi minh',
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Thành phố Hồ Chí Minh'));
      await t.pumpAndSettle();
      expect(find.text('Phường Ba Đình'), findsNothing);
      await t.tap(find.text('Lưu hồ sơ'));
      await t.pumpAndSettle();
      expect(r.data.profile.provinceCode, '79');
      expect(r.data.profile.wardCode, '');
    },
  );
  testWidgets('grade picker standard/custom/duplicate validation', (t) async {
    String? result;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<String>(
                  context: ctx,
                  builder: (_) =>
                      const GradeDialog(existing: ['6', 'Khối năng khiếu']),
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
    await t.tap(find.text('Tạo'));
    await t.pumpAndSettle();
    expect(find.text('Chọn hoặc nhập khối học.'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('grade-select')));
    await t.pumpAndSettle();
    await t.tap(find.text('Khối 6').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Tạo'));
    await t.pumpAndSettle();
    expect(find.text('Khối này đã có trong kì thi.'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('grade-select')));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('Tùy chỉnh'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await t.tap(find.text('Tùy chỉnh').last);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('grade-custom')), findsOneWidget);
    await t.enterText(
      find.byKey(const ValueKey('grade-custom')),
      'Khối năng khiếu',
    );
    await t.tap(find.text('Tạo'));
    await t.pumpAndSettle();
    expect(find.text('Khối này đã có trong kì thi.'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('grade-custom')), 'Khối dự bị');
    await t.tap(find.text('Tạo'));
    await t.pumpAndSettle();
    expect(result, 'Khối dự bị');
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('grade-select')));
    await t.pumpAndSettle();
    await t.tap(find.text('Khối 1').last);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('grade-custom')), findsNothing);
    await t.tap(find.text('Tạo'));
    await t.pumpAndSettle();
    expect(result, '1');
  });
  testWidgets('grade dialog is used when adding a grade inside an exam', (
    t,
  ) async {
    final r = ExamRepository(MemoryStorage());
    await r.load();
    final year = r.data.children([]).first;
    await r.update((d) => d.add([year], 'Grade QA'));
    await t.pumpWidget(SiroMixApp(repository: r));
    await t.pumpAndSettle();
    await t.tap(find.text('Chấm bài trắc nghiệm'));
    await t.pumpAndSettle();
    await t.tap(find.text('Grade QA'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Thêm khối'));
    await t.tap(find.text('Thêm khối'));
    await t.pumpAndSettle();
    expect(find.byType(GradeDialog), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('grade-select')));
    await t.pumpAndSettle();
    await t.tap(find.text('Khối 2').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Tạo'));
    await t.pumpAndSettle();
    expect(r.data.children([year, 'Grade QA']), ['2']);
    await t.pump(const Duration(seconds: 1));
  });
}
