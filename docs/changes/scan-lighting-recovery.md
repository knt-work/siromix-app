# Offline lighting recovery for still scans

## Goal

Recover alignment when uneven lighting or low local contrast hides printed markers on NTL or QM2025 A4. See [Scanning and recognition](../specs/scanning.md).

## Plan and scope

1. Add a synthetic uneven-lighting regression for each template using known marks and establish the failure on the current readers.
2. Estimate the paper background on a coarse grid of bright local samples. Interpolate those estimates and apply a bounded contrast stretch to a temporary grayscale copy.
3. Try the existing alignment paths first, including NTL marker and border recovery. If they fail, retry the standard marker checks once on the corrected copy. A valid alignment must still pass the template's standard geometry checks. Warp and read the original grayscale photo using that alignment.
4. Run Flutter analysis and regression tests. Check a normal sheet and a damaged NTL sheet on an Android phone when connected.

## Acceptance criteria

- A previously rejected uneven-lighting fixture for each template aligns and reads its known marks and exam code. An ambiguous mark in the fixtures still requires review.
- A wrong template and an NTL-like border without the printed layout still fail validation. Normal scans and NTL's existing damaged-marker and border recovery continue to pass.
- The retry runs on the device after still capture. The corrected copy is used only for alignment. Mark classification and review crops use the original grayscale pixels, and the live preview and data format remain unchanged. No API or new package is required.

## Verification

- Before the change, both new synthetic tests failed during alignment. After the change, NTL reads code `008` and the 39 clear responses while leaving the faint response for teacher review. QM2025 reads code `209` and all 54 expected responses.
- Flutter analysis reported no issues. All 136 tests passed, including the existing local physical photos, wrong-template rejection and NTL border recovery.
- The local Android test APK was built as build 36. The packaging script verified the ARM64, ARMv7 and x86-64 Flutter engines.
- Android camera verification is pending. ADB reported no connected phone.

## ABCD review rule follow-up

Use the shared OMR classifier for ABCD rows on NTL and QM2025 Part I. Accept a single clear mark when it leads any faint competitor by at least 0.20. Send rows with closely competing marks or multiple clear marks to teacher review. Digit fields and other QM2025 parts retain their current rules. Verify the original NTL report and regressions for both ABCD readers before building the next phone APK.

Flutter analysis reported no issues. All 138 cases passed, including a temporary test of the reported NTL photo. That photo now reads C for question 6 and D for question 8, with the exam code still unresolved. Build 37 was packaged for phone testing. ADB reported no connected device.

## NTL verification follow-up

- Use the fitted block offset once and the sample offset once in the recovered-answer fill check.
- Recover the reported code 485 through a field-level low-contrast check. A candidate must lead independently in its core and wider side bands, with no competing mark supported by both the core and original side bands. Require candidates in all three columns and a core score of at least 0.22 in two of them.
- Show the reason and available ABCD scores for pending NTL answers on the scan review screen. Keep diagnostic details in memory for the scan session.
- Verify the reported physical photo, the synthetic low-contrast field, damaged NTL photos, faint digits, paired marks and printed-digit artifacts.

Flutter analysis reported no issues. All 139 cases passed, including a temporary local test of the reported photo that returned code 485, answer B for question 7 and answer D for question 8. Build 38 was packaged for Android. A new phone capture of this sheet remains to be verified.

## Isolated light ABCD marks

For NTL answers, reuse the recovered-answer fill check for a single light candidate scoring at least 0.20. Accept it when the lead is at least 0.14, each other answer scores at most 0.065, and each of four interior samples scores at least 0.16. The reported row scored 0.001, 0.012, 0.063 and 0.207, which qualifies for the fill check. The screenshot does not provide the original pixel samples. Verify that a distributed light mark is accepted and that a dark speck, a weaker mark, and competing marks still require review.

All 139 regression tests passed and Flutter analysis reported no issues. Build 39 was packaged for Android. The reported row still needs a new phone capture to verify the fill check.

## Retry a single unresolved NTL code column

Preserve both clear digits. Reuse the existing independent center and wider-band lead checks in the unresolved column, with a minimum core score of 0.22 and an original side-band score of at least 0.12. A clear competitor, weak evidence, or closely competing marks still require teacher verification. When only one digit remains unknown, show matching complete NTL keys first and require explicit selection. Verify first- and middle-column retry, conflicting marks, and explicit selection of a unique matching key.

All 141 regression tests passed and Flutter analysis reported no issues. Build 40 was packaged for Android. The new retry was verified on synthetic first- and middle-column cases and awaits verification on fresh phone captures.

## Clearly filled digit with weak print artifacts

The reported 132 code crop reproduced `?32` after rescaling the screenshot to the original crop dimensions. The first column's filled digit scored about 0.663, but several visibly empty bubbles exceeded the 0.065 possible-mark threshold. Accept a filled digit at 0.50 or higher in both channels when every other bubble has a core score below 0.12. Retain review for competing fills and for a genuine faint second digit. The screenshot-derived crop returned 132 with the new rule. A synthetic regression reproduces `?32` when the rule is disabled.

All 142 tests passed and Flutter analysis reported no issues. Build 41 was packaged for Android. A fresh camera scan of the reported sheet remains to be verified.

## Shared recognition thresholds

Continue on the existing scan branch because this extends the same threshold changes to both supported sheets. Route both ABCD readers through the shared clear and isolated light mark rules, using each template's own interior sample positions. Route both exam-code readers through the shared digit classifier, with additional side-band evidence supplied by NTL for its printed numerals. Verify that QM accepts a distributed light ABCD mark and a solid digit with weak competitors, while stronger competing digits still require verification. Other QM field policies retain their existing behavior.

All 143 tests passed and Flutter analysis reported no issues. Build 42 was packaged for Android. The new QM threshold cases were verified with synthetic marks. Phone-camera verification remains pending.
