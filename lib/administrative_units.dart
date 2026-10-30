import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AdministrativeUnit {
  const AdministrativeUnit(this.code, this.name);
  final String code, name;
}

class AdministrativeCatalog {
  AdministrativeCatalog._(
    this.version,
    this.effectiveAt,
    this.provinces,
    this._wards,
  );
  final String version, effectiveAt;
  final List<AdministrativeUnit> provinces;
  final Map<String, List<AdministrativeUnit>> _wards;
  static Future<AdministrativeCatalog>? _cached;
  static Future<AdministrativeCatalog> load() => _cached ??= _load();
  static Future<AdministrativeCatalog> _load() async {
    try {
      return AdministrativeCatalog.decode(
        await rootBundle.loadString('assets/data/vn-admin.json'),
      );
    } catch (_) {
      _cached = null;
      rethrow;
    }
  }

  factory AdministrativeCatalog.decode(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final provinces = <AdministrativeUnit>[],
        wards = <String, List<AdministrativeUnit>>{};
    final seen = <String>{};
    for (final p in j['provinces'] as List) {
      final code = p['code'] as String, name = p['name'] as String;
      if (!RegExp(r'^\d{2}$').hasMatch(code) ||
          wards.containsKey(code) ||
          name.isEmpty) {
        throw const FormatException('Invalid province');
      }
      provinces.add(AdministrativeUnit(code, name));
      wards[code] = [
        for (final w in p['wards'] as List)
          AdministrativeUnit(w['code'] as String, w['name'] as String),
      ];
      for (final w in wards[code]!) {
        if (!RegExp(r'^\d{5}$').hasMatch(w.code) ||
            !seen.add(w.code) ||
            w.name.isEmpty) {
          throw const FormatException('Invalid ward');
        }
      }
    }
    return AdministrativeCatalog._(
      j['version'] as String,
      j['effectiveAt'] as String,
      List.unmodifiable(provinces),
      {for (final e in wards.entries) e.key: List.unmodifiable(e.value)},
    );
  }
  AdministrativeUnit? province(String code) {
    for (final p in provinces) {
      if (p.code == code) return p;
    }
    return null;
  }

  List<AdministrativeUnit> wards(String code) => _wards[code] ?? const [];
  AdministrativeUnit? ward(String provinceCode, String code) {
    for (final w in wards(provinceCode)) {
      if (w.code == code) return w;
    }
    return null;
  }
}

String administrativeSearch(String text) {
  var result = text.toLowerCase().trim();
  const groups = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };
  for (final group in groups.entries) {
    for (final rune in group.value.runes) {
      result = result.replaceAll(String.fromCharCode(rune), group.key);
    }
  }
  return result;
}

Future<AdministrativeUnit?> chooseAdministrativeUnit(
  BuildContext context, {
  required String title,
  required List<AdministrativeUnit> units,
}) => showModalBottomSheet<AdministrativeUnit>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _AdministrativePicker(title: title, units: units),
);

class _AdministrativePicker extends StatefulWidget {
  const _AdministrativePicker({required this.title, required this.units});
  final String title;
  final List<AdministrativeUnit> units;
  @override
  State<_AdministrativePicker> createState() => _AdministrativePickerState();
}

class _AdministrativePickerState extends State<_AdministrativePicker> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final filtered = widget.units
        .where(
          (u) =>
              administrativeSearch(u.name).contains(query) ||
              u.code.contains(query),
        )
        .toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: Column(
            children: [
              ListTile(
                title: Text(
                  widget.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: IconButton(
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  key: const ValueKey('location-search'),
                  decoration: const InputDecoration(
                    hintText: 'Tìm theo tên hoặc mã',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (text) =>
                      setState(() => query = administrativeSearch(text)),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return ListTile(
                        title: const Text('Bỏ chọn'),
                        onTap: () => Navigator.pop(
                          context,
                          const AdministrativeUnit('', ''),
                        ),
                      );
                    }
                    final unit = filtered[i - 1];
                    return ListTile(
                      title: Text(unit.name),
                      onTap: () => Navigator.pop(context, unit),
                    );
                  },
                ),
              ),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Không tìm thấy địa phương.'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
