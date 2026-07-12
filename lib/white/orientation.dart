import 'package:flutter/services.dart';

/// Locks the app to portrait for game screens.
Future<void> lockPortrait() async {
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
}

/// Allows all orientations (used by loading + gray screens).
Future<void> allowAllOrientations() async {
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
}
