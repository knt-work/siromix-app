import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data.dart';
import 'administrative_units.dart';
import 'ui.dart';
import 'navigation.dart';

abstract class BackupDocuments {
  Future<bool> save(String content);
  Future<String?> open();
}

class AndroidBackupDocuments implements BackupDocuments {
  static const channel = MethodChannel('siromix/backup');
  @override
  Future<bool> save(String content) async =>
      await channel.invokeMethod<bool>('save', {
        'payload': content,
        'name':
            'SiroMix-${DateTime.now().toIso8601String().substring(0, 19).replaceAll(':', '-')}.json',
      }) ??
      false;
  @override
  Future<String?> open() => channel.invokeMethod<String>('open');
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.repository,
    this.documents,
    this.onHome,
  });
  final ExamRepository repository;
  final BackupDocuments? documents;
  final VoidCallback? onHome;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final form = GlobalKey<FormState>();
  late TextEditingController name, school, email;
  String provinceCode = '', provinceName = '', wardCode = '', wardName = '';
  AdministrativeCatalog? locations;
  String? locationError;
  bool busy = false, dirty = false;
  String? message;
  BackupDocuments get documents => widget.documents ?? AndroidBackupDocuments();
  @override
  void initState() {
    super.initState();
    final p = widget.repository.data.profile;
    name = TextEditingController(text: p.name);
    school = TextEditingController(text: p.school);
    provinceCode = p.provinceCode;
    provinceName = p.provinceName;
    wardCode = p.wardCode;
    wardName = p.wardName;
    loadLocations();
    email = TextEditingController(text: p.email);
  }

  @override
  void dispose() {
    name.dispose();
    school.dispose();
    email.dispose();
    super.dispose();
  }

  Future<void> loadLocations() async {
    try {
      final loaded = await AdministrativeCatalog.load();
      if (mounted) {
        setState(() {
          locations = loaded;
          locationError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => locationError =
              'Không mở được danh sách địa phương. Nhấn để thử lại.',
        );
      }
    }
  }

  Future<void> selectProvince() async {
    if (busy || locations == null) return;
    final selected = await chooseAdministrativeUnit(
      context,
      title: 'Tỉnh/TP',
      units: locations!.provinces,
    );
    if (selected == null || !mounted || selected.code == provinceCode) return;
    setState(() {
      provinceCode = selected.code;
      provinceName = selected.name;
      wardCode = '';
      wardName = '';
      dirty = true;
    });
  }

  Future<void> selectWard() async {
    if (busy || locations == null || provinceCode.isEmpty) return;
    final selected = await chooseAdministrativeUnit(
      context,
      title: 'Phường/Xã',
      units: locations!.wards(provinceCode),
    );
    if (selected == null || !mounted || selected.code == wardCode) return;
    setState(() {
      wardCode = selected.code;
      wardName = selected.name;
      dirty = true;
    });
  }

  Widget locationField(
    String label,
    String value,
    String hint,
    VoidCallback? onTap,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      key: ValueKey('profile-$label'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          enabled: onTap != null,
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          value.isEmpty ? hint : value,
          style: TextStyle(color: value.isEmpty ? muted : null),
        ),
      ),
    ),
  );

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await widget.repository.update(
        (d) => d.profile = UserProfile(
          id: d.profile.id,
          name: name.text.trim(),
          school: school.text.trim(),
          provinceCode: provinceCode,
          provinceName: locations?.province(provinceCode)?.name ?? provinceName,
          wardCode: wardCode,
          wardName: locations?.ward(provinceCode, wardCode)?.name ?? wardName,
          email: email.text.trim(),
        ),
      );
      if (mounted) {
        setState(() {
          dirty = false;
          message = 'Đã lưu hồ sơ trên thiết bị.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => message = 'Không thể lưu hồ sơ. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> export() async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final raw = BackupFile(widget.repository.data).encode();
      if (raw.length > BackupFile.maximumBytes) {
        throw const FormatException('Too large');
      }
      final saved = await documents.save(raw);
      if (mounted) {
        setState(
          () => message = saved ? 'Đã lưu file sao lưu.' : 'Đã hủy sao lưu.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message = 'Không thể sao lưu. Kiểm tra nơi lưu và thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> restore() async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final raw = await documents.open();
      if (raw == null) return;
      final backup = BackupFile.decode(raw);
      if (!mounted) return;
      final replace = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Khôi phục dữ liệu?'),
          content: Text(
            'Hồ sơ: ${backup.data.profile.name.isEmpty ? 'Chưa đặt tên' : backup.data.profile.name}\n'
            '${backup.data.children([]).length} năm học · ${backup.data.keys.length} mã đề · ${backup.data.papers.length} bài chấm\n\n'
            'Toàn bộ hồ sơ, bộ đề, kết quả và số thứ tự trên máy sẽ được thay bằng bản sao lưu. Hãy sao lưu dữ liệu hiện tại nếu cần giữ lại.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Thay thế và khôi phục'),
            ),
          ],
        ),
      );
      if (replace != true) return;
      await widget.repository.restore(backup);
      if (mounted) {
        setState(() {
          busy = false;
          dirty = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context, true);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message = 'Không thể khôi phục. File không hợp lệ, không được hỗ trợ hoặc không lưu được. Dữ liệu hiện tại chưa thay đổi.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<bool> mayLeave() async =>
      !dirty ||
      (await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Hồ sơ chưa được lưu'),
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
  Future<void> profileHome() async {
    if (busy || !await mayLeave() || !mounted) return;
    setState(() => dirty = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.onHome != null) {
        widget.onHome!();
      } else {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy && !dirty,
    onPopInvokedWithResult: (didPop, _) async {
      if (!didPop && !busy && await mayLeave() && mounted) {
        setState(() => dirty = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      }
    },
    child: Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ & dữ liệu')),
      bottomNavigationBar: AppBottomNavigation(
        selectedIndex: 0,
        onHome: busy ? null : profileHome,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: form,
            onChanged: () => setState(() => dirty = true),
            child: ListView(
              padding: const EdgeInsets.all(22),
              children: [
                heading('Hồ sơ giáo viên'),
                TextFormField(
                  controller: name,
                  enabled: !busy,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'Tên Hiển Thị'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('profile-unit'),
                  controller: school,
                  enabled: !busy,
                  maxLength: 200,
                  decoration: const InputDecoration(labelText: 'Đơn vị'),
                ),
                const SizedBox(height: 12),
                locationField(
                  'Tỉnh/TP',
                  locations?.province(provinceCode)?.name ?? provinceName,
                  'Chọn Tỉnh/TP',
                  !busy && locations != null ? selectProvince : null,
                ),
                locationField(
                  'Phường/Xã',
                  locations?.ward(provinceCode, wardCode)?.name ?? wardName,
                  provinceCode.isEmpty
                      ? 'Chọn Tỉnh/TP trước'
                      : 'Chọn Phường/Xã',
                  !busy && locations != null && provinceCode.isNotEmpty
                      ? selectWard
                      : null,
                ),
                if (locationError != null)
                  TextButton(
                    onPressed: loadLocations,
                    child: Text(locationError!),
                  ),
                TextFormField(
                  controller: email,
                  enabled: !busy,
                  maxLength: 254,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) =>
                      v == null ||
                          v.trim().isEmpty ||
                          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(v.trim())
                      ? null
                      : 'Nhập email hợp lệ.',
                ),
                action(
                  'Lưu hồ sơ',
                  busy ? null : save,
                  icon: Icons.save_outlined,
                ),
                note(
                  'Google / Apple · Chưa liên kết\nĐăng nhập và đồng bộ sẽ được bổ sung sau.',
                  icon: Icons.cloud_off_outlined,
                ),
                const SizedBox(height: 16),
                heading('Sao lưu & khôi phục'),
                secondary(
                  'File sao lưu gồm hồ sơ đã lưu, bộ đề, kết quả và số thứ tự bài. Ảnh phiếu không được lưu.',
                ),
                if (dirty)
                  secondary('Lưu hồ sơ trước khi sao lưu hoặc khôi phục.'),
                action(
                  'Sao lưu dữ liệu',
                  busy || dirty ? null : export,
                  icon: Icons.download_outlined,
                ),
                action(
                  'Khôi phục từ file',
                  busy || dirty ? null : restore,
                  outline: true,
                  icon: Icons.restore,
                ),
                if (busy) const Center(child: CircularProgressIndicator()),
                if (message != null) note(message!),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
