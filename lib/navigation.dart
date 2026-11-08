import 'package:flutter/material.dart';

import 'ui.dart';

const _pageSlideDuration = Duration(milliseconds: 300);

Widget _pageSlide(
  BuildContext context,
  Animation<double> animation,
  double direction,
  Widget child,
) => ColoredBox(
  color: Theme.of(context).scaffoldBackgroundColor,
  child: ClipRect(
    child: SlideTransition(
      position: animation.drive(
        Tween(
          begin: Offset(direction, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeInOut)),
      ),
      child: child,
    ),
  ),
);

class SlidePageRoute<T> extends MaterialPageRoute<T> {
  SlidePageRoute({required super.builder});

  @override
  Duration get transitionDuration => _pageSlideDuration;

  @override
  Duration get reverseTransitionDuration => transitionDuration;

  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) => false;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _pageSlide(context, animation, 1, child);
  }
}

/// Animates navigation between views that share a route and its state.
class InPlacePageSlide extends StatefulWidget {
  const InPlacePageSlide({super.key, required this.page, required this.child});

  /// Increasing values go forward. A null page skips the transition both ways.
  final int? page;
  final Widget child;

  @override
  State<InPlacePageSlide> createState() => _InPlacePageSlideState();
}

class _InPlacePageSlideState extends State<InPlacePageSlide>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: _pageSlideDuration,
    value: 1,
  );
  double _direction = 1;

  @override
  void didUpdateWidget(covariant InPlacePageSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget.page;
    final current = widget.page;
    if (previous == current) return;
    if (previous == null || current == null) {
      _controller.value = 1;
      return;
    }
    _direction = current > previous ? 1 : -1;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _pageSlide(context, _controller, _direction, widget.child);
}

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onHome,
    this.onExams,
    this.onScan,
    this.onResults,
  });
  final int selectedIndex;
  final VoidCallback? onHome, onExams, onScan, onResults;
  @override
  Widget build(BuildContext context) => NavigationBar(
    backgroundColor: Colors.white,
    indicatorColor: soft,
    selectedIndex: selectedIndex,
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    onDestinationSelected: (i) =>
        [onHome, onExams, onScan, onResults][i]?.call(),
    destinations: [
      NavigationDestination(
        enabled: onHome != null,
        icon: const Icon(Icons.home_outlined),
        label: 'Trang chủ',
      ),
      NavigationDestination(
        enabled: onExams != null,
        icon: const Icon(Icons.layers_outlined),
        label: 'Kì thi',
      ),
      NavigationDestination(
        enabled: onScan != null,
        icon: const Icon(Icons.document_scanner_outlined),
        label: 'Quét bài',
      ),
      NavigationDestination(
        enabled: onResults != null,
        icon: const Icon(Icons.fact_check_outlined),
        label: 'Kết quả',
      ),
    ],
  );
}

Future<bool> confirmLeaveDraft(BuildContext context, String message) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dữ liệu chưa được lưu'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tiếp tục kiểm tra'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bỏ và rời đi'),
          ),
        ],
      ),
    ) ??
    false;
