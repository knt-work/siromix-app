import 'package:flutter/material.dart';

import 'data.dart';
import 'templates.dart';
import 'ui.dart';
import 'navigation.dart';

class QmKeyEditor extends StatefulWidget {
  const QmKeyEditor({
    super.key,
    required this.contextPath,
    required this.code,
    required this.original,
    required this.onSave,
    required this.onTemplateChanged,
    this.onHome,
    this.initialDirty = false,
  });
  final List<String> contextPath;
  final String code;
  final ExamKey original;
  final Future<bool> Function(ExamKey) onSave;
  final void Function(ExamKey) onTemplateChanged;
  final VoidCallback? onHome;
  final bool initialDirty;
  @override
  State<QmKeyEditor> createState() => _QmKeyEditorState();
}

class _QmKeyEditorState extends State<QmKeyEditor> {
  late ExamKey keyData;
  QmParts get p => keyData.parts;
  final fields = <String, TextEditingController>{};
  final fieldScrolls = <String, ScrollController>{};
  bool dirty = false, saving = false, saved = false;
  String error = '';
  int templateRevision = 0;
  TextEditingController field(String id) => fields[id]!;
  @override
  void initState() {
    super.initState();
    keyData = widget.original.copy();
    dirty = widget.initialDirty;
    final values = <String, String>{
      'n1': '${keyData.count}',
      'n2': '${p.twoCount}',
      'n3': '${p.threeCount}',
      'p1': '${keyData.common}',
      'p3': '${p.threeCommon}',
      for (var i = 1; i <= 4; i++) 'r$i': '${p.rates[i]}',
      for (var i = 0; i < 40; i++) 'i$i': '${keyData.points[i]}',
      for (var i = 0; i < 6; i++) 's$i': p.threeAnswers[i],
      for (var i = 0; i < 6; i++) 'v$i': '${p.threePoints[i]}',
    };
    values.forEach((k, v) {
      fields[k] = TextEditingController(text: v);
      fieldScrolls[k] = ScrollController(keepScrollOffset: false);
    });
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    for (final scroll in fieldScrolls.values) {
      scroll.dispose();
    }
    super.dispose();
  }

  void edit(VoidCallback fn) => setState(() {
    fn();
    dirty = true;
    saved = false;
    error = '';
  });
  Future<bool> leave() async =>
      !dirty ||
      await confirmLeaveDraft(
        context,
        'Cấu hình mã đề chưa được lưu. Bạn muốn bỏ các thay đổi?',
      );
  Future<void> home() async {
    if (saving || !await leave() || !mounted) return;
    setState(() => dirty = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.onHome != null) {
        widget.onHome!();
      } else {
        Navigator.pop(context);
      }
    });
  }

  void common(String part, String text) {
    if (!validPoints(text)) return;
    final n = decimal(text)!;
    if (part == '1') {
      keyData.common = n;
      for (var i = 0; i < 40; i++) {
        keyData.points[i] = n;
        field('i$i').text = text;
      }
    }
    if (part == '3') {
      p.threeCommon = n;
      for (var i = 0; i < 6; i++) {
        p.threePoints[i] = n;
        field('v$i').text = text;
      }
    }
  }

  void maximum(String text) {
    if (!validPoints(text)) return;
    final next = decimal(text)!, old = p.rates[4];
    for (var i = 1; i < 4; i++) {
      final value = next * (old > 0 ? p.rates[i] / old : [0, .1, .25, .5][i]);
      p.rates[i] = (value * 1000000).round() / 1000000;
      field('r$i').text = '${p.rates[i]}';
    }
    p.rates[4] = next;
  }

  bool commitRates() {
    final values = [
      0.0,
      for (var i = 1; i <= 4; i++) decimal(field('r$i').text) ?? -1,
    ];
    if (values.any((v) => !v.isFinite || v < 0) ||
        List.generate(4, (i) => values[i] > values[i + 1]).any((v) => v)) {
      return false;
    }
    for (var i = 1; i <= 4; i++) {
      p.rates[i] = values[i];
    }
    return true;
  }

  bool sync() {
    bool count(String id, int max) {
      final n = int.tryParse(field(id).text);
      return n != null && n >= 1 && n <= max;
    }

    if (!count('n1', 40) ||
        !validPoints(field('p1').text) ||
        (p.twoEnabled &&
            (!count('n2', 8) ||
                List.generate(
                  4,
                  (i) => field('r${i + 1}').text,
                ).any((s) => !validPoints(s)))) ||
        (p.threeEnabled &&
            (!count('n3', 6) || !validPoints(field('p3').text)))) {
      setState(() => error = 'Kiểm tra số câu và điểm của các phần đang bật.');
      return false;
    }
    keyData.count = int.parse(field('n1').text);
    keyData.common = decimal(field('p1').text)!;
    if (p.twoEnabled) {
      if (!commitRates()) {
        setState(
          () => error =
              'Điểm Đúng/Sai phải tăng hoặc bằng nhau từ 1 đến 4 ý đúng.',
        );
        return false;
      }
      p.twoCount = int.parse(field('n2').text);
    }
    if (p.threeEnabled) {
      p.threeCount = int.parse(field('n3').text);
      p.threeCommon = decimal(field('p3').text)!;
    }
    for (var i = 0; i < keyData.count; i++) {
      if (!validPoints(field('i$i').text)) {
        setState(() => error = 'Điểm Phần I phải là số không âm.');
        return false;
      }
      keyData.points[i] = decimal(field('i$i').text)!;
    }
    if (p.threeEnabled) {
      for (var i = 0; i < p.threeCount; i++) {
        final answer = field('s$i').text.trim();
        if ((answer.isNotEmpty && !fitsNumberGrid(answer)) ||
            !validPoints(field('v$i').text)) {
          setState(
            () => error =
                'Phần III: đáp án phải là số vừa 4 ô tô; điểm không âm.',
          );
          return false;
        }
        p.threeAnswers[i] = answer;
        p.threePoints[i] = decimal(field('v$i').text)!;
      }
    }
    if (!p.valid) {
      setState(
        () =>
            error = 'Điểm Đúng/Sai phải tăng hoặc bằng nhau từ 1 đến 4 ý đúng.',
      );
      return false;
    }
    return true;
  }

  Future<void> save() async {
    if (saving || !sync()) return;
    if (!keyData.complete) {
      setState(
        () => error =
            'Cần nhập đủ đáp án cho tất cả các câu trong những phần đang bật.',
      );
      return;
    }
    setState(() => saving = true);
    try {
      final ok = await widget.onSave(keyData.copy());
      if (mounted) {
        setState(() {
          saving = false;
          saved = ok;
          dirty = !ok;
          error = ok ? '' : 'Không thể lưu dữ liệu. Vui lòng thử lại.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = 'Không thể lưu dữ liệu. Vui lòng thử lại.';
        });
      }
    }
  }

  Widget input(
    String id,
    String label, {
    bool integer = false,
    void Function(String)? onChanged,
    bool answer = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: const TextStyle(color: muted, fontSize: 12, height: 1.4),
      ),
      const SizedBox(height: 8),
      SiroInput(
        child: TextField(
          key: ValueKey('qm-$id'),
          controller: field(id),
          scrollController: fieldScrolls[id],
          enabled: !saving,
          keyboardType: TextInputType.numberWithOptions(
            decimal: !integer,
            signed: answer,
          ),
          decoration: const InputDecoration(),
          onChanged: (v) => edit(() {
            onChanged?.call(v);
          }),
        ),
      ),
    ],
  );

  Widget pair(Widget first, Widget second) => LayoutBuilder(
    builder: (context, box) => MediaQuery.textScalerOf(context).scale(14) > 20
        ? Column(children: [first, const SizedBox(height: 12), second])
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: first),
              const SizedBox(width: 12),
              Expanded(child: second),
            ],
          ),
  );
  Widget structure(
    int part,
    String title,
    String subtitle,
    Widget body, {
    bool? enabled,
  }) => panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            tileIcon(
              part == 1
                  ? Icons.list_alt
                  : part == 2
                  ? Icons.check_circle_outline
                  : Icons.numbers,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  secondary(subtitle),
                ],
              ),
            ),
            if (enabled == null)
              const Text(
                'Bắt buộc',
                style: TextStyle(color: teal, fontSize: 11),
              )
            else
              Switch(
                key: ValueKey('qm-toggle-$part'),
                value: enabled,
                onChanged: saving
                    ? null
                    : (v) => edit(() {
                        if (part == 2) {
                          p.twoEnabled = v;
                        } else {
                          p.threeEnabled = v;
                        }
                      }),
              ),
          ],
        ),
        if (enabled == false) ...[
          const SizedBox(height: 12),
          secondary('Không chấm phần này'),
        ] else ...[
          const SizedBox(height: 20),
          body,
        ],
      ],
    ),
  );
  Widget choices(int i) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: pair(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Câu ${i + 1}',
            style: const TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (final a in ['A', 'B', 'C', 'D'])
                SizedBox(
                  width: 36,
                  height: 40,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: keyData.answers[i] == a
                          ? teal
                          : Colors.white,
                      foregroundColor: keyData.answers[i] == a
                          ? Colors.white
                          : muted,
                    ),
                    onPressed: saving
                        ? null
                        : () => edit(() => keyData.answers[i] = a),
                    child: Text(a),
                  ),
                ),
            ],
          ),
        ],
      ),
      input(
        'i$i',
        'Điểm câu ${i + 1}',
        onChanged: (v) {
          if (validPoints(v)) keyData.points[i] = decimal(v)!;
        },
      ),
    ),
  );
  Widget tfAnswers(int i) {
    final current = p.twoAnswers[i].padRight(4, '_');
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Câu ${i + 1}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          for (var j = 0; j < 4; j++)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Text('${String.fromCharCode(97 + j)})'),
                  const SizedBox(width: 14),
                  for (final a in ['T', 'F'])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: OutlinedButton(
                          key: ValueKey('qm-tf-$i-$j-$a'),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: current[j] == a
                                ? teal
                                : Colors.white,
                            foregroundColor: current[j] == a
                                ? Colors.white
                                : muted,
                          ),
                          onPressed: saving
                              ? null
                              : () => edit(() {
                                  final next = current.split('');
                                  next[j] = a;
                                  p.twoAnswers[i] = next.join();
                                }),
                          child: Text(a == 'T' ? 'Đúng' : 'Sai'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !dirty && !saving,
    onPopInvokedWithResult: (didPop, _) async {
      if (!didPop && !saving && await leave() && context.mounted) {
        setState(() => dirty = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) Navigator.pop(context);
        });
      }
    },
    child: Scaffold(
      appBar: SiroAppBar(title: Text('Mã đề ${widget.code}')),
      bottomNavigationBar: AppBottomNavigation(
        selectedIndex: 1,
        onHome: saving ? null : home,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(22),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                secondary(widget.contextPath.join(' / ')),
                const SizedBox(height: 18),
                SiroInput(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(('qm-template', templateRevision)),
                    initialValue: SheetTemplate.qm2025.id,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Loại phiếu trắc nghiệm',
                    ),
                    items: [SheetTemplate.compact, SheetTemplate.qm2025]
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
                            if (id == null ||
                                id == keyData.templateId ||
                                !sync()) {
                              setState(() => templateRevision++);
                              return;
                            }
                            final chosen = SheetTemplate.find(id, 1);
                            if (keyData.count > chosen.capacity) {
                              templateRevision++;
                              setState(
                                () => error =
                                    'Giảm số câu Phần I xuống tối đa ${chosen.capacity} trước khi đổi loại phiếu.',
                              );
                              return;
                            }
                            final next = keyData.copy()..templateId = id;
                            widget.onTemplateChanged(next);
                          },
                  ),
                ),
                const SizedBox(height: 10),
                ExpansionTile(
                  title: const Text('Xem mẫu phiếu'),
                  children: [
                    Image.asset(
                      SheetTemplate.qm2025.preview!,
                      height: 240,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
                panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          tileIcon(Icons.badge_outlined),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Quét số báo danh',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Switch(
                            key: const ValueKey('qm-toggle-candidate'),
                            value: p.scanCandidate,
                            onChanged: saving
                                ? null
                                : (value) =>
                                      edit(() => p.scanCandidate = value),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      secondary(
                        p.scanCandidate
                            ? 'Đọc 6 chữ số. Nếu chưa rõ, cần kiểm tra trước khi lưu kết quả.'
                            : 'Không đọc số báo danh. Bài chấm vẫn được đánh số thứ tự.',
                      ),
                    ],
                  ),
                ),
                note(
                  'Quét toàn phiếu · Chỉ chấm những phần đang bật.',
                  icon: Icons.document_scanner_outlined,
                ),
                structure(
                  1,
                  'Phần I',
                  'Trắc nghiệm A/B/C/D',
                  pair(
                    input(
                      'n1',
                      'Tổng số câu · 1–40',
                      integer: true,
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        if (n != null && n >= 1 && n <= 40) {
                          keyData.count = n;
                        }
                      },
                    ),
                    input(
                      'p1',
                      'Điểm chung mỗi câu',
                      onChanged: (v) => common('1', v),
                    ),
                  ),
                ),
                structure(
                  2,
                  'Phần II',
                  'Trắc nghiệm Đúng/Sai',
                  Column(
                    children: [
                      pair(
                        input(
                          'n2',
                          'Tổng số câu · 1–8',
                          integer: true,
                          onChanged: (v) {
                            final n = int.tryParse(v);
                            if (n != null && n >= 1 && n <= 8) p.twoCount = n;
                          },
                        ),
                        input('r4', 'Điểm tối đa mỗi câu', onChanged: maximum),
                      ),
                      const SizedBox(height: 8),
                      ExpansionTile(
                        title: const Text(
                          'Cách tính điểm Đúng/Sai',
                          style: TextStyle(fontSize: 13),
                        ),
                        children: [
                          for (var i = 1; i <= 3; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              child: input(
                                'r$i',
                                'Đúng $i ý',
                                onChanged: (v) {
                                  commitRates();
                                },
                              ),
                            ),
                          note(
                            'Đúng 4 ý: ${score(p.rates[4])} điểm.\nKhông đúng ý nào: 0 điểm.',
                          ),
                        ],
                      ),
                    ],
                  ),
                  enabled: p.twoEnabled,
                ),
                structure(
                  3,
                  'Phần III',
                  'Trả lời ngắn bằng số',
                  pair(
                    input(
                      'n3',
                      'Tổng số câu · 1–6',
                      integer: true,
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        if (n != null && n >= 1 && n <= 6) p.threeCount = n;
                      },
                    ),
                    input(
                      'p3',
                      'Điểm chung mỗi câu',
                      onChanged: (v) => common('3', v),
                    ),
                  ),
                  enabled: p.threeEnabled,
                ),
                note(
                  'Tổng điểm: ${score(keyData.total)}\nĐiểm tự cộng từ từng câu, không chia thang điểm.',
                  icon: Icons.functions,
                ),
                ExpansionTile(
                  key: const PageStorageKey('qm-answers-one'),
                  initiallyExpanded: true,
                  title: const Text('Đáp án & điểm · Phần I'),
                  children: [
                    for (var i = 0; i < keyData.count; i++) choices(i),
                  ],
                ),
                if (p.twoEnabled)
                  ExpansionTile(
                    key: const PageStorageKey('qm-answers-two'),
                    title: const Text('Đáp án · Phần II'),
                    children: [
                      for (var i = 0; i < p.twoCount; i++) tfAnswers(i),
                    ],
                  ),
                if (p.threeEnabled)
                  ExpansionTile(
                    key: const PageStorageKey('qm-answers-three'),
                    title: const Text('Đáp án & điểm · Phần III'),
                    children: [
                      note(
                        'Nhập số vừa 4 ô tô, kể cả dấu âm và dấu phẩy. Ví dụ: -1,5; 0,25; 1234.',
                      ),
                      for (var i = 0; i < p.threeCount; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: pair(
                            input(
                              's$i',
                              'Đáp án câu ${i + 1}',
                              answer: true,
                              onChanged: (v) {
                                if (v.trim().isEmpty ||
                                    fitsNumberGrid(v.trim())) {
                                  p.threeAnswers[i] = v.trim();
                                }
                              },
                            ),
                            input(
                              'v$i',
                              'Điểm câu ${i + 1}',
                              onChanged: (v) {
                                if (validPoints(v)) {
                                  p.threePoints[i] = decimal(v)!;
                                }
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                if (error.isNotEmpty) note(error, warning: true),
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
                          if (dirty || !keyData.complete) await save();
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
