import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siromix/ui.dart';

void main() {
  testWidgets('borderless field keeps validation and keyboard focus feedback', (
    t,
  ) async {
    final form = GlobalKey<FormState>();
    await t.pumpWidget(
      MaterialApp(
        theme: siroTheme(),
        home: Scaffold(
          appBar: SiroAppBar(title: const Text('Hồ sơ & dữ liệu')),
          body: Form(
            key: form,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: SiroInput(
                child: TextFormField(
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) => v == null || !v.contains('@')
                      ? 'Email chưa hợp lệ'
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final header = find.descendant(
      of: find.byType(SiroAppBar),
      matching: find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).gradient == brandGradient,
      ),
    );
    expect(header, findsOneWidget);
    expect(t.getSize(header).height, greaterThanOrEqualTo(64));
    expect(t.getSize(header).width, greaterThan(300));
    final theme = Theme.of(t.element(find.byType(TextFormField)));
    for (final border in [
      theme.inputDecorationTheme.enabledBorder,
      theme.inputDecorationTheme.focusedBorder,
      theme.inputDecorationTheme.errorBorder,
      theme.inputDecorationTheme.focusedErrorBorder,
    ]) {
      expect(border!.borderSide, BorderSide.none);
    }
    final surface = find.descendant(
      of: find.byType(SiroInput),
      matching: find.byType(AnimatedContainer),
    );
    final before =
        t.widget<AnimatedContainer>(surface).decoration as BoxDecoration;
    expect(before.border, isNull);
    expect(before.boxShadow, isNotEmpty);
    await t.tap(find.byType(TextFormField));
    await t.pumpAndSettle();
    final focused =
        t.widget<AnimatedContainer>(surface).decoration as BoxDecoration;
    expect(focused.color, isNot(before.color));
    expect(focused.boxShadow, isNot(before.boxShadow));
    expect(form.currentState!.validate(), false);
    await t.pumpAndSettle();
    expect(find.text('Email chưa hợp lệ'), findsOneWidget);
    await t.enterText(find.byType(TextFormField), 'teacher@example.com');
    expect(form.currentState!.validate(), true);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
