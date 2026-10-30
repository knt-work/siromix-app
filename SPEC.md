# SiroMix — Product Specification and Development Handoff

Updated: **29 October 2026**, Asia/Bangkok (UTC+7). Product scope and UI approved on 28 October; documentation translated on 29 October.

## 1. Purpose and initial scope

SiroMix is a handheld tool for teachers to configure multiple-choice answer keys, scan answer sheets with a phone camera, grade responses, and view scores. The interface should be attractive, readable, and convenient for grading successive papers.

- Use **Flutter**, targeting a shared Android/iOS codebase.
- Deliver **Android first**. iOS comes later and requires macOS/Xcode for builds and testing.
- Initial operation is **offline, without login or synchronization**. The user's last phrase about synchronization was interpreted this way in the scope summary, after which the user agreed to continue.
- Use conventional image processing and **optical mark recognition (OMR)**. AI may be added later but is not required now.
- Initially support **A/B/C/D, with one correct answer per question**. Multi-part true/false and short-answer formats are excluded.

## 2. Approved data hierarchy

**Academic year → Exam session → Grade level → Subject → Exam code → Answer key and per-question points.**

“Class” was clarified to mean **grade level: 6/7/8/9/…**, not a specific classroom such as 6A1. No student roster is required initially.

| Level | Requirements and examples |
| --- | --- |
| Academic year | For example, 2026 – 2027; contains exam sessions |
| Exam session | User-defined names, for example midterm/end-of-term |
| Grade level | 6, 7, 8, 9, and additional levels |
| Subject | Mathematics, Physics, English, and additional subjects |
| Exam code | Free-form entry; examples 132, 246, 357, 480 |
| Answer key | Question count, correct answers, and individual question points |

Keys belong to their complete year/session/grade/subject/code context. Identical exam codes across different contexts must not accidentally share data. The approved prototype rejects duplicate codes within one subject and its parent context. Example names and codes are not fixed product lists.

## 3. Exam configuration and points

- Allow **1–30 questions** for the first template; only grade configured questions.
- Each question has one correct option A, B, C, or D.
- Provide an **editable points input for every question**, explicitly requested by the user.
- Also provide a common points input and an apply-to-all action, followed by individual overrides.
- Calculate the maximum score by summing individual points. Do not replace these inputs with automatic division of a total grading scale.
- Points must be finite, nonnegative numbers; question count must be an integer within template capacity.
- Require complete answers before grading. The approved prototype also requires completeness before saving a configuration.
- Persist **exam configurations and answer keys locally across restarts**. This is distinct from grading history, which is deferred.
- **Unresolved:** final rounding policy. The prototype displays two decimal places. Do not round individual question scores before summing unless another policy is approved.

## 4. Recognition and grading rules

| Response | Behavior |
| --- | --- |
| One clear mark matching the key | Award that question's configured points |
| One clear mark not matching the key | 0 points |
| Blank | **0 points** |
| Multiple marked answers | **0 points** |
| Faint mark | **Teacher review required** |
| Incomplete erasure or uncertain reading | **Teacher review required** |

Do not present an uncertain score as final. Show a cropped/enlarged image of the actual questionable response; let the teacher confirm A/B/C/D, blank, or invalid/multiple marks. Recalculate and enable final confirmation after all uncertain responses are resolved.

For blurred, poorly lit, cropped, or template-mismatched images, request recapture or correct template selection rather than silently misreading the sheet.

**No duplicate-paper detection is required**. Candidate numbers are read alongside a separate sequential paper number; they are not deduplication keys. Do not add duplicate warnings or replacement workflows initially.

Main flow: choose exam context/key → capture → read candidate number, exam code, and answer marks → compare with key → review uncertain responses → confirm score and assign a sequential paper number → scan next paper.

## 5. Original answer-sheet reference (superseded as first implementation priority by section 14)

Reference image: `docs/references/answer-sheet-abcd-30-reference.png`.

Observed layout:

- One column of **30 questions**, four A/B/C/D bubbles per row.
- The sheet physically includes a **six-digit candidate number** area and a **three-digit exam code** area. The user subsequently restored candidate-number recognition; candidate number, exam code, and answer areas all require recognition.
- Black square alignment markers.
- Header information and ruled writing area on the right are ignored for ABCD grading.
- Candidate-number recognition is required. Handwritten-name recognition is not required.

The approved Vietnamese template label is **“Phiếu ABCD – 30 câu”**. Implement this template first. Plan for versioned template configurations and additional layouts later. Do not promise recognition of arbitrary ABCD or all Ministry of Education sheets; the image's official provenance has not been verified.

Codes can be entered freely, but the physical template only encodes **three numeric digits**. Read compatible codes automatically; other codes require manual selection. Resolve unreadable codes or codes without configured keys before grading.

Before production use, obtain the **original PDF or clear print of the exact template**, calibrate coordinates, and validate marked sheets with known answers. Test multiple devices, lighting conditions, and angles. No accuracy measurements or guarantees exist yet.

Proposed processing: detect markers → correct perspective → normalize lighting → measure bubble fill → classify blank/single/multiple/uncertain. Libraries and thresholds remain undecided.

## 6. Approved UI and copy

**The user approved the current interface and required all product copy/text to remain unchanged. Translating this specification does not authorize translating the Vietnamese interface.**

- Name: **SiroMix**.
- **Fixed light theme**, independent of system dark mode.
- Light background and white cards. Updated on 29 October: the approved multi-tool launcher uses warm orange; the grading module retains teal `#087f78`.
- Preserve approved mobile layout, navigation, and clear touch targets when implementing Flutter.
- Do not rewrite copy, add marketing claims, or redesign approved workflows without agreement.

Authoritative reference: `docs/references/siromix-approved-ui.html`. This exact copy includes markup, styles, JavaScript, all screens, and dynamically generated Vietnamese strings. Read it before Flutter implementation; this document's summaries do not replace it.

Original preview location on the development machine:

`C:/Users/nhutt/.codex/visualizations/2026/10/28/01a182f2-cdab-7a42-b880-d52c490a33dd/cham-thi-mobile.html`

Approved screens:

1. Exam sessions: year selection and session creation/opening.
2. Select/add grade levels.
3. Select/add subjects.
4. List/add exam codes.
5. Answer editor: question count, common points, apply-to-all, individual points, calculated total, groups of ten questions.
6. Scan: complete context, selected code, capture guidance.
7. Results: provisional/final score, correct/incorrect/blank/invalid/review counts, applied rules, next scan.
8. Manual review: enlarged uncertain response and teacher choices.
9. Grading log: future-feature placeholders only.

Bottom navigation stays **“Kì thi / Quét bài / Kết quả”**.

Representative strings, deliberately retained verbatim:

- “Công cụ chấm bài của giáo viên”
- “Chấm nhanh. Dạy trọn tâm.”
- “Từ bộ đáp án đến điểm số, thật gọn gàng.”
- “Kì thi của bạn”, “Khối học”, “Môn thi”, “Mã đề”
- “Đáp án & điểm”, “Điểm chung mỗi câu”, “Áp dụng điểm chung cho mọi câu”
- “Lưu cấu hình đề”, “Quét với mã đề này”
- “Đưa phiếu vào khung”, “Đặt phiếu phẳng, đủ sáng và đủ mốc đen.”
- “Kiểm tra bài chấm”, “Điểm tạm tính”, “Tổng điểm”, “Xác nhận điểm”
- “Quét bài tiếp theo”, “Sổ chấm bài”, “Sắp có”

Simulation labels currently reflect real prototype limitations. Do not claim the camera/recognition is implemented. Agree on replacing simulation-only wording when real functionality is connected, consistent with copy preservation.

### Prototype limitations

- Interactive conversation HTML, **not a Flutter app or APK**.
- Camera, enlarged images, papers, and grading examples are simulated.
- Questions 17/23, default 0.25 points, and codes 132/246/357/480 are demo data, not hardcoded recognition requirements. The old candidate-number label (001286) in the existing simulated screen is obsolete and must be replaced by the sequential paper number in the next grading implementation.
- State uses the preview host's widget mechanism, not an app database.
- JavaScript syntax and in-memory interaction checks covered hierarchy, question points, mock grading, review, confirmation, and placeholders. Flutter and real-camera testing have not happened.

## 7. Deferred features

Display **“Sắp có”** placeholders for saving captured sheets, grading history, and Excel/score-table export. These features are not implemented in the initial release.

Also deferred: accounts, synchronization/cloud services, specific classrooms/rosters, duplicate-paper detection, AI, non-ABCD question formats, complete multi-template recognition, and iOS release.

## 8. Development environment and repository

New repository supplied on 29 October 2026:

`C:\My Data\Projects\Mobile App\siromix-app`

Previous workspace retained as a source/backup:

`C:\Users\nhutt\OneDrive\Tài liệu\ChatGPT\SiroMix`

The following environment was verified on **28 October 2026**:

| Component | Verified state |
| --- | --- |
| Flutter | **3.47.8 stable**, `C:\Users\nhutt\develop\flutter` |
| Dart | **3.13.7**, included with Flutter |
| Git | `C:\Program Files\Git\cmd\git.exe` |
| Java/JDK/javac | **OpenJDK 25.0.3**, bundled with Android Studio |
| JAVA_HOME | `C:\Program Files\Android\Android Studio\jbr` |
| Android Studio | `C:\Program Files\Android\Android Studio` |
| ANDROID_HOME | `C:\Users\nhutt\AppData\Local\Android\Sdk` |
| Command-line Tools | `cmdline-tools\latest`, sdkmanager **22.0** |
| ADB / Platform Tools | ADB **1.0.41**, Platform Tools **37.0.1-15733141** |
| Android platform | API **36** installed for Flutter; `android-37.0` already existed |
| Build Tools | **36.0.0** |
| Emulator | **37.2.12.0**, no running Android emulator confirmed |
| Licenses | Accepted, verified by doctor |
| Flutter analytics | Disabled |

User PATH includes Flutter, Java, platform-tools, and cmdline-tools. Flutter explicitly uses the configured JDK and Android SDK.

**Last full check: `flutter doctor -v` → `No issues found!`.**

Installed Flutter template defaults: Gradle **9.3.1**, Android Gradle Plugin **9.1.0**, compile/target SDK **36**, NDK **28.2.13676358**. NDK/CMake installation has not been verified; install exact versions if builds require them. Doctor success is not proof of an APK build.

Detected targets: Windows desktop, Chrome, Edge. **No Android phone was connected.** Use a physical phone with USB debugging for camera validation.

Initial sandbox checks missed host-installed tools. Distinguish sandbox restrictions, stale PATH, and actual missing installations before reinstalling. Use absolute paths or fresh shells with user PATH loaded.

Installation history:

- `install-flutter.ps1` cloned official stable after the ZIP manifest returned 404. Do not rerun unchanged over an existing SDK.
- First bootstrap stalled on `git fetch --tags`; only those download processes were stopped, after which initialization succeeded. No SDK deletion occurred.
- `install-android-tools.ps1` downloaded official tools, verified SHA-256, installed API 36/Platform Tools, configured PATH and licenses. No need to rerun for ordinary development.
- sdkmanager emitted deprecation and Java native-access warnings; installation succeeded.
- Host SDK writes required execution approval. Future sessions must respect their current filesystem permissions.

## 9. Initial planning status (superseded by the implementation checkpoint)

Completed: scope and grading decisions, interactive prototype, grade-level/point/review refinements, approved name/theme/copy, environment setup, documentation and reference preservation, and English translation.

Not done: Flutter project creation, Dart app code, real persistence, real camera/OMR, APK builds/device runs, accuracy measurement, original sheet PDF, and known-answer capture test set. No commit or push has been made during this documentation handoff.

## 10. Next steps

1. Open the new repository as a Codex project; read this spec, the approved HTML, and any repository instructions.
2. Briefly check tools without reinstalling completed dependencies.
3. Initialize Flutter for Android while preserving existing `.git`, README, and docs. The new path contains spaces; address actual build issues if encountered rather than moving/deleting the checkout without agreement.
4. Port the approved UI and Vietnamese copy to Flutter.
5. Implement real data management and offline exam-configuration persistence. Architecture, storage, and state-management libraries remain undecided.
6. Deliver the **first APK with working exam management, without requiring camera grading yet**.
7. Start a 30-question OMR proof of concept early; obtain the original PDF/clear print and actual Android captures.
8. Integrate recognition, manual review, and scoring; calibrate on physical devices.

No OpenAI API key is needed: no AI, backend, or cloud service is required initially.

## 11. Previously discussed estimates

Preliminary effort estimate: **3–5 weeks** for a reasonably stable Android trial including real-sheet validation; **5–9 working days** for the first exam-management APK.

Rough breakdown: interface 2–4 days, management/offline storage 3–5 days, camera/OMR 5–10 days, testing/calibration 5–7 days. These are estimates, not committed delivery dates. Real-world recognition is the main uncertainty.

Work happens during chat sessions. **No overnight background development or scheduled automation was created.**

## 12. Implementation checkpoint — 29 October 2026

The orange multi-tool launcher was approved after this initial specification. A Flutter Android implementation, real exam configuration management, offline persistence, tests, and a debug APK now exist. Camera/OMR remains simulated. See [Development checkpoint](docs/DEVELOPMENT.md) for current implementation details and validation limits. Sections 9–10 above describe the earlier planning state and must be read with this checkpoint.


## 13. Earlier paper identification revision (superseded by section 14) — 29 October 2026

The user tested the phone build and reported that the app works well. The next milestone is real answer-sheet recognition and grading.

Updated requirement: **do not read or require the candidate number**. Read the answers and grade the paper; display a sequential number for each graded paper, such as “Bài số 1”, “Bài số 2”, and so on. Read/select the exam code as before to choose the correct answer key. This revision authorizes replacing the old SBD label while preserving the rest of the approved interface copy.

Assign the number when the score is confirmed after any required manual review. Rebuilding the results screen, recalculating, failed captures, or retrying the same pending capture must not consume another number. Scanning a paper again is treated as another paper; no identity/deduplication system is requested.

Implementation default proposed for the next milestone: number papers within the academic-year/exam-session/grade-level/subject context, across exam codes. Exact reset behavior and whether the counter continues across app restarts have not been explicitly confirmed by the user. Do not assume that numbering requests full grading-history storage, image retention, student rosters, or Excel export; those remain deferred.

This entry records the next implementation requirement. The current APK still has a simulated candidate-number label; recognition and sequential numbering have not yet been implemented.


## 14. Candidate-number restoration and first registered sheet type — 29 October 2026

The user restored **candidate-number recognition**, requested management by sheet type, and supplied the first PDF: a **10-question A4 ABCD + written-response sheet**. This supersedes section 13's instruction to omit candidate numbers and the initial choice of the 30-question image as the first real OMR target.

Read candidate number, exam code, and answers. Retain sequential paper numbers separately; scope/reset/persistence of numbering is not yet finalized. Do not add duplicate-paper detection or student-roster management.

First registered type: `abcd-10-a4-tn-tl`, version `1`; proposed selector label “A4 – 10 câu trắc nghiệm và tự luận”. Read **page 1 only**: **10 ABCD questions, six-digit candidate number, three-digit exam code**. Ignore all written-response areas and page 2. Select a sheet type when configuring the exam, save its ID/version, and constrain question count to the selected type's capacity. Existing 30-question keys must not be truncated automatically.

See [10-question template specification](docs/templates/abcd-10-a4-tn-tl-v1.md). The original PDF and rendered recognition-page preview are preserved under `docs/references/templates/`. This is a source-registration/specification milestone; template selection, real recognition, and sequential numbering are not yet implemented in the APK.


## 15. Camera/OMR implementation checkpoint — 29 October 2026

The user confirmed continuous paper numbering within each academic-year/exam-session/grade-level/subject context, across exam codes and app restarts. Allocate a number only after final score confirmation; do not store grading history implicitly.

Build 1.1.0+3 implements versioned template selection, safe migration of old 30-question keys, real camera capture, and an experimental local OMR reader for the 10-question template. Candidate numbers and exam codes are read with leading zeros preserved. Uncertain answers display actual cropped images for review; unknown codes require explicit key selection. Missing/uncertain candidate numbers require manual six-digit entry. Camera capture, decoding and scoring replace the old simulated grading flow.

See [Camera/OMR milestone](docs/OMR-MILESTONE.md) for code structure, automated coverage, limitations and the physical-phone test procedure. This supersedes earlier source-registration-only descriptions. Real photographed-sheet accuracy has not been measured; the current validation set is synthetic plus native emulator checks.


## 16. Camera controls and live framing — 29 October 2026

The user approved these changes for build 1.2.0+4:

- Place equal-width “Mở camera” and “Sửa đề” buttons on one row, below the selected template name and above its thumbnail.
- Provide a torch toggle on the live camera preview. Turn it off when leaving/backgrounding the camera; report unsupported hardware without claiming it is on.
- Put the manual capture button in a translucent circle at the center of the preview. A green guide never triggers capture automatically and a red guide does not block manual capture.
- Check a throttled, downsampled luminance frame locally for the registered template's alignment markers and placement inside the guide. Show a green check after two matching frames, a red cross when placement is invalid, and a neutral state while searching or when checking is unavailable. Expire stale results and reset on capture, torch changes and lifecycle transitions.

Live guidance checks placement only. It does not guarantee readable answer marks or an accurate score. Full-resolution OMR and manual review still run after capture. No AI, server calls, additional permissions, or saved camera frames were introduced.

Automated validation: 25 tests passed, including live marker detection, padded camera planes, guide geometry, stale-state handling, responsive action placement, and manual capture behavior. Flutter analysis is clean. Physical-phone torch operation and printed-sheet framing/accuracy require Xiaomi testing.


## 17. Answer comparison and immediate common points — 29 October 2026

The user requested these changes after testing build 4:

- Each answer-review row shows the question number, the selected response, and the correct answer from the currently selected exam code, with the existing manual-review action. Use pale green for correct responses, pale red for incorrect responses (including blank/multiple responses that score zero), and pale amber for uncertain marks awaiting review. Include text status so color is not the only indication. Recalculate the comparison after manual corrections or exam-code changes. Keep confirmation/paper numbering rules unchanged.
- Editing “Điểm chung mỗi câu” immediately updates all question-point inputs and the total, including questions on other pages. A valid new common value replaces individual point overrides; users can edit individual points afterward. Empty, negative, nonfinite or invalid common input must not overwrite existing scores. Saving still requires valid input. Keep the existing apply-all button for reapplying the common value after individual edits.

Build 1.2.1+5 implements both changes. No data-schema migration is necessary.

Home-screen design is discussion only at this checkpoint. The user finds the current launcher insufficiently striking and asked for advice. Proposed direction: retain the light orange identity, app name and multi-tool launcher without a slogan; reduce the oversized decorative banner and unused space; emphasize the grading function with a more substantial icon/card and consistent spacing. Do not imply grading-history metrics or unimplemented functions are available. The current home screen remains unchanged pending design review.


## 18. User-supplied Android launcher icon — 29 October 2026

The user supplied “Quiz Shuffle Checkmark Icon.png” and requested it as the phone launcher icon. Preserve the supplied artwork and store the exact source at assets/branding/launcher-source.png (1254 × 1254 RGBA; SHA-256 A3B9F573B11738821565589DC75E7209936ABA5F6CBEB69894A28973EB5F63EB).

Build 1.2.2+6 replaces the scaffold launcher icon with this artwork. Android 8+ uses an adaptive icon with a white background and transparent foreground; size visible pixels within a centered 64 dp safe circle on a 108 dp layer to accommodate launcher masks. Android 7 uses opaque white bitmap fallback icons. Generate resources for mdpi through xxxhdpi using scripts/generate-launcher-icons.py (Python with Pillow). This is deterministic asset packaging, without AI redrawing. The home-screen UI, internal feature icons, product copy and persisted exam data remain unchanged. iOS packaging remains outside the current Android implementation.

## 19. History, continuous grading, backups and a local teacher profile — 29 October 2026

The user approved the four proposed functions, deferring Excel export, and requested user information management in preparation for future Google/Apple account synchronization. Build 1.3.0+7 implements the offline milestone below; actual authentication and cloud synchronization remain future work.

### Local teacher profile

Add “Hồ sơ & dữ liệu” to the app bar. Store optional display name, school/unit and email locally. Profiles are not required for grading. Use a persisted randomly generated local ID; preserve it through edits and backup/restore. User-entered email is contact information, not a verified login or identity link. Future OAuth identities must be linked via verified provider/subject identifiers while retaining local ownership; no credentials or provider tokens are currently stored. Show an honest “Google / Apple · Chưa liên kết” status without nonfunctional login controls. No login, networking, or cloud backend is introduced.

### Saved papers and results

Confirming a score atomically saves its paper number and result within the existing year/session/grade/subject counter scope. Save stable record/profile IDs, six-digit candidate number (including leading zeros), free-form exam code, UTC timestamp, full context, selected template, a snapshot of the answer key and question points, and finalized responses. Calculate historic scores from that saved snapshot, so later answer-key edits do not change prior grades. Uncertain responses cannot be confirmed; failed writes publish neither a paper nor a counter increment. Repeated confirmation of the same pending capture is disabled. Scanning a paper again creates another record; no duplicate detection.

The “Kết quả” tab shows “Sổ chấm bài” within the current hierarchy prefix, newest first, with search by candidate number, exam code or exact paper number. Open read-only detail with score and per-question selected/correct answers. Store results from this version onward; earlier versions saved counters only and cannot reconstruct previous papers. Images are not retained.

### Continuous grading

After a successful save, “Quét bài tiếp theo” returns directly to the same camera/context/template. Keep manual shutter capture, fresh live guidance and existing lighting/lifecycle handling. Display the count of saved papers in the current camera visit. The next-paper action is enabled only after confirmation; backing out remains possible. No automatic capture or automatic confirmation is introduced.

### Backup and restore

Use Android's Storage Access Framework document picker to create/select a JSON file, without broad storage permissions. An explicit `siromix-backup` envelope version 1 contains data schema version 3, profile, catalogs, answer keys, results and counters. Backups do not include photos. Import is bounded to 20 MiB; reject invalid/future formats, malformed keys, duplicate IDs/numbers, invalid confirmed marks, mismatched ownership or counters behind saved paper numbers before changing data.

Preview the backup's profile and counts, then require an explicit in-app confirmation to replace all local data. Replacement is transactional at the repository/storage boundary; cancellation or write failure leaves current data intact. Reset navigation after restore. This milestone restores by replacement, not merge. The JSON file is unencrypted; the user chooses its storage location. Cloud document providers in the system picker are optional user choices and are not account synchronization implemented by SiroMix.

Schema migration accepts existing versions 1 and 2, preserving keys/templates and counters, creating an empty history and persisting the local profile ID once. No old 30-question key is truncated. The release retains development signing and the custom launcher icon. Excel export and cloud synchronization are deferred.


## 20. Approved Sunrise home and application information — 29 October 2026

The user approved the updated “Cam bình minh” home mockup and requested implementation. Use the light peach/orange abstract wallpaper across the home background. Remove the previous oversized brand banner. Show SiroMix and Offline near the top, with profile access.

Display five smaller, equal-sized function tiles in a two-column grid, in reading order:

1. “Chấm bài trắc nghiệm” opens the existing exam-management flow.
2. “Trộn đề” is disabled, visibly muted and marked “Sắp có”; no shuffle implementation is implied.
3. “Sổ chấm bài” opens saved results across all academic years. The grading module's existing results tab remains scoped to its hierarchy context.
4. “Hồ sơ & dữ liệu” opens the existing local profile and backup/restore screen.
5. “Giới thiệu về ứng dụng” opens the about screen.

Keep all five tiles equal in width and height, including the final unpaired tile. Adapt the shared height to measured text so accessibility text scaling does not clip labels. Allow vertical scrolling on smaller screens; place version and copyright at the bottom on taller screens. Render the wallpaper locally with Flutter painting; no network assets are required.

Read the actual installed version/build from Android package metadata for the footer and about screen. Show “© 2026 SiroMix. Bảo lưu mọi quyền.” in the footer. The about screen must include the user-provided information: “Ứng dụng được phát triển bởi Nhựt Triều, mọi thắc mắc xin liên hệ qua Zalo/SĐT: 0358974020.” Provide a copy-contact-number action; do not initiate a call or message automatically.

The implementation is build 1.4.0+8. The approved mockup reference is preserved in docs/references/siromix-home-sunrise-approved.html. Other module copy, exam data, saved history, camera behavior and custom Android launcher icon remain unchanged.


## 21. Full-sheet / three-part scanning and Home navigation — 29 October 2026

The user approved this milestone after reviewing the proposed UX. Build 1.5.0+9 adds “Quét toàn phiếu” and “Quét từng phần” for the registered 10-question template, plus a bottom “Trang chủ” destination.

### Mode selection and capture flow

Every “Quét bài” or “Quét phiếu chấm bài” entry asks which scanning mode to use. Cancelling keeps the existing screen. The configuration preview shows the selected mode before opening the camera; “Đổi chế độ” is available there and in the camera. Retain the chosen mode during a continuous camera visit so a teacher need not select it again after each saved paper.

Full-sheet mode uses the existing outer-marker pipeline. Three-part mode captures, in order: six-digit candidate number, three-digit exam code, then all ten answer rows. Show the current step, the completed parts, an aspect-matched local frame guide, and an expandable reference crop for the required region. The user must capture the entire printed rectangular frame and its local black markers for each region; the whole page is not required. Only completed/current steps can be revisited. Keep the same physical paper through all three captures; no reliable cross-capture paper-identity verification is implemented.

After each capture, preview the actual crop and reading, allowing “Dùng phần này” or “Chụp lại”. Accepting an uncertain field is allowed only with a warning that final manual review is required; existing final candidate/code/answer gates remain authoritative. Retaking one region preserves other accepted regions. Once complete, combine the three readings into the existing review/scoring screen. “Chụp lại từng phần” returns to the accepted parts; “Kiểm tra bài chấm” reopens the combined result. Save history and allocate the number only at final confirmation. After a saved result, clear the three-part draft and start candidate-number capture for the next paper in the same mode/context.

Capture errors appear immediately in a snackbar as well as the inline error area. No automatic shutter or automatic score confirmation is introduced. Temporary photos are deleted using the existing cleanup flow; part crops are held in memory only. Existing scoring, history snapshots, counters and schema version 3 remain unchanged.

### Regional image processing

For this exact template, the printed region rectangles are independent references: candidate frame (577,-2)–(832,419), exam-code frame (841,-2)–(1002,419), and answers frame (52,429)–(302,841), in the established canonical coordinate system. Find connected hollow-frame proposals, estimate a homography, and verify the expected region's black markers, complete border, printed bubble-ring pattern and white gaps before accepting alignment. This prevents treating an arbitrary crop or the wrong field as the requested region. Reuse baseline-subtracted bubble classification and existing uncertainty thresholds. The live checker uses downsampled regional frame proposals and the current region's aspect ratio, with the existing throttling, revision guards and stale-result expiry.

This remains an experimental offline reader for the supplied template. Positive cropped/JPEG/rotation fixtures and wrong-region/clipped-border negatives do not establish accuracy on real photographs. Severe perspective, blur, shadows, broken/thin borders or print variations may require recapture and further calibration.

### Home navigation

The module's bottom bar reads “Trang chủ · Kì thi · Quét bài · Kết quả”. The context-dependent scan entry remains disabled until a subject is selected. Add bottom Home access to the camera, result review, key editor, local profile, direct-history and about routes. Non-applicable destinations are disabled on focused routes. Home returns to the Sunrise launcher. Dirty key/profile forms and unconfirmed results/accepted part drafts require a discard confirmation before Home; cancelling preserves current work. Disable Home while saving or capturing. Do not allocate a paper number when leaving without confirmation.


## 22. Correct regional marker counts and automatic shutter — 29 October 2026

The user supplied three cropped region images and requested rewriting partial scanning around the actual marker counts, then removing the manual shutter in favor of automatic capture. Build 1.6.0+10 supersedes section 21's manual-shutter behavior for both scanning modes.

Candidate number and exam code each have two local black square markers on the left. The answer region has four square corner markers. Regional alignment now proposes candidate/code transforms from the two-marker axis and searches bounded horizontal stretch/shear, verifies the expected bubble grid and white gaps, and requires every bubble to remain in the photograph. A visible rectangular border is an optional perspective fallback rather than a required input. The four answer markers provide a projective transform; the printed question-number strip distinguishes the otherwise symmetric 180-degree orientation without OCR. Reject the visible extra columns of an SBD region when scanning a three-column code. This is a template-specific geometric reader, not AI or general text recognition. Severe projective distortion or missing/faint content may still require repositioning and calibration.

The camera guide shows the expected two or four local marker positions and explicit field/column instructions. The entire field and all its markers must be visible. Removing the dependence on a printed rectangle does not allow missing columns or omitted answer rows. The original full-sheet outer-marker reader remains available.

The manual shutter has been removed. Automatic capture requires three fresh, valid observations spanning at least 900 ms, with all inferred field corners inside the guide and stable against the first observation's geometry (maximum normalized displacement 0.018). Analysis results older than 650 ms cannot trigger the shutter. The gate fires once, is blocked during capture/review/modals/backgrounding, and resets on field/mode/torch/lifecycle transitions. Failure requires the field to leave the guide before automatic rearming, avoiding repeated shots of the same failed view; explicit camera retry also resets the gate. Retaking and accepting individual parts, final manual corrections, score confirmation, saved history and numbering remain unchanged. Automatic shutter does not mean automatic score confirmation.

The three user-supplied PNGs are preserved as regression fixtures. Their blank digit fields do not become selected digits. Rasterized printed answer letters can leave ambiguous residual ink in the answer example; those remain “Cần kiểm tra”, never invented selected answers. Keep the established faint/erasure review policy instead of relaxing classification thresholds to force a blank reading.


## 23. Bounded camera layout and tap capture — 30 October 2026

The user approved correcting the camera layout in BOTH full-sheet and three-part modes and replacing automatic capture with a tap on the camera surface. This supersedes section 22's automatic-shutter and exact marker-target UI requirements.

Both camera modes use the available bounded screen height; the camera screen itself does not scroll. Title, mode switch, help, regional step controls and bottom navigation remain reachable. The preview preserves its aspect ratio and uses the remaining height, with a compact header/footer on short screens. Detailed instructions and regional reference images are moved to a separate help sheet.

Tap the camera surface to capture, regardless of the live frame verdict. Torch, help, mode, step and navigation controls do not trigger capture. Block capture while processing, changing the torch, switching streams, in a modal, away or backgrounded. Remove the automatic shutter gate entirely. Validate and align each high-resolution still before reading; invalid images remain retryable by tapping without leaving/re-entering the frame. No automatic score confirmation is introduced.

For partial scanning, retain the correct aspect ratio for each field but remove square targets that imply exact marker matching. Live green status accepts a complete detected field offset within the actual preview, with minimum size and visibility checks. The guide is advisory, not a crop applied to the photo. All expected markers and all bubble columns/rows still need to be present. Full-sheet recognition and bubble-classification thresholds remain unchanged; the two-marker regional transform and optional border fallback are retained. This UX improvement does not establish real-photo accuracy or remove limitations under strong perspective, blur or broken print. Continue physical-phone calibration using actual sheets.

No change to schema, history, scoring, numbering, accepted-part preservation or final manual-review requirements.

## 24. Teacher profile address and grade selection — 30 October 2026

The profile form contains exactly four visible fields, in order: Tên Hiển Thị, Tỉnh/TP, Phường/Xã, Email. Remove the previous optional/local-only explanatory sentence and the school/organization field from the form. Preserve existing school values internally for lossless migration and backup. The stable local profile identifier and future Google/Apple placeholders remain unchanged; no authentication or synchronization is introduced.

Use the two-level administrative structure after July 2025. Bundle a versioned offline catalog of province/city and subordinate commune/ward/special administrative zone codes and names. In this build, use the reviewed v5.2.0 snapshot effective 2026-09-20 (34 provincial units, 3,321 commune-level units), with source/provenance and MIT attribution in docs/ADMINISTRATIVE-DATA.md and the bundled license. This is a packaged snapshot updated by app releases, not a live-address service. Both pickers support name searches without accents and administrative-code searches. Select province first; changing/clearing the province clears the ward; cancelling a picker changes nothing. Profile fields remain optional, with the existing email validation.

Persist province/ward codes as zero-padded strings and full display-name snapshots. Data schema 4 reads versions 1–3, preserves profile identity, exam catalogs/keys, result history and counters, and adds empty address fields when missing. Backups include the address; restoring previous schema-3 backups remains supported.

When adding a grade inside an exam, show a dropdown with grades 1 through 12 and one Tùy chỉnh option. Reveal a text input only for Tùy chỉnh. Require a selection or non-empty custom name, enforce existing length/duplicate checks, and preserve all previously stored grade names. Normal grade values are stored as strings 1–12 so existing context paths continue to match.

### Shadow-photo diagnostic status

The three supplied shadow photographs are preserved unchanged under test/fixtures/shadow-*.png. An offline diagnostic compared the existing reader with a background-illumination-normalized copy. All three original and normalized examples were rejected during regional alignment. The answer photograph also cuts off the far marker edge. Merely brightening/normalizing these images is insufficient to demonstrate safe reading. No experimental shadow preprocessing or changed classification thresholds are enabled in the app by this build. Further alignment and local-contrast work requires validated photo fixtures and must retain uncertain/manual-review and severe-shadow recapture behavior.

## 25. Restore teacher organization input — 30 October 2026

The user clarified that the profile must retain a free-text Đơn vị field. The current visible field order is Tên Hiển Thị, Đơn vị, Tỉnh/TP, Phường/Xã, Email, superseding section 24's four-field-only layout. The organization input is optional, limited to 200 characters and trimmed on save. Reuse the existing school storage key so old values are prefilled and remain part of backups/restores; no schema migration or identity change is needed. Retain the new cascading address pickers and the removal of the local/optional explanatory sentence.

## 26. Answer-region-only capture replaces three-part scanning — 30 October 2026

The user retired the three-capture flow because candidate-number and exam-code regional scans were unreliable. Scan mode selection now offers Quét toàn phiếu and Chỉ quét đáp án. The latter takes exactly one answer-region photograph, requiring all four local answer markers and all ten response rows. Do not capture or recognize candidate-number/exam-code regions. Remove the three-step coordinator, per-part acceptance sheet, SBD/code step chips and combined-capture draft controls from the application flow. The regional OMR implementation can retain inactive digit-region helpers/fixtures for regression work; they are not exposed in this mode.

Select an answer key before opening the camera. Show that selected code in the camera and result review and use it as the fixed grading key, including arbitrary custom/alphanumeric codes. Do not derive a code from the photograph or silently fall back to another key. If the selected key is missing/incomplete/unsupported, block confirmation and ask the teacher to return to code selection. The selection screen shows the answer-region reference image and explains that the candidate number is unknown.

After capture and image validation, go directly to the existing answer review/scoring screen. Candidate number is read-only Không xác định; hide the candidate input, candidate/code crops and editable result-code selector in this mode. Keep manual answer correction, faint/erasure review gates, blank/multiple zero scoring and explicit final score confirmation. Chụp lại đáp án returns to the same camera/context/key without saving; after saving, Quét bài tiếp theo uses the same mode/key for a new paper. Retakes/cancellation do not consume paper numbers.

The stored candidate value is an empty string representing unknown, displayed as Không xác định in result review, history and paper details; never invent a six-digit candidate number from the paper sequence. Unknown candidates are permitted at confirmation only through an explicit candidateUnknown flag. Full-sheet scanning continues to read candidate number and code, supports manual correction as before and still requires a six-digit candidate before confirmation.

Data schema 5 reads versions 1–4 and preserves profile (including organization/address), local identity, keys/catalogs, historic scores and subject counters. Schema-5 records can contain an unknown candidate; older-schema records must retain the original six-digit constraint. Backups include these records. Paper numbering remains the existing continuous per-year/session/grade/subject sequence, shared across codes and both scanning modes and persisted across restarts. Allocate only when final score confirmation is committed. History displays the number plus SBD Không xác định and supports lookup by paper number or the unknown-candidate label.

Camera remains bounded/no-scroll with tap-to-capture, torch and bottom Home access. Full-sheet image recognition, mark-classification thresholds and shadow handling are unchanged.

## 27. Confirmed deletion and personalized compact home — 30 October 2026

Add delete controls to each exam session, grade and subject card. Every delete opens an explicit confirmation naming the item, showing counts of affected descendant grades/subjects/keys/saved papers and warning that the action cannot be undone. Cancelling or dismissing changes nothing. Confirmed deletion removes only that exact hierarchy subtree, including child catalogs, configured keys, saved paper history and its scoped sequence counters. Match path components rather than textual prefixes so similarly named exams or the same exam name in another year are untouched. No year or answer-code delete control is introduced by this request.

The grading history supports single-paper deletion from a row's trash control, plus Chọn nhiều / checkbox or long-press selection / Chọn tất cả đang hiển thị / Xóa (n). Both single and batch deletion require confirmation. Stable paper IDs define the deletion set. Selection persists across searches within the same history scope; select-all affects the current filtered rows only, while the selected count and delete count include previously selected hidden rows. Changing the history context clears selections/search to avoid carrying a batch into another subject. Cancelling preserves selection; failed writes preserve all data and selection for retry. The toolbar can scroll within a bounded height on small/large-text screens. Removing saved results preserves subject sequence counters: previously used paper numbers are never reissued, even if all results were removed. Existing repository validation/persist-before-publish makes each deletion atomic. Schema remains 5 and backup format is unchanged.

The Sunrise home adds a local-time greeting using the saved display name: Chào buổi sáng (05:00–11:59), Chào buổi chiều (12:00–17:59), Chào buổi tối (18:00–04:59). Omit the name/comma when the profile has no name. Refresh while the app stays open and when it resumes; show updated profile names after returning from profile editing. Retain the approved wallpaper, function order, disabled shuffle badge, app identity and version/copyright footer.

Shrink the five equal-sized two-column function tiles in both width and default height, with text measurement allowing larger tiles when accessibility text needs space. Each function uses a separate coordinated pastel background/icon accent: peach grading, muted lilac shuffle, sage history, soft blue profile, warm sand about. The disabled shuffle remains inert and marked Sắp có. No changes to recognition, scoring, scan-mode behavior or profile fields.


## 28. User-approved version baseline — 30 October 2026

The user approved the current implementation as version 1.0.0 and explicitly requested committing and pushing it to the existing GitHub repository. Earlier 1.x labels in this document and development checkpoints describe prototype iterations; do not rewrite their historical evidence. Current package version is 1.0.0+16: preserve the monotonically increasing Android build code so the APK can update prior test installs without clearing data. Tag the source baseline v1.0.0. This version designation does not add iOS configuration, store publishing, production signing, cloud sync or previously deferred features.

## 29. Replacement phone launcher artwork — 30 October 2026

Use the user's newly supplied ChatGPT Image Oct 30, 2026, 03_42_35 PM.png as the phone launcher icon, replacing the earlier checkmark illustration. Preserve the exact source bytes at assets/branding/launcher-source.png (SHA-256 D36A079B622881D2ED4590FAD9137CAF3561CBA4AE7635329C18C4DBC39AFA30). Package it using the existing deterministic launcher generator into five legacy and five transparent adaptive foreground resources, retaining safe margins and the existing white adaptive background. No generated/redrawn replacement artwork or app-flow change is requested.

Keep the user-visible version 1.0.0; increment Android build code to 17 for an in-place update. The prior v1.0.0 source tag is not moved by this icon update.


## 30. Separate compact 40-question sheet (30 October 2026)

The 5–20 question PDF family is deferred. Add `abcd-40-compact`, version 1, alongside the existing ten-question template. The compact sheet supports full-frame scanning only; visibly disable answer-only scanning for it and enforce this restriction in camera state. Capture the complete small OMR frame, not the entire A4 document. Read its three-digit exam code, preserving leading zeros. Do not scan, request or invent a candidate number or handwritten anonymous ID. Store candidate as unknown and retain persistent per-subject paper numbering.

Allow 1–40 configured questions. Grade only the contiguous range 1..count, with the existing per-question points and mark policies. Marks beyond count do not score, subtract points, trigger review or appear in saved response lists. A mismatched/ambiguous code requires explicit teacher correction; result keys must belong to the scanned template. Do not use the initially selected code as an automatic fallback in this full mode.

Keep the ten-question template, its two scan modes, stored keys and history unchanged in meaning. Expand key storage for compact sheets while retaining existing thirty-slot keys. Preserve the source PDF and cropped raster baseline. The supplied source is visibly soft; implementation must not imply that synthetic recognition tests establish real-photo accuracy.


## 31. Compact real-photo alignment correction (30 October 2026)

Handle modest paper curvature using bounded, unique matching of all twelve compact-template markers followed by piecewise correction in the rectified plane. Retain full-frame-only scanning, unknown candidate numbers and count-limited grading. Measure compact bubble interiors/backgrounds with template-specific radii; do not reuse ten-question circle dimensions. Apply conservative code-column print-noise correction while retaining ambiguous/multiple-digit review gates. Continue rejecting incomplete frames and wrong templates. The first physical-photo regression is code 132 with responses BCABDBAC for eight active questions. This fixture and its transformed variants do not establish general camera accuracy.


## 32. User acceptance and source checkpoint (30 October 2026)

The user reported that build 19 runs satisfactorily in real-device testing and explicitly requested updating the specification and pushing the source. The accepted working package is 1.0.0+19, including the replacement launcher icon, independent compact 40-question template and real-photo recognition corrections in sections 29–31. The compact sheet remains full-frame-only, reads the three-digit exam code, does not read candidate numbers and grades only questions 1..count. The separate ten-question template retains both scan modes and its existing behavior.

Record this as user acceptance of the current tested workflow, not a broad recognition-accuracy certification or a Google Play release. Retain the original v1.0.0 tag at its existing release-baseline commit; push the new checkpoint to origin/main without moving that tag. Source, assets, tests and English specifications are included. Generated APKs, local SDK configuration, caches and signing keys remain excluded. The latest universal APK is dist/SiroMix-build-19-universal.apk (SHA-256 C214115DA807133EA9A382701F9B93BC8E5AB68E2DFE1076AF9F46372C11AD5E). Automated evidence remains 112 passing Flutter tests, clean Flutter analysis, successful universal Android build, APK signature verification and 16 KB ZIP alignment.
