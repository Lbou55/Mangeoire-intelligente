import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/api.dart';
import '../services/session.dart';
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
  final _email = TextEditingController();
  final _motDePasse = TextEditingController();
  bool _masquer = true;
  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    _email.dispose();
    _motDePasse.dispose();
    super.dispose();
  }

  Future<void> _entrer() async {
    if (_email.text.trim().isEmpty || _motDePasse.text.isEmpty) {
      setState(() => _erreur = 'Saisissez votre e-mail et votre mot de passe.');
      return;
    }
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      await Session.instance.connexion(_email.text, _motDePasse.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (context) => const AccueilShell()),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
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
                        controller: _email,
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
                        controller: _motDePasse,
                        obscureText: _masquer,
                        onSubmitted: (_) => _entrer(),
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
                      if (_erreur != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _erreur!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.danger, fontWeight: FontWeight.w600),
                        ),
                      ],
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _enCours ? null : _entrer,
                        child: _enCours
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5),
                              )
                            : const Text('Se connecter'),
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
