import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'data.dart';
import 'ui.dart';

class QmReviewSheet extends StatefulWidget {
  const QmReviewSheet({
    super.key,
    required this.label,
    required this.kind,
    required this.mark,
    required this.crop,
  });
  final String label;
  final QuestionKind kind;
  final ResponseMark mark;
  final Uint8List crop;
  @override
  State<QmReviewSheet> createState() => _QmReviewSheetState();
}

class _QmReviewSheetState extends State<QmReviewSheet> {
  late final TextEditingController number;
  late List<String> ideas;
  @override
  void initState() {
    super.initState();
    number = TextEditingController(
      text: widget.kind == QuestionKind.number ? widget.mark.answer : '',
    );
    ideas = widget.kind == QuestionKind.trueFalse
        ? widget.mark.answer.padRight(4, '_').substring(0, 4).split('')
        : [];
  }

  @override
  void dispose() {
    number.dispose();
    super.dispose();
  }

  ResponseMark tf() {
    final text = ideas.join();
    if (ideas.contains('?')) return ResponseMark(MarkState.uncertain, text);
    if (ideas.any((v) => v == 'T' || v == 'F')) {
      return ResponseMark(MarkState.single, text);
    }
    return ResponseMark(
      ideas.contains('X') ? MarkState.multiple : MarkState.blank,
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        22,
        22,
        22,
        22 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          heading(widget.label),
          Image.memory(widget.crop, height: 210, fit: BoxFit.contain),
          const SizedBox(height: 18),
          if (widget.kind == QuestionKind.trueFalse) ...[
            const Text('Đối chiếu và xác nhận từng ý:'),
            for (var i = 0; i < 4; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('${String.fromCharCode(97 + i)})'),
                    for (final v in ['T', 'F', '_', 'X'])
                      ChoiceChip(
                        label: Text(
                          {
                            'T': 'Đúng',
                            'F': 'Sai',
                            '_': 'Trống',
                            'X': 'Nhiều',
                          }[v]!,
                        ),
                        selected: ideas[i] == v,
                        onSelected: (_) => setState(() => ideas[i] = v),
                      ),
                  ],
                ),
              ),
            action(
              'Xác nhận từng ý',
              ideas.contains('?') ? null : () => Navigator.pop(context, tf()),
              icon: Icons.check,
            ),
          ] else ...[
            SiroInput(
              child: TextField(
                controller: number,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Đáp án số đọc trên phiếu',
                  errorText: number.text.isEmpty || fitsNumberGrid(number.text)
                      ? null
                      : 'Nhập số vừa 4 ô tô',
                ),
              ),
            ),
            action(
              'Xác nhận đáp án số',
              fitsNumberGrid(number.text)
                  ? () => Navigator.pop(
                      context,
                      ResponseMark(MarkState.single, number.text.trim()),
                    )
                  : null,
              icon: Icons.check,
            ),
          ],
          action(
            'Xác nhận bỏ trống · 0 điểm',
            () => Navigator.pop(context, const ResponseMark(MarkState.blank)),
            outline: true,
            icon: Icons.circle_outlined,
          ),
          if (widget.kind == QuestionKind.number)
            action(
              'Không hợp lệ / nhiều ô · 0 điểm',
              () => Navigator.pop(
                context,
                const ResponseMark(MarkState.multiple),
              ),
              outline: true,
              icon: Icons.block,
            ),
        ],
      ),
    ),
  );
}
