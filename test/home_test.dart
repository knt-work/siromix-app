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
      expect(sizes.first.height, lessThanOrEqualTo(110));
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
        find.text(
          'Ứng dụng được phát triển bởi Nhựt Triều, mọi thắc mắc xin liên hệ qua Zalo/SĐT: 0358974020.',
        ),
        findsOneWidget,
      );
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
      expect(copiedText, '0358974020');
      expect(t.takeException(), isNull);
    },
  );
}
