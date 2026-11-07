enum QuestionKind { choice, trueFalse, number }

String? normalizedNumber(String text) {
  final value = text.trim().replaceAll(',', '.');
  if (!RegExp(r'^-?(?:\d+(?:\.\d+)?|\.\d+)$').hasMatch(value)) return null;
  final negative = value.startsWith('-');
  final parts = (negative ? value.substring(1) : value).split('.');
  var whole = parts[0].replaceFirst(RegExp(r'^0+'), '');
  if (whole.isEmpty) whole = '0';
  final fraction = parts.length == 2
      ? parts[1].replaceFirst(RegExp(r'0+$'), '')
      : '';
  final body = fraction.isEmpty ? whole : '$whole.$fraction';
  return negative && body != '0' ? '-$body' : body;
}

bool fitsNumberGrid(String text) {
  final value = text.trim().replaceAll(',', '.');
  if (value.length > 4 || normalizedNumber(value) == null) return false;
  for (var offset = 0; offset <= 4 - value.length; offset++) {
    var fits = true;
    for (var i = 0; i < value.length; i++) {
      final position = offset + i, c = value[i];
      if (c == '-' && position != 0 ||
          c == '.' && position != 1 && position != 2) {
        fits = false;
      }
    }
    if (fits) return true;
  }
  return false;
}

String trueFalseText(String value) => value
    .split('')
    .asMap()
    .entries
    .map(
      (e) =>
          '${String.fromCharCode(97 + e.key)}: ${{'T': 'Đ', 'F': 'S', '_': 'trống', 'X': 'nhiều', '?': '?'}[e.value] ?? '?'}',
    )
    .join(' · ');

class QmParts {
  QmParts({
    this.scanCandidate = false,
    this.twoEnabled = false,
    this.threeEnabled = false,
    this.twoCount = 4,
    this.threeCount = 6,
    this.threeCommon = .5,
    List<double>? rates,
    List<String>? twoAnswers,
    List<String>? threeAnswers,
    List<double>? threePoints,
  }) : rates = rates ?? [0, .1, .25, .5, 1],
       twoAnswers = twoAnswers ?? List.filled(8, ''),
       threeAnswers = threeAnswers ?? List.filled(6, ''),
       threePoints = threePoints ?? List.filled(6, .5);
  bool scanCandidate, twoEnabled, threeEnabled;
  int twoCount, threeCount;
  double threeCommon;
  final List<double> rates, threePoints;
  final List<String> twoAnswers, threeAnswers;
  bool get valid =>
      twoCount >= 1 &&
      twoCount <= 8 &&
      threeCount >= 1 &&
      threeCount <= 6 &&
      rates.length == 5 &&
      rates[0] == 0 &&
      rates.every((v) => v.isFinite && v >= 0) &&
      List.generate(4, (i) => rates[i] <= rates[i + 1]).every((v) => v) &&
      threeCommon.isFinite &&
      threeCommon >= 0 &&
      threePoints.length == 6 &&
      threePoints.every((v) => v.isFinite && v >= 0) &&
      twoAnswers.length == 8 &&
      threeAnswers.length == 6 &&
      twoAnswers.every((v) => v.isEmpty || RegExp(r'^[TF_]{4}$').hasMatch(v)) &&
      threeAnswers.every((v) => v.isEmpty || fitsNumberGrid(v));
  bool get complete =>
      valid &&
      (!twoEnabled ||
          twoAnswers
              .take(twoCount)
              .every((v) => RegExp(r'^[TF]{4}$').hasMatch(v))) &&
      (!threeEnabled || threeAnswers.take(threeCount).every(fitsNumberGrid));
  double get total =>
      (twoEnabled ? twoCount * rates[4] : 0) +
      (threeEnabled
          ? threePoints.take(threeCount).fold<double>(0, (a, b) => a + b)
          : 0);
  Map<String, dynamic> toJson() => {
    'scanCandidate': scanCandidate,
    'twoEnabled': twoEnabled,
    'threeEnabled': threeEnabled,
    'twoCount': twoCount,
    'threeCount': threeCount,
    'threeCommon': threeCommon,
    'rates': rates,
    'twoAnswers': twoAnswers,
    'threeAnswers': threeAnswers,
    'threePoints': threePoints,
  };
  QmParts copy() => QmParts.fromJson(toJson());
  factory QmParts.fromJson(Map<String, dynamic> j) {
    final p = QmParts(
      scanCandidate: j['scanCandidate'] as bool? ?? false,
      twoEnabled: j['twoEnabled'] as bool,
      threeEnabled: j['threeEnabled'] as bool,
      twoCount: j['twoCount'] as int,
      threeCount: j['threeCount'] as int,
      threeCommon: (j['threeCommon'] as num).toDouble(),
      rates: (j['rates'] as List).map((v) => (v as num).toDouble()).toList(),
      twoAnswers: List<String>.from(j['twoAnswers'] as List),
      threeAnswers: List<String>.from(j['threeAnswers'] as List),
      threePoints: (j['threePoints'] as List)
          .map((v) => (v as num).toDouble())
          .toList(),
    );
    if (!p.valid) throw const FormatException('Invalid multipart key');
    return p;
  }
}
