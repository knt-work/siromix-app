class SheetTemplate {
  const SheetTemplate(
    this.id,
    this.version,
    this.name,
    this.capacity, {
    required this.readable,
    this.preview,
    this.readsCandidate = true,
  });
  final String id, name;
  final int version, capacity;
  final bool readable;
  final String? preview;
  final bool readsCandidate;
  static const qm2025 = SheetTemplate(
    'qm2025-a4-40-8-6',
    1,
    'QM2025 A4',
    40,
    readable: true,
    preview: 'assets/templates/qm2025-a4-v1.png',
    readsCandidate: true,
  );
  static const compact = SheetTemplate(
    'abcd-40-compact',
    1,
    'Phiếu chuẩn Trắc Nghiệm - Tự Luận - NTL',
    40,
    readable: true,
    preview: 'assets/templates/abcd-40-compact-v1.png',
    readsCandidate: false,
  );
  // Decode-only identity for old keys/history/backups; not selectable or readable.
  static const retiredTen = SheetTemplate(
    'abcd-10-a4-tn-tl',
    1,
    'Phiếu 10 câu (đã ngừng hỗ trợ)',
    10,
    readable: false,
  );
  static const supported = [compact, qm2025];
  static const legacy = SheetTemplate(
    'legacy-abcd-30',
    1,
    'Phiếu ABCD – 30 câu (mẫu cũ)',
    30,
    readable: false,
  );
  static SheetTemplate find(String id, int version) {
    if (version == 1 && id == qm2025.id) return qm2025;
    if (version == 1 && id == retiredTen.id) return retiredTen;
    if (version == 1 && id == compact.id) return compact;
    if (version == 1 && id == legacy.id) return legacy;
    throw const FormatException('Unsupported sheet template version');
  }
}
