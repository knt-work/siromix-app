import 'package:flutter/material.dart';

import 'ui.dart';

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
