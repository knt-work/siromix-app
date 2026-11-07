import 'package:flutter/material.dart';

import 'templates.dart';
import 'ui.dart';

enum ScanMode { full }

extension ScanModeInfo on ScanMode {
  String get label => 'Quét toàn phiếu';
}

Future<ScanMode?> chooseScanMode(
  BuildContext context, {
  SheetTemplate template = SheetTemplate.compact,
}) => showModalBottomSheet<ScanMode>(
  context: context,
  isScrollControlled: true,
  builder: (ctx) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading('Chọn cách quét'),
          for (final mode in ScanMode.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton(
                key: ValueKey('choose-${mode.name}'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(18),
                ),
                onPressed: () => Navigator.pop(ctx, mode),
                child: Row(
                  children: [
                    const Icon(Icons.document_scanner_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mode.label,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            template == SheetTemplate.compact
                                ? 'Chụp trọn khung trắc nghiệm và mã đề. Không cần chụp cả tờ A4.'
                                : 'Chụp một lần, lấy đủ bốn góc phiếu.',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  ),
);
