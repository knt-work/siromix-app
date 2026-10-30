import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'camera_controls.dart';
import 'camera_guidance.dart';
import 'data.dart';
import 'omr.dart';
import 'templates.dart';
import 'ui.dart';
import 'scan_flow.dart';
import 'navigation.dart';

class SheetScan extends StatefulWidget {
  const SheetScan({
    super.key,
    required this.repository,
    required this.contextPath,
    required this.initialCode,
    this.mode = ScanMode.full,
    this.onHome,
  });
  final ExamRepository repository;
  final List<String> contextPath;
  final String initialCode;
  final ScanMode mode;
  final VoidCallback? onHome;
  @override
  State<SheetScan> createState() => _SheetScanState();
}

class _SheetScanState extends State<SheetScan> with WidgetsBindingObserver {
  CameraController? camera;
  late ScanMode mode;
  double get guideAspect =>
      mode == ScanMode.answers ? SheetPart.answers.aspect : 1067 / 1549;
  String? failure;
  bool processing = false,
      away = false,
      active = true,
      initializing = false,
      torchOn = false,
      torchBusy = false;
  int generation = 0, probeRevision = 0, probeNumber = 0, streamOperations = 0;
  int? activeProbe;
  int sessionCount = 0;
  Future<void> closing = Future.value();
  final guide = GuideTracker();
  bool modalOpen = false;
  Size? viewport;
  DateTime lastSample = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? freshnessTimer;

  void invalidateGuide() {
    probeRevision++;
    guide.reset();
    lastSample = DateTime.now();
  }

  double displayAspect(CameraController c) {
    final orientation =
        c.value.previewPauseOrientation ??
        c.value.lockedCaptureOrientation ??
        c.value.deviceOrientation;
    final landscape =
        orientation == DeviceOrientation.landscapeLeft ||
        orientation == DeviceOrientation.landscapeRight;
    return landscape ? c.value.aspectRatio : 1 / c.value.aspectRatio;
  }

  void streamBusy(int change) {
    if (mounted) {
      setState(() => streamOperations += change);
    } else {
      streamOperations += change;
    }
  }

  Future<void> stopFrameStream(CameraController c) async {
    if (!c.value.isInitialized || !c.value.isStreamingImages) return;
    streamBusy(1);
    try {
      await c.stopImageStream();
    } finally {
      streamBusy(-1);
    }
  }

  Future<void> startFrameStream(CameraController c) async {
    if (!mounted ||
        !active ||
        processing ||
        away ||
        camera != c ||
        c.value.isStreamingImages) {
      return;
    }
    if (!c.supportsImageStreaming()) {
      setState(guide.unavailable);
      return;
    }
    streamBusy(1);
    try {
      await c.startImageStream((frame) {
        unawaited(analyzeFrame(c, frame));
      });
    } catch (e) {
      if (mounted && camera == c) setState(guide.unavailable);
    } finally {
      streamBusy(-1);
    }
  }

  Future<void> analyzeFrame(CameraController c, CameraImage frame) async {
    if (!mounted ||
        !active ||
        processing ||
        away ||
        modalOpen ||
        torchBusy ||
        camera != c ||
        activeProbe != null) {
      return;
    }
    final received = DateTime.now();
    if (received.difference(lastSample) < const Duration(milliseconds: 450)) {
      return;
    }
    lastSample = received;
    final id = ++probeNumber,
        epoch = generation,
        revision = probeRevision,
        aspect = displayAspect(c);
    activeProbe = id;
    try {
      final format = frame.format.group;
      final bgra = format == ImageFormatGroup.bgra8888;
      if (frame.planes.isEmpty ||
          (!bgra &&
              format != ImageFormatGroup.yuv420 &&
              format != ImageFormatGroup.nv21)) {
        if (mounted && camera == c) setState(guide.unavailable);
        return;
      }
      final plane = frame.planes.first;
      final input = sampleLuminance(
        bytes: plane.bytes,
        width: frame.width,
        height: frame.height,
        rowStride: plane.bytesPerRow,
        pixelStride: plane.bytesPerPixel ?? (bgra ? 4 : 1),
        bgra: bgra,
      );
      input['part'] = SheetPart.answers.name;
      final probe = await compute(
        mode == ScanMode.full ? probeTenSheet : probeTenPart,
        input,
      );
      if (!mounted ||
          !active ||
          processing ||
          camera != c ||
          epoch != generation ||
          revision != probeRevision) {
        return;
      }
      if (DateTime.now().difference(received) > GuideTracker.lifetime ||
          (aspect - displayAspect(c)).abs() > .001) {
        setState(guide.reset);
        return;
      }
      final size = viewport;
      if (size != null) {
        final matches = CameraGuideLayout(
          size,
          aspect,
          markerAspect: guideAspect,
        ).containsSheet(probe, flexible: mode == ScanMode.answers);
        setState(() => guide.observe(matches, received));
      }
    } catch (e) {
      if (mounted &&
          camera == c &&
          epoch == generation &&
          revision == probeRevision) {
        setState(guide.unavailable);
      }
    } finally {
      if (activeProbe == id) activeProbe = null;
    }
  }

  Future<void> closeCamera(CameraController? c) {
    if (c == null) return closing;
    final operation = closing.then((_) async {
      try {
        await stopFrameStream(c);
      } catch (e) {
        debugPrint('Frame stream cleanup: $e');
      }
      try {
        if (c.value.isInitialized && c.value.flashMode != FlashMode.off) {
          await c.setFlashMode(FlashMode.off);
        }
      } catch (_) {}
      try {
        await c.dispose();
      } catch (e) {
        debugPrint('Camera cleanup: $e');
      }
    });
    closing = operation;
    return operation;
  }

  @override
  void initState() {
    super.initState();
    mode = widget.mode;
    WidgetsBinding.instance.addObserver(this);
    freshnessTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (mounted && active && !processing && guide.expire(DateTime.now())) {
        setState(() {});
      }
    });
    initialize();
  }

  @override
  void dispose() {
    generation++;
    invalidateGuide();
    freshnessTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    active = false;
    closeCamera(camera);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      active = false;
      invalidateGuide();
      final old = camera;
      if (old != null && old.value.isInitialized) {
        generation++;
        camera = null;
        torchOn = false;
        closeCamera(old);
      }
    } else if (state == AppLifecycleState.resumed) {
      active = true;
      if (!processing && !away) initialize();
    }
  }

  Future<void> initialize() async {
    if (initializing || !active || away || processing || !mounted) return;
    initializing = true;
    final token = ++generation;
    final previous = camera;
    camera = null;
    invalidateGuide();
    CameraController? next;
    try {
      await closeCamera(previous);
      if (!mounted || token != generation || !active) return;
      setState(() {
        failure = null;
        torchOn = false;
        torchBusy = false;
      });
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw CameraException('NoCamera', 'No camera');
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      next = CameraController(
        back,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      // Do not time out while the user is reading the permission dialog.
      await next.initialize();
      if (!mounted || token != generation || !active) {
        await closeCamera(next);
        return;
      }
      await next.setFlashMode(FlashMode.off);
      setState(() => camera = next);
      await startFrameStream(next);
    } catch (e) {
      await closeCamera(next);
      if (!mounted || token != generation) return;
      setState(
        () => failure =
            e is CameraException && e.code.toLowerCase().contains('denied')
            ? 'Vui lòng cấp quyền camera trong Cài đặt ứng dụng, rồi thử lại.'
            : 'Không mở được camera. Kiểm tra quyền truy cập và thử lại.',
      );
    } finally {
      initializing = false;
    }
  }

  Future<void> toggleTorch() async {
    final c = camera;
    if (c == null ||
        !c.value.isInitialized ||
        processing ||
        torchBusy ||
        streamOperations > 0) {
      return;
    }
    final epoch = generation, wanted = !torchOn;
    setState(() {
      torchBusy = true;
      invalidateGuide();
    });
    try {
      await c.setFlashMode(wanted ? FlashMode.torch : FlashMode.off);
      if (mounted && camera == c && epoch == generation) {
        setState(() => torchOn = wanted);
      }
    } catch (e) {
      if (mounted && camera == c) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không đổi được đèn trên camera này. Vui lòng thử lại.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => torchBusy = false);
    }
  }

  Future<void> capture() async {
    final c = camera;
    final captureMode = mode;
    if (c == null ||
        !c.value.isInitialized ||
        processing ||
        !active ||
        away ||
        modalOpen ||
        torchBusy ||
        streamOperations > 0) {
      return;
    }
    setState(() {
      processing = true;
      failure = null;
      invalidateGuide();
    });
    XFile? photo;
    try {
      // Still capture and the preview checker must not race over camera streams.
      await stopFrameStream(c);
      photo = await c.takePicture();
      final bytes = await photo.readAsBytes();
      final reference = await rootBundle.load(SheetTemplate.ten.preview!);
      if (captureMode == ScanMode.answers) {
        final read = await compute(recognizeTenPart, <String, Object>{
          'photo': bytes,
          'reference': reference.buffer.asUint8List(),
          'part': SheetPart.answers.name,
        });
        if (!mounted) return;
        away = true;
        generation++;
        camera = null;
        await closeCamera(c);
        if (!mounted) return;
        await showRead(answersOnlyRead(read), fixedCode: widget.initialCode);
      } else {
        final read = await compute(recognizeTenSheet, {
          'photo': bytes,
          'reference': reference.buffer.asUint8List(),
        });
        if (!mounted) return;
        away = true;
        generation++;
        camera = null;
        await closeCamera(c);
        if (mounted) await showRead(read);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => failure = e is OmrException
              ? e.message
              : 'Không đọc được phiếu. Giữ phiếu phẳng, đủ sáng và chụp lại.',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$failure Chạm màn hình để chụp lại.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (photo != null) {
        try {
          await File(photo.path).delete();
        } catch (_) {}
      }
      away = false;
      if (mounted) {
        setState(() => processing = false);
        if (camera == null && active) {
          await initialize();
        } else if (camera == c && active) {
          await startFrameStream(c);
        }
      }
    }
  }

  Future<void> showRead(OmrRead read, {String? fixedCode}) async {
    final previousCount = widget.repository.data.papers.length;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => ScannedResult(
          repository: widget.repository,
          contextPath: widget.contextPath,
          read: read,
          onHome: widget.onHome,
          fixedCode: fixedCode,
        ),
      ),
    );
    final saved = widget.repository.data.papers.length - previousCount;
    sessionCount += saved;
    invalidateGuide();
  }

  Future<void> changeMode() async {
    if (processing || modalOpen) return;
    setState(() {
      modalOpen = true;
      invalidateGuide();
    });
    try {
      final chosen = await chooseScanMode(context);
      if (chosen == null || chosen == mode || !mounted) return;
      if (mounted) {
        setState(() {
          mode = chosen;
          failure = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          modalOpen = false;
          invalidateGuide();
        });
      }
    }
  }

  Future<void> scanHome() async {
    if (processing || modalOpen) return;
    setState(() {
      modalOpen = true;
      invalidateGuide();
    });
    try {
      if (!mounted) return;
      if (widget.onHome != null) {
        widget.onHome!();
      } else {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() {
          modalOpen = false;
          invalidateGuide();
        });
      }
    }
  }

  Widget cameraViewport() {
    Widget overlay() {
      final c = camera, ready = c?.value.isInitialized == true;
      final aspect = ready ? displayAspect(c!) : .75;
      return LayoutBuilder(
        builder: (context, constraints) {
          viewport = constraints.biggest;
          return CaptureOverlay(
            imageAspect: aspect,
            guideAspect: guideAspect,
            onCapture:
                ready &&
                    !processing &&
                    !torchBusy &&
                    !modalOpen &&
                    streamOperations == 0
                ? capture
                : null,
            verdict: guide.verdict,
            ready: ready,
            processing: processing,
            torchOn: torchOn,
            onTorch: ready && !processing && !torchBusy && streamOperations == 0
                ? toggleTorch
                : null,
            preview: ready
                ? Center(
                    child: AspectRatio(
                      aspectRatio: aspect,
                      child: CameraPreview(c!),
                    ),
                  )
                : const ColoredBox(color: Color(0xffdbe3e3)),
          );
        },
      );
    }

    final c = camera;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: c == null
          ? overlay()
          : ValueListenableBuilder<CameraValue>(
              valueListenable: c,
              builder: (_, value, child) => overlay(),
            ),
    );
  }

  Future<void> showGuide() async {
    if (processing || modalOpen) return;
    setState(() => modalOpen = true);
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading('Hướng dẫn chụp'),
                if (mode == ScanMode.answers)
                  Image.asset(
                    'assets/templates/part-answers.png',
                    height: 240,
                    fit: BoxFit.contain,
                  ),
                secondary(
                  mode == ScanMode.full
                      ? 'Đưa đủ bốn mốc ngoài cùng của trang 1 vào vùng camera. Phần tự luận không được chấm.'
                      : 'Đưa đủ 4 mốc đen và toàn bộ 10 hàng đáp án vào vùng camera. Bài được chấm theo mã đề ${widget.initialCode}; số báo danh là Không xác định. Không cần chụp số báo danh hoặc mã đề.',
                ),
                secondary(
                  'Giữ phiếu phẳng, đủ sáng và điện thoại song song với phiếu. Chạm vùng camera để chụp. Màu khung chỉ hỗ trợ căn phiếu; ảnh sẽ được kiểm tra lại sau khi chụp.',
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Đã hiểu'),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => modalOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('SiroMix')),
    bottomNavigationBar: AppBottomNavigation(
      selectedIndex: 2,
      onHome: processing ? null : scanHome,
    ),
    body: CameraScreenLayout(
      title: mode == ScanMode.full ? 'Đưa phiếu vào khung' : 'Quét vùng đáp án',
      modeLabel: mode == ScanMode.answers
          ? '${mode.label} · Mã đề ${widget.initialCode}'
          : mode.label,
      onMode: processing || modalOpen ? null : changeMode,
      onHelp: processing || modalOpen ? null : showGuide,
      preview: cameraViewport(),
      message: failure,
      onRetry: failure != null && camera == null && !processing
          ? initialize
          : null,
    ),
  );
}

class ScannedResult extends StatefulWidget {
  const ScannedResult({
    super.key,
    required this.repository,
    required this.contextPath,
    required this.read,
    this.onHome,
    this.fixedCode,
  });
  final ExamRepository repository;
  final List<String> contextPath;
  final OmrRead read;
  final VoidCallback? onHome;
  final String? fixedCode;
  @override
  State<ScannedResult> createState() => _ScannedResultState();
}

class _ScannedResultState extends State<ScannedResult> {
  late TextEditingController candidate;
  late List<ResponseMark> responses;
  String? selectedCode;
  int? paperNumber;
  bool confirming = false;
  String? error;
  final form = GlobalKey<FormState>();
  bool get answersOnly => widget.fixedCode != null;
  Map<String, ExamKey> get keys => Map.fromEntries(
    widget.repository.data
        .codes(widget.contextPath)
        .entries
        .where(
          (e) =>
              e.value.templateId == SheetTemplate.ten.id &&
              e.value.templateVersion == 1 &&
              e.value.complete,
        ),
  );
  GradeResult? get result =>
      selectedCode == null || !keys.containsKey(selectedCode)
      ? null
      : GradeResult(
          keys[selectedCode]!,
          responses.take(keys[selectedCode]!.count).toList(),
        );
  @override
  void initState() {
    super.initState();
    candidate = TextEditingController(
      text: !answersOnly && widget.read.candidateClear
          ? widget.read.candidateText
          : '',
    );
    responses = List.of(widget.read.answers);
    if (answersOnly) {
      if (keys.containsKey(widget.fixedCode)) selectedCode = widget.fixedCode;
    } else if (widget.read.codeClear &&
        keys.containsKey(widget.read.codeText)) {
      selectedCode = widget.read.codeText;
    }
  }

  @override
  void dispose() {
    candidate.dispose();
    super.dispose();
  }

  Future<void> review(int index) async {
    final value = await showModalBottomSheet<ResponseMark>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              eyebrow('Kiểm tra thủ công'),
              heading('Câu ${index + 1}'),
              Image.memory(
                widget.read.answerCrops[index],
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
              const SizedBox(height: 16),
              const Text('Phiếu thực tế tô đáp án nào?'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final a in ['A', 'B', 'C', 'D'])
                    OutlinedButton(
                      onPressed: () =>
                          Navigator.pop(ctx, ResponseMark(MarkState.single, a)),
                      child: Text(a),
                    ),
                ],
              ),
              action(
                'Xác nhận bỏ trống · 0 điểm',
                () => Navigator.pop(ctx, const ResponseMark(MarkState.blank)),
                outline: true,
                icon: Icons.circle_outlined,
              ),
              action(
                'Không hợp lệ / nhiều ô · 0 điểm',
                () =>
                    Navigator.pop(ctx, const ResponseMark(MarkState.multiple)),
                outline: true,
                icon: Icons.block,
              ),
            ],
          ),
        ),
      ),
    );
    if (value != null && mounted) setState(() => responses[index] = value);
  }

  Widget answerRow(int index, ExamKey key) {
    final response = responses[index];
    final pending = response.state == MarkState.uncertain;
    final correct =
        response.state == MarkState.single &&
        response.answer == key.answers[index];
    final background = pending
        ? const Color(0xfffff5db)
        : correct
        ? const Color(0xffe7f5e9)
        : const Color(0xffffebee);
    final foreground = pending
        ? const Color(0xff795500)
        : correct
        ? const Color(0xff256436)
        : const Color(0xffa12838);
    final chosen = switch (response.state) {
      MarkState.single => 'Chọn ${response.answer}',
      MarkState.blank => 'Bỏ trống · 0 điểm',
      MarkState.multiple => 'Nhiều đáp án · 0 điểm',
      MarkState.uncertain => 'Cần kiểm tra',
    };
    final status = pending
        ? 'Cần kiểm tra'
        : correct
        ? 'Đúng'
        : 'Sai';
    return Container(
      key: ValueKey('answer-row-$index'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: Text(
          'Câu ${index + 1} - $chosen',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Đáp án đúng: ${key.answers[index]} · $status',
          style: TextStyle(color: foreground, fontSize: 12),
        ),
        trailing: paperNumber == null
            ? TextButton(
                onPressed: confirming ? null : () => review(index),
                child: Text(pending ? 'Kiểm tra' : 'Xem lại'),
              )
            : null,
      ),
    );
  }

  Future<void> confirm() async {
    if (confirming || paperNumber != null) return;
    if (!form.currentState!.validate() ||
        result == null ||
        !result!.canConfirm) {
      return;
    }
    setState(() {
      confirming = true;
      error = null;
    });
    try {
      int? allocated;
      await widget.repository.update(
        (d) => allocated = d
            .confirmPaper(
              path: widget.contextPath,
              candidate: answersOnly ? '' : candidate.text,
              candidateUnknown: answersOnly,
              code: selectedCode!,
              responses: responses.take(keys[selectedCode]!.count).toList(),
            )
            .number,
      );
      if (mounted) setState(() => paperNumber = allocated);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Không thể lưu bài chấm. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => confirming = false);
    }
  }

  Future<void> resultHome() async {
    if (confirming) return;
    if (paperNumber == null &&
        !await confirmLeaveDraft(
          context,
          'Bài này chưa được lưu. Về Trang chủ và bỏ kết quả đang kiểm tra?',
        )) {
      return;
    }
    if (!mounted) return;
    if (widget.onHome != null) {
      widget.onHome!();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final graded = result;
    return PopScope(
      canPop: !confirming,
      child: Scaffold(
        appBar: AppBar(title: const Text('SiroMix')),
        bottomNavigationBar: AppBottomNavigation(
          selectedIndex: 3,
          onHome: confirming ? null : resultHome,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: form,
                child: ListView(
                  padding: const EdgeInsets.all(22),
                  children: [
                    Text(
                      widget.contextPath.join(' / '),
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                    const SizedBox(height: 16),
                    eyebrow(
                      paperNumber == null
                          ? 'Kết quả đọc phiếu'
                          : 'Bài số $paperNumber',
                    ),
                    if (paperNumber != null)
                      note(
                        'Đã lưu kết quả trên thiết bị.',
                        icon: Icons.save_outlined,
                      ),
                    heading(
                      paperNumber == null
                          ? 'Kiểm tra bài chấm'
                          : 'Đã xác nhận điểm',
                    ),
                    if (!answersOnly && !widget.read.candidateClear)
                      note(
                        'Số báo danh cần kiểm tra. Đối chiếu ảnh và nhập đủ 6 chữ số.',
                        warning: true,
                      ),
                    if (answersOnly) ...[
                      secondary('Số báo danh: Không xác định'),
                      secondary('Mã đề đã chọn: ${widget.fixedCode}'),
                      if (paperNumber == null)
                        secondary('Số thứ tự bài được cấp khi xác nhận điểm.'),
                      if (selectedCode == null)
                        note(
                          'Mã đề đã chọn không còn hợp lệ. Quay lại để chọn mã đề.',
                          warning: true,
                        ),
                    ] else if (paperNumber == null) ...[
                      ExpansionTile(
                        title: const Text('Ảnh số báo danh và mã đề'),
                        tilePadding: EdgeInsets.zero,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: Image.memory(widget.read.candidateCrop),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Image.memory(widget.read.codeCrop),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                      TextFormField(
                        controller: candidate,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Số báo danh',
                        ),
                        validator: (v) =>
                            v != null && RegExp(r'^\d{6}$').hasMatch(v)
                            ? null
                            : 'Nhập đủ 6 chữ số theo phiếu.',
                      ),
                      if (!widget.read.codeClear ||
                          !keys.containsKey(widget.read.codeText))
                        note(
                          'Mã đề đọc được: ${widget.read.codeText}. Chọn bộ đáp án đúng trước khi xác nhận.',
                          warning: true,
                        ),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCode,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Mã đề'),
                        items: keys.keys
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: confirming
                            ? null
                            : (c) => setState(() => selectedCode = c),
                        validator: (v) =>
                            v == null ? 'Chọn mã đề có đủ đáp án.' : null,
                      ),
                    ] else
                      secondary('SBD ${candidate.text} · Mã đề $selectedCode'),
                    if (graded != null) ...[
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 20),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: soft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Text(
                              paperNumber == null
                                  ? 'Điểm tạm tính'
                                  : 'Tổng điểm',
                              style: const TextStyle(color: teal),
                            ),
                            Text(
                              score(graded.score),
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w700,
                                color: teal,
                              ),
                            ),
                            Text(
                              '/ ${score(graded.key.total)}',
                              style: const TextStyle(color: teal),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${graded.correct} / ${graded.key.count} câu đúng',
                              style: const TextStyle(color: teal),
                            ),
                          ],
                        ),
                      ),
                      Wrap(
                        spacing: 18,
                        runSpacing: 10,
                        children: [
                          for (final e in {
                            'Đúng': graded.correct,
                            'Sai': graded.wrong,
                            'Không hợp lệ / trống': graded.invalid,
                            'Cần kiểm tra': graded.pending,
                          }.entries)
                            Text(
                              '${e.key}: ${e.value}',
                              style: const TextStyle(
                                color: muted,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      if (graded.pending > 0)
                        note(
                          '${graded.pending} câu cần giáo viên kiểm tra\nTô mờ hoặc tẩy chưa sạch. Xử lý từng câu trước khi xác nhận điểm.',
                          warning: true,
                        ),
                      const SizedBox(height: 20),
                      const Text(
                        'Đáp án đọc được',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      for (var i = 0; i < graded.key.count; i++)
                        answerRow(i, graded.key),
                      if (error != null) note(error!, warning: true),
                      if (paperNumber == null)
                        action(
                          'Xác nhận điểm',
                          graded.canConfirm && !confirming ? confirm : null,
                          icon: Icons.check,
                        ),
                    ] else
                      note(
                        'Chọn mã đề có đủ đáp án để tính điểm.',
                        warning: true,
                      ),
                    if (answersOnly && paperNumber == null)
                      action(
                        'Chụp lại đáp án',
                        confirming ? null : () => Navigator.pop(context, false),
                        outline: true,
                        icon: Icons.refresh,
                      ),
                    action(
                      'Quét bài tiếp theo',
                      confirming || paperNumber == null
                          ? null
                          : () => Navigator.pop(context, true),
                      outline: true,
                      icon: Icons.document_scanner_outlined,
                    ),
                    note(
                      'Bỏ trống: 0 điểm\nTô nhiều đáp án: 0 điểm\nTô mờ / tẩy chưa sạch: kiểm tra thủ công',
                    ),
                    const Text(
                      'Kết quả được lưu khi xác nhận điểm. Xuất Excel sẽ bổ sung sau.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
