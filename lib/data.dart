import 'dart:convert';
import 'dart:math';

import 'templates.dart';

import 'package:flutter/services.dart';

abstract class LocalStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class AndroidStorage implements LocalStorage {
  static const channel = MethodChannel('siromix/storage');
  @override
  Future<String?> read() => channel.invokeMethod<String>('read');
  @override
  Future<void> write(String value) async {
    await channel.invokeMethod<void>('write', value);
  }
}

class ExamKey {
  ExamKey({
    int? count,
    this.templateId = 'abcd-10-a4-tn-tl',
    this.templateVersion = 1,
    this.common = 0.25,
    List<String>? answers,
    List<double>? points,
  }) : count =
           count ?? SheetTemplate.find(templateId, templateVersion).capacity,
       answers =
           answers ??
           List.filled(templateId == SheetTemplate.compact.id ? 40 : 30, ''),
       points =
           points ??
           List.filled(templateId == SheetTemplate.compact.id ? 40 : 30, 0.25);
  int count;
  String templateId;
  int templateVersion;
  SheetTemplate get template => SheetTemplate.find(templateId, templateVersion);
  double common;
  final List<String> answers;
  final List<double> points;
  bool get complete =>
      answers.take(count).every((a) => 'ABCD'.split('').contains(a));
  double get total => points.take(count).fold(0, (a, b) => a + b);
  ExamKey copy() => ExamKey(
    count: count,
    templateId: templateId,
    templateVersion: templateVersion,
    common: common,
    answers: List.of(answers),
    points: List.of(points),
  );
  Map<String, dynamic> toJson() => {
    'count': count,
    'templateId': templateId,
    'templateVersion': templateVersion,
    'common': common,
    'answers': answers,
    'points': points,
  };
  factory ExamKey.fromJson(Map<String, dynamic> j) {
    final count = j['count'] as int;
    final templateId = j['templateId'] as String? ?? SheetTemplate.legacy.id;
    final templateVersion = j['templateVersion'] as int? ?? 1;
    final template = SheetTemplate.find(templateId, templateVersion);
    final common = (j['common'] as num).toDouble();
    final answers = List<String>.from(j['answers'] as List);
    final points = (j['points'] as List)
        .map((v) => (v as num).toDouble())
        .toList();
    if (count < 1 ||
        count > template.capacity ||
        ![30, 40].contains(answers.length) ||
        points.length != answers.length ||
        count > answers.length ||
        !common.isFinite ||
        common < 0 ||
        points.any((v) => !v.isFinite || v < 0) ||
        answers.any((a) => !['', 'A', 'B', 'C', 'D'].contains(a))) {
      throw const FormatException('Invalid answer key');
    }
    return ExamKey(
      count: count,
      templateId: templateId,
      templateVersion: templateVersion,
      common: common,
      answers: answers,
      points: points,
    );
  }
}

class ExamData {
  UserProfile profile = UserProfile(id: localId());
  final List<SavedPaper> papers = [];
  SavedPaper confirmPaper({
    required List<String> path,
    required String candidate,
    bool candidateUnknown = false,
    required String code,
    required List<ResponseMark> responses,
  }) {
    final key = codes(path)[code];
    if ((candidateUnknown
            ? candidate.isNotEmpty
            : !RegExp(r'^\d{6}$').hasMatch(candidate)) ||
        key == null ||
        !key.complete ||
        responses.length != key.count ||
        !GradeResult(key, responses).canConfirm) {
      throw const FormatException('Unconfirmed paper');
    }
    final paper = SavedPaper(
      id: localId(),
      ownerId: profile.id,
      path: path,
      number: nextPaper(path),
      candidate: candidate,
      code: code,
      createdAt: DateTime.now().toUtc(),
      key: key,
      responses: responses,
    );
    final validated = SavedPaper.fromJson(paper.toJson());
    papers.add(validated);
    return validated;
  }

  final Map<String, List<String>> catalogs = {};
  final Map<String, ExamKey> keys = {};
  final Map<String, int> counters = {};
  int nextPaper(List<String> context) {
    final k = jsonEncode(context);
    final n = (counters[k] ?? 0) + 1;
    counters[k] = n;
    return n;
  }

  List<String> children(List<String> path) =>
      List.unmodifiable(catalogs[jsonEncode(path)] ?? []);
  void add(List<String> path, String name) {
    final items = catalogs.putIfAbsent(jsonEncode(path), () => []);
    if (name.trim().isEmpty || items.contains(name.trim())) {
      throw const FormatException('Duplicate or empty name');
    }
    items.add(name.trim());
  }

  static bool pathStartsWith(List<String> path, List<String> prefix) =>
      path.length >= prefix.length &&
      List.generate(prefix.length, (i) => path[i] == prefix[i]).every((v) => v);

  ({int grades, int subjects, int keys, int papers}) deletionImpact(
    List<String> path,
  ) => (
    grades: catalogs.entries
        .where((e) {
          final parent = List<String>.from(jsonDecode(e.key) as List);
          return parent.length == 2 && pathStartsWith(parent, path);
        })
        .fold(0, (n, e) => n + e.value.length),
    subjects: catalogs.entries
        .where((e) {
          final parent = List<String>.from(jsonDecode(e.key) as List);
          return parent.length == 3 && pathStartsWith(parent, path);
        })
        .fold(0, (n, e) => n + e.value.length),
    keys: keys.keys
        .where(
          (k) => pathStartsWith(List<String>.from(jsonDecode(k) as List), path),
        )
        .length,
    papers: papers.where((p) => pathStartsWith(p.path, path)).length,
  );

  void deleteCatalog(List<String> path) {
    // Limit destructive scope to an explicitly named exam/grade/subject.
    if (path.length < 2 ||
        path.length > 4 ||
        !children(path.take(path.length - 1).toList()).contains(path.last)) {
      throw const FormatException('Missing or invalid catalog deletion target');
    }
    catalogs[jsonEncode(path.take(path.length - 1).toList())]!.remove(
      path.last,
    );
    bool matches(String encoded) =>
        pathStartsWith(List<String>.from(jsonDecode(encoded) as List), path);
    catalogs.removeWhere((k, _) => matches(k));
    keys.removeWhere((k, _) => matches(k));
    papers.removeWhere((p) => pathStartsWith(p.path, path));
    counters.removeWhere((k, _) => matches(k));
  }

  void deletePapers(Set<String> ids) {
    if (ids.isEmpty ||
        papers.where((p) => ids.contains(p.id)).length != ids.length) {
      throw const FormatException('Missing saved-paper deletion targets');
    }
    papers.removeWhere((p) => ids.contains(p.id));
    // Deleting results must not reissue numbers already used in this subject.
  }

  Map<String, ExamKey> codes(List<String> context) => {
    for (final c in children(context)) c: keys[jsonEncode([...context, c])]!,
  };
  void addCode(List<String> context, String code) {
    if (code.trim().length > 20) throw const FormatException('Code too long');
    add(context, code);
    keys[jsonEncode([...context, code.trim()])] = ExamKey();
  }

  void saveKey(List<String> context, String code, ExamKey key) {
    if (!key.complete) throw const FormatException('Incomplete answer key');
    keys[jsonEncode([...context, code])] = key.copy();
  }

  String encode() => jsonEncode({
    'version': 5,
    'profile': profile.toJson(),
    'papers': papers.map((p) => p.toJson()).toList(),
    'counters': counters,
    'catalogs': catalogs,
    'keys': keys.map((k, v) => MapEntry(k, v.toJson())),
  });
  factory ExamData.empty() {
    final d = ExamData._();
    final y = DateTime.now().month >= 8
        ? DateTime.now().year
        : DateTime.now().year - 1;
    d.add([], '$y – ${y + 1}');
    return d;
  }
  ExamData._();
  factory ExamData.decode(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    if (![1, 2, 3, 4, 5].contains(j['version'])) {
      throw const FormatException('Unsupported data version');
    }
    final d = ExamData._();
    final counterData = j['counters'] as Map<String, dynamic>? ?? {};
    counterData.forEach((k, v) {
      if (v is! int || v < 0 || (jsonDecode(k) as List).length != 4) {
        throw const FormatException('Invalid paper counter');
      }
      d.counters[k] = v;
    });
    (j['catalogs'] as Map<String, dynamic>).forEach((k, v) {
      final path = List<String>.from(jsonDecode(k) as List);
      if (path.length > 4) throw const FormatException('Invalid catalog path');
      final items = List<String>.from(v as List);
      if (items.any((v) => v.trim().isEmpty) ||
          items.toSet().length != items.length) {
        throw const FormatException('Invalid catalog');
      }
      d.catalogs[k] = items;
    });
    (j['keys'] as Map<String, dynamic>).forEach((k, v) {
      final path = List<String>.from(jsonDecode(k) as List);
      if (path.length != 5 ||
          !d.children(path.take(4).toList()).contains(path.last)) {
        throw const FormatException('Orphan key');
      }
      d.keys[k] = ExamKey.fromJson(v as Map<String, dynamic>);
    });
    for (final entry in d.catalogs.entries) {
      final path = List<String>.from(jsonDecode(entry.key) as List);
      if (path.length == 4 &&
          entry.value.any(
            (c) => !d.keys.containsKey(jsonEncode([...path, c])),
          )) {
        throw const FormatException('Missing answer key');
      }
    }
    if ((j['version'] as int) >= 3) {
      d.profile = UserProfile.fromJson(j['profile'] as Map<String, dynamic>);
      final ids = <String>{}, numbers = <String>{};
      for (final value in j['papers'] as List) {
        final paper = SavedPaper.fromJson(
          value as Map<String, dynamic>,
          allowUnknownCandidate: j['version'] == 5,
        );
        if (paper.ownerId != d.profile.id ||
            !ids.add(paper.id) ||
            !numbers.add(jsonEncode([...paper.path, paper.number])) ||
            (d.counters[jsonEncode(paper.path)] ?? 0) < paper.number) {
          throw const FormatException('Invalid history identity or counter');
        }
        d.papers.add(paper);
      }
    }
    return d;
  }
}

class ExamRepository {
  ExamRepository(this.storage);
  final LocalStorage storage;
  late ExamData data;
  Future<void> load() async {
    final raw = await storage.read();
    final decoded = raw == null ? ExamData.empty() : ExamData.decode(raw);
    // Persist the local profile identity once, including on an empty install.
    if (raw == null || (jsonDecode(raw) as Map)['version'] != 5) {
      await storage.write(decoded.encode());
    }
    data = decoded;
  }

  // Persist before publishing new state, so failed writes cannot appear saved.
  Future<void> _queue = Future.value();
  Future<void> update(void Function(ExamData) change) {
    final operation = _queue.then((_) => _update(change));
    _queue = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> restore(BackupFile backup) {
    // Snapshot/validate before queuing; failed disk writes publish nothing.
    final payload = backup.data.encode();
    final validated = ExamData.decode(payload);
    final operation = _queue.then((_) async {
      await storage.write(payload);
      data = validated;
    });
    _queue = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _update(void Function(ExamData) change) async {
    final next = ExamData.decode(data.encode());
    change(next);
    final payload = next.encode();
    final validated = ExamData.decode(payload);
    await storage.write(payload);
    data = validated;
  }
}

enum MarkState { single, blank, multiple, uncertain }

class ResponseMark {
  const ResponseMark(this.state, [this.answer = '']);
  final MarkState state;
  final String answer;
}

class GradeResult {
  GradeResult(this.key, this.responses);
  final ExamKey key;
  final List<ResponseMark> responses;
  int get pending =>
      responses.where((r) => r.state == MarkState.uncertain).length;
  int get correct => List.generate(key.count, (i) => i)
      .where(
        (i) =>
            responses[i].state == MarkState.single &&
            responses[i].answer == key.answers[i],
      )
      .length;
  int get wrong =>
      responses.where((r) => r.state == MarkState.single).length - correct;
  int get invalid => responses
      .where((r) => [MarkState.blank, MarkState.multiple].contains(r.state))
      .length;
  double get score {
    double total = 0;
    for (var i = 0; i < key.count; i++) {
      if (responses[i].state == MarkState.single &&
          responses[i].answer == key.answers[i]) {
        total += key.points[i];
      }
    }
    return total;
  }

  bool get canConfirm => pending == 0;
}

// Local IDs remain stable through backups. Future provider identities must be
// verified by authentication, never inferred from a user-entered email address.
String localId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

class UserProfile {
  const UserProfile({
    required this.id,
    this.name = '',
    this.school =
        '', // Free-text teacher organization; retains the existing storage key.
    this.provinceCode = '',
    this.provinceName = '',
    this.wardCode = '',
    this.wardName = '',
    this.email = '',
  });
  final String id, name, school, email;
  final String provinceCode, provinceName, wardCode, wardName;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'school': school,
    'provinceCode': provinceCode,
    'provinceName': provinceName,
    'wardCode': wardCode,
    'wardName': wardName,
    'email': email,
  };
  factory UserProfile.fromJson(Map<String, dynamic> j) {
    final p = UserProfile(
      id: j['id'] as String,
      name: j['name'] as String,
      school: j['school'] as String? ?? '',
      provinceCode: j['provinceCode'] as String? ?? '',
      provinceName: j['provinceName'] as String? ?? '',
      wardCode: j['wardCode'] as String? ?? '',
      wardName: j['wardName'] as String? ?? '',
      email: j['email'] as String,
    );
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(p.id) ||
        p.name.length > 100 ||
        p.school.length > 200 ||
        p.email.length > 254 ||
        (p.provinceCode.isNotEmpty &&
            !RegExp(r'^\d{2}$').hasMatch(p.provinceCode)) ||
        (p.wardCode.isNotEmpty &&
            (p.provinceCode.isEmpty ||
                !RegExp(r'^\d{5}$').hasMatch(p.wardCode))) ||
        p.provinceName.length > 150 ||
        p.wardName.length > 150) {
      throw const FormatException('Invalid profile');
    }
    return p;
  }
}

class SavedPaper {
  SavedPaper({
    required this.id,
    required this.ownerId,
    required List<String> path,
    required this.number,
    required this.candidate,
    required this.code,
    required this.createdAt,
    required ExamKey key,
    required List<ResponseMark> responses,
  }) : path = List.unmodifiable(path),
       key = key.copy(),
       responses = List.unmodifiable(responses);
  final String id, ownerId, candidate, code;
  final List<String> path;
  final int number;
  final DateTime createdAt;
  final ExamKey key;
  final List<ResponseMark> responses;
  String get candidateLabel => candidate.isEmpty ? 'Không xác định' : candidate;
  GradeResult get grade => GradeResult(key, responses);
  Map<String, dynamic> toJson() => {
    'id': id,
    'ownerId': ownerId,
    'path': path,
    'number': number,
    'candidate': candidate,
    'code': code,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'key': key.toJson(),
    'responses': responses
        .map((r) => {'state': r.state.name, 'answer': r.answer})
        .toList(),
  };
  factory SavedPaper.fromJson(
    Map<String, dynamic> j, {
    bool allowUnknownCandidate = true,
  }) {
    final r = SavedPaper(
      id: j['id'] as String,
      ownerId: j['ownerId'] as String,
      path: List<String>.from(j['path'] as List),
      number: j['number'] as int,
      candidate: j['candidate'] as String,
      code: j['code'] as String,
      createdAt: DateTime.parse(j['createdAt'] as String),
      key: ExamKey.fromJson(j['key'] as Map<String, dynamic>),
      responses: (j['responses'] as List)
          .map(
            (v) => ResponseMark(
              MarkState.values.byName(v['state'] as String),
              v['answer'] as String,
            ),
          )
          .toList(),
    );
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(r.id) ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(r.ownerId) ||
        r.path.length != 4 ||
        r.path.any((s) => s.trim().isEmpty || s.length > 60) ||
        r.number < 1 ||
        !(RegExp(r'^\d{6}$').hasMatch(r.candidate) ||
            (allowUnknownCandidate && r.candidate.isEmpty)) ||
        r.code.isEmpty ||
        r.code.length > 20 ||
        !r.key.complete ||
        r.responses.length != r.key.count ||
        r.responses.any(
          (a) =>
              a.state == MarkState.uncertain ||
              (a.state == MarkState.single
                  ? !['A', 'B', 'C', 'D'].contains(a.answer)
                  : a.answer.isNotEmpty),
        )) {
      throw const FormatException('Invalid saved paper');
    }
    return r;
  }
}

class BackupFile {
  BackupFile(this.data);
  final ExamData data;
  static const maximumBytes = 20 * 1024 * 1024;
  String encode() => jsonEncode({
    'format': 'siromix-backup',
    'version': 1,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'data': jsonDecode(data.encode()),
  });
  factory BackupFile.decode(String raw) {
    if (utf8.encode(raw).length > maximumBytes) {
      throw const FormatException('Backup too large');
    }
    final j = jsonDecode(raw) as Map<String, dynamic>;
    if (j['format'] != 'siromix-backup' || j['version'] != 1) {
      throw const FormatException('Unsupported backup');
    }
    final data = ExamData.decode(jsonEncode(j['data']));
    if (data.children([]).isEmpty) {
      throw const FormatException('Missing academic year');
    }
    return BackupFile(data);
  }
}
