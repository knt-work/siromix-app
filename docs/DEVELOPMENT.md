# Development checkpoint — 29 October 2026

## Approved home-screen revision

SiroMix is now a multi-tool launcher. The home screen has the app name, a warm orange brand panel, and an icon grid under “Chức năng”. It has no slogan. The only available tool is “Chấm bài trắc nghiệm”. Selecting it opens academic-year/exam management. Future tools can be added to the launcher without changing the grading hierarchy.

The user approved the orange dashboard reference on 29 October. `docs/references/siromix-approved-ui.html` now contains that latest reference. The home uses orange; the grading module retains its previously approved teal/light palette. Vietnamese product copy remains unchanged except for the explicitly approved removal of the home slogan and the tool-launcher labels. Necessary operational labels for new forms/errors are implemented in Vietnamese.

## First Flutter implementation

- Native Flutter Android scaffold, app label SiroMix, fixed light theme.
- Real academic years, exam sessions, grade levels, subjects, and freely entered exam codes.
- Empty exam catalogs on first use; demo answer keys are not silently created.
- Answer editor: 1–30 questions, A/B/C/D, common points, per-question overrides, calculated total, groups of ten, complete-key validation, and unsaved-change handling.
- Durable Android local storage through a small MethodChannel and SharedPreferences. Writes run on a single background worker and use commit acknowledgements; Dart publishes updated state only after a successful write.
- Versioned JSON with validation. Read failures show a retry screen instead of resetting stored data. Failed saves do not claim success.
- Duplicate codes are rejected within their full context; different contexts are isolated.
- Camera, review imagery, and grading demonstrations remain explicitly simulated.
- Simulated scoring follows blank/multiple = zero and uncertain = teacher review. Final confirmation is gated until review is complete.
- Image saving, grading history, and Excel export remain “Sắp có”.

## Code map

- `lib/main.dart`: Flutter theme, launcher, exam management, answer editor, simulated scan/review/results.
- `lib/data.dart`: versioned data models, storage adapter, transactional repository, scoring rules.
- `android/app/src/main/kotlin/com/example/siromix/MainActivity.kt`: Android storage channel.
- `test/widget_test.dart`: persistence round trip, context isolation, failed writes, scoring/review rules, corrupt-version handling, small-screen UI and per-question editing.

Only Android persistence is implemented. The storage interface can receive an iOS implementation later. No database/cloud/AI package or API credential is required for this milestone.

## Validation

Final validation: Flutter analysis reported no issues, all six tests passed after the direct-editor-to-scan navigation refinement, and the updated debug APK built successfully.

The unit round-trip tests use an injected in-memory backend. An additional Android emulator smoke check installed and cold-launched the final APK, created an exam through the UI, confirmed its SharedPreferences write, force-stopped/relaunched the app, and verified the saved exam appeared again. The home screenshot was visually inspected. Physical-phone storage validation and real camera testing remain outstanding. Do not equate simulated results with measured OMR accuracy.

## Build and run

Prerequisite tool versions and local paths are recorded in SPEC.md. On a fresh terminal with PATH loaded:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter devices
flutter run -d <android-device-id>
```

Debug artifact: `build/app/outputs/flutter-apk/app-debug.apk` (ignored by Git). This is a test build, using the scaffold's development ID `com.example.siromix` and debug signing. Production application ID, branding assets, signing, and store release are not configured.

No commit or push has been requested or performed. Preserve the existing repository history and user documents.

## Next validation and implementation

1. Install the APK on Android and create an exam → grade → subject → code.
2. Enter a short answer key with unequal question points, save, force-close, reopen, and verify it remains unchanged.
3. Try the same code in another grade/subject and confirm isolation.
4. Review usability and Vietnamese text on a physical phone.
5. Obtain the original PDF/clear print of the 30-question template and marked sheets with known answers.
6. Implement and calibrate actual camera capture and OMR, replacing simulation after review of simulation-specific copy.


## Phone installation packaging — 29 October 2026

After `flutter run -d emulator-5554`, the debug output APK contained only x86_64 native libraries. That emulator-specific artifact is not suitable for an ARM64 phone (the user reported Xiaomi 15T Pro). Do not distribute `app-debug.apk` as a phone build after an emulator run.

Use `powershell -File scripts/build-phone.ps1 -BuildNumber 2` to build release-mode test packages for all supported Android ABIs. The script checks Flutter engine libraries for arm64-v8a, armeabi-v7a, and x86_64 before copying the package to `dist/SiroMix-build-2-universal.apk`. Emulator debug sessions do not overwrite this named artifact. Increase the build number for subsequent distributed updates.

The release build currently uses the project's development signing key, as configured by the Flutter scaffold. This is for sideload testing, not store publication. Minimum Android version remains API 24 (Android 7.0).

## User feedback and next scope revision — 29 October 2026

The user tested the phone APK and reported that it works well. They requested dropping candidate-number recognition: read and grade answer marks, and identify graded papers by sequential paper numbers instead. The exam code still selects the answer key. See SPEC.md section 13 for allocation semantics and the proposed numbering scope. This is a pending implementation requirement, not a feature already present in the APK. Replace the obsolete simulated SBD label in the next grading milestone. Keep grading history/image storage/export deferred.

## First sheet type supplied — 29 October 2026

The user restored candidate-number reading and supplied the first real template: 10 ABCD questions on page 1 of a two-page A4 ABCD/written-response PDF. Page 1 has a six-digit candidate number and three-digit exam code; page 2 contains ruled lines only. The source and canonical preview are archived in `docs/references/templates/`; the English template specification is `docs/templates/abcd-10-a4-tn-tl-v1.md`. This supersedes the earlier candidate-number omission and prioritizes the 10-question type before the historical 30-question reference. Existing APK behavior is unchanged at this source-registration step.

## Final Android QA — build 1.1.0+3

- Installed the release APK over the existing emulator app; retained the previous exam catalogs and saved keys.
- Created a QA subject/key using the 10-question template, entered a one-question answer key, saved, and opened the real camera.
- Reproduced and fixed the first-permission lifecycle race. Also removed the artificial initialization timeout that could expire while a user was still reading the permission prompt. Retested from a revoked-camera-permission state: granting permission enabled camera preview and capture.
- Matched the capture guide's bounds/aspect ratio to the actual preview so the four guide corners lie inside the visible camera image. Inspected the final screenshot.
- Final minimal-permission APK opened the camera and took a picture on the emulator. The emulator's room/checkerboard scene was rejected as missing template markers; it did not produce a grade or consume a paper number.
- Final APK metadata: version 1.1.0, versionCode 3, minimum SDK 24, ARM64/ARMv7/x86_64 engines present. Camera is the only dangerous permission; transitive microphone, shared-storage, and network-state declarations were removed. No Internet permission.
- APK signature and 16 KB ZIP alignment checks passed. Stable artifact: `dist/SiroMix-build-3-universal.apk`; SHA-256 is saved alongside it.
- Flutter analysis is clean. Sixteen automated tests passed. No real photographed-paper accuracy measurement has been performed; physical Xiaomi 15T Pro validation remains required.

The sequential-paper-number policy is confirmed by the user and implemented persistently per academic-year/session/grade/subject context. The release still uses development signing; store publication is outside this milestone. No commit or push was performed.

## Camera guidance QA — build 1.2.0+4

Implemented the approved action row above the thumbnail, preview torch toggle, translucent central manual shutter, and local live marker/placement guidance. SPEC.md section 16 records the behavior. Live checking downsamples luminance to an 800-pixel longest edge, throttles requests, uses one worker at a time, requires two valid observations, and invalidates stale/background/capture/torch results. Still capture stops the image stream first and restarts it after a failed read.

Validation on 29 October 2026:
- Flutter analysis clean; 25 automated tests passed without hit-test warnings.
- Installed the universal release over the existing emulator app without clearing data. Confirmed equal-width camera/edit buttons above the preview image.
- Inspected the native camera screenshot: central translucent shutter, torch control, and red framing guide displayed. The unrelated virtual-room scene consistently produced “Chưa vào khung” and never triggered automatic capture.
- Toggled the virtual camera torch, manually captured, received the expected missing-marker error, and observed live checking resume. No Flutter/native fatal errors appeared in the bounded log check.
- Backgrounded and resumed the app: preview and live checking resumed, torch reset to off. Physical LED operation and green guidance on real printed paper remain unverified.
- APK version 1.2.0/code 4, min SDK 24, ARM64/ARMv7/x86_64. Camera remains the only dangerous permission. Signature and 16 KB ZIP alignment checks passed. Artifact: dist/SiroMix-build-4-universal.apk, SHA-256 stored alongside it.

Physical Xiaomi testing is still required for torch hardware behavior, lighting/placement calibration, and actual marked-paper recognition accuracy. No commit or push was performed.

## Answer review and point input feedback — build 1.2.1+5

Implemented the two functional feedback items from the user. Answer rows now show selected and correct answers together, with pale green/red backgrounds for correct/incorrect results and amber for pending manual review. Text labels communicate the same states. Manual corrections and changing exam code refresh the comparison immediately. Existing score confirmation and paper-counter allocation remain unchanged.

Common points now apply as soon as valid text is entered, updating all question controllers and the total across pages. Each valid edit replaces prior individual scores; individual overrides can be entered afterward. Empty, negative, NaN and invalid intermediate input leave existing points intact and cannot be saved. The existing apply-all action reuses the same update method.

Flutter analysis is clean; all 28 tests passed. Added regression coverage for all response states at 320 pixels, comparison/color changes after manual correction and key switching, common-score propagation to off-page questions, decimal comma/zero/invalid inputs, individual overrides after common edits, and serialized key values. The new UI was verified with widget tests; no new physical-phone or native-emulator run was performed for these UI-only changes.

The user also requested home-screen design advice. SPEC.md section 17 records the proposed direction; the launcher is unchanged pending design review. No new feature placeholders, statistics, commits, or pushes were added.
Final artifact: dist/SiroMix-build-5-universal.apk; version 1.2.1/code 5; ARM64/ARMv7/x86_64 engines present. Signature and 16 KB ZIP alignment checks passed. SHA-256 saved alongside the APK.

## User-supplied launcher icon — build 1.2.2+6

Replaced the default Flutter launcher artwork with the exact PNG supplied by the user. Source: assets/branding/launcher-source.png; deterministic regeneration: scripts/generate-launcher-icons.py (Python/Pillow). Five density-specific legacy icons and adaptive foreground layers were generated. Android 8+ uses mipmap-anydpi-v26/ic_launcher.xml with a white background; visible foreground pixels fit a centered 64 dp circle within the 108 dp layer. Reference: https://developer.android.com/develop/ui/compose/system/icon_design_adaptive . No artwork was redrawn or generated with AI. No Dart logic, in-app icons, or app-home layout changed.

Built the universal release, version 1.2.2/code 6. Confirmed ARM64/ARMv7/x86_64 engines, minimum SDK 24, unchanged permissions, valid signature, and 16 KB ZIP alignment. Installed over the existing emulator application without clearing data, inspected the launcher screenshot (build/launcher-build6.png), and opened SiroMix by tapping its new icon. The circle mask preserves the supplied artwork. Full Flutter tests were not repeated for this asset-only change; the preceding code checkpoint passed all 28 tests.

Artifact: dist/SiroMix-build-6-universal.apk, with SHA-256 stored alongside it. The original source copy matches the supplied file byte-for-byte. No commit or push performed.

## History, profile and backup checkpoint — build 1.3.0+7

Implemented the user-approved offline feature set (Excel deferred). See SPEC.md section 19 for the current requirements, superseding older statements that history remains a placeholder.

- lib/data.dart: schema 3 migration from versions 1/2, persistently generated local profile identity, saved paper/key/response snapshots, atomic confirmation plus numbering, validated backup envelope and serialized transactional restore.
- lib/history.dart: hierarchy-scoped searchable result list and read-only saved-paper details. Scores remain based on historic answer/point snapshots after key edits.
- lib/profile.dart: optional local name, school/unit and email; honest future Google/Apple linking status; file export/import, backup summary, explicit replacement confirmation, dirty-profile protection and failure/cancellation handling.
- Android BackupBridge.kt: Storage Access Framework create/open document intents, background I/O with a 20 MiB limit, cancellation and activity-cleanup handling. No broad storage or network permission added. Reference: https://developer.android.com/training/data-storage/shared/documents-files .
- lib/scan.dart: confirmation saves the finalized result and number together. Next-paper action is available after saving and returns to the same camera/context/template. Track papers saved during the current camera visit. Images remain temporary and are not part of history or backups.

Validation:
- Flutter analysis clean. All 39 tests passed, including migration and stable profile IDs, immutable historic scores, invalid/failed confirmation, backup roundtrip and next counter, malformed/future/duplicate/inconsistent backup rejection, failed restore, hierarchy/search/detail UI, profile export, restore cancellation, and durable confirmed restore/navigation. The existing result-screen test now asserts that an actually confirmed paper persists with the finalized score.
- Installed universal release over the existing emulator app, retaining both existing exam catalogs and keys. Inspected the profile page and empty history layout.
- Used Android's native create-document picker to write a JSON backup to Downloads. Pulled and inspected the envelope/schema/counts without exposing contact data. Open-document import displayed the profile/count preview; explicitly restoring that same backup succeeded. Existing catalogs remained intact after restore and force-stop/relaunch. The source QA backup is preserved under build/qa-original-backup.json (ignored build output).
- No Flutter/native fatal errors found in the bounded native QA log. Actual photographed-paper continuous capture/recognition remains dependent on physical-phone validation; this run did not measure OMR accuracy or test actual Google/Apple authentication.
- APK version 1.3.0/code 7, minimum SDK 24; ARM64/ARMv7/x86_64 engines present. Camera remains the only dangerous permission. Signature and 16 KB ZIP alignment checks passed. Stable artifact: dist/SiroMix-build-7-universal.apk; SHA-256 saved alongside it.

Limitations: saved papers begin with this version; old counter-only grades cannot be reconstructed. Photos are not retained. Backups replace, rather than merge, the current local data and are ordinary unencrypted JSON. Local JSON storage is adequate for this initial offline milestone; database/storage scaling and sync conflict resolution remain separate work. No Excel export, verified account linkage, cloud backend or background synchronization is implemented. No commit/push performed.

## Sunrise launcher and author information — build 1.4.0+8

Implemented the user's approved Cam bình minh mockup. lib/home.dart contains the locally painted peach/orange wallpaper, responsive equal-size two-column function grid, installed-version footer and about page. The five tiles follow the requested order; Trộn đề is disabled and marked Sắp có. Home shortcuts reach the existing grading flow, all-year saved-paper history, and local profile/data screen. The about text names Nhựt Triều and the supplied Zalo/phone contact 0358974020, with an explicit copy-number action. No call or message is sent.

Android appInfo reads the actual package version/build through the existing platform channel, with API 24 compatibility. Version/footer content does not require a manually maintained display version. Existing module navigation, stored data, camera reader, and custom launcher icon are preserved. The approved mockup is archived as docs/references/siromix-home-sunrise-approved.html; SPEC.md section 20 records the requirements.

Validation on 29 October 2026:
- Flutter analysis clean. All 41 tests passed. Added checks for tile dimensions/order, disabled shuffle, functional shortcuts, package-version display, 320-pixel large-text scrolling, author/contact content and exact clipboard payload. Shared tile height is based on measured labels to avoid clipping at larger text scales.
- Installed release over the existing emulator app without clearing data. Inspected build/home-build8.png: wallpaper, ordered equal-size tiles, footer with actual version 1.4.0 and copyright. Inspected the about screen and successfully copied the exact contact number; observed its confirmation snackbar.
- The disabled-shuffle native check remained on home as expected. Further history/catalog navigation checks were interrupted by an emulator ADB disconnect; functional shortcut callbacks passed automated tests. Do not treat stale UI dumps after that disconnect as native navigation evidence. No data clearing, new OMR accuracy test, or physical-phone test was performed for this UI milestone.
- Universal APK version 1.4.0/code 8, min SDK 24; ARM64/ARMv7/x86_64 included. Permissions unchanged. Signature and 16 KB ZIP alignment checks passed. Stable artifact: dist/SiroMix-build-8-universal.apk, with SHA-256 alongside it.

No schema migration, login/synchronization, shuffle engine, or Excel export was introduced. No commit/push performed.

## Three-part capture and Home navigation — build 1.5.0+9

The user approved full-sheet versus three-part scanning and bottom Home navigation. SPEC.md section 21 is the current specification.

Implementation:
- lib/scan_flow.dart: explicit mode picker, in-memory three-part coordinator, actual-crop review with accept/retake, and assembly into the existing OmrRead/result pipeline. Failed captures and incomplete drafts do not allocate numbers or persist history.
- lib/omr.dart: regional alignment for the exact 10-question template using its printed rectangular borders, local markers, expected ring grid and white-space checks. Full-sheet default alignment is unchanged. Reuse baseline subtraction/classification. Candidate/code preserve leading zeros; uncertain fields still require final manual resolution.
- lib/scan.dart: mode-specific guide/probe, ordered steps, accepted-part revisiting, result-to-part-retake navigation, same-mode continuous capture, immediate failure snackbar, temporary-file cleanup, and Home confirmation for accepted drafts/unconfirmed results. Only explicitly accepted regions get completion checkmarks.
- lib/navigation.dart and existing pages: four-destination module navigation with Home access on focused routes. Context-inapplicable destinations are disabled. Key/profile drafts and unconfirmed scans require confirmation before Home; ongoing capture/save disables Home.
- assets/templates/part-*.png: small deterministic reference crops showing the required printed local frames. No AI or network service is involved. Data schema stays at version 3; saved-history/scoring policies are unchanged.

Validation:
- All 57 automated tests passed. Flutter analysis is clean. New coverage includes exact reading of all three independently cropped/JPEG fields without outer page corners, rotated blank regions, mild skew, wrong-region rejection, downsampled live probes, clipped-border rejection, step progression/single-part retake, existing score/history integration, mode cancellation/selection and dirty-editor/unconfirmed-result Home guards.
- Universal APK installed over the existing emulator app without data clearing. Existing QA and user exam catalogs remained accessible. Mode selection appeared at entry; both full-sheet and partial cameras opened. Inspected the partial camera layout with stage chips, narrow guide, shutter, torch and bottom Home control.
- On the final APK, captured the unrelated virtual-room scene in both modes. Full-sheet capture rejected missing page markers; partial capture rejected the wrong candidate region and stayed at step 1. The error snackbar displayed without requiring scrolling; live checking remained active. Switching full → parts in the camera worked. Home returned to the Sunrise launcher. Positive three-photo camera capture on actual paper has not been tested; positive recognition coverage is fixture-based.
- The final APK was checked for signature and 16 KB ZIP alignment. Version 1.5.0/code 9, min SDK 24; ARM64/ARMv7/x86_64 included, permissions unchanged. Artifact: dist/SiroMix-build-9-universal.apk, SHA-256 stored alongside it. The visible emulator is intentionally left open for the user with this version installed.

Physical-phone trial: select a configured 10-question key → choose Quét từng phần → capture the complete SBD rectangle and black markers → accept → capture code rectangle → accept → capture answer rectangle → accept → manually review the combined reading → confirm score. Use the same physical sheet for all three captures. Test retaking one completed part and verify the others remain, and verify the next saved paper starts at SBD in the same mode. Real photograph accuracy, severe perspective/blur/shadows and print-border variation still require Xiaomi calibration. No automatic paper identity/deduplication, cloud sync, AI or Excel export was added. No commit/push performed.

## Marker-based regions and automatic shutter — build 1.6.0+10

The user's correction and new shutter request are recorded in SPEC.md section 22, superseding the earlier manual-only capture requirements.

- Candidate and code alignment now use the actual two left-side square markers, with bounded stretch/shear search plus grid/space/coverage validation. The answer block uses four marker centers and printed question-number-side ink to avoid 180-degree reversal. A visible frame remains an optional perspective fallback, not a prerequisite. Reject visible SBD extra columns in the code step and prevent cropped-out columns from being silently blank.
- Guides explicitly depict two/four local marker targets, show the expected column/row count, and retain regional reference crops. All manual shutter controls and the capture-overlay action have been removed from both modes.
- AutoCaptureGate requires three fresh observations over at least 900 ms, geometry stable relative to the first observation, and the whole field inside the guide. Each trigger latches; capture failures require leaving the guide before rearming. Lifecycle/step/mode changes reset stability. Disallow auto capture while processing, away, backgrounded, changing torch, or inside a mode/Home-confirmation modal. Capture snapshots the selected mode/part before asynchronous camera work.
- Existing three-part preview/accept/retake, manual uncertainty resolution, final score confirmation, history and counter semantics remain unchanged. No schema or permissions changed.

Validation:
- Flutter analysis clean; all 68 automated tests passed. Added stable-once, motion/gap/reset, failure-rearm and drift tests; revised overlay tests assert no manual shutter. Regression fixtures include all three user-provided images, marker-only fields with printed rectangular borders removed, and upside-down marked answer blocks. The blank digit examples remain blank; two rows in the rasterized blank answer example can remain uncertain due to printed-glyph residuals, never a fabricated single selection. Do not claim perfect blank classification or physical-photo accuracy from these examples.
- Built and installed universal release over existing emulator data. Inspected build/auto-camera-build10.png: two SBD marker targets, explicit six-column instruction, automatic-capture hint, torch, Home, and no manual shutter. The unrelated virtual scene stayed red/at step 1 across observations and did not auto-capture. Mode selection and Home remained usable; bounded logs showed no Flutter/native fatal errors.
- Positive automatic capture through a physical camera has not been measured. Positive alignment and shutter-gate behavior are covered separately by fixtures and unit tests. Real Xiaomi captures, autofocus/motion, illumination and substantial perspective still require field testing/calibration.
- APK version 1.6.0/code 10, min SDK 24, ARM64/ARMv7/x86_64 included; Camera remains the only dangerous permission. Signature and 16 KB ZIP alignment checks passed. Artifact: dist/SiroMix-build-10-universal.apk; SHA-256 stored alongside it. The visible emulator is left open with this version installed.

No AI, network dependency, automatic grade confirmation, duplicate-paper detection, account sync, or Excel export was added. No commit/push performed.

## Bounded camera and tap-to-capture — build 1.6.1+11

SPEC.md section 23 supersedes build 10's automatic shutter. Both camera modes now use CameraScreenLayout with a bounded Column/Expanded preview, no scrolling camera body, compact controls on short/landscape screens, reachable bottom navigation and a separate help sheet containing the reference image and detailed guidance. Regional steps remain visible and revisitable under the existing rules.

CaptureOverlay provides a semantic camera-surface tap action regardless of live guide color. Torch/help/mode/navigation are independent controls. Processing/stream/torch/modal/lifecycle guards remain; capture immediately locks processing before asynchronous work. The automatic gate and its superseded tests have been removed. Still-image alignment/validation and all scoring/history behavior remain unchanged. Failed recognition can be retried by tapping, without leaving and re-entering the guide.

Partial guides retain region aspect ratios but remove exact square marker targets. Live partial acceptance uses the actual preview bounds with a small safety inset and a minimum detected-region size rather than requiring exact guide placement. This is framing feedback only: it neither crops away image evidence nor relaxes still-image mark classification. The existing two-/four-marker regional alignment, grid checks and optional border fallback are retained. Actual paper photography, especially perspective and print variations, still needs phone calibration.

Validation:
- Flutter analysis clean; all 71 automated tests passed (build/camera-tap-tests.log). Coverage includes tap capture in red/green with no spontaneous capture after waiting, torch isolation, blocked capture while processing, both layouts at 320x568 / 412x915 / 740x360 with 1.4x text, no camera Scrollable or layout overflow, and flexible regional framing rejecting clipped/tiny regions. Existing full-sheet/partial OMR, grading, history and persistence tests passed.
- Installed release build 11 over existing emulator data. Inspected partial and full camera screens: complete preview controls and bottom navigation visible without scrolling; regional help opens separately. Tapping the unrelated virtual-room scene in both modes captured and correctly rejected it, keeping the flow retryable. No physical positive paper capture was performed; fixture-based accuracy is not a real-photo accuracy claim.
- Universal APK version 1.6.1/code 11, min SDK 24, ARM64/ARMv7/x86_64; signature and 16 KB ZIP alignment verification passed. Artifact: dist/SiroMix-build-11-universal.apk. SHA-256 CBDB0278CB833538E820C2234B95287D675E17D1094ADFD683D3527F6768C748, stored alongside the APK. Existing dangerous permission remains CAMERA only.

The emulator is left running with build 11. No data clearing, schema change, cloud sync, AI, Excel export or commit/push performed.

## Profile address and grade picker — build 1.7.0+12

SPEC.md section 24 is the current profile/grade specification. The visible profile now has Tên Hiển Thị, Tỉnh/TP, Phường/Xã and Email. Removed the local/optional introduction and school field from the form; legacy school data remains preserved internally. Address selection uses the bundled Vietnamese Provinces Database v5.2.0 snapshot (34 provinces/cities, 3,321 commune-level units; effective 2026-09-20). Search supports Vietnamese without accents and codes. Province changes clear the ward, cancellation is inert, and a ward cannot be chosen before its province. The picker accounts for keyboard and status-bar safe areas. See docs/ADMINISTRATIVE-DATA.md for pinned source, effective dates, official references, update policy and MIT license; the license is also included in APK assets.

Data schema 4 accepts previous versions, preserves profile identity, school, catalogs/keys, paper history/counters and supports backup round trips with province/ward code+name snapshots. Address data remains offline. No login/sync added. Grade creation now uses 1–12 plus Tùy chỉnh, with conditional text input, duplicate and empty checks, preserving existing custom grade paths.

Validation:
- Flutter analysis clean. All 77 regression tests passed (build/profile-grade-all-tests.log); after the final picker safe-area adjustment, the new small-screen/keyboard test and six profile/grade tests also passed (7 focused tests, build/address-final-focused.log). The migration test includes a real confirmed paper, its score, ID and counter; address persistence, old backup fields and new backup round trips are covered.
- Native release installed over the existing emulator app without clearing data. Inspected four profile fields and removed copy, selected Hà Nội via unaccented search and opened its ward list. Cancelled the test draft through Home/discard. Opened existing StorageSmoke exam, verified all grades 1–12 and Tùy chỉnh, observed the conditional custom input and cancelled without creating a grade. Final APK reinstalled; emulator left running.
- APK 1.7.0/code 12, min SDK 24, ARM64/ARMv7/x86_64, unchanged permissions. Final signature and 16 KB ZIP alignment passed. dist/SiroMix-build-12-universal.apk, SHA-256 33EAF37DC17DED6A3181177536B89D5D69D5D4A1DD3F6E775C6AE4E98AD4A18A (sidecar saved).

Shadow-image experiment (not shipped): originals are preserved at test/fixtures/shadow-{candidate,code,answers}.png. tool/shadow_normalization_probe.py creates illumination-normalized copies under build; tool/shadow_probe_test.dart reports both sets using the production regional reader. All six attempts were rejected during alignment, so there is no claim of successful shadow reading. The diagnostic test's pass status only means the reporting tool ran, not that these images were recognized. No production OMR changes, threshold relaxation or new supported shadow range were made. Further alignment/local-contrast development remains needed before enabling shadow support.

No data clearing, Excel export, cloud sync or commit/push performed.

## Teacher organization input restored — build 1.7.1+13

User clarified the profile also requires an editable Đơn vị field. Added it directly below Tên Hiển Thị, before the province/ward selectors and Email. Existing school storage values prefill the controller, edits are trimmed and saved under the same key, with the existing 200-character limit. Schema remains 4; no address, identity, scoring or history change. SPEC.md section 25 supersedes the previous four-field layout.

Flutter analysis clean; all 17 focused history/profile/grade tests passed (build/profile-unit-tests.log). The existing profile test now verifies a prior organization prepopulates, an edited organization survives saving, repository reopening and backup encoding/decoding. No additional test suite or OMR change was needed for this field restoration. Artifact: dist/SiroMix-build-13-universal.apk, version 1.7.1/code 13. No commit/push performed.

## Answer-region-only scan replaces three-part capture — build 1.8.0+14

SPEC.md section 26 is current. Mode picker now offers Quét toàn phiếu / Chỉ quét đáp án. Removed ThreePartSession, part acceptance/revisit UI and SBD/code camera steps. The new camera always probes/recognizes SheetPart.answers, shows the preselected code and opens ScannedResult directly after one capture. Selection preview and help show only the answer block; retain no-scroll camera, tap shutter, torch and Home. Existing inactive regional digit-reader helpers/fixtures remain available for diagnostic regression work but are not called by the new flow.

ScannedResult receives fixedCode only for answer-only capture. It ignores any detected identity/code in that mode, locks grading to the configured code (including arbitrary alphanumeric codes), shows Số báo danh: Không xác định and hides identity inputs/crops. Missing/invalid preselected keys block scoring instead of falling back. Chụp lại đáp án returns to the camera; final confirmation/continuous next-paper behavior is retained. Unknown SBD is stored as an empty string, displayed through candidateLabel in history/detail; it is never fabricated from the paper sequence. confirmPaper requires explicit candidateUnknown=true to accept an empty SBD. Full-sheet capture keeps six-digit SBD validation and detected/manual code handling.

Schema 5 accepts versions 1–4, preserves profiles/organization/address, identity, histories, keys and counters, and supports unknown SBD in new records/backups. Older schema records still enforce six digits. Counters remain per subject/context, shared across scan modes/codes, increment only when final confirmation persists.

Validation:
- Flutter analysis clean. All 81 tests passed after the main flow change (build/answers-only-tests.log). Two additional schema-4 migration/full-sheet missing-SBD checks were then added; all 14 final focused scan-flow/result tests passed (build/answers-final-focused.log). Tests verify fixed custom code overrides supplied detected code, no editable identity fields, unknown SBD rendering/search/history, uncertainty gates, no-save retake, persistence/backup and numbering across modes/codes/restarts, rejection of blank full-sheet SBD and no silent fallback for a missing fixed key. Existing full-sheet and regional OMR fixtures passed; no image-classification algorithm was changed.
- Installed universal release over the existing emulator data, no data clearing. Launcher reports 1.8.0. Existing StorageSmoke / grade 6 / QA-Camera key 098 remained available. Native chooser contains the two new choices; answer selection shows the unknown-SBD explanation and answer thumbnail; camera shows Quét vùng đáp án and Chỉ quét đáp án · Mã đề 098 without any three-stage chips. Inspected build/siromix-answers-camera14.png. Tapping the unrelated virtual room entered processing; Home subsequently returned to the launcher. No physical positive paper capture was tested in this milestone, and no native recognition accuracy claim is made.
- Final universal APK version 1.8.0/code 14, min SDK 24, ARM64/ARMv7/x86_64, unchanged permissions. Signature and 16 KB ZIP alignment passed. Artifact dist/SiroMix-build-14-universal.apk; SHA-256 AE4A320977E09A289722C8DB477C31118F10CA4FE69BA2DB65ACDE2094996AE6 saved alongside it. Emulator left running at home.

No shadow preprocessing, Excel export, AI, login/sync or commit/push introduced.

## Confirmed deletion and personalized home — build 1.9.0+15

SPEC.md section 27 defines this milestone. Added scoped delete buttons to exam, grade and subject cards; confirmation names the item and lists relevant descendant counts. Exact path-component matching removes the subtree's catalogs, keys, saved results and scoped counters, preserving similarly named siblings and other years. Year/code deletion was not requested. Root selection state resets after successful removal; failed persistence publishes no partial changes.

History supports row trash controls and multi-selection via Chọn nhiều, checkboxes/long press, select-all filtered results and Xóa (n). Every write requires confirmation. Stable IDs determine the batch; cancelling preserves selection and changing history scope clears it. Searches can retain selected hidden results, with an explicit selected/delete count; select-all affects filtered matches only. Busy state prevents repeated actions; progress is shown only while writing. A bounded independently scrollable toolbar supports small screens/large fonts. Deleting results retains counters, including when the subject's last result is removed. Recreating a deleted whole catalog starts a new scoped sequence because catalog deletion also removes its counters.

Home keeps the Sunrise painter, five-function order, disabled shuffle badge and footer. It adds local-time morning/afternoon/evening greeting plus the saved display name (omitted when blank), refreshed on minute/hour changes and app resume. Five equal two-column cards now have narrower width and roughly 100-dp default height (growing with accessible text), smaller icons and coordinated peach/lilac/sage/blue/sand palettes. User profile edits are reflected on return to home. No recognition, scoring, scan-mode or schema change; data schema remains 5.

Validation:
- All 98 tests passed (build/delete-home-all-tests.log). Final independent-toolbar-scroll adjustment and lint formatting then passed all 13 deletion tests (build/delete-final-focused.log). Analysis clean, including after the final confirmation-copy polish.
- New model tests cover exam/grade/subject cascades, exact-name/year isolation, invalid scopes, stale IDs, restart/backup validity, result numbering after deleting all results and atomic failed writes. UI tests cover confirmation/cancel for all three catalog types and single results, filtered batch selection across searches, cancellation preserving selection, failed writes retaining selection/data, small 320x568 large-text layout and scope-change reset. Home tests cover greeting boundaries, timer/resume/name updates, smaller equal cards, distinct palettes and retained actions/disabled state; prior history/scan/profile/OMR tests passed.
- Native release updated over existing emulator data. Launcher shows 1.9.0 and the correct afternoon greeting for the emulator's local clock; inspected build/siromix-home15.png for the smaller colored cards. Opened exam, grade and subject deletion confirmations in existing StorageSmoke/grade 6/QA-Camera, checked scoped key/child counts and cancelled each. No existing emulator records or catalogs were deleted. Positive deletion/batch commits are automated in-memory UI/model tests, not destructive native tests on user data. Final APK reinstalled; emulator left running at home.
- Universal APK 1.9.0/code 15, min SDK 24, ARM64/ARMv7/x86_64, unchanged permissions. Final signature and 16 KB ZIP alignment verification passed. dist/SiroMix-build-15-universal.apk, SHA-256 C53A3DC7A2F1F0B5180952ED01E7BCC27A5972A064E3C7FC4FEBB4EC8506917E, sidecar saved.

No data clearing, shadow preprocessing, AI, login/sync, Excel export or commit/push introduced.

## User-approved release baseline — version 1.0.0+16

The user designated the current application as version 1.0.0 and authorized committing/pushing the complete project to origin/main (https://github.com/knt-work/siromix-app.git), with source tag v1.0.0. Earlier 1.x labels are retained as prototype checkpoint history rather than rewritten as public releases.

Updated pubspec.yaml and build script to 1.0.0+16. Android code 16 remains greater than all prior test builds, allowing updates without deleting installed data despite the user-visible version reset. README now describes the current feature set, reproducible run/build commands, Android-only configuration, development signing and deferred features. Source behavior is unchanged from the validated 1.9.0 checkpoint (98 regression tests passed, final analysis clean); only release metadata/documentation and trailing blank lines changed.

Built universal APK with ARM64/ARMv7/x86_64, versionName 1.0.0/versionCode 16/min SDK 24. Signature and 16 KB ZIP alignment passed. Local packages: dist/SiroMix-build-16-universal.apk and dist/SiroMix-1.0.0.apk, SHA-256 EE146833CF440483F9435DB4A99063CD2C2AA6F19F87E3CB415088F7FE4F1B36. APK output is intentionally ignored by Git; source/assets/tests/specifications and data licensing are included. No GitHub binary Release or store publishing was requested.

## User-supplied replacement launcher icon — build 1.0.0+17

Replaced assets/branding/launcher-source.png with the exact supplied PNG from Downloads (ChatGPT Image Oct 30, 2026, 03_42_35 PM.png). The new image contains the blue rounded-square paper/shuffle artwork. Source SHA-256 D36A079B622881D2ED4590FAD9137CAF3561CBA4AE7635329C18C4DBC39AFA30. No AI redraw or image-content editing was performed; the existing Pillow packaging script regenerates five legacy icons and five alpha-preserving adaptive foreground resources, keeping safe margins and the established white launcher background.

Validation: source bytes match the attachment, all ten resources have correct density dimensions and adaptive transparency, and the high-density legacy icon was visually inspected. The release APK builds successfully, passes signature and 16 KB ZIP alignment checks, and contains ARM64/ARMv7/x86_64. No runtime code changed, so the full behavioral test suite was not repeated for this asset-only update. Manifest icon remains @mipmap/ic_launcher.

Version remains 1.0.0, Android code increments to 17 for updates over build 16. Artifact: dist/SiroMix-build-17-universal.apk; SHA-256 EDCC39609A0849AD108314EF4B6B331979DA17BAAE24E99FA41CEC23D223B632, sidecar saved. README and build script reference the current package. Existing v1.0.0 Git tag is unchanged; this new icon change is local and has not been committed/pushed in this turn.


## Compact 40-question checkpoint (30 October 2026, build 18)

Added independent full-frame-only compact 40-question template, source PDF archive and baseline. Code recognition is three-digit, unknown candidates use existing subject numbering. The result screen filters keys by template, grades only the configured prefix and ignores inactive uncertain marks. Existing 10-question behavior remains supported. Data permits 30/40-slot keys without discarding old answers or snapshots. Source-raster blur is unchanged; physical-photo calibration remains necessary. See docs/templates/abcd-40-compact-v1.md and test/compact_test.dart.

Validation: all 108 Flutter tests pass (`build/compact-all-tests.log`); `flutter analyze` reports no issues (`build/compact-analysis.log`). The original source and archived PDF share SHA-256 D816502049366ED6D6792402EA79B1312A6F2ADCE1489BE04FCF85073DFB86C6. No physical-camera acceptance run has been performed for this template. Existing local icon changes are retained; these changes have not been committed or pushed.

Build 18 universal APK succeeded (Android ARM64/ARMv7/x86_64, versionName 1.0.0, versionCode 18, minimum SDK 24, target SDK 36). APK signature verification and 16 KB ZIP alignment checks passed. SHA-256: D3C0840B81969DAA0F761868446F2823D14432A3B387254DAB26A47FB8E4F1F5. Artifact: dist/SiroMix-build-18-universal.apk. This build was not installed on an emulator or physical device during this change.


## Compact real-photo correction (30 October 2026, build 19)

Reproduced build 18 failure on the supplied physical photograph: the rigid local marker test rejected a gently curved page before code classification. Added bounded twelve-marker matching and mesh correction, compact-specific density dimensions and bounded code-column print-noise compensation. Low-resolution compact matching keeps more candidates and tolerates antialiased squares; ten-question defaults stay unchanged. Real fixture and rotated/JPEG/probe derivatives are regression tests; the original reads code 132 and responses BCABDBAC. Photos are never retained by the application; the test fixture is a developer reference. All build 18 documentation above is historical; native phone verification of build 19 remains pending.

Validation: all 112 Flutter tests pass (`build/compact-real-all-tests.log`), including the original physical photo, rotated/JPEG and low-resolution probe derivatives, ambiguous digit gates and the ten-question regression suite. Photo fixture SHA-256: C45901FE4EF5D872BD2F3C4C958325E136034163282D662805C80093C647CCE8.

Final checks: Flutter analysis clean (build/compact-real-analysis.log); universal APK build 19 succeeded with ARM64/ARMv7/x86_64. Signature verification and 16 KB ZIP alignment passed. SHA-256: C214115DA807133EA9A382701F9B93BC8E5AB68E2DFE1076AF9F46372C11AD5E. Artifact: dist/SiroMix-build-19-universal.apk. No emulator/phone installation was performed during this fix; successful image-fixture recognition still needs confirmation through the phone camera UX.


## User-accepted build 19 and Git source checkpoint (30 October 2026)

The user confirmed that this version runs satisfactorily during their real-device test, then requested a specification update and source push. This supersedes the earlier pending-phone-verification notes for the tested workflow. No device model or wider photo/device coverage is inferred from this confirmation. No runtime change or version increment is required for this documentation checkpoint: package version remains 1.0.0+19.

Include all approved local work since the original v1.0.0 baseline: replacement launcher assets, compact-template assets/source PDF, template registry/editor/data changes, full-only compact scan flow, bounded marker matching and mesh rectification, template-specific bubble measurements, digit noise compensation, regression fixtures/tests and diagnostic tool. Existing automated validation is 112 passing tests and clean analysis; build 19 signature/ABI/16 KB checks passed. Documentation-only acceptance updates do not require repeating that suite. APKs remain in ignored dist/, and the original v1.0.0 tag must not move. Push the new commit to origin/main.
