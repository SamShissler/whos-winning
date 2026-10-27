# Who's Winning?

<img src="assets/icon/whos-winning-icon.png" alt="Who's Winning? app icon" width="120">

A score-keeping app for card and board games, built with Flutter. Create a game, add teams, and record scores round by round; running totals are calculated for you.

## Features

- **Games list:** create, search, and rename games (long-press a game to rename it). Swipe left to delete one.
- **Score table:** one column per team, with a total row under each round.
  - Tap anywhere in a cell to add a score. Tap an existing score to edit or delete it.
  - Negative scores are entered with the `+/−` button in the score field, since the iOS number pad has no minus key.
  - Rows grow as scores are added, always leaving a blank line for the next one.
  - The table scrolls in both directions when it's larger than the screen.
- **Edit mode:** delete teams, rounds, or the whole game.
- **Settings** (gear icon on the Games screen):
  - Appearance: follow the system setting, or always light or dark.
  - Score font size from 12 to 28pt, with a live preview. The table also respects the device's own text size setting.

Everything is stored on the device with `shared_preferences`; there is no account or server.

## Requirements

- Flutter 3.47 or newer (Dart 3.8+)
- **iOS / macOS:** Xcode. Plugins are linked with Swift Package Manager; CocoaPods is not used.
- **Android:** Android Studio and its bundled JDK. The Android build uses Gradle 9.3 and Android Gradle plugin 9.1, which run on current Java versions, including Java 25.

Run `flutter doctor` to check your setup.

## Running the app

```sh
flutter pub get
flutter devices                 # list simulators, emulators, and connected phones
flutter run -d <device id>
```

**Android emulator:** start one from Android Studio's Device Manager, or with `flutter emulators --launch <emulator id>`.

**iOS simulator:** open the Simulator app, or run `open -a Simulator`.

### Installing on a physical iPhone

1. Set your own signing team and bundle identifier. In Xcode, open `ios/Runner.xcworkspace`, select the Runner target, and go to Signing & Capabilities.
2. Build and install a release build, which keeps working after the phone is unplugged:

   ```sh
   flutter build ios --release
   xcrun devicectl device install app --device <device id> build/ios/iphoneos/Runner.app
   ```

   Installing with `devicectl` updates the app in place and keeps its saved data. `flutter install` uninstalls the app first, which deletes saved games.
3. The first time, trust the developer certificate on the phone under Settings → General → VPN & Device Management.

With a free Apple developer account, the installed app expires after 7 days and needs reinstalling.

## Tests

```sh
flutter test
```

The widget tests in `test/widget_test.dart` cover creating games and scoring, negative scores, swipe-to-delete, both settings, large system text sizes, and scrolling a wide table.

## Project notes

- **All app code is in `lib/main.dart`.** The main pieces:
  - `AppSettings` holds the font size and appearance, saved to `shared_preferences`. Screens listen to it so changes apply immediately.
  - `ScoreSheetMetrics` derives every score-table size (line heights, padding, column widths, row heights) and color from the font size, the system text size, and light or dark mode. The table and its grid painter (`TableGridPainter`) both read from it, so they always line up. Change table sizing here, not in the widgets.
- **iOS uses the UIScene lifecycle.** iOS 27 terminates apps that don't, so `ios/Runner/AppDelegate.swift` starts the Flutter engine and a `SceneDelegate` shows it. `Info.plist` declares the scene manifest instead of a main storyboard.
- **App icon:** the original artwork is `assets/icon/whos-winning-icon.png`. The other images in `assets/icon/` are derived from it: a full-bleed square (also used as the Android adaptive-icon foreground, which the tool insets 16%) and a padded macOS version. After changing them, run `dart run flutter_launcher_icons` to regenerate every platform's icons. The tool sets the iOS project's `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` setting to `AppIcon`; change it back to `YES`.
- **Identifiers:** the Dart package is `whos_winning`, and the bundle and application ID is `com.samshissler.whoswinning` on every platform. Changing an ID makes the device treat the result as a different app, so avoid it once people have saved games.
- **Minimum OS versions:** iOS 17.0 and macOS 12.0, set in the Xcode projects.
