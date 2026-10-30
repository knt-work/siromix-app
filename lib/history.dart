import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'data.dart';
import 'ui.dart';

String paperTime(DateTime value) {
  final d = value.toLocal();
  String pad(int v) => '$v'.padLeft(2, '0');
  return '${pad(d.day)}/${pad(d.month)}/${d.year} ${pad(d.hour)}:${pad(d.minute)}';
}

class HistoryView extends StatefulWidget {
  const HistoryView({super.key, required this.repository, required this.path});
  final ExamRepository repository;
  final List<String> path;
  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  final search = TextEditingController();
  String query = '';
  bool selecting = false, busy = false, writing = false;
  final selected = <String>{};
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HistoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.path, widget.path) ||
        oldWidget.repository != widget.repository) {
      selected.clear();
      selecting = false;
      query = '';
      search.clear();
    }
  }

  void toggle(SavedPaper paper) {
    if (busy) return;
    setState(() {
      if (!selected.add(paper.id)) selected.remove(paper.id);
    });
  }

  Future<void> remove(Set<String> ids) async {
    if (busy || ids.isEmpty) return;
    final targets = widget.repository.data.papers
        .where((p) => ids.contains(p.id))
        .toList();
    if (targets.length != ids.length) return;
    setState(() => busy = true);
    try {
      final single = targets.length == 1 ? targets.single : null;
      final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            single == null
                ? 'Xóa ${targets.length} bài chấm?'
                : 'Xóa bài số ${single.number}?',
          ),
          content: SingleChildScrollView(
            child: Text(
              '${single == null ? 'Sẽ xóa ${targets.length} kết quả đã chọn.' : '${single.path.join(' / ')}\nSBD ${single.candidateLabel} · Mã đề ${single.code}'}\n\n'
              'Kết quả và điểm đã lưu sẽ bị xóa. Không thể hoàn tác. Số thứ tự đã dùng sẽ không được cấp lại.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(single == null ? 'Xóa ${targets.length} bài' : 'Xóa'),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
      setState(() => writing = true);
      await widget.repository.update((d) => d.deletePapers(ids));
      if (mounted) {
        setState(() {
          selected.clear();
          selecting = false;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không thể xóa kết quả. Dữ liệu chưa thay đổi. Vui lòng thử lại.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          writing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final papers =
        widget.repository.data.papers
            .where(
              (p) =>
                  ExamData.pathStartsWith(p.path, widget.path) &&
                  (query.isEmpty ||
                      p.candidateLabel.toLowerCase().contains(
                        query.toLowerCase(),
                      ) ||
                      p.code.contains(query) ||
                      '${p.number}' == query),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final allVisible =
        papers.isNotEmpty && papers.every((p) => selected.contains(p.id));
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: constraints.maxHeight * .65),
            child: SingleChildScrollView(
              key: const ValueKey('history-toolbar'),
              primary: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    heading('Sổ chấm bài'),
                    secondary(
                      widget.path.isEmpty
                          ? 'Tất cả năm học'
                          : widget.path.join(' / '),
                    ),
                    TextField(
                      controller: search,
                      enabled: !busy,
                      decoration: const InputDecoration(
                        labelText: 'Tìm SBD, mã đề hoặc số bài',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (v) => setState(() => query = v.trim()),
                    ),
                    const SizedBox(height: 10),
                    secondary('${papers.length} bài đã chấm'),
                    if (selecting) ...[
                      Text(
                        'Đã chọn ${selected.length} bài',
                        key: const ValueKey('history-selection-count'),
                      ),
                      Wrap(
                        spacing: 6,
                        children: [
                          TextButton(
                            onPressed: busy || papers.isEmpty
                                ? null
                                : () => setState(() {
                                    if (allVisible) {
                                      selected.removeAll(
                                        papers.map((p) => p.id),
                                      );
                                    } else {
                                      selected.addAll(papers.map((p) => p.id));
                                    }
                                  }),
                            child: Text(
                              allVisible
                                  ? 'Bỏ chọn đang hiển thị'
                                  : 'Chọn tất cả đang hiển thị',
                            ),
                          ),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => setState(() {
                                    selected.clear();
                                    selecting = false;
                                  }),
                            child: const Text('Hủy chọn'),
                          ),
                          FilledButton.icon(
                            key: const ValueKey('history-delete-selected'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                            ),
                            onPressed: busy || selected.isEmpty
                                ? null
                                : () => remove(Set.of(selected)),
                            icon: const Icon(Icons.delete_outline),
                            label: Text('Xóa (${selected.length})'),
                          ),
                        ],
                      ),
                    ] else if (papers.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          key: const ValueKey('history-select-mode'),
                          onPressed: busy
                              ? null
                              : () => setState(() => selecting = true),
                          icon: const Icon(Icons.checklist),
                          label: const Text('Chọn nhiều'),
                        ),
                      ),
                    if (writing) const LinearProgressIndicator(),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: papers.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Text(
                        query.isEmpty
                            ? 'Chưa có bài chấm được lưu trong mục này.'
                            : 'Không tìm thấy bài chấm.',
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                    itemCount: papers.length,
                    itemBuilder: (context, i) {
                      final p = papers[i];
                      return Card(
                        key: ValueKey('history-paper-${p.id}'),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          leading: selecting
                              ? Checkbox(
                                  key: ValueKey('paper-select-${p.id}'),
                                  value: selected.contains(p.id),
                                  onChanged: busy ? null : (_) => toggle(p),
                                )
                              : null,
                          title: Text(
                            'Bài số ${p.number} · SBD ${p.candidateLabel}',
                          ),
                          subtitle: Text(
                            '${p.path.skip(1).join(' / ')}\nMã đề ${p.code} · ${paperTime(p.createdAt)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${score(p.grade.score)}\n/ ${score(p.key.total)}',
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  color: teal,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (!selecting)
                                IconButton(
                                  key: ValueKey('paper-delete-${p.id}'),
                                  tooltip: 'Xóa bài số ${p.number}',
                                  onPressed: busy ? null : () => remove({p.id}),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Color(0xffad4c44),
                                    size: 21,
                                  ),
                                ),
                            ],
                          ),
                          onLongPress: busy
                              ? null
                              : () => setState(() {
                                  selecting = true;
                                  selected.add(p.id);
                                }),
                          onTap: busy
                              ? null
                              : selecting
                              ? () => toggle(p)
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => PaperDetail(paper: p),
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class PaperDetail extends StatelessWidget {
  const PaperDetail({super.key, required this.paper});
  final SavedPaper paper;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết bài chấm')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            secondary(paper.path.join(' / ')),
            heading('Bài số ${paper.number}'),
            Text('SBD ${paper.candidateLabel} · Mã đề ${paper.code}'),
            secondary(paperTime(paper.createdAt)),
            note(
              'Tổng điểm: ${score(paper.grade.score)} / ${score(paper.key.total)}\n${paper.grade.correct} / ${paper.key.count} câu đúng',
              icon: Icons.fact_check_outlined,
            ),
            for (var i = 0; i < paper.key.count; i++) savedRow(i),
          ],
        ),
      ),
    ),
  );
  Widget savedRow(int i) {
    final r = paper.responses[i],
        correct =
            r.state == MarkState.single && r.answer == paper.key.answers[i];
    final chosen = switch (r.state) {
      MarkState.single => 'Chọn ${r.answer}',
      MarkState.blank => 'Bỏ trống',
      MarkState.multiple => 'Nhiều đáp án',
      MarkState.uncertain => 'Cần kiểm tra',
    };
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: correct ? const Color(0xffe7f5e9) : const Color(0xffffebee),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        title: Text('Câu ${i + 1} - $chosen'),
        subtitle: Text(
          'Đáp án đúng: ${paper.key.answers[i]} · ${correct ? 'Đúng' : 'Sai'}',
        ),
        trailing: Text('${score(correct ? paper.key.points[i] : 0)} đ'),
      ),
    );
  }
}
