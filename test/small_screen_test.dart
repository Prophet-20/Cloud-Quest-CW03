import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_quest/main.dart';

void main() {
  testWidgets('Sign-in and registration fit a small phone', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: SignInScreen()));
    await tester.scrollUntilVisible(
      find.byKey(const Key('toggle-register')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('toggle-register')));
    await tester.pumpAndSettle();
    expect(find.text('Create your learner account'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('authenticate')));
    await tester.tap(find.byKey(const Key('authenticate')));
    await tester.pumpAndSettle();
    expect(find.textContaining('at least 6 characters'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
