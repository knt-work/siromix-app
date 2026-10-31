import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siromix/home.dart';

void main() {
  String? copiedText;
  setUp(() {
    copiedText = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('siromix/storage'),
          (call) async => call.method == 'appInfo'
              ? {'version': '1.4.0', 'build': '8'}
              : null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('siromix/storage'), null);
  });
  test('greeting uses local morning/afternoon/evening boundaries and trims display name', () {
    for (final entry in {
      0: 'tối',
      4: 'tối',
      5: 'sáng',
      11: 'sáng',
      12: 'chiều',
      17: 'chiều',
      18: 'tối',
      23: 'tối',
    }.entries) {
      expect(
        homeGreeting(DateTime(2026, 10, 30, entry.key), ' Cô An '),
        'Chào buổi ${entry.value}, Cô An!',
      );
    }
    expect(homeGreeting(DateTime(2026, 10, 30, 8), ''), 'Chào buổi sáng!');
  });
  testWidgets('home greeting updates across the day and profile-name changes', (
    t,
  ) async {
    var clock = DateTime(2026, 10, 30, 11, 59);
    Widget screen(String name) => MaterialApp(
      home: HomeLauncher(
        displayName: name,
        now: () => clock,
        onGrading: () {},
        onHistory: () {},
        onProfile: () {},
      ),
    );
    await t.pumpWidget(screen('Cô An'));
    await t.pumpAndSettle();
    expect(find.text('Chào buổi sáng, Cô An!'), findsOneWidget);
    clock = DateTime(2026, 10, 30, 12);
    await t.pump(const Duration(minutes: 1));
    await t.pumpAndSettle();
    expect(find.text('Chào buổi chiều, Cô An!'), findsOneWidget);
    clock = DateTime(2026, 10, 30, 18);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpAndSettle();
    expect(find.text('Chào buổi tối, Cô An!'), findsOneWidget);
    await t.pumpWidget(screen('Thầy Bình'));
    await t.pumpAndSettle();
    expect(find.text('Chào buổi tối, Thầy Bình!'), findsOneWidget);
  });
  testWidgets(
    'five equal compact tiles preserve order, disabled shuffle and actual version',
    (t) async {
      t.view.physicalSize = const Size(360, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      var grading = 0, history = 0, profile = 0;
      await t.pumpWidget(
        MaterialApp(
          home: HomeLauncher(
            onGrading: () => grading++,
            onHistory: () => history++,
            onProfile: () => profile++,
          ),
        ),
      );
      await t.pumpAndSettle();
      const ids = ['grading', 'shuffle', 'results', 'profile', 'about'];
      final sizes = ids
          .map((id) => t.getSize(find.byKey(ValueKey('home-$id'))))
          .toList();
      expect(sizes, everyElement(sizes.first));
      // Allow the wider test font to wrap labels to three lines.
      expect(sizes.first.height, lessThanOrEqualTo(100));
      expect(sizes.first.width, lessThanOrEqualTo(130));
      final colors = <Color?>[];
      for (final card in t.widgetList<HomeFunction>(
        find.byType(HomeFunction),
      )) {
        final material = find.descendant(
          of: find.byWidget(card),
          matching: find.byType(Material),
        );
        colors.add(t.widget<Material>(material).color);
      }
      expect(colors.toSet().length, 5);
      final positions = ids
          .map((id) => t.getTopLeft(find.byKey(ValueKey('home-$id'))))
          .toList();
      expect(positions[0].dy, positions[1].dy);
      expect(positions[0].dx, lessThan(positions[1].dx));
      expect(positions[2].dy, greaterThan(positions[0].dy));
      expect(positions[2].dy, positions[3].dy);
      expect(positions[4].dy, greaterThan(positions[3].dy));
      expect(
        t.widget<InkWell>(find.byKey(const ValueKey('home-shuffle'))).onTap,
        isNull,
      );
      expect(find.text('Sắp có'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('home-grading')));
      await t.tap(find.byKey(const ValueKey('home-results')));
      await t.tap(find.byKey(const ValueKey('home-profile')));
      expect([grading, history, profile], [1, 1, 1]);
      expect(find.text('Phiên bản 1.4.0'), findsOneWidget);
      expect(find.text(copyright), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'small-screen large-text layout scrolls and opens correct author/contact',
    (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        MaterialApp(
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(ctx)
                .copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: HomeLauncher(
            onGrading: () {},
            onHistory: () {},
            onProfile: () {},
          ),
        ),
      );
      await t.pumpAndSettle();
      final about = find.byKey(const ValueKey('home-about'));
      await t.ensureVisible(about);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.tap(about);
      await t.pumpAndSettle();
      expect(find.text('Giới thiệu về ứng dụng'), findsOneWidget);
      expect(
        find.text('Thêm thời gian cho việc dạy, bớt thời gian cho việc chấm.'),
        findsOneWidget,
      );
      final author = find.text('Được phát triển bởi Nhựt Triều');
      await t.scrollUntilVisible(
        author,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(author, findsOneWidget);
      final copy = find.text('Sao chép số liên hệ');
      await t.scrollUntilVisible(
        copy,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await t.ensureVisible(copy);
      await t.pumpAndSettle();
      await t.tap(copy);
      await t.pumpAndSettle();
      expect(find.text('Liên hệ qua Zalo/SĐT: 0358974020'), findsOneWidget);
      expect(copiedText, '0358974020');
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Home search handles accents, word filters, empty state and stable actions',
    (t) async {
      t.view.physicalSize = const Size(360, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      var grading = 0, history = 0, profile = 0;
      await t.pumpWidget(
        MaterialApp(
          home: HomeLauncher(
            onGrading: () => grading++,
            onHistory: () => history++,
            onProfile: () => profile++,
          ),
        ),
      );
      await t.pumpAndSettle();
      final search = find.byKey(const ValueKey('home-search'));
      final original = t.getSize(find.byKey(const ValueKey('home-grading')));
      List<String> visible() => t
          .widgetList<HomeFunction>(find.byType(HomeFunction))
          .map((v) => v.id)
          .toList();
      Future<void> query(String text) async {
        await t.enterText(search, text);
        await t.pumpAndSettle();
      }

      await query('BÀI');
      expect(visible(), ['grading', 'results']);
      expect(t.getSize(find.byKey(const ValueKey('home-results'))), original);
      await t.tap(find.byKey(const ValueKey('home-results')));
      await t.pumpAndSettle();
      expect(history, 1);
      expect(grading, 0);
      await query('  cham   nghiem  ');
      expect(visible(), ['grading']);
      await t.tap(find.byKey(const ValueKey('home-grading')));
      await t.pumpAndSettle();
      expect(grading, 1);
      await query('tRoN dE');
      expect(visible(), ['shuffle']);
      expect(
        t.widget<InkWell>(find.byKey(const ValueKey('home-shuffle'))).onTap,
        isNull,
      );
      await t.tap(find.byKey(const ValueKey('home-shuffle')));
      await t.pumpAndSettle();
      expect([grading, history, profile], [1, 1, 0]);
      await query('HO SO DU LIEU');
      expect(visible(), ['profile']);
      await t.tap(find.byKey(const ValueKey('home-profile')));
      await t.pumpAndSettle();
      expect(profile, 1);
      await query('gio\u031b\u0301i thie\u0302\u0323u');
      expect(visible(), ['about']);
      await query('zzzz');
      expect(visible(), isEmpty);
      expect(find.text('Không tìm thấy chức năng phù hợp'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('home-search-clear')));
      await t.pumpAndSettle();
      expect(visible(), ['grading', 'shuffle', 'results', 'profile', 'about']);
      expect(t.widget<TextField>(search).controller!.text, isEmpty);
      expect(t.getSize(find.byKey(const ValueKey('home-grading'))), original);
      await query('   ');
      expect(visible().length, 5);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Home search remains usable with keyboard and large text at 320px',
    (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      t.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetViewInsets);
      await t.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: HomeLauncher(
            onGrading: () {},
            onHistory: () {},
            onProfile: () {},
          ),
        ),
      );
      await t.pumpAndSettle();
      final search = find.byKey(const ValueKey('home-search'));
      await t.ensureVisible(search);
      await t.enterText(search, 'tron de');
      await t.pumpAndSettle();
      final tile = find.byKey(const ValueKey('home-shuffle'));
      await t.ensureVisible(tile);
      await t.pumpAndSettle();
      expect(find.text('Sắp có'), findsOneWidget);
      expect(t.widget<InkWell>(tile).onTap, isNull);
      expect(t.takeException(), isNull);
      await t.ensureVisible(search);
      await t.tap(find.byKey(const ValueKey('home-search-clear')));
      await t.pumpAndSettle();
      expect(t.widgetList<HomeFunction>(find.byType(HomeFunction)).length, 5);
      expect(t.takeException(), isNull);
    },
  );
}
