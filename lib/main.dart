import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data.dart';
import 'grade_dialog.dart';
import 'ui.dart';
import 'templates.dart';
import 'scan.dart';
import 'camera_controls.dart';
import 'history.dart';
import 'profile.dart';
import 'home.dart';
import 'scan_flow.dart';
import 'navigation.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(SiroMixApp(repository: ExamRepository(AndroidStorage())));
}

class SiroMixApp extends StatelessWidget {
  const SiroMixApp({super.key, required this.repository});
  final ExamRepository repository;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SiroMix',
    debugShowCheckedModeBanner: false,
    themeMode: ThemeMode.light,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: teal,
        brightness: Brightness.light,
        primary: teal,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xfff5f7f8),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: ink, fontSize: 14),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: line),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          backgroundColor: Colors.white,
          side: const BorderSide(color: line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
    ),
    home: AppHome(repository: repository),
  );
}

class AppHome extends StatefulWidget {
  const AppHome({super.key, required this.repository});
  final ExamRepository repository;
  @override
  State<AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends State<AppHome> {
  bool loading = true, failed = false, launcher = true, busy = false;
  bool history = false, scanning = false;
  List<String> path = [];
  String? selectedCode;
  ScanMode? scanMode;
  ExamRepository get repo => widget.repository;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      failed = false;
    });
    try {
      await repo.load();
      if (!mounted) return;
      setState(() {
        path = [repo.data.children([]).first];
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          failed = true;
        });
      }
    }
  }

  Future<bool> change(void Function(ExamData) fn) async {
    if (busy) return false;
    setState(() => busy = true);
    try {
      await repo.update(fn);
      if (mounted) setState(() {});
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể lưu dữ liệu. Vui lòng thử lại.'),
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> deleteCatalogItem(String name) async {
    if (busy) return;
    final target = [...path, name];
    final type = {1: 'kì thi', 2: 'khối', 3: 'môn thi'}[path.length]!;
    final impact = repo.data.deletionImpact(target);
    final details = [
      if (target.length == 2) '${impact.grades} khối',
      if (target.length <= 3) '${impact.subjects} môn',
      '${impact.keys} mã đề',
      '${impact.papers} bài đã chấm',
    ].join(' · ');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xóa $type "$name"?'),
        content: SingleChildScrollView(
          child: Text(
            'Sẽ xóa toàn bộ dữ liệu bên trong mục này:\n'
            '$details.\n\n'
            'Không thể hoàn tác thao tác này.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final saved = await change((d) => d.deleteCatalog(target));
    if (saved && mounted) {
      setState(() {
        selectedCode = null;
        scanMode = null;
      });
    }
  }

  Widget deleteCatalogButton(String name) => IconButton(
    tooltip: 'Xóa ${{1: 'kì thi', 2: 'khối', 3: 'môn thi'}[path.length]} $name',
    onPressed: busy ? null : () => deleteCatalogItem(name),
    icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xffad4c44)),
  );

  Future<void> addName({bool year = false}) async {
    final level = year ? 0 : path.length;
    final labels = [
      'Năm học',
      'Tên kì thi',
      'Khối học',
      'Tên môn thi',
      'Mã đề',
    ];
    final titles = [
      'Thêm năm học',
      'Tạo kì thi',
      'Thêm khối',
      'Thêm môn thi',
      'Thêm mã đề',
    ];
    final hints = [
      'Ví dụ: 2027 – 2028',
      'Ví dụ: Kiểm tra tháng 11',
      'Ví dụ: 6',
      'Ví dụ: Toán',
      'Ví dụ: 132',
    ];
    final parent = year ? <String>[] : List<String>.of(path);
    final form = GlobalKey<FormState>();
    final input = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => level == 2
          ? GradeDialog(existing: repo.data.children(parent))
          : AlertDialog(
              title: Text(titles[level]),
              content: SingleChildScrollView(
                child: Form(
                  key: form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: input,
                        autofocus: true,
                        maxLength: level == 4 ? 20 : 60,
                        decoration: InputDecoration(
                          labelText: labels[level],
                          hintText: hints[level],
                        ),
                        validator: (v) =>
                            v == null ||
                                v.trim().isEmpty ||
                                repo.data.children(parent).contains(v.trim())
                            ? (level == 4
                                  ? 'Nhập mã mới, không trùng mã đã có.'
                                  : 'Vui lòng nhập tên mới, không trùng.')
                            : null,
                      ),
                      if (level == 4) ...[
                        note(
                          SheetTemplate.ten.name,
                          icon: Icons.description_outlined,
                        ),
                        note(
                          'Phiếu hiện tại đọc tự động mã 3 chữ số. Với mã khác, giáo viên chọn mã thủ công khi quét.',
                          warning: true,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () {
                    if (form.currentState!.validate()) {
                      Navigator.pop(ctx, input.text.trim());
                    }
                  },
                  child: Text(level == 4 ? 'Tạo bộ đáp án' : 'Tạo'),
                ),
              ],
            ),
    );
    // Dialog route animations may still reference its controller during disposal.
    Future<void>.delayed(const Duration(seconds: 1), input.dispose);
    if (value == null || !mounted) return;
    final ok = await change(
      (d) => level == 4 ? d.addCode(parent, value) : d.add(parent, value),
    );
    if (!ok || !mounted) return;
    if (year) {
      setState(() => path = [value]);
    } else if (level == 4) {
      await edit(value);
    } else {
      setState(() => path = [...parent, value]);
    }
  }

  Future<void> edit(String code) async {
    final contextPath = List<String>.of(path);
    selectedCode = code;
    final scanNext = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => KeyEditor(
          contextPath: contextPath,
          code: code,
          original: repo.data.codes(contextPath)[code]!,
          onHome: goHome,
          onSave: (key) => change((d) => d.saveKey(contextPath, code, key)),
        ),
      ),
    );
    if (mounted) {
      setState(() {});
      if (scanNext == true) openScan();
    }
  }

  void back() => setState(() {
    if (history || scanning) {
      history = false;
      scanning = false;
    } else if (path.length > 1) {
      path.removeLast();
      selectedCode = null;
    } else {
      launcher = true;
    }
  });
  Future<void> openProfile() async {
    final restored = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => ProfilePage(repository: repo, onHome: goHome),
      ),
    );
    if (!mounted) return;
    setState(() {
      if (restored == true) {
        path = [repo.data.children([]).first];
        selectedCode = null;
        scanning = false;
        history = false;
        launcher = true;
      }
    });
  }

  void goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      launcher = true;
      history = false;
      scanning = false;
    });
  }

  Future<void> openScan() async {
    if (path.length != 4) return;
    final keys = repo.data.codes(path);
    final template =
        keys[selectedCode]?.template ??
        (keys.isEmpty ? SheetTemplate.ten : keys.values.first.template);
    final chosen = await chooseScanMode(context, template: template);
    if (chosen == null || !mounted) return;
    scanMode = chosen;
    if (keys.isNotEmpty && !keys.containsKey(selectedCode)) {
      selectedCode = keys.keys.first;
    }
    setState(() {
      scanning = true;
      history = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading || failed) {
      return Scaffold(
        appBar: AppBar(title: const Text('SiroMix')),
        body: Center(
          child: loading
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Không thể đọc dữ liệu đã lưu. Dữ liệu chưa bị thay đổi.',
                        textAlign: TextAlign.center,
                      ),
                      action('Thử lại', load, icon: Icons.refresh),
                    ],
                  ),
                ),
        ),
      );
    }
    if (launcher) {
      return HomeLauncher(
        displayName: repo.data.profile.name,
        onGrading: () => setState(() {
          launcher = false;
          history = false;
          scanning = false;
        }),
        onHistory: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('SiroMix')),
              bottomNavigationBar: AppBottomNavigation(
                selectedIndex: 3,
                onHome: goHome,
              ),
              body: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: HistoryView(repository: repo, path: const []),
                  ),
                ),
              ),
            ),
          ),
        ),
        onProfile: openProfile,
      );
    }
    return PopScope(
      canPop: launcher,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back();
      },
      child: Scaffold(
        backgroundColor: launcher ? const Color(0xfffaf9f7) : null,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: launcher
              ? null
              : IconButton(
                  tooltip: 'Quay lại',
                  onPressed: back,
                  icon: const Icon(Icons.arrow_back),
                ),
          title: Row(
            children: [
              Icon(
                launcher
                    ? Icons.category_outlined
                    : Icons.document_scanner_outlined,
                color: launcher ? orange : teal,
                size: 24,
              ),
              const SizedBox(width: 9),
              const Flexible(
                child: Text(
                  'SiroMix',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 23),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Hồ sơ & dữ liệu',
              onPressed: busy ? null : openProfile,
              icon: const Icon(Icons.account_circle_outlined),
            ),
            const Icon(Icons.cloud_off_outlined, size: 14, color: muted),
            const Padding(
              padding: EdgeInsets.only(left: 4, right: 20),
              child: Text(
                'Offline',
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: history
                  ? HistoryView(repository: repo, path: List.of(path))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(22, 16, 22, 30),
                      children: module(),
                    ),
            ),
          ),
        ),
        bottomNavigationBar: AppBottomNavigation(
          selectedIndex: history
              ? 3
              : scanning
              ? 2
              : 1,
          onHome: busy ? null : goHome,
          onExams: () => setState(() {
            scanning = false;
            history = false;
          }),
          onScan: path.length == 4 ? openScan : null,
          onResults: () => setState(() {
            scanning = false;
            history = true;
          }),
        ),
      ),
    );
  }

  List<Widget> module() {
    final crumbs = Text(
      path.join(' / '),
      style: const TextStyle(color: muted, fontSize: 11),
    );
    if (scanning) return scanWidgets();
    final depth = path.length;
    final items = repo.data.children(path);
    if (depth == 1) {
      return [
        heading('Chấm bài trắc nghiệm'),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: path.first,
          key: ValueKey(path.first),
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Năm học',
            prefixIcon: Icon(Icons.calendar_month_outlined),
          ),
          items: repo.data
              .children([])
              .map((y) => DropdownMenuItem(value: y, child: Text(y)))
              .toList(),
          onChanged: busy
              ? null
              : (y) {
                  if (y != null) setState(() => path = [y]);
                },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: busy ? null : () => addName(year: true),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Thêm năm học'),
          ),
        ),
        sectionTitle('Kì thi của bạn', '${items.length} kì thi'),
        for (final e in items)
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    tileIcon(Icons.copy_all_outlined),
                    const Spacer(),
                    const Text(
                      'Bộ đề',
                      style: TextStyle(color: teal, fontSize: 11),
                    ),
                    deleteCatalogButton(e),
                  ],
                ),
                const SizedBox(height: 15),
                Text(
                  e,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                secondary('Năm học ${path.first}'),
                const Divider(height: 28, color: line),
                const Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Quản lý theo khối → môn → mã đề',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    ),
                    Icon(Icons.north_east, size: 16, color: muted),
                  ],
                ),
              ],
            ),
            onTap: () => setState(() => path = [...path, e]),
          ),
        action('Tạo kì thi', busy ? null : () => addName(), outline: true),
      ];
    }
    if (depth == 2) {
      return [
        crumbs,
        const SizedBox(height: 16),
        eyebrow('Kì thi'),
        heading(path.last),
        secondary('Chọn khối để mở bộ đề tương ứng.'),
        sectionTitle('Khối học', '${items.length} khối'),
        Wrap(
          spacing: 12,
          runSpacing: 0,
          children: [
            for (final g in items)
              SizedBox(
                width: tileWidth(),
                child: panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: eyebrow('KHỐI')),
                          deleteCatalogButton(g),
                        ],
                      ),
                      Text(
                        g,
                        style: const TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Chọn môn thi →',
                        style: TextStyle(color: teal, fontSize: 12),
                      ),
                    ],
                  ),
                  onTap: () => setState(() => path = [...path, g]),
                ),
              ),
          ],
        ),
        action('Thêm khối', busy ? null : () => addName(), outline: true),
      ];
    }
    if (depth == 3) {
      return [
        crumbs,
        const SizedBox(height: 16),
        eyebrow('Khối ${path.last}'),
        heading('Môn thi'),
        secondary('Đáp án được quản lý riêng theo từng khối.'),
        sectionTitle('Chọn môn', '${items.length} môn'),
        for (final m in items)
          panel(
            Row(
              children: [
                tileIcon(Icons.menu_book_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      secondary('Bộ mã đề · Phiếu ABCD'),
                    ],
                  ),
                ),
                deleteCatalogButton(m),
                const Icon(Icons.chevron_right, color: muted),
              ],
            ),
            onTap: () => setState(() => path = [...path, m]),
          ),
        action('Thêm môn thi', busy ? null : () => addName(), outline: true),
      ];
    }
    final keys = repo.data.codes(path);
    return [
      crumbs,
      const SizedBox(height: 16),
      eyebrow('Khối ${path[2]} · Bộ đề'),
      heading(path.last),
      secondary('Chọn mã để nhập đáp án và điểm mỗi câu.'),
      note(
        'Chọn loại phiếu trong cấu hình đề\nChấm trên máy · Không cần Internet',
        icon: Icons.fact_check_outlined,
      ),
      sectionTitle('Mã đề', '${keys.length} đề'),
      Wrap(
        spacing: 12,
        children: [
          for (final entry in keys.entries)
            SizedBox(
              width: tileWidth(),
              child: panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    eyebrow('MÃ ĐỀ'),
                    Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      entry.value.complete ? 'Đủ đáp án' : 'Chưa đủ đáp án',
                      style: const TextStyle(color: teal, fontSize: 11),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      '${entry.value.count} câu · ${score(entry.value.total)} điểm',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
                onTap: () => edit(entry.key),
              ),
            ),
        ],
      ),
      action('Thêm mã đề', busy ? null : () => addName(), outline: true),
      action(
        'Quét phiếu chấm bài',
        keys.isEmpty ? null : openScan,
        icon: Icons.document_scanner_outlined,
      ),
    ];
  }

  double tileWidth() =>
      (math.min(MediaQuery.sizeOf(context).width, 560) - 56) / 2;
  List<Widget> scanWidgets() {
    final keys = repo.data.codes(path);
    final code = selectedCode;
    final key = keys[code];
    return [
      Text(
        path.join(' / '),
        style: const TextStyle(color: muted, fontSize: 11),
      ),
      const SizedBox(height: 16),
      eyebrow('Chấm bài'),
      heading(
        scanMode == ScanMode.answers
            ? 'Quét vùng đáp án'
            : 'Đưa phiếu vào khung',
      ),
      secondary(
        scanMode == ScanMode.answers
            ? 'Chọn đúng mã đề trước khi chụp. Số báo danh: Không xác định.'
            : 'Đặt phiếu phẳng, đủ sáng và đủ mốc đen.',
      ),
      const SizedBox(height: 20),
      DropdownButtonFormField<String>(
        initialValue: code,
        key: ValueKey(code),
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Mã đề đang chọn'),
        items: keys.keys
            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
            .toList(),
        onChanged: (v) => setState(() {
          selectedCode = v;
          if (keys[v]?.template.supportsAnswersOnly == false) {
            scanMode = ScanMode.full;
          }
        }),
      ),
      if (key != null)
        note(key.template.name, icon: Icons.description_outlined),
      if (key?.template == SheetTemplate.compact)
        note(
          'Chỉ quét toàn khung trắc nghiệm và mã đề. Chấm câu 1–${key!.count}; các câu còn lại được bỏ qua. Số báo danh: Không xác định.',
        ),
      if (scanMode != null)
        Row(
          children: [
            Expanded(child: Text(scanMode!.label)),
            TextButton(onPressed: openScan, child: const Text('Đổi chế độ')),
          ],
        ),
      ScanActionBar(
        onCamera: key != null && key.complete && key.template.readable
            ? () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => SheetScan(
                      repository: repo,
                      contextPath: List.of(path),
                      initialCode: code!,
                      mode: scanMode ?? ScanMode.full,
                      onHome: goHome,
                    ),
                  ),
                );
                if (mounted) setState(() {});
              }
            : null,
        onEdit: key == null ? null : () => edit(code!),
      ),
      if (key != null && !key.template.readable)
        note(
          'Mẫu cũ chưa hỗ trợ quét. Chọn mẫu 10 câu hoặc phiếu gọn 40 câu trong cấu hình đề.',
          warning: true,
        ),
      if (key != null && !key.complete)
        note(
          'Mã đề chưa đủ đáp án. Quay lại bộ đề để nhập đầy đủ trước khi chấm.',
          warning: true,
        ),
      if (key != null && key.template.readable)
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            scanMode == ScanMode.answers
                ? 'assets/templates/part-answers.png'
                : key.template.preview!,
            height: 320,
            fit: BoxFit.contain,
          ),
        ),
    ];
  }
}

class KeyEditor extends StatefulWidget {
  const KeyEditor({
    super.key,
    required this.contextPath,
    required this.code,
    required this.original,
    required this.onSave,
    this.onHome,
  });
  final List<String> contextPath;
  final String code;
  final ExamKey original;
  final Future<bool> Function(ExamKey) onSave;
  final VoidCallback? onHome;
  @override
  State<KeyEditor> createState() => _KeyEditorState();
}

class _KeyEditorState extends State<KeyEditor> {
  late ExamKey keyData;
  late TextEditingController count, common;
  late List<TextEditingController> points;
  int page = 0;
  bool saving = false, dirty = false, saved = false;
  String error = '';
  int templateRevision = 0;
  @override
  void initState() {
    super.initState();
    keyData = widget.original.copy();
    count = TextEditingController(text: '${keyData.count}');
    common = TextEditingController(text: '${keyData.common}');
    points = keyData.points
        .map((v) => TextEditingController(text: '$v'))
        .toList();
  }

  @override
  void dispose() {
    count.dispose();
    common.dispose();
    for (final c in points) {
      c.dispose();
    }
    super.dispose();
  }

  Future<bool> mayLeave() async =>
      !dirty ||
      (await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Cấu hình chưa được lưu'),
              content: const Text('Bạn muốn bỏ các thay đổi chưa lưu?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Tiếp tục chỉnh sửa'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Bỏ thay đổi'),
                ),
              ],
            ),
          )) ==
          true;
  void updateCommon(String value) {
    setState(() {
      dirty = true;
      saved = false;
      // Keep the previous scores while the input is empty or invalid.
      if (!validPoints(value)) return;
      keyData.common = decimal(value)!;
      for (var i = 0; i < points.length; i++) {
        keyData.points[i] = keyData.common;
        points[i].text = value;
      }
      error = '';
    });
  }

  Future<void> editorHome() async {
    if (saving || !await mayLeave() || !mounted) return;
    setState(() => dirty = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (widget.onHome != null) {
          widget.onHome!();
        } else {
          Navigator.pop(context);
        }
      }
    });
  }

  bool sync() {
    final n = int.tryParse(count.text);
    if (n == null ||
        n < 1 ||
        n > keyData.template.capacity ||
        !validPoints(common.text) ||
        points
            .take(n.clamp(1, keyData.template.capacity))
            .any((p) => !validPoints(p.text))) {
      setState(
        () => error =
            'Số câu phải từ 1–${keyData.template.capacity}, điểm phải là số không âm.',
      );
      return false;
    }
    keyData.count = n;
    keyData.common = decimal(common.text)!;
    for (var i = 0; i < n; i++) {
      keyData.points[i] = decimal(points[i].text)!;
    }
    return true;
  }

  Future<void> save() async {
    if (!sync()) return;
    if (!keyData.complete) {
      setState(() => error = 'Cần chọn đáp án đúng cho tất cả các câu.');
      return;
    }
    setState(() => saving = true);
    final ok = await widget.onSave(keyData.copy());
    if (!mounted) return;
    setState(() {
      saving = false;
      if (ok) {
        dirty = false;
        saved = true;
        error = '';
      } else {
        error = 'Không thể lưu dữ liệu. Vui lòng thử lại.';
      }
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !dirty,
    onPopInvokedWithResult: (didPop, _) async {
      if (!didPop && await mayLeave() && context.mounted) {
        setState(() => dirty = false);
        Navigator.pop(context);
      }
    },
    child: Scaffold(
      appBar: AppBar(title: const Text('SiroMix')),
      bottomNavigationBar: AppBottomNavigation(
        selectedIndex: 1,
        onHome: saving ? null : editorHome,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(22),
              children: [
                Text(
                  widget.contextPath.join(' / '),
                  style: const TextStyle(color: muted, fontSize: 11),
                ),
                const SizedBox(height: 16),
                eyebrow('Đáp án chuẩn · Khối ${widget.contextPath[2]}'),
                heading('Mã đề ${widget.code}'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey((keyData.templateId, templateRevision)),
                  initialValue: keyData.templateId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Loại phiếu trắc nghiệm',
                  ),
                  items:
                      [
                            SheetTemplate.ten,
                            SheetTemplate.compact,
                            if (keyData.templateId == SheetTemplate.legacy.id)
                              SheetTemplate.legacy,
                          ]
                          .map(
                            (t) => DropdownMenuItem(
                              value: t.id,
                              child: Text(
                                t.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: saving
                      ? null
                      : (id) {
                          if (id == null || id == keyData.templateId) return;
                          final chosen = SheetTemplate.find(id, 1);
                          final current = int.tryParse(count.text);
                          if (current == null ||
                              current < 1 ||
                              current > chosen.capacity) {
                            setState(
                              () => error =
                                  'Giảm số câu xuống tối đa ${chosen.capacity} trước khi đổi loại phiếu. Dữ liệu cũ chưa bị thay đổi.',
                            );
                            setState(() => templateRevision++);
                            return;
                          }
                          setState(() {
                            if (chosen.capacity > keyData.answers.length) {
                              final extra =
                                  chosen.capacity - keyData.answers.length;
                              keyData.answers.addAll(List.filled(extra, ''));
                              keyData.points.addAll(
                                List.filled(extra, keyData.common),
                              );
                              points.addAll(
                                List.generate(
                                  extra,
                                  (_) => TextEditingController(
                                    text: '${keyData.common}',
                                  ),
                                ),
                              );
                            }
                            keyData.templateId = id;
                            keyData.templateVersion = 1;
                            keyData.count = current;
                            dirty = true;
                            saved = false;
                            error = '';
                          });
                        },
                ),
                const SizedBox(height: 12),
                if (keyData.template.preview != null)
                  ExpansionTile(
                    title: const Text('Xem mẫu phiếu'),
                    children: [
                      Image.asset(
                        keyData.template.preview!,
                        height: 240,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),

                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: count,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText:
                              'Số câu · tối đa ${keyData.template.capacity}',
                        ),
                        onChanged: (v) {
                          final n = int.tryParse(v);
                          setState(() {
                            dirty = true;
                            saved = false;
                            if (n != null &&
                                n >= 1 &&
                                n <= keyData.template.capacity) {
                              keyData.count = n;
                              page = math.min(page, (n - 1) ~/ 10);
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: common,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Điểm chung mỗi câu',
                        ),
                        onChanged: updateCommon,
                      ),
                    ),
                  ],
                ),
                action(
                  'Áp dụng điểm chung cho mọi câu',
                  saving
                      ? null
                      : () {
                          if (!validPoints(common.text)) {
                            setState(
                              () => error =
                                  'Số câu phải từ 1–${keyData.template.capacity}, điểm phải là số không âm.',
                            );
                            return;
                          }
                          updateCommon(common.text);
                        },
                  outline: true,
                  icon: Icons.copy,
                ),
                note(
                  'Tổng điểm: ${score(keyData.total)}\nĐiểm tự cộng từ từng câu, không chia thang điểm.',
                  icon: Icons.functions,
                ),
                sectionTitle(
                  'Đáp án & điểm',
                  '${keyData.answers.take(keyData.count).where((a) => a.isNotEmpty).length}/${keyData.count} câu đã nhập',
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (var p = 0; p < (keyData.count + 9) ~/ 10; p++)
                      ChoiceChip(
                        label: Text(
                          '${p * 10 + 1}–${math.min(keyData.count, p * 10 + 10)}',
                        ),
                        selected: p == page,
                        onSelected: (_) => setState(() => page = p),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text(
                        'Câu',
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Đáp án đúng',
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                    ),
                    SizedBox(
                      width: 66,
                      child: Text(
                        'Điểm',
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                    ),
                  ],
                ),
                for (
                  var i = page * 10;
                  i < math.min(keyData.count, page * 10 + 10);
                  i++
                )
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 30,
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(fontSize: 12, color: muted),
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              for (final a in ['A', 'B', 'C', 'D'])
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Semantics(
                                      label: 'Câu ${i + 1}, đáp án $a',
                                      selected: keyData.answers[i] == a,
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(0, 44),
                                          backgroundColor:
                                              keyData.answers[i] == a
                                              ? teal
                                              : Colors.white,
                                          foregroundColor:
                                              keyData.answers[i] == a
                                              ? Colors.white
                                              : muted,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              9,
                                            ),
                                          ),
                                        ),
                                        onPressed: saving
                                            ? null
                                            : () => setState(() {
                                                keyData.answers[i] = a;
                                                dirty = true;
                                                saved = false;
                                              }),
                                        child: Text(a),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 66,
                          child: TextField(
                            key: ValueKey('points-$i'),
                            controller: points[i],
                            textAlign: TextAlign.center,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 12,
                              ),
                              errorText: validPoints(points[i].text)
                                  ? null
                                  : '≥ 0',
                            ),
                            onChanged: (v) => setState(() {
                              dirty = true;
                              saved = false;
                              if (validPoints(v)) {
                                keyData.points[i] = decimal(v)!;
                              }
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (error.isNotEmpty)
                  Text(error, style: const TextStyle(color: Colors.red)),
                action(
                  saved ? 'Đã lưu cấu hình đề' : 'Lưu cấu hình đề',
                  saving ? null : save,
                  icon: Icons.check,
                ),
                action(
                  'Quét với mã đề này',
                  saving
                      ? null
                      : () async {
                          if (dirty || !keyData.complete) {
                            await save();
                          }
                          if (!dirty && keyData.complete && context.mounted) {
                            Navigator.pop(context, true);
                          }
                        },
                  outline: true,
                  icon: Icons.document_scanner_outlined,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
