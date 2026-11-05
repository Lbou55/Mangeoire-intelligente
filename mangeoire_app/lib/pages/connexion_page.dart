import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme.dart';
import '../widgets/bouton_theme.dart';
import '../widgets/carte.dart';
import '../widgets/ico.dart';
import 'accueil_shell.dart';
import 'creer_compte_page.dart';

class ConnexionPage extends StatefulWidget {
  const ConnexionPage({super.key});

  @override
  State<ConnexionPage> createState() => _ConnexionPageState();
}

class _ConnexionPageState extends State<ConnexionPage> {
  bool _masquer = true;

  void _entrer() {
    // Pas de vraie vérification pour l'instant : on entre dans l'application.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (context) => const AccueilShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ThemeSwitchingArea(
      child: Builder(
        builder: (context) {
          final p = Palette.of(context);
          return Scaffold(
            appBar: AppBar(
              scrolledUnderElevation: 0,
              actions: const [BoutonTheme(), SizedBox(width: 8)],
            ),
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset(
                        'assets/branding/mangeoire_app_icon_blue.png',
                        height: 130,
                      ).animate().fadeIn(duration: 500.ms).slideY(
                            begin: 0.1,
                            end: 0,
                            duration: 500.ms,
                          ),
                      const SizedBox(height: 8),
                      const Text(
                        'Connexion',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Suivez le repas de chaque animal.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: p.texte2, fontSize: 15),
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        keyboardType: TextInputType.emailAddress,
                        decoration: decorationChamp(
                          p,
                          indice: 'Adresse e-mail',
                          debut: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Ico('email', taille: 22, couleur: p.texte2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        obscureText: _masquer,
                        decoration: decorationChamp(
                          p,
                          indice: 'Mot de passe',
                          debut: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Ico('password_lock', taille: 22, couleur: p.texte2),
                          ),
                          fin: IconButton(
                            onPressed: () => setState(() => _masquer = !_masquer),
                            icon: Ico(
                              _masquer ? 'eye_show' : 'eye_hide',
                              taille: 22,
                              couleur: p.texte2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _entrer,
                        child: const Text('Se connecter'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Pas encore de compte ?',
                            style: TextStyle(color: p.texte2),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (context) => const CreerComptePage(),
                                ),
                              );
                            },
                            child: const Text(
                              'Créer un compte',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
