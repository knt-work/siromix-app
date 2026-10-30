import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siromix/camera_controls.dart';
import 'package:siromix/camera_guidance.dart';
import 'package:siromix/data.dart';
import 'package:siromix/main.dart';

import 'widget_test.dart' show MemoryStorage;

void main() {
  testWidgets('scan actions share a row above the thumbnail at 320 pixels', (
    t,
  ) async {
    t.view.physicalSize = const Size(320, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final disk = MemoryStorage(), r = ExamRepository(MemoryStorage());
    await r.load();
    final year = r.data.children([]).first;
    final data = ExamData.empty();
    data.add([year], 'QA');
    data.add([year, 'QA'], '6');
    data.add([year, 'QA', '6'], 'Toán');
    data.addCode([year, 'QA', '6', 'Toán'], '132');
    final k = data.codes([year, 'QA', '6', 'Toán'])['132']!;
    k.count = 1;
    k.answers[0] = 'A';
    disk.value = data.encode();
    await t.pumpWidget(SiroMixApp(repository: ExamRepository(disk)));
    await t.pumpAndSettle();
    for (final text in [
      'Chấm bài trắc nghiệm',
      'QA',
      '6',
      'Toán',
      'Quét bài',
    ]) {
      final f = find.text(text).last;
      await t.ensureVisible(f);
      await t.tap(f);
      await t.pumpAndSettle();
    }
    await t.tap(find.byKey(const ValueKey('choose-full')));
    await t.pumpAndSettle();
    final left = find.byKey(const ValueKey('open-camera')),
        right = find.byKey(const ValueKey('edit-exam'));
    await t.ensureVisible(left);
    await t.pumpAndSettle();
    expect(t.getCenter(left).dy, closeTo(t.getCenter(right).dy, .1));
    expect(t.getCenter(left).dx, lessThan(t.getCenter(right).dx));
    expect(t.getSize(left).width, closeTo(t.getSize(right).width, .1));
    expect(
      t.getBottomLeft(left).dy,
      lessThan(t.getTopLeft(find.byType(Image)).dy),
    );
    expect(find.text('Sửa đề'), findsOneWidget);
    expect(t.getTopLeft(left).dy, lessThan(800));
  });
  testWidgets('tap captures in green and red; torch never triggers capture', (
    t,
  ) async {
    var torch = 0, captures = 0;
    Widget screen(GuideVerdict verdict) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            height: 400,
            child: CaptureOverlay(
              key: const ValueKey('overlay'),
              preview: const ColoredBox(color: Colors.grey),
              imageAspect: 9 / 16,
              verdict: verdict,
              processing: false,
              torchOn: false,
              ready: true,
              onTorch: () => torch++,
              onCapture: () => captures++,
            ),
          ),
        ),
      ),
    );
    await t.pumpWidget(screen(GuideVerdict.valid));
    await t.pumpAndSettle();
    expect(find.text('Đã vào khung'), findsOneWidget);
    expect(find.byKey(const ValueKey('capture-overlay')), findsNothing);
    expect(find.text('Chạm màn hình để chụp'), findsOneWidget);
    await t.pump(const Duration(seconds: 4));
    expect(captures, 0);
    await t.tapAt(t.getCenter(find.byKey(const ValueKey('capture-surface'))));
    expect(captures, 1);
    await t.tap(find.byKey(const ValueKey('camera-torch')));
    expect(torch, 1);
    expect(captures, 1);
    await t.pumpWidget(screen(GuideVerdict.invalid));
    await t.pumpAndSettle();
    expect(find.text('Chưa vào khung'), findsOneWidget);
    await t.tapAt(t.getCenter(find.byKey(const ValueKey('capture-surface'))));
    expect(captures, 2);
    expect(find.byKey(const ValueKey('capture-overlay')), findsNothing);
  });
  testWidgets('processing blocks both capture and torch controls', (t) async {
    var torch = 0, captures = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 400,
            child: CaptureOverlay(
              preview: const ColoredBox(color: Colors.grey),
              imageAspect: 9 / 16,
              verdict: GuideVerdict.valid,
              processing: true,
              torchOn: false,
              ready: true,
              onTorch: () => torch++,
              onCapture: () => captures++,
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('capture-overlay')), findsNothing);
    expect(
      t
          .widget<IconButton>(find.byKey(const ValueKey('camera-torch')))
          .onPressed,
      isNull,
    );
    await t.tapAt(t.getCenter(find.byKey(const ValueKey('capture-surface'))));
    expect(captures, 0);
    expect(torch, 0);
  });
  for (final size in [
    const Size(320, 568),
    const Size(412, 915),
    const Size(740, 360),
  ]) {
    for (final partial in [false, true]) {
      testWidgets(
        'camera fits $size, partial=$partial, large text without scroll',
        (t) async {
          t.view.physicalSize = size;
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          var captures = 0, help = 0;
          await t.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.4)),
                child: child!,
              ),
              home: Scaffold(
                appBar: AppBar(title: const Text('SiroMix')),
                bottomNavigationBar: const SizedBox(height: 80),
                body: CameraScreenLayout(
                  title: partial
                      ? 'Bước 1/3 · Số báo danh'
                      : 'Đưa phiếu vào khung',
                  modeLabel: partial ? 'Chỉ quét đáp án' : 'Quét toàn phiếu',
                  onMode: () {},
                  onHelp: () => help++,
                  steps: partial
                      ? [
                          for (final label in [
                            '1. SBD',
                            '2. Mã đề',
                            '3. Đáp án',
                          ])
                            Expanded(child: Text(label, maxLines: 1)),
                        ]
                      : const [],
                  message: size.width > size.height
                      ? null
                      : 'Không đọc được vùng này. Chạm để chụp lại.',
                  onReview: partial ? () {} : null,
                  preview: CaptureOverlay(
                    preview: const ColoredBox(color: Colors.grey),
                    imageAspect: .75,
                    verdict: GuideVerdict.invalid,
                    processing: false,
                    torchOn: false,
                    ready: true,
                    onTorch: () {},
                    onCapture: () => captures++,
                  ),
                ),
              ),
            ),
          );
          expect(t.takeException(), isNull);
          expect(find.byType(Scrollable), findsNothing);
          final surface = find.byKey(const ValueKey('capture-surface'));
          expect(t.getSize(surface).height, greaterThan(70));
          expect(
            t.getBottomLeft(surface).dy,
            lessThanOrEqualTo(size.height - 80),
          );
          await t.tapAt(t.getCenter(surface));
          expect(captures, 1);
          await t.tap(find.byTooltip('Xem hướng dẫn'));
          expect(help, 1);
          expect(captures, 1);
        },
      );
    }
  }
}
