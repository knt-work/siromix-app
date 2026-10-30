import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'navigation.dart';

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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void about() => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => AboutPage(info: info)),
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
                                LayoutBuilder(
                                  builder: (context, box) {
                                    final available =
                                        math.min(box.maxWidth, 420.0) * .94;
                                    final width = (available - 12) / 2;
                                    var height = 100.0;
                                    const labels = [
                                      'Chấm bài trắc nghiệm',
                                      'Trộn đề',
                                      'Sổ chấm bài',
                                      'Hồ sơ & dữ liệu',
                                      'Giới thiệu về ứng dụng',
                                    ];
                                    for (final label in labels) {
                                      final painter = TextPainter(
                                        text: TextSpan(
                                          text: label,
                                          style: DefaultTextStyle.of(context)
                                              .style
                                              .merge(
                                                const TextStyle(
                                                  fontSize: 12.5,
                                                  height: 1.3,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                        ),
                                        textDirection: Directionality.of(
                                          context,
                                        ),
                                        textScaler: MediaQuery.textScalerOf(
                                          context,
                                        ),
                                      )..layout(maxWidth: width - 20);
                                      height = math.max(
                                        height,
                                        20 + 30 + 8 + painter.height,
                                      );
                                      painter.dispose();
                                    }
                                    return Center(
                                      child: SizedBox(
                                        width: available,
                                        child: Wrap(
                                          spacing: 12,
                                          runSpacing: 12,
                                          children: [
                                            HomeFunction(
                                              id: 'grading',
                                              label: labels[0],
                                              icon: Icons
                                                  .document_scanner_outlined,
                                              onTap: widget.onGrading,
                                              width: width,
                                              height: height,
                                            ),
                                            HomeFunction(
                                              id: 'shuffle',
                                              label: labels[1],
                                              icon: Icons.shuffle,
                                              onTap: null,
                                              width: width,
                                              height: height,
                                            ),
                                            HomeFunction(
                                              id: 'results',
                                              label: labels[2],
                                              icon: Icons.fact_check_outlined,
                                              onTap: widget.onHistory,
                                              width: width,
                                              height: height,
                                            ),
                                            HomeFunction(
                                              id: 'profile',
                                              label: labels[3],
                                              icon: Icons.person_outline,
                                              onTap: widget.onProfile,
                                              width: width,
                                              height: height,
                                            ),
                                            HomeFunction(
                                              id: 'about',
                                              label: labels[4],
                                              icon: Icons.info_outline,
                                              onTap: about,
                                              width: width,
                                              height: height,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
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
    Color(0xffffe3d1),
    Color(0xffffc9a8),
    Color(0xff9f411d),
  ),
  'shuffle': HomeTileColors(
    Color(0xffeee5f2),
    Color(0xffdfd0e5),
    Color(0xff765c80),
  ),
  'results': HomeTileColors(
    Color(0xffe0eee2),
    Color(0xffc5ddc8),
    Color(0xff3d6b4c),
  ),
  'profile': HomeTileColors(
    Color(0xffe1ebf1),
    Color(0xffc8dae7),
    Color(0xff42677d),
  ),
  'about': HomeTileColors(
    Color(0xffffedc9),
    Color(0xfff3d89c),
    Color(0xff816126),
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
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: Semantics(
      button: true,
      enabled: onTap != null,
      label: onTap == null ? '$label · Chưa phát triển' : label,
      child: ExcludeSemantics(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: onTap == null
                ? null
                : const [
                    BoxShadow(
                      color: Color(0x128e4f32),
                      blurRadius: 22,
                      offset: Offset(0, 7),
                    ),
                  ],
          ),
          child: Material(
            color: homeTilePalette[id]!.background,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: ValueKey('home-$id'),
              onTap: onTap,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: homeTilePalette[id]!.iconBackground,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            icon,
                            size: 19,
                            color: homeTilePalette[id]!.accent,
                          ),
                        ),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                            color: onTap == null
                                ? const Color(0xff80776d)
                                : homeInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onTap == null)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xffe8e1d9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Sắp có',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xff80776d),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
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
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'SiroMix',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(info.label),
            const SizedBox(height: 28),
            const SelectableText(
              'Ứng dụng được phát triển bởi Nhựt Triều, mọi thắc mắc xin liên hệ qua Zalo/SĐT: 0358974020.',
              style: TextStyle(fontSize: 16, height: 1.6),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Sao chép số liên hệ'),
              onPressed: () async {
                await Clipboard.setData(
                  const ClipboardData(text: '0358974020'),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã sao chép số 0358974020.')),
                  );
                }
              },
            ),
            const SizedBox(height: 36),
            const Text(
              copyright,
              style: TextStyle(fontSize: 12, color: homeMuted),
            ),
          ],
        ),
      ),
    ),
  );
}
