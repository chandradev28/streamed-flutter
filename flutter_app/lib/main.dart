import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:fvp/fvp.dart' as fvp;

import 'src/app.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  HttpOverrides.global = MyHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();
  try {
    fvp.registerWith(
      options: <String, Object>{
        'fastSeek': true,
        'lowLatency': 1,
        'video.decoders': <String>['auto'],
      },
    );
  } catch (_) {
    // Some Android devices can fail native player registration at startup.
    // Keep the app usable and let external playback remain available.
  }
  runApp(const StreamedApp());
}
