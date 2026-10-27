// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:whos_winning/main.dart';

void main() {
  testWidgets('create a game and record a score', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const WhosWinningApp());
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
    // Tap the empty score cell beside the round label (label column is 100px wide)
    final roundLabel = tester.getCenter(find.text('Round 1'));
    await tester.tapAt(roundLabel + const Offset(105, 0));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField), '12');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('12'), findsNWidgets(2));

    // The blank line beneath the first score adds another, made negative with +/-
    await tester.tapAt(tester.getCenter(find.text('12').first) + const Offset(0, 22));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField), '5');
    await tester.tap(find.text('+/−'));
    await tester.pump();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('-5'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);

    // Tapping +/- again on an existing score makes it positive
    await tester.tap(find.text('-5'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+/−'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('5'), findsOneWidget);
    expect(find.text('17'), findsOneWidget);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Game'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('No games yet'), findsOneWidget);
  });

  testWidgets('score table grows with the system text size', (WidgetTester tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const WhosWinningApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField).last, 'Friday Cards');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Friday Cards'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Team'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField), 'Alice');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Round').first);
    await tester.pumpAndSettle();
    // At 2x the label column is 200px wide, so step past it into the score cell
    final roundLabel = tester.getCenter(find.text('Round 1'));
    await tester.tapAt(roundLabel + const Offset(110, 0));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField), '12');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    // Each score line doubles with the text, and the enlarged text still fits in it
    final score = find.text('12').first;
    final scoreLine = tester.getSize(find.ancestor(of: score, matching: find.byType(SizedBox)).first);
    expect(scoreLine.height, 44.0);
    final scoreText = tester.renderObject<RenderParagraph>(score);
    expect(scoreText.getMaxIntrinsicHeight(double.infinity), lessThanOrEqualTo(scoreLine.height));

    // Edit mode adds delete buttons to the header and round labels; any overflow fails the test
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.delete), findsNWidgets(2));
  });

  testWidgets('font size setting is saved and sizes the score table', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const WhosWinningApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.settings));
    await tester.pumpAndSettle();
    expect(find.text('16 pt'), findsOneWidget);

    // Drag the slider's thumb (a quarter of the way along at 16pt) to the largest size.
    // The track is inset by the thumb radius plus padding on each side.
    final slider = tester.getRect(find.byType(CupertinoSlider));
    const trackInset = 22.0;
    final thumb = Offset(
      slider.left + trackInset + (slider.width - 2 * trackInset) * 0.25,
      slider.center.dy,
    );
    await tester.dragFrom(thumb, const Offset(1000, 0));
    await tester.pumpAndSettle();
    expect(find.text('28 pt'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('scoreFontSize'), 28.0);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField).last, 'Friday Cards');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Friday Cards'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Team'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField), 'Alice');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Round').first);
    await tester.pumpAndSettle();
    // At 28pt the label column is 175px wide, so step past it into the score cell
    final roundLabel = tester.getCenter(find.text('Round 1'));
    await tester.tapAt(roundLabel + const Offset(100, 0));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField), '12');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    // Score lines are 22px at 16pt, so 38.5px at 28pt
    final score = find.text('12').first;
    final scoreLine = tester.getSize(find.ancestor(of: score, matching: find.byType(SizedBox)).first);
    expect(scoreLine.height, 38.5);
  });

  testWidgets('appearance setting switches to dark mode and is saved', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const WhosWinningApp());
    await tester.pumpAndSettle();

    Brightness currentBrightness() =>
        CupertinoTheme.brightnessOf(tester.element(find.byType(CupertinoPageScaffold).last));

    // Defaults to following the system, which is light in tests
    expect(currentBrightness(), Brightness.light);

    await tester.tap(find.byIcon(CupertinoIcons.settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(currentBrightness(), Brightness.dark);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('appearance'), 'dark');

    // The score table uses its dark background
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(CupertinoIcons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField).last, 'Friday Cards');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Friday Cards'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Team'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField), 'Alice');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Round').first);
    await tester.pumpAndSettle();

    final tableBackground = find.byWidgetPredicate(
      (widget) =>
          widget is Container && widget.color?.toARGB32() == scoreSheetPaper.darkColor.toARGB32(),
    );
    expect(tableBackground, findsOneWidget);
  });

  testWidgets('saved appearance is restored on launch', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'appearance': 'dark'});
    await tester.pumpWidget(const WhosWinningApp());
    await tester.pumpAndSettle();

    final screen = tester.element(find.byType(CupertinoPageScaffold));
    expect(CupertinoTheme.brightnessOf(screen), Brightness.dark);
  });

  testWidgets('wide table scrolls sideways from the empty space below it', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const WhosWinningApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField).last, 'Friday Cards');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Friday Cards'));
    await tester.pumpAndSettle();

    // Enough teams to make the table wider than the 800px test screen
    for (var i = 1; i <= 10; i++) {
      await tester.tap(find.byIcon(CupertinoIcons.person_add));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(CupertinoTextField), 'Team number $i');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Add Round').first);
    await tester.pumpAndSettle();

    final horizontalScroll = find.byWidgetPredicate(
      (widget) => widget is Scrollable && widget.axisDirection == AxisDirection.right,
    );
    double scrollOffset() => tester.state<ScrollableState>(horizontalScroll).position.pixels;
    expect(scrollOffset(), 0);

    // Swipe left just above the bottom bar, well below the one-round table
    final bottomBar = tester.getTopLeft(find.text('Add Round'));
    await tester.dragFrom(Offset(600, bottomBar.dy - 60), const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(scrollOffset(), greaterThan(0));
  });

  testWidgets('swipe to delete a game from the list', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const WhosWinningApp());
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
