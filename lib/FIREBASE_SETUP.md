Firebase setup instructions

1) Install FlutterFire CLI (one-time):

```bash
dart pub global activate flutterfire_cli
# ensure ~/.pub-cache/bin is on PATH
```

2) Log in and configure your project:

```bash
flutterfire configure --project <YOUR_FIREBASE_PROJECT_ID>
```

This generates `lib/firebase_options.dart` and updates platform files.

3) Manually add platform files if not using FlutterFire CLI:
- Android: place `google-services.json` into `android/app/`.
- iOS: place `GoogleService-Info.plist` into `ios/Runner/`.

4) After adding files, run:

```bash
flutter pub get
flutter run
```

Notes:
- I added the Google Services Gradle plugin and classpath to Gradle files.
- If you want, I can run the FlutterFire configure step here, but it requires your Firebase project ID and auth.
