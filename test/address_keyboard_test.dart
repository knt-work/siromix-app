import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siromix/administrative_units.dart';

void main() {
  testWidgets(
    'address search stays reachable on a small screen with keyboard and status bar',
    (t) async {
      t.view.physicalSize = const Size(320, 568);
      t.view.devicePixelRatio = 1;
      t.view.padding = const FakeViewPadding(top: 24, bottom: 16);
      t.view.viewPadding = const FakeViewPadding(top: 24, bottom: 16);
      t.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPadding);
      addTearDown(t.view.resetViewPadding);
      addTearDown(t.view.resetViewInsets);
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () => chooseAdministrativeUnit(
                  ctx,
                  title: 'Tỉnh/TP',
                  units: const [AdministrativeUnit('01', 'Thành phố Hà Nội')],
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final search = find.byKey(const ValueKey('location-search'));
      expect(t.getTopLeft(search).dy, greaterThanOrEqualTo(24));
      expect(t.getBottomLeft(search).dy, lessThanOrEqualTo(568 - 280));
      await t.enterText(search, 'ha noi');
      await t.pumpAndSettle();
      expect(find.text('Thành phố Hà Nội'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
