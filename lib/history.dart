import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'data.dart';
import 'navigation.dart';
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
  static const levels = ['Năm học', 'Kì thi', 'Khối', 'Môn thi', 'Mã đề'];
  List<String> drillDown = [];
  bool selecting = false, busy = false, writing = false;
  final selected = <String>{};

  @override
  void didUpdateWidget(covariant HistoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.path, widget.path) ||
        oldWidget.repository != widget.repository) {
      selected.clear();
      selecting = false;
      drillDown = [];
    }
  }

  void navigate(List<String> next) {
    if (busy) return;
    setState(() {
      drillDown = next;
      selected.clear();
      selecting = false;
    });
  }

  String pathLabel(int depth, String value) => switch (depth) {
    2 => 'Khối $value',
    4 => 'Mã đề $value',
    _ => value,
  };

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
                foregroundColor: Colors.white,
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
    final path = [...widget.path, ...drillDown];
    final depth = path.length;
    final showPapers = depth == levels.length;
    final subjectPath = path.take(4).toList();
    final papers = widget.repository.data.papers.where((paper) {
      return ExamData.pathStartsWith(paper.path, subjectPath) &&
          (!showPapers || paper.code == path.last);
    }).toList();
    final groups = <String, int>{};
    if (showPapers) {
      papers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else {
      for (final paper in papers) {
        final name = depth == 4 ? paper.code : paper.path[depth];
        groups.update(name, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    final names = groups.keys.toList()
      ..sort((a, b) => depth == 0 ? b.compareTo(a) : a.compareTo(b));
    final allVisible =
        papers.isNotEmpty && papers.every((p) => selected.contains(p.id));
    void goUp() => navigate(drillDown.sublist(0, drillDown.length - 1));

    final content = LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: constraints.maxHeight * .65),
            child: SingleChildScrollView(
              key: ValueKey(('history-toolbar', depth)),
              primary: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.path.isNotEmpty) heading('Sổ chấm bài'),
                    if (path.isNotEmpty)
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 4,
                        children: [
                          if (widget.path.isNotEmpty && drillDown.isNotEmpty)
                            IconButton(
                              tooltip: 'Quay lại cấp trước',
                              onPressed: busy ? null : goUp,
                              icon: const Icon(Icons.arrow_back),
                            ),
                          if (widget.path.isEmpty)
                            TextButton(
                              onPressed: busy ? null : () => navigate([]),
                              child: const Text('Năm học'),
                            ),
                          for (var i = 0; i < depth; i++) ...[
                            if (i > 0 || widget.path.isEmpty)
                              const Icon(Icons.chevron_right, size: 16),
                            if (i >= widget.path.length - 1 && i < depth - 1)
                              TextButton(
                                onPressed: busy
                                    ? null
                                    : () => navigate(
                                        drillDown
                                            .take(i + 1 - widget.path.length)
                                            .toList(),
                                      ),
                                child: Text(pathLabel(i, path[i])),
                              )
                            else
                              Text(pathLabel(i, path[i])),
                          ],
                        ],
                      ),
                    Text(
                      showPapers
                          ? 'Bài đã chấm · ${pathLabel(4, path.last)}'
                          : levels[depth],
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
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
                              foregroundColor: Colors.white,
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
                    ] else if (showPapers && papers.isNotEmpty)
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
                      child: const Text(
                        'Chưa có bài chấm được lưu trong mục này.',
                      ),
                    ),
                  )
                : !showPapers
                ? ListView.builder(
                    key: ValueKey(('history-groups', depth)),
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                    itemCount: names.length,
                    itemBuilder: (context, i) {
                      final name = names[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: tileIcon(Icons.folder_outlined),
                          title: Text(pathLabel(depth, name)),
                          subtitle: Text('${groups[name]} bài đã chấm'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => navigate([...drillDown, name]),
                        ),
                      );
                    },
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
                          subtitle: Text(paperTime(p.createdAt)),
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
                                  SlidePageRoute<void>(
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
    return PopScope(
      canPop: widget.path.isNotEmpty || (!busy && drillDown.isEmpty),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.path.isEmpty && drillDown.isNotEmpty) goUp();
      },
      child: InPlacePageSlide(page: drillDown.length, child: content),
    );
  }
}

class PaperDetail extends StatelessWidget {
  const PaperDetail({super.key, required this.paper});
  final SavedPaper paper;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: SiroAppBar(title: const Text('Chi tiết bài chấm')),
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
              'Tổng điểm: ${score(paper.grade.score)} / ${score(paper.key.total)}\n${paper.grade.correct} / ${paper.key.questionCount} câu đúng',
              icon: Icons.fact_check_outlined,
            ),
            for (var i = 0; i < paper.key.questionCount; i++) savedRow(i),
          ],
        ),
      ),
    ),
  );
  Widget savedRow(int i) {
    final r = paper.responses[i], correct = paper.grade.matches(i);
    final chosen = switch (r.state) {
      MarkState.single => 'Chọn ${paper.key.displayAnswer(i, r.answer)}',
      MarkState.blank => 'Bỏ trống',
      MarkState.multiple => 'Nhiều đáp án',
      MarkState.uncertain => 'Cần kiểm tra',
    };
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: correct ? const Color(0xffe7f5e9) : const Color(0xffffebee),
        boxShadow: surfaceShadows,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        title: Text('${paper.key.questionLabel(i)} - $chosen'),
        subtitle: Text(
          'Đáp án đúng: ${paper.key.displayAnswer(i, paper.key.expected(i))} · ${paper.key.kind(i) == QuestionKind.trueFalse
              ? 'Đúng ${paper.grade.correctIdeas(i)}/4 ý'
              : correct
              ? 'Đúng'
              : 'Sai'}',
        ),
        trailing: Text('${score(paper.grade.earned(i))} đ'),
      ),
    );
  }
}
