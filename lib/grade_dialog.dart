import 'package:flutter/material.dart';

class GradeDialog extends StatefulWidget {
  const GradeDialog({super.key, required this.existing});
  final List<String> existing;
  @override
  State<GradeDialog> createState() => _GradeDialogState();
}

class _GradeDialogState extends State<GradeDialog> {
  final form = GlobalKey<FormState>();
  final custom = TextEditingController();
  String? selected;
  @override
  void dispose() {
    custom.dispose();
    super.dispose();
  }

  String? validate(String? value) => value == null || value.trim().isEmpty
      ? 'Chọn hoặc nhập khối học.'
      : widget.existing.contains(value.trim())
      ? 'Khối này đã có trong kì thi.'
      : null;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Thêm khối'),
    content: SingleChildScrollView(
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              key: const ValueKey('grade-select'),
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Khối học'),
              items: [
                for (var i = 1; i <= 12; i++)
                  DropdownMenuItem(value: '$i', child: Text('Khối $i')),
                const DropdownMenuItem(
                  value: 'custom',
                  child: Text('Tùy chỉnh'),
                ),
              ],
              onChanged: (value) => setState(() => selected = value),
              validator: (value) => value == 'custom' ? null : validate(value),
            ),
            if (selected == 'custom')
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: TextFormField(
                  key: const ValueKey('grade-custom'),
                  controller: custom,
                  maxLength: 60,
                  decoration: const InputDecoration(
                    labelText: 'Khối tùy chỉnh',
                    hintText: 'Nhập tên khối',
                  ),
                  validator: validate,
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(
              context,
              selected == 'custom' ? custom.text.trim() : selected,
            );
          }
        },
        child: const Text('Tạo'),
      ),
    ],
  );
}
