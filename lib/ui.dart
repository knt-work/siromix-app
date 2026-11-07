import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const teal = Color(0xff6052a9),
    ink = Color(0xff252940),
    muted = Color(0xff747b91);
const soft = Color(0xffeeebfa),
    line = Color(0xffeeedf5),
    orange = Color(0xfff4a357);
String score(double value) => value.toStringAsFixed(2).replaceAll('.', ',');
double? decimal(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.'));
bool validPoints(String value) {
  final n = decimal(value);
  return n != null && n.isFinite && n >= 0;
}

Widget heading(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 9),
  child: Text(
    text,
    style: const TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      height: 1.2,
      letterSpacing: -.7,
    ),
  ),
);
Widget secondary(String text) =>
    Text(text, style: const TextStyle(color: muted));
Widget eyebrow(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Text(
    text,
    style: const TextStyle(fontSize: 11, color: muted, letterSpacing: 1),
  ),
);
Widget note(
  String text, {
  bool warning = false,
  IconData icon = Icons.info_outline,
}) => Container(
  margin: const EdgeInsets.symmetric(vertical: 18),
  padding: const EdgeInsets.all(15),
  decoration: BoxDecoration(
    color: warning ? const Color(0xfffff4dc) : soft,
    borderRadius: BorderRadius.circular(14),
  ),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 20, color: warning ? const Color(0xff875710) : teal),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: warning ? const Color(0xff875710) : teal,
          ),
        ),
      ),
    ],
  ),
);
Widget action(
  String text,
  VoidCallback? onTap, {
  IconData icon = Icons.add,
  bool outline = false,
}) => Padding(
  padding: const EdgeInsets.only(top: 12),
  child: SizedBox(
    width: double.infinity,
    child: outline
        ? OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 19),
            label: Text(text, textAlign: TextAlign.center),
          )
        : FilledButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 19),
            label: Text(text, textAlign: TextAlign.center),
          ),
  ),
);
Widget panel(Widget child, {VoidCallback? onTap}) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Material(
    color: Colors.white,
    elevation: 3,
    shadowColor: const Color(0x25263658),
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(17), child: child),
    ),
  ),
);
Widget tileIcon(IconData icon, {bool warm = false}) => Container(
  width: 44,
  height: 44,
  decoration: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: warm
          ? [const Color(0xffffcf98), orange]
          : [const Color(0xffa99ae6), teal],
    ),
    boxShadow: surfaceShadows,
    borderRadius: BorderRadius.circular(13),
  ),
  child: Icon(icon, color: Colors.white, size: 23),
);
Widget sectionTitle(String title, String count) => Padding(
  padding: const EdgeInsets.only(top: 22, bottom: 13),
  child: Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      Text(count, style: const TextStyle(fontSize: 12, color: muted)),
    ],
  ),
);

const appBackground = Color(0xfff8f9fc);
const brandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xff208ebe), Color(0xff3e4d9d), Color(0xff69317f)],
);
const surfaceShadows = [
  BoxShadow(color: Color(0x12263658), blurRadius: 22, offset: Offset(0, 7)),
  BoxShadow(color: Color(0x08263658), blurRadius: 5, offset: Offset(0, 2)),
];

class SiroAppBar extends AppBar {
  SiroAppBar({
    super.key,
    super.title,
    super.leading,
    super.actions,
    super.automaticallyImplyLeading = true,
  }) : super(
         foregroundColor: Colors.white,
         backgroundColor: Colors.transparent,
         surfaceTintColor: Colors.transparent,
         elevation: 0,
         scrolledUnderElevation: 0,
         toolbarHeight: 64,
         titleTextStyle: const TextStyle(
           fontFamily: 'Roboto',
           fontSize: 20,
           fontWeight: FontWeight.w600,
           color: Colors.white,
         ),
         systemOverlayStyle: SystemUiOverlayStyle.light,
         flexibleSpace: const DecoratedBox(
           decoration: BoxDecoration(
             gradient: brandGradient,
             borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
           ),
           child: SizedBox.expand(),
         ),
       );
}

/// Adds surface separation without drawing input outlines. Focus changes the
/// fill and shadow; native semantics, validation and keyboard behavior stay intact.
class SiroInput extends StatefulWidget {
  const SiroInput({super.key, required this.child});
  final Widget child;
  @override
  State<SiroInput> createState() => _SiroInputState();
}

class _SiroInputState extends State<SiroInput> {
  bool focused = false;
  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    onFocusChange: (value) => setState(() => focused = value),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      decoration: BoxDecoration(
        color: focused ? const Color(0xfff1edff) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: focused
            ? const [
                BoxShadow(
                  color: Color(0x306052a9),
                  blurRadius: 16,
                  offset: Offset(0, 5),
                ),
              ]
            : surfaceShadows,
      ),
      child: widget.child,
    ),
  );
}

ThemeData siroTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(
    seedColor: teal,
    primary: teal,
    surface: Colors.white,
  ),
  scaffoldBackgroundColor: appBackground,
  textTheme: const TextTheme(bodyMedium: TextStyle(color: ink, fontSize: 14)),
  appBarTheme: const AppBarTheme(
    foregroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
  ),
  inputDecorationTheme: InputDecorationTheme(
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
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    labelStyle: const TextStyle(color: muted),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: orange,
      foregroundColor: const Color(0xff572e0d),
      elevation: 3,
      shadowColor: const Color(0x60ed9c49),
      minimumSize: const Size(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: teal,
      backgroundColor: Colors.white,
      side: BorderSide.none,
      elevation: 3,
      shadowColor: const Color(0x25263658),
      minimumSize: const Size(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: soft,
    elevation: 6,
    shadowColor: const Color(0x25263658),
    surfaceTintColor: Colors.transparent,
    labelTextStyle: WidgetStateProperty.resolveWith(
      (states) => TextStyle(
        fontSize: 11,
        color: states.contains(WidgetState.selected) ? teal : muted,
        fontWeight: states.contains(WidgetState.selected)
            ? FontWeight.w600
            : FontWeight.w400,
      ),
    ),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: appBackground,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: appBackground,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
  ),
  expansionTileTheme: const ExpansionTileThemeData(
    shape: RoundedRectangleBorder(),
    collapsedShape: RoundedRectangleBorder(),
  ),
  chipTheme: ChipThemeData(
    side: BorderSide.none,
    backgroundColor: soft,
    selectedColor: const Color(0xffded7f6),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  ),
);
