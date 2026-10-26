// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:scoresheet_app/main.dart';

void main() {
  testWidgets('create a game and record a score', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ScoresheetApp());
    await tester.pumpAndSettle();

    expect(find.text('No games yet'), findsOneWidget);

    await tester.tap(find.byIcon(CupertinoIcons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField).last, 'Friday Cards');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Friday Cards'), findsOneWidget);
    await tester.tap(find.text('Friday Cards'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Team'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField), 'Alice');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Round').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(CupertinoIcons.plus_circle));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField), '12');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('12'), findsNWidgets(2));

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Game'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('No games yet'), findsOneWidget);
  });

  testWidgets('swipe to delete a game from the list', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ScoresheetApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField).last, 'Friday Cards');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    // Cancelling the confirmation keeps the game.
    await tester.drag(find.text('Friday Cards'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Friday Cards'), findsOneWidget);

    await tester.drag(find.text('Friday Cards'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('No games yet'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('games'), isEmpty);
  });
}
