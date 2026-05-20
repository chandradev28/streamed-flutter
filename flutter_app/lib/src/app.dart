import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'theme/app_theme.dart';

class StreamedApp extends StatelessWidget {
  const StreamedApp({
    super.key,
    this.home,
  });

  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Streamed Flutter',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: home ?? const HomeShell(),
    );
  }
}
