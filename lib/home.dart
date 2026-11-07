import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'navigation.dart';
import 'ui.dart';
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

const homeInk = Color(0xff252940),
    homeMuted = Color(0xff747b91),
    homeOrange = Color(0xfff4a357);
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
      final available = math.min(box.maxWidth, 420.0) * .92;
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
      final headerHeight = math.max(36.0, badgeHeight);
      var height = 106.0;
      // Measure every label, not just matches: filtering never resizes the cards.
      for (final entry in entries) {
        height = math.max(
          height,
          24 +
              headerHeight +
              6 +
              textHeight(
                entry.label,
                const TextStyle(
                  fontSize: 12.5,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
                width - 24,
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
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: appBackground,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
    child: Scaffold(
      backgroundColor: appBackground,
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(gradient: brandGradient),
                  child: SafeArea(
                    bottom: false,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 17, 24, 42),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(text: 'SiroMix'),
                                          TextSpan(
                                            text: '.',
                                            style: TextStyle(color: homeOrange),
                                          ),
                                        ],
                                      ),
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: -1,
                                      ),
                                    ),
                                  ),
                                  Material(
                                    color: const Color(0x25ffffff),
                                    borderRadius: BorderRadius.circular(15),
                                    child: IconButton(
                                      tooltip: 'Hồ sơ & dữ liệu',
                                      onPressed: widget.onProfile,
                                      icon: const Icon(
                                        Icons.person_outline,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 22),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      homeGreeting(now, widget.displayName),
                                      key: const ValueKey('home-greeting'),
                                      style: const TextStyle(
                                        fontSize: 21,
                                        height: 1.4,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -.4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const ExcludeSemantics(
                                    child: HomeScanIllustration(),
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
                Transform.translate(
                  offset: const Offset(0, -23),
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: appBackground,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(22, 24, 22, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SiroInput(
                                child: TextField(
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
                                    fillColor: Colors.transparent,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 25),
                              const Text(
                                'Chức năng',
                                style: TextStyle(
                                  color: homeInk,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 17),
                              functionGrid(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 17),
                    child: Column(
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
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Lightweight native illustration: crisp at every density, no network assets.
class HomeScanIllustration extends StatelessWidget {
  const HomeScanIllustration({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 104,
    height: 106,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 13,
          top: 11,
          child: Transform.rotate(
            angle: .2,
            child: Container(
              width: 76,
              height: 85,
              decoration: BoxDecoration(
                color: const Color(0xff9584db),
                borderRadius: BorderRadius.circular(15),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x30202765),
                    blurRadius: 15,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 4,
          top: 8,
          child: Transform.rotate(
            angle: -.17,
            child: Container(
              width: 76,
              height: 85,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Color(0xffd9e5ff)],
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: const [
                  BoxShadow(color: Color(0xffafbfed), offset: Offset(3, 4)),
                ],
              ),
              child: const Icon(
                Icons.fact_check_outlined,
                color: Color(0xff6581c9),
                size: 51,
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xff9bf2cb), Color(0xff24b998)],
              ),
              boxShadow: [
                BoxShadow(color: Color(0xff168b8d), offset: Offset(1, 3)),
              ],
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 25,
            ),
          ),
        ),
        const Positioned(
          right: 0,
          top: 0,
          child: Icon(Icons.auto_awesome, size: 20, color: Color(0xffffca7e)),
        ),
      ],
    ),
  );
}

class HomeTileColors {
  const HomeTileColors(this.background, this.iconBackground, this.accent);
  final Color background, iconBackground, accent;
}

const homeTilePalette = {
  'grading': HomeTileColors(
    Color(0xfffefeff),
    Color(0xffb9a3ff),
    Color(0xff8c6cdb),
  ),
  'shuffle': HomeTileColors(
    Color(0xfff7f7fb),
    Color(0xffd0d9f0),
    Color(0xff9bafd1),
  ),
  'results': HomeTileColors(
    Color(0xfffcfffe),
    Color(0xffa6dfd4),
    Color(0xff51ae9b),
  ),
  'profile': HomeTileColors(
    Color(0xfffefdff),
    Color(0xffc8b4ef),
    Color(0xff9677cd),
  ),
  'about': HomeTileColors(
    Color(0xfffffefb),
    Color(0xffffd49c),
    Color(0xfff4ae69),
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
              boxShadow: surfaceShadows,
            ),
            child: Material(
              color: palette.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
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
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  palette.iconBackground,
                                  palette.accent,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: palette.accent.withValues(alpha: .3),
                                  blurRadius: 8,
                                  offset: const Offset(1, 4),
                                ),
                              ],
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(icon, size: 23, color: Colors.white),
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

class AboutPage extends StatelessWidget {
  const AboutPage({super.key, required this.info});
  final AppBuildInfo info;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: SiroAppBar(title: const Text('Giới thiệu về ứng dụng')),
    bottomNavigationBar: AppBottomNavigation(
      selectedIndex: 0,
      onHome: () => Navigator.of(context).popUntil((r) => r.isFirst),
    ),
    backgroundColor: appBackground,
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
                    colors: [Color(0xfff6f4ff), Color(0xffe6ecfb)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: surfaceShadows,
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
                        color: teal,
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
                  boxShadow: surfaceShadows,
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
