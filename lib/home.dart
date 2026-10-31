import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'navigation.dart';
import 'administrative_units.dart' show administrativeSearch;

class AppBuildInfo {
  const AppBuildInfo(this.version, this.build);
  final String version, build;
  String get label => version.isEmpty ? 'SiroMix' : 'Phiên bản $version';
  static Future<AppBuildInfo> read() async {
    try {
      final value = await const MethodChannel('siromix/storage')
          .invokeMapMethod<String, dynamic>('appInfo');
      return AppBuildInfo(
        value?['version'] as String? ?? '',
        value?['build'] as String? ?? '',
      );
    } catch (_) {
      return const AppBuildInfo('', '');
    }
  }
}

const homeInk = Color(0xff3d2d24),
    homeMuted = Color(0xff766458),
    homeOrange = Color(0xffd85c2b);
const copyright = '© 2026 SiroMix. Bảo lưu mọi quyền.';

String homeGreeting(DateTime time, String displayName) {
  final period = time.hour >= 5 && time.hour < 12
      ? 'sáng'
      : time.hour >= 12 && time.hour < 18
      ? 'chiều'
      : 'tối';
  final name = displayName.trim();
  return name.isEmpty ? 'Chào buổi $period!' : 'Chào buổi $period, $name!';
}

class HomeLauncher extends StatefulWidget {
  const HomeLauncher({
    super.key,
    required this.onGrading,
    required this.onHistory,
    required this.onProfile,
    this.displayName = '',
    this.now,
  });
  final VoidCallback onGrading, onHistory, onProfile;
  final String displayName;
  final DateTime Function()? now;
  @override
  State<HomeLauncher> createState() => _HomeLauncherState();
}

class _HomeLauncherState extends State<HomeLauncher>
    with WidgetsBindingObserver {
  AppBuildInfo info = const AppBuildInfo('', '');
  Timer? greetingTimer;
  final functionSearch = TextEditingController();
  late int lastHour;
  DateTime get now => widget.now?.call() ?? DateTime.now();
  @override
  void initState() {
    super.initState();
    lastHour = now.hour;
    WidgetsBinding.instance.addObserver(this);
    greetingTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => refreshGreeting(),
    );
    AppBuildInfo.read().then((v) {
      if (mounted) setState(() => info = v);
    });
  }

  void refreshGreeting() {
    if (mounted && now.hour != lastHour) setState(() => lastHour = now.hour);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refreshGreeting();
  }

  @override
  void dispose() {
    greetingTimer?.cancel();
    functionSearch.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void about() => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => AboutPage(info: info)),
  );
  Widget functionGrid() => LayoutBuilder(
    builder: (context, box) {
      const entries = [
        (
          id: 'grading',
          label: 'Chấm bài trắc nghiệm',
          icon: Icons.document_scanner_outlined,
        ),
        (id: 'shuffle', label: 'Trộn đề', icon: Icons.shuffle),
        (id: 'results', label: 'Sổ chấm bài', icon: Icons.fact_check_outlined),
        (id: 'profile', label: 'Hồ sơ & dữ liệu', icon: Icons.person_outline),
        (
          id: 'about',
          label: 'Giới thiệu về ứng dụng',
          icon: Icons.info_outline,
        ),
      ];
      final query = administrativeSearch(functionSearch.text)
          .replaceAll(RegExp(r'[\u0300-\u036f]'), '');
      final terms = query
          .split(RegExp(r'\s+'))
          .where((term) => term.isNotEmpty)
          .toList();
      final visible = entries.where((entry) {
        final name = administrativeSearch(entry.label);
        return terms.every(name.contains);
      }).toList();
      final available = math.min(box.maxWidth, 420.0) * .84;
      final width = (available - 12) / 2;
      final scaler = MediaQuery.textScalerOf(context);
      double textHeight(String label, TextStyle style, double maxWidth) {
        final painter = TextPainter(
          text: TextSpan(
            text: label,
            style: DefaultTextStyle.of(context).style.merge(style),
          ),
          textDirection: Directionality.of(context),
          textScaler: scaler,
        )..layout(maxWidth: maxWidth);
        final height = painter.height;
        painter.dispose();
        return height;
      }

      final badgeHeight =
          textHeight(
            'Sắp có',
            const TextStyle(
              fontSize: 10,
              height: 1.1,
              fontWeight: FontWeight.w600,
            ),
            math.max(1.0, width - 62),
          ) +
          6;
      final headerHeight = math.max(28.0, badgeHeight);
      var height = 88.0;
      // Measure every label, not just matches: filtering never resizes the cards.
      for (final entry in entries) {
        height = math.max(
          height,
          18 +
              headerHeight +
              6 +
              textHeight(
                entry.label,
                const TextStyle(
                  fontSize: 12.5,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
                width - 18,
              ),
        );
      }
      return Center(
        child: SizedBox(
          width: available,
          child: visible.isEmpty
              ? Container(
                  key: const ValueKey('home-search-empty'),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xfffffdfa),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.search_off, color: homeMuted),
                      SizedBox(height: 10),
                      Text(
                        'Không tìm thấy chức năng phù hợp',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: homeInk, height: 1.4),
                      ),
                    ],
                  ),
                )
              : Wrap(
                  spacing: 12,
                  runSpacing: 14,
                  children: [
                    for (final entry in visible)
                      HomeFunction(
                        key: ValueKey('function-${entry.id}'),
                        id: entry.id,
                        label: entry.label,
                        icon: entry.icon,
                        onTap: switch (entry.id) {
                          'grading' => widget.onGrading,
                          'results' => widget.onHistory,
                          'profile' => widget.onProfile,
                          'about' => about,
                          _ => null,
                        },
                        width: width,
                        height: height,
                      ),
                  ],
                ),
        ),
      );
    },
  );
  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xffefbea5),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
    child: Scaffold(
      backgroundColor: const Color(0xffffe6ca),
      body: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: SunriseWallpaper()),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 25, 22, 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 516),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text.rich(
                                              TextSpan(
                                                children: [
                                                  TextSpan(text: 'SiroMix'),
                                                  TextSpan(
                                                    text: '.',
                                                    style: TextStyle(
                                                      color: homeOrange,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              style: TextStyle(
                                                color: homeInk,
                                                fontSize: 33,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: -1.6,
                                              ),
                                            ),
                                          ),
                                          SizedBox(height: 5),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.cloud_off_outlined,
                                                size: 13,
                                                color: homeMuted,
                                              ),
                                              SizedBox(width: 5),
                                              Text(
                                                'Offline',
                                                style: TextStyle(
                                                  color: homeMuted,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Material(
                                      color: const Color(0xfffffdfa),
                                      shape: const CircleBorder(),
                                      child: IconButton(
                                        tooltip: 'Hồ sơ & dữ liệu',
                                        onPressed: widget.onProfile,
                                        icon: const Icon(
                                          Icons.person_outline,
                                          color: homeInk,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  homeGreeting(now, widget.displayName),
                                  key: const ValueKey('home-greeting'),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: homeInk,
                                    fontSize: 18,
                                    height: 1.35,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                TextField(
                                  key: const ValueKey('home-search'),
                                  controller: functionSearch,
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: (_) =>
                                      FocusScope.of(context).unfocus(),
                                  onChanged: (_) => setState(() {}),
                                  style: const TextStyle(
                                    color: homeInk,
                                    fontSize: 14,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Tìm chức năng…',
                                    prefixIcon: const Icon(
                                      Icons.search,
                                      color: homeMuted,
                                    ),
                                    suffixIcon: functionSearch.text.isEmpty
                                        ? null
                                        : IconButton(
                                            key: const ValueKey(
                                              'home-search-clear',
                                            ),
                                            tooltip: 'Xóa tìm kiếm',
                                            icon: const Icon(
                                              Icons.close,
                                              color: homeMuted,
                                            ),
                                            onPressed: () =>
                                                setState(functionSearch.clear),
                                          ),
                                    filled: true,
                                    fillColor: const Color(0xfffffdfa),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 14,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(
                                        color: Color(0xffd7b89e),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(
                                        color: homeOrange,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  'Chức năng',
                                  style: TextStyle(
                                    color: homeMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                functionGrid(),
                                const SizedBox(height: 28),
                              ],
                            ),
                          ),
                        ),
                        Column(
                          children: [
                            Text(
                              info.label,
                              key: const ValueKey('home-version'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                color: homeMuted,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              copyright,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11, color: homeMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class HomeTileColors {
  const HomeTileColors(this.background, this.iconBackground, this.accent);
  final Color background, iconBackground, accent;
}

const homeTilePalette = {
  'grading': HomeTileColors(
    Color(0xffffb782),
    Color(0xfffff1e6),
    Color(0xff8a3518),
  ),
  'shuffle': HomeTileColors(
    Color(0xffd9c4ee),
    Color(0xfff3ecfa),
    Color(0xff66457c),
  ),
  'results': HomeTileColors(
    Color(0xffa7d8ac),
    Color(0xffeaf7ec),
    Color(0xff285f35),
  ),
  'profile': HomeTileColors(
    Color(0xff9ecbe4),
    Color(0xffeaf5fc),
    Color(0xff28566f),
  ),
  'about': HomeTileColors(
    Color(0xfff5cf72),
    Color(0xfffff6da),
    Color(0xff765313),
  ),
};

class HomeFunction extends StatelessWidget {
  const HomeFunction({
    super.key,
    required this.id,
    required this.label,
    required this.icon,
    required this.onTap,
    required this.width,
    required this.height,
  });
  final String id, label;
  final IconData icon;
  final VoidCallback? onTap;
  final double width, height;
  @override
  Widget build(BuildContext context) {
    final palette = homeTilePalette[id]!;
    return SizedBox(
      width: width,
      height: height,
      child: Semantics(
        button: true,
        enabled: onTap != null,
        label: onTap == null ? '$label · Chưa phát triển' : label,
        child: ExcludeSemantics(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33804d38),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
                BoxShadow(
                  color: Color(0x0f3d2d24),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: palette.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: palette.accent.withValues(alpha: .25)),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: ValueKey('home-$id'),
                onTap: onTap == null
                    ? null
                    : () {
                        FocusScope.of(context).unfocus();
                        onTap!();
                      },
                child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: palette.iconBackground,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(icon, size: 18, color: palette.accent),
                          ),
                          if (onTap == null) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.iconBackground,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  'Sắp có',
                                  style: TextStyle(
                                    fontSize: 10,
                                    height: 1.1,
                                    fontWeight: FontWeight.w600,
                                    color: palette.accent,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: onTap == null ? palette.accent : homeInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SunriseWallpaper extends CustomPainter {
  const SunriseWallpaper();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xfffffcf3), Color(0xffffe6ca), Color(0xffe8a586)],
          stops: [0, .42, 1],
        ).createShader(rect),
    );
    final sun = Rect.fromCircle(
      center: Offset(size.width * .94, size.height * .25),
      radius: size.width * .3,
    );
    canvas.drawOval(
      sun,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xfffff8db), Color(0xffffc68c)],
        ).createShader(sun),
    );
    final a = Path()
      ..moveTo(-size.width * .1, size.height * .47)
      ..cubicTo(
        size.width * .24,
        size.height * .29,
        size.width * .9,
        size.height * .27,
        size.width * 1.2,
        size.height * .43,
      )
      ..lineTo(size.width * 1.2, size.height)
      ..lineTo(-size.width * .1, size.height)
      ..close();
    canvas.drawPath(
      a,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xfffff1d3), Color(0xfff0bba0), Color(0xffdf9b81)],
        ).createShader(rect),
    );
    canvas.drawPath(
      a,
      Paint()
        ..color = const Color(0x99fff5e7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final b = Path()
      ..moveTo(0, size.height * .87)
      ..cubicTo(
        size.width * .48,
        size.height * .89,
        size.width * .55,
        size.height * .59,
        size.width,
        size.height * .67,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      b,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xffffdec1), Color(0xffefbea5)],
        ).createShader(rect),
    );
    final contour = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x45fff9e2);
    for (var i = 0; i < 4; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * .03, size.height * .47),
          width: size.width * (1.22 + i * .1),
          height: size.height * (.8 + i * .05),
        ),
        contour,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SunriseWallpaper oldDelegate) => false;
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key, required this.info});
  final AppBuildInfo info;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Giới thiệu về ứng dụng')),
    bottomNavigationBar: AppBottomNavigation(
      selectedIndex: 0,
      onHome: () => Navigator.of(context).popUntil((r) => r.isFirst),
    ),
    backgroundColor: const Color(0xfffffcf3),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xfffff8ed), Color(0xffffe6ca)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xfff1dcc7)),
                ),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/branding/launcher-source.png',
                      width: 104,
                      height: 104,
                      semanticLabel: 'Biểu tượng SiroMix',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'SiroMix',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: homeInk,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Thêm thời gian cho việc dạy, bớt thời gian cho việc chấm.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: homeOrange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'SiroMix được xây dựng từ những công việc quen thuộc của giáo viên, với mong muốn giúp mỗi ngày đứng lớp nhẹ nhàng và thuận tiện hơn.',
                style: TextStyle(fontSize: 16, height: 1.65, color: homeInk),
              ),
              const SizedBox(height: 16),
              const Text(
                'Bắt đầu với chấm bài trắc nghiệm, SiroMix giúp thầy cô quản lý đề thi, quét phiếu bằng camera, đối chiếu đáp án và lưu kết quả ngay trên điện thoại. Ứng dụng hoạt động ngoại tuyến, để thầy cô chủ động sử dụng cả khi không có kết nối mạng.',
                style: TextStyle(fontSize: 16, height: 1.65, color: homeInk),
              ),
              const SizedBox(height: 16),
              const Text(
                'Từng bước, SiroMix sẽ bổ sung những công cụ thiết thực khác, trở thành người bạn đồng hành trong công việc giảng dạy.',
                style: TextStyle(fontSize: 16, height: 1.65, color: homeInk),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xfff1dcc7)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Được phát triển bởi Nhựt Triều',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: homeInk,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Mọi góp ý từ thầy cô đều giúp SiroMix hoàn thiện hơn.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: homeMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const SelectableText(
                      'Liên hệ qua Zalo/SĐT: 0358974020',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: homeInk,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text('Sao chép số liên hệ'),
                      onPressed: () async {
                        await Clipboard.setData(
                          const ClipboardData(text: '0358974020'),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã sao chép số 0358974020.'),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(
                info.label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: homeMuted),
              ),
              const SizedBox(height: 6),
              const Text(
                copyright,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: homeMuted, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
