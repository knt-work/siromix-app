# SiroMix

SiroMix **1.0.0** is an offline, Android-first Flutter app for teachers to manage ABCD answer keys and grade paper answer sheets using on-device optical mark recognition (OMR). The interface is Vietnamese; project specifications and development notes are English.

## Features

- Academic year → exam session → grade → subject → arbitrary exam code. Grades 1–12 and custom grades are supported.
- Correct answers, common/per-question points and weighted grading for the A4 10-question template and the separate compact 40-question template.
- Full-sheet scanning reads the six-digit candidate number and three-digit code. Answer-region-only scanning uses the preselected key and records the candidate as unknown.
- Compact 40-question sheets support full-frame scanning only, read the three-digit exam code and record the candidate as unknown. Configure 1–40 active questions; marks after that count never affect scores or pending review.
- Tap-to-capture, torch and live framing guidance. Ambiguous marks require teacher review; blank/multiple responses score zero.
- Confirmed grading history with persistent per-subject numbering and immutable answer-key snapshots.
- Confirmed exam/grade/subject cascade deletion, plus individual/batch result deletion. Result deletion does not reuse issued paper numbers.
- Local teacher profile, searchable offline province/ward selectors and JSON backup/restore.
- Sunrise home wallpaper, personalized time-of-day greeting and compact colored function tiles.

## Run and build

Use Flutter 3.47.8 / Dart 3.13.7 (the validated development environment), Android SDK and a compatible JDK. Android minimum SDK is 24. Android Studio's bundled JDK was used for the current project.

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

For a universal phone APK containing ARM64, ARMv7 and x86_64:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-phone.ps1
```

The script writes `dist/SiroMix-build-19-universal.apk`. Version is `1.0.0+19`: the user-visible version is 1.0.0, while Android build code 19 remains greater than earlier development builds. APKs, SDK caches, local Android configuration and signing keys are excluded from Git. The existing development signing configuration is retained; store publishing is a separate milestone.

## Scope and limitations

Only Android is configured in this repository. iOS support is planned. The registered automatic readers target the supplied 10-question sheet and compact 40-question frame; legacy 30-question answer keys are preserved but not camera-readable. Physical-photo accuracy, particularly shadows, blur and strong perspective, still needs calibration. Experimental shadow diagnostics are separate from production recognition.

Question shuffling, Excel export, Google/Apple sign-in and cloud synchronization are not implemented. The disabled shuffle tile and account-link placeholders describe future work. Images are processed locally and are not retained in grading history or backups.

## Documents

- [Product specification](SPEC.md): latest sections supersede earlier prototype decisions.
- [Development checkpoints](docs/DEVELOPMENT.md): validation, environment and handoff notes.
- [OMR milestone](docs/OMR-MILESTONE.md): reader architecture and phone test procedure.
- [Administrative data provenance](docs/ADMINISTRATIVE-DATA.md): pinned offline address snapshot and licensing.
- [Ten-question template](docs/templates/abcd-10-a4-tn-tl-v1.md).
- [Compact 40-question template](docs/templates/abcd-40-compact-v1.md).

Earlier 1.x version labels in checkpoint history were development iterations. The user-approved release baseline is **v1.0.0**.

The root PowerShell installation scripts document the original workstation setup. Inspect them before running on a machine that already has an SDK.

The compact reference preserves the embedded raster in the supplied PDF. Synthetic tests do not establish physical-photo accuracy; blurred printouts still require real-device calibration. See `docs/templates/abcd-40-compact-v1.md`.

The user confirmed build 19 works satisfactorily in real-device testing. The compact reader is also covered by a physical-photo regression and derived rotation/JPEG/live-probe cases; broader print/photo/device accuracy remains to be measured.
