import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import 'package:flutter/material.dart';

import 'pages/connexion_page.dart';
import 'pages/detail_signalement_page.dart';
import 'pages/splash_page.dart';
import 'services/session.dart';
import 'theme.dart';

void main() {
  runApp(const MangeoireApp());
}

class MangeoireApp extends StatelessWidget {
  const MangeoireApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Session.instance;
    // Ouvrir un signalement depuis le bandeau d'une notification.
    session.ouvrirSignalement = (id) {
      session.navigateur.currentState?.push(
        MaterialPageRoute<void>(builder: (context) => DetailSignalementPage(signalementId: id)),
      );
    };
    // Session expirée : retour à la page de connexion.
    session.versConnexion = () {
      session.navigateur.currentState?.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (context) => const ConnexionPage()),
        (route) => false,
      );
    };

    // ThemeProvider garde le thème courant (clair ou sombre) pour toute l'application.
    return ThemeProvider(
      initTheme: themeClair,
      builder: (context, theme) {
        return MaterialApp(
          title: 'Mangeoire',
          debugShowCheckedModeBanner: false,
          theme: theme,
          themeAnimationDuration: Duration.zero,
          navigatorKey: session.navigateur,
          scaffoldMessengerKey: session.messagerie,
          home: const SplashPage(),
        );
      },
    );
  }
}
