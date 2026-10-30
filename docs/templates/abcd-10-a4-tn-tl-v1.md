# Answer-sheet type: A4 - 10 ABCD questions and written responses

Status: source geometry calibrated against the supplied PDF render and implemented in the experimental OMR reader. Synthetic-image regression tests pass. **Accuracy on real phone captures has not been measured yet.**

## Identity and source

- Template ID: `abcd-10-a4-tn-tl`.
- Template version: `1`.
- Proposed Vietnamese selector label: **A4 – 10 câu trắc nghiệm và tự luận**.
- Authoritative PDF: `../references/templates/abcd-10-a4-tn-tl-v1.pdf`.
- Preview of the recognition page: `../references/templates/abcd-10-a4-tn-tl-v1-page-1.png`.
- Original filename supplied by the user: `10 cau_ Phieu A4-TN va TL_ky thi.pdf`.
- Two PDF pages. Page 1 contains recognition regions; page 2 contains ruled written-response lines only.
- PDF metadata reports a landscape media box of 842 x 595 points with page rotation 270 degrees. The intended rendered reading orientation is portrait A4. Normalize rotation before deriving coordinates; do not treat the raw media box as the camera orientation.

## Recognition regions on page 1

| Region | Observed layout | Required behavior |
| --- | --- | --- |
| ABCD responses | One vertical column of 10 rows, four circles A/B/C/D per row | Read configured questions and award their configured points |
| Candidate number | Six digit columns, ten rows labeled 0–9 | Read as a string; retain leading zeros |
| Exam code | Three digit columns, ten rows labeled 0–9 | Read as a string, match the key in the selected exam context |
| Alignment | Large black squares near four outer corners; smaller black square markers around recognition regions | Use template-specific marker geometry for alignment and validation |

The response block is on the left below the information section. The candidate-number and exam-code blocks are near the upper right. Their positions differ from the earlier 30-question reference, so the old coordinates cannot be reused.

The template has letters printed inside the answer circles; a blank reference contains dark ink. Bubble classification must account for this baseline instead of treating any dark pixel as a filled answer.

Ignore school, name, classroom, room, date, invigilator signatures, manually written scores, and the ruled written-response area. Do not implement handwriting recognition or written-response scoring. Page 2 does not need scanning for multiple-choice grading.

## Template management contract

- Register sheet types by stable ID and version, with a user-visible name, thumbnail/reference, capacity, digit fields, and independently calibrated recognition geometry.
- An exam configuration must reference its selected sheet type and version. Preserve the identity with the saved key so future template changes do not silently reinterpret existing keys.
- For this type, allow **1–10 questions**, never 30. Existing 30-question keys must not be truncated or reassigned automatically.
- Keep the old 30-question image as a historical/future reference. This 10-question PDF is now the first priority for real recognition; this does not establish that the old layout is supported.
- The source is a fixed built-in template reference. The user has not requested an arbitrary user-uploaded-template calibration editor.
- Do not claim automatic recognition of every sheet type; select the correct registered template before capture.

## Grading and paper identification

Continue reading the **candidate number**, exam code, and answer marks. The user's restoration of candidate-number recognition supersedes the previous request to omit it.

Keep the sequential paper number as a separate internal/display identifier, alongside the candidate number. The candidate number is not a student-roster lookup and is not a deduplication key. The user confirmed that numbering is continuous within the subject/year/session/grade context, shared across codes and preserved across app restarts.

Response rules remain unchanged: clear correct answer earns the configured points, clear incorrect/blank/multiple answers earn zero, faint or incompletely erased answers require teacher review. Resolve uncertain answers before final score confirmation.

Blank or ambiguous candidate-number columns and incomplete exam-code columns must be surfaced rather than guessed. The implemented workflow requires the teacher to inspect the candidate-number crop and enter all six digits before confirmation; do not silently fill zeros. Read exam codes with leading zeros intact. Free-form codes outside the physical three-digit format require manual key selection as previously specified.

## Calibration and validation still required

1. Normalize the PDF page's rotation and render a canonical reference.
2. Derive marker and bubble geometry from the PDF/reference and record it in normalized coordinates.
3. Validate marker detection and perspective correction on actual camera captures.
4. Establish template-aware empty/fill thresholds and uncertainty rules, accounting for printed A/B/C/D letters and digit outlines.
5. Test clear fills, faint fills, erasures, blanks, multiple answers, and ambiguous digit columns.
6. Compare captured-sheet readings and weighted scores against known answers on the user's Xiaomi 15T Pro.

The source PDF has been visually inspected on both pages. No real-camera recognition accuracy has been measured yet. The original PDF is preserved unchanged; it has not been regenerated, edited, flattened, or rescaled.
