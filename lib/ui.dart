import 'package:flutter/material.dart';

const teal = Color(0xff087f78),
    ink = Color(0xff182f39),
    muted = Color(0xff607780);
const soft = Color(0xffe2f3ee),
    line = Color(0xffe1e9ec),
    orange = Color(0xffe75d20);
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
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: line),
    ),
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
    color: warm ? const Color(0xffffe4cf) : soft,
    borderRadius: BorderRadius.circular(13),
  ),
  child: Icon(icon, color: warm ? orange : teal, size: 23),
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
