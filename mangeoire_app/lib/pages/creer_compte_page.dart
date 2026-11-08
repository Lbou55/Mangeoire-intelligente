import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import 'package:flutter/material.dart';

import '../services/api.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets/bouton_theme.dart';
import '../widgets/carte.dart';
import '../widgets/ico.dart';
import 'accueil_shell.dart';

/// Création du compte PROPRIÉTAIRE (le premier compte). Les agriculteurs sont
/// ensuite créés par le propriétaire, depuis son profil.
class CreerComptePage extends StatefulWidget {
  const CreerComptePage({super.key});

  @override
  State<CreerComptePage> createState() => _CreerComptePageState();
}

class _CreerComptePageState extends State<CreerComptePage> {
  final _nom = TextEditingController();
  final _email = TextEditingController();
  final _motDePasse = TextEditingController();
  bool _masquer = true;
  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    _nom.dispose();
    _email.dispose();
    _motDePasse.dispose();
    super.dispose();
  }

  Future<void> _creer() async {
    if (_nom.text.trim().length < 2 || !_email.text.contains('@')) {
      setState(() => _erreur = 'Saisissez votre nom et une adresse e-mail valide.');
      return;
    }
    if (_motDePasse.text.length < 8) {
      setState(() => _erreur = 'Le mot de passe doit contenir au moins 8 caractères.');
      return;
    }
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      await Session.instance.inscription(_nom.text, _email.text, _motDePasse.text);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (context) => const AccueilShell()),
        (route) => false,
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
              title: const Text('Créer un compte', style: TextStyle(fontWeight: FontWeight.w700)),
              actions: const [BoutonTheme(), SizedBox(width: 8)],
            ),
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Le premier compte créé est le compte propriétaire. '
                        'Vous pourrez ensuite ajouter vos agriculteurs depuis votre profil.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: p.texte2, fontSize: 14.5),
                      ),
                      const SizedBox(height: 22),
                      TextField(
                        controller: _nom,
                        textCapitalization: TextCapitalization.words,
                        decoration: decorationChamp(
                          p,
                          indice: 'Nom complet',
                          debut: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Ico('nav_profile', taille: 22, couleur: p.texte2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
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
                        onSubmitted: (_) => _creer(),
                        decoration: decorationChamp(
                          p,
                          indice: 'Mot de passe (8 caractères minimum)',
                          debut: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Ico('password_lock', taille: 22, couleur: p.texte2),
                          ),
                          fin: IconButton(
                            onPressed: () => setState(() => _masquer = !_masquer),
                            icon: Ico(_masquer ? 'eye_show' : 'eye_hide', taille: 22, couleur: p.texte2),
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
                        onPressed: _enCours ? null : _creer,
                        child: _enCours
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5),
                              )
                            : const Text('Créer mon compte'),
                      ),
                      const SizedBox(height: 24),
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
