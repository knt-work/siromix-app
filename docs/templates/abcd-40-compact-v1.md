# Compact ABCD 40-question template, version 1

Source: `docs/references/templates/abcd-40-compact-v1.pdf` (the supplied GIAY THI TN + TL.pdf).
Registry ID: `abcd-40-compact`; name: Phiếu gọn ABCD – 40 câu.

The source is a two-page A4 document. Only the bounded OMR frame on page 1 is recognized. Capture the entire frame, including all four corner markers, the three-digit exam-code field and all 40 responses; the rest of the A4 page is unnecessary. Page 2 and essay lines are not graded. The frame has two additional large edge markers and six small internal markers. The asymmetric marker layout determines orientation. Do not confuse handwritten anonymous paper ID (MÃ PHÁCH) with the machine-readable exam-code field (MÃ ĐỀ).

The source contains a relatively low-resolution embedded raster. The bundled baseline is a 4x PDF render cropped to the frame, preserving the source rather than redrawing or claiming improved print resolution. Marker-center frame coordinates are 1082x1597. Actual rows are irregular; their measured coordinates are stored in CompactSheetGeometry. Four response groups map to questions 1–10, 11–20, 21–30 and 31–40.

Full scan only. The answer-only option is visibly disabled and camera state also forces full mode. Candidate number is not recognized or requested; persist an empty candidate and show Không xác định. Continue the existing per-subject paper-number sequence. Read the three-digit code, preserving zeros; unresolved or unmatched codes require explicit teacher selection from complete keys belonging to this template. Never silently fall back to the preselected code.

Each exam key has 1–40 active questions. Only questions 1 through count contribute to scores, review requirements, history responses and totals. For an eight-question key, answers 9–40 are ignored even when filled, multiple or uncertain. Active blanks/multiple choices score zero; uncertain marks require review. Dark bubble areas are returned as uncertain so darkness in an inactive row does not block confirmation.

The original ten-question template and its full/answer-only scanning remain separate and retain their existing identity policy. Thirty-slot stored keys remain valid; compact keys allocate 40 slots. The editor expands storage when changing template without truncating existing values; imported keys validate matching slot lengths and enough slots for the configured count. Existing saved-paper snapshots remain independent of template edits.

Validation uses blank/marked raster fixtures, rotation, faint/multiple responses, an independently transformed perspective JPEG, live-probe sampling, missing-marker and wrong-template rejection, editor switching, persistence and result UI. The perspective JPEG is synthetic, not a physical camera photograph. Real print/camera accuracy remains unverified, especially source blur, severe skew and shadows.


## Real-photo correction (30 October 2026, build 19)

The first supplied physical photo (`test/fixtures/compact-132-real.png`, code 132, eight active responses BCABDBAC) failed the original rigid local-marker checks. Four-corner rectification predicted some local marker positions 10–18 source pixels away from their measured centers because the paper is slightly curved. The reader now matches all twelve square centers within a bounded 32-unit canonical search radius, including marker-size constraints and unique matches. It corrects residual deformation with a fixed triangular mesh after projective rectification. The blank baseline uses the same process. Missing markers and the wrong template remain rejected.

Compact circles need a different measurement kernel from the ten-question template: core radius 11, paper annulus radii 20–23 in canonical coordinates. The previous annulus crossed the larger printed outlines and could incorrectly report darkness. Code columns additionally subtract a bounded common print-noise floor (third-smallest of ten baseline differences, capped at 0.04); existing single/multiple/uncertain thresholds are unchanged. Ambiguous digit marks still require manual review. Compact marker detection retains a larger candidate pool and tolerates antialiased square edges for low-resolution live analysis. Defaults for the ten-question reader remain unchanged.

The real-photo regression verifies code 132 and all eight responses, plus a rotated/JPEG derivative and an 800-pixel live-probe derivative. These are one physical source photograph and derived variants, not independent photos or a broad accuracy study. Unused rows can still be marked uncertain by the reader and are ignored by the eight-question grading scope. The user subsequently confirmed build 19 works satisfactorily in real-device testing. This acceptance covers their tested workflow; additional physical photos and devices are still needed to measure general recognition accuracy.
