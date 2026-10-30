import 'package:flutter/material.dart';

import 'camera_guidance.dart';

class ScanActionBar extends StatelessWidget {
  const ScanActionBar({
    super.key,
    required this.onCamera,
    required this.onEdit,
  });
  final VoidCallback? onCamera, onEdit;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: FilledButton.icon(
              key: const ValueKey('open-camera'),
              onPressed: onCamera,
              icon: const Icon(Icons.camera_alt_outlined, size: 19),
              label: const Text('Mở camera', textAlign: TextAlign.center),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              key: const ValueKey('edit-exam'),
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 19),
              label: const Text('Sửa đề', textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    ),
  );
}

class CaptureOverlay extends StatelessWidget {
  const CaptureOverlay({
    super.key,
    required this.preview,
    required this.imageAspect,
    required this.verdict,
    required this.processing,
    required this.torchOn,
    required this.onTorch,
    required this.ready,
    this.onCapture,
    this.guideAspect = 1067 / 1549,
    this.markerHints = const [],
  });
  final Widget preview;
  final double imageAspect, guideAspect;
  final List<Offset> markerHints;
  final GuideVerdict verdict;
  final bool processing, torchOn, ready;
  final VoidCallback? onTorch, onCapture;
  @override
  Widget build(BuildContext context) {
    final color = switch (verdict) {
      GuideVerdict.valid => const Color(0xff52dc9b),
      GuideVerdict.invalid => const Color(0xffff8f8f),
      _ => Colors.white,
    };
    final label = !ready && !processing
        ? 'Đang mở camera'
        : switch (verdict) {
            GuideVerdict.valid => 'Đã vào khung',
            GuideVerdict.invalid => 'Chưa vào khung',
            GuideVerdict.unavailable => 'Không kiểm tra được khung',
            GuideVerdict.searching => 'Đang tìm phiếu',
          };
    return Stack(
      fit: StackFit.expand,
      children: [
        Semantics(
          label: 'Chạm màn hình để chụp',
          button: true,
          enabled: ready && !processing && onCapture != null,
          child: GestureDetector(
            key: const ValueKey('capture-surface'),
            behavior: HitTestBehavior.opaque,
            onTap: ready && !processing ? onCapture : null,
            child: preview,
          ),
        ),
        IgnorePointer(
          child: CustomPaint(
            painter: _GuidePainter(
              imageAspect,
              color,
              guideAspect,
              markerHints,
            ),
          ),
        ),
        Positioned(
          left: 12,
          top: 12,
          right: 70,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .58),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    switch (verdict) {
                      GuideVerdict.valid => Icons.check_circle,
                      GuideVerdict.invalid => Icons.cancel,
                      _ => Icons.hourglass_top,
                    },
                    color: color,
                    size: 20,
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      label,
                      key: const ValueKey('guide-status'),
                      style: TextStyle(color: color, fontSize: 12),
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: 12,
          top: 12,
          child: Material(
            color: Colors.black.withValues(alpha: .55),
            shape: const CircleBorder(),
            child: IconButton(
              key: const ValueKey('camera-torch'),
              tooltip: torchOn ? 'Tắt đèn camera' : 'Bật đèn camera',
              onPressed: processing ? null : onTorch,
              color: Colors.white,
              disabledColor: Colors.white38,
              icon: Icon(torchOn ? Icons.flash_on : Icons.flash_off),
            ),
          ),
        ),
        if (!processing)
          Positioned(
            left: 12,
            right: 12,
            bottom: 16,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .58),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Chạm màn hình để chụp',
                  key: const ValueKey('tap-capture-hint'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
        if (processing)
          const ColoredBox(
            color: Color(0x99000000),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Đang đọc phiếu…',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _GuidePainter extends CustomPainter {
  const _GuidePainter(
    this.imageAspect,
    this.color,
    this.guideAspect,
    this.markerHints,
  );
  final double imageAspect, guideAspect;
  final Color color;
  final List<Offset> markerHints;
  @override
  void paint(Canvas canvas, Size size) {
    final r = CameraGuideLayout(
      size,
      imageAspect,
      markerAspect: guideAspect,
    ).target;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    for (final p in markerHints) {
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(r.left + p.dx * r.width, r.top + p.dy * r.height),
          width: 13,
          height: 13,
        ),
        paint,
      );
    }
    for (final c in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
      final sx = c.dx == r.left ? 1 : -1, sy = c.dy == r.top ? 1 : -1;
      canvas.drawLine(c, Offset(c.dx + sx * 22, c.dy), paint);
      canvas.drawLine(c, Offset(c.dx, c.dy + sy * 22), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GuidePainter old) =>
      old.imageAspect != imageAspect ||
      old.color != color ||
      old.guideAspect != guideAspect ||
      old.markerHints != markerHints;
}

/// The preview receives the remaining bounded height in BOTH scan modes.
/// Long help content lives in a separate sheet instead of scrolling the camera.
class CameraScreenLayout extends StatelessWidget {
  const CameraScreenLayout({
    super.key,
    required this.title,
    required this.modeLabel,
    required this.preview,
    this.steps = const [],
    this.message,
    this.onMode,
    this.onHelp,
    this.onRetry,
    this.onReview,
  });
  final String title, modeLabel;
  final String? message;
  final Widget preview;
  final List<Widget> steps;
  final VoidCallback? onMode, onHelp, onRetry, onReview;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 300;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (compact)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onMode,
                      tooltip: 'Đổi chế độ',
                      icon: const Icon(Icons.swap_horiz),
                    ),
                    IconButton(
                      onPressed: onHelp,
                      tooltip: 'Xem hướng dẫn',
                      icon: const Icon(Icons.help_outline),
                    ),
                  ],
                ),
              if (!compact)
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (!compact)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        modeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: onMode,
                      child: const Text('Đổi chế độ'),
                    ),
                    IconButton(
                      onPressed: onHelp,
                      tooltip: 'Xem hướng dẫn',
                      icon: const Icon(Icons.help_outline),
                    ),
                  ],
                ),
              if (steps.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: steps),
                ),
              Expanded(child: preview),
              if (message != null || (compact && onReview != null))
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          message ?? '',
                          maxLines: compact ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xffa12838),
                          ),
                        ),
                      ),
                    ),
                    if (compact && onReview != null)
                      IconButton(
                        onPressed: onReview,
                        tooltip: 'Kiểm tra bài chấm',
                        icon: const Icon(Icons.fact_check_outlined),
                      ),
                    if (onRetry != null)
                      IconButton(
                        onPressed: onRetry,
                        tooltip: 'Thử lại',
                        icon: const Icon(Icons.refresh),
                      ),
                  ],
                ),
              if (!compact && onReview != null)
                TextButton.icon(
                  onPressed: onReview,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Kiểm tra bài chấm'),
                ),
            ],
          );
        },
      ),
    ),
  );
}
