import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/session.dart';
import 'accueil_shell.dart';
import 'connexion_page.dart';

/// Écran de démarrage : le logo apparaît, puis on passe à la connexion.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _continuer();
  }

  Future<void> _continuer() async {
    // On attend l'animation du logo ET la vérification du jeton enregistré.
    final resultats = await Future.wait<bool>([
      Future.delayed(const Duration(milliseconds: 2600), () => true),
      Session.instance.restaurer(),
    ]);
    final dejaConnecte = resultats[1];
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) =>
            dejaConnecte ? const AccueilShell() : const ConnexionPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/branding/mangeoire_logo_blue.png', width: 340)
                .animate()
                .fadeIn(duration: 700.ms)
                .scale(
                  begin: const Offset(0.9, 0.9),
                  end: const Offset(1, 1),
                  duration: 700.ms,
                  curve: Curves.easeOutBack,
                ),
            const SizedBox(height: 8),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF1F63D1),
              ),
            ).animate().fadeIn(delay: 900.ms, duration: 500.ms),
          ],
        ),
      ),
    );
  }
}
