import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/bouton_theme.dart';
import '../widgets/ico.dart';

/// Page vide pour l'instant (la création de compte viendra plus tard).
class CreerComptePage extends StatelessWidget {
  const CreerComptePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemeSwitchingArea(
      child: Builder(
        builder: (context) {
          final p = Palette.of(context);
          return Scaffold(
            appBar: AppBar(
              scrolledUnderElevation: 0,
              title: const Text(
                'Créer un compte',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              actions: const [BoutonTheme(), SizedBox(width: 8)],
            ),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Ico('nav_profile', taille: 56, couleur: p.primaire),
                  const SizedBox(height: 12),
                  Text(
                    'Page en construction',
                    style: TextStyle(color: p.texte2, fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
