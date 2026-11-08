# Scanning and recognition

- NTL (Phiếu chuẩn Trắc Nghiệm - Tự Luận - NTL) is the default. It reads up to 40 ABCD responses and a three-digit code. Candidate number is unknown. [NTL geometry](../templates/abcd-40-compact-v1.md)
- QM2025 A4 reads Parts I–III from a single full sheet. The selected key controls whether the six-digit candidate number is required. Preserve leading zeros. If enabled and uncertain, require manual verification. [QM geometry](../templates/qm2025-a4-v1.md)
- Both modes use tap capture, torch and a bounded, non-scrolling camera viewport. Live framing is advisory. A red frame permits capture. The still reader independently validates the photo. After confirming a paper, the next-paper action returns to the same camera context.
- NTL tries the regular marker reader, then damaged-marker recovery. Build 30 adds automatic border recovery on the same still photo when both fail. Use evidence from the outer strokes, internal markers and printed answer rings before reading bubbles. If alignment remains unreliable, request recapture. There is no four-tap or manual-corner flow.
- Retired templates remain decodable in saved keys and results. Only NTL and QM2025 are selectable for scanning.
- Release checks should include a normal sheet and a damaged NTL sheet on a phone when changing camera or recognition behavior. Private fixtures stay local. Existing regression coverage includes an NTL photo derived from a real damaged sheet with four corner markers removed.
