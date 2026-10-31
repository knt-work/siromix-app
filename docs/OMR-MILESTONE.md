# Experimental camera and 10-question OMR milestone

Date: 29 October 2026. Target build: **1.1.0+3**, Android.

## Implemented

- Versioned built-in sheet registry. New exam codes default to `abcd-10-a4-tn-tl`, version 1, capacity 10.
- Template selector and preview in the answer-key editor. Limits derive from template capacity. An existing 30-question key retains its old template and all answers/points; the app does not silently truncate it. To switch it to the 10-question type, the teacher must explicitly reduce its configured question count first.
- Real camera preview and capture through Flutter's camera plugin, with audio disabled and the Android camera permission. No microphone permission is needed.
- On-device, non-AI OMR on a background Dart isolate. No image or response is sent to a server.
- Detection of black square markers, template-specific geometry checks, rotation selection, projective rectification, and grayscale bubble measurements relative to the unfilled reference. Printed letters inside answer bubbles are accounted for using the source baseline.
- Six-digit candidate-number and three-digit exam-code reading, preserving leading zeros.
- Answer classification: single/blank/multiple/uncertain. Unknown codes cannot silently select a different key. A teacher can choose the correct configured code explicitly when automatic code reading is missing or ambiguous.
- Actual cropped response images for manual review. Candidate-number/code crops can be expanded for inspection. A missing or unclear candidate number must be entered manually as six digits before final confirmation.
- Weighted scoring against the selected complete key. Final confirmation is disabled while answer review is pending.
- User-confirmed numbering policy: sequential paper numbers are shared across exam codes in a subject within the same academic year/session/grade. The counter persists across app restarts, increments only on confirmed grading, and does not store a grading history or captured images.
- Repository writes are serialized and validated before publication. Failed writes do not consume a paper number or claim success.
- Native-storage JSON upgrades from version 1 to version 2 without resetting existing data. The native preference key remains unchanged.

## Code map

- `lib/templates.dart`: stable template identities, versions, labels, capacities, supported/legacy distinction.
- `lib/data.dart`: key schema, migration, local persistence, counters, serialized writes, weighted grading.
- `lib/omr.dart`: canonical geometry, marker detection, homography, reference-aware classification, digit fields, review crops.
- `lib/scan.dart`: camera lifecycle, capture, review, identity/code correction, score confirmation and paper numbering.
- `lib/ui.dart`: shared light-theme colors and UI helpers.
- `assets/templates/abcd-10-v1.png`: canonical source render used as the unfilled baseline.

The old simulation-only result screens were removed from the app's grading flow. The historical HTML prototype still documents the approved visual design; it does not implement this camera milestone.

## Automated validation

**16 tests pass**; Flutter analysis reports no issues.

Coverage includes:

- Round-trip persistence, failed writes, context isolation, and grading rules.
- Legacy 30-question-key migration without losing answers/points.
- New-template capacity and rejection of unknown template versions.
- Counter persistence, subject isolation, serialized concurrent updates, and recovery after failed writes.
- Blank source sheets not being mistaken for filled letters.
- Synthetic filled answers and six-/three-digit fields, including leading zeros.
- Rotation, faint/multiple marks, missing markers, and an independently generated skewed JPEG fixture.
- Manual-review gating, unknown-code handling, and allocation only after confirmation.
- Small-screen home/editor behavior.

The synthetic fixtures are regression tests, **not measurements of accuracy on photographed physical papers**. The image-processing thresholds remain experimental until calibrated on real phone captures. Severe shadows, low resolution, blur, page curvature, marker clipping, and print variations can require recapture or review.

## Android QA

The first native QA run detected duplicate initialization during the camera permission dialog's inactive/resumed transitions. The lifecycle was changed to serialize initialization/disposal and avoid starting a second controller during an in-flight permission request. Final emulator retesting passed: first-permission initialization, camera preview/capture, and rejection of an unrelated scene. The initialization timeout was removed so the user can take time to read the permission prompt. Full QA details are in DEVELOPMENT.md.

No physical Xiaomi camera has been accessed or tested by the agent. The user must validate the build on their Xiaomi 15T Pro using printed sheets and known answers.

## Phone test procedure

1. Install `dist/SiroMix-build-22-universal.apk` over the previous build; do not uninstall or clear app data.
2. Open the grading tool and create/select a key using **A4 – 10 câu trắc nghiệm và tự luận**. Configure 1–10 questions, their correct answers, and points. Save.
3. Print page 1 of the original PDF. Ensure all four outer black markers are present. Fill the candidate number, exam code, and test answers.
4. Select the key, open the camera, grant permission, and capture the flat, well-lit sheet with all four outer markers visible. Page 2 and the written-response areas are ignored.
5. Compare the recognized candidate number, code, answers, and score against the known paper. Inspect crops and resolve uncertain responses. Confirm only after checking correctness.
6. Repeat with blank, multiple-mark, faint, and erased answers. Report mismatches or repeated recapture failures for calibration.

Keep real-paper test images and expected readings available during calibration. Saving a permanent image gallery, grading history, export, AI, and support for arbitrary templates remain outside this milestone.


## Compact 40-question template (30 October 2026)

Build 18 adds the independent compact frame template, full scan only, no candidate recognition, with active question counts 1–40. Read `docs/templates/abcd-40-compact-v1.md` for current geometry, source-raster limitations and validation. The older ten-question behavior remains available. All 108 automated tests pass and analysis is clean. Synthetic results do not establish real print/camera accuracy.


Build 19 corrects compact alignment and bubble measurement on the first physical-photo fixture. See the real-photo correction section in docs/templates/abcd-40-compact-v1.md. This supersedes the build 18 statement that only synthetic compact fixtures have been tested.


User acceptance, 30 October 2026: the user reported build 19 runs satisfactorily in real-device testing and requested pushing the source checkpoint. Earlier pending-phone-verification notes are historical; this does not imply broad device/photo accuracy certification. See SPEC.md section 32.


Build 21 (31 October 2026) separates compact code-field fill evidence from preprinted numeral blur using both central and side-band samples. The user-labeled 209 source photo and the existing 132 photo are regression fixtures; answer handling and the ten-question reader are unchanged. See SPEC.md section 34.
