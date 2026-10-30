class SheetTemplate {
  const SheetTemplate(
    this.id,
    this.version,
    this.name,
    this.capacity, {
    required this.readable,
    this.preview,
    this.supportsAnswersOnly = true,
    this.readsCandidate = true,
  });
  final String id, name;
  final int version, capacity;
  final bool readable;
  final String? preview;
  final bool supportsAnswersOnly, readsCandidate;
  static const compact = SheetTemplate(
    'abcd-40-compact',
    1,
    'Phiếu gọn ABCD – 40 câu',
    40,
    readable: true,
    preview: 'assets/templates/abcd-40-compact-v1.png',
    supportsAnswersOnly: false,
    readsCandidate: false,
  );
  static const ten = SheetTemplate(
    'abcd-10-a4-tn-tl',
    1,
    'A4 – 10 câu trắc nghiệm và tự luận',
    10,
    readable: true,
    preview: 'assets/templates/abcd-10-v1.png',
  );
  static const legacy = SheetTemplate(
    'legacy-abcd-30',
    1,
    'Phiếu ABCD – 30 câu (mẫu cũ)',
    30,
    readable: false,
  );
  static SheetTemplate find(String id, int version) {
    if (version == 1 && id == ten.id) return ten;
    if (version == 1 && id == compact.id) return compact;
    if (version == 1 && id == legacy.id) return legacy;
    throw const FormatException('Unsupported sheet template version');
  }
}
