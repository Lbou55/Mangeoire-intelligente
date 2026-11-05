import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import 'package:flutter/material.dart';

import 'pages/splash_page.dart';
import 'theme.dart';

void main() {
  runApp(const MangeoireApp());
}

class MangeoireApp extends StatelessWidget {
  const MangeoireApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ThemeProvider garde le thème courant (clair ou sombre) pour toute l'application.
    return ThemeProvider(
      initTheme: themeClair,
      builder: (context, theme) {
        return MaterialApp(
          title: 'Mangeoire',
          debugShowCheckedModeBanner: false,
          theme: theme,
          themeAnimationDuration: Duration.zero,
          home: const SplashPage(),
        );
      },
    );
  }
}
