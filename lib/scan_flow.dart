import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'omr.dart';
import 'ui.dart';

enum ScanMode { full, answers }

extension ScanModeInfo on ScanMode {
  String get label =>
      this == ScanMode.full ? 'Quét toàn phiếu' : 'Chỉ quét đáp án';
}

Future<ScanMode?> chooseScanMode(BuildContext context) =>
    showModalBottomSheet<ScanMode>(
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
                        Icon(
                          mode == ScanMode.full
                              ? Icons.document_scanner_outlined
                              : Icons.crop_free,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mode.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                mode == ScanMode.full
                                    ? 'Chụp một lần, lấy đủ bốn góc phiếu.'
                                    : 'Chụp vùng đáp án, dùng mã đề đã chọn. Không đọc số báo danh.',
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

// The selected code belongs to the scan context, not the photographed field.
// Never fabricate digits or candidate numbers for this mode.
OmrRead answersOnlyRead(PartRead read) {
  if (read.part != SheetPart.answers ||
      read.answers.length != 10 ||
      read.answerCrops.length != 10) {
    throw StateError('A complete answer-region reading is required');
  }
  return OmrRead(
    answers: read.answers,
    candidate: const [],
    code: const [],
    aligned: read.crop,
    answerCrops: read.answerCrops,
    candidateCrop: Uint8List(0),
    codeCrop: Uint8List(0),
  );
}
