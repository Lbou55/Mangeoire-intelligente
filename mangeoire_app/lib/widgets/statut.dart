import 'package:flutter/material.dart';

import '../models/animal.dart';
import '../theme.dart';
import 'ico.dart';

/// Petite pastille "Normal" (bleu) ou "Alerte" (orange), toujours avec icône + texte.
class PastilleStatut extends StatelessWidget {
  const PastilleStatut(this.statut, {super.key});

  final Statut statut;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final alerte = statut == Statut.alerte;
    final couleur = alerte ? p.alerte : p.primaire;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: alerte ? p.alerteClair : p.primaireClair,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Ico(alerte ? 'status_alert' : 'status_normal', taille: 15, couleur: couleur),
          const SizedBox(width: 6),
          Text(
            alerte ? 'Alerte' : 'Normal',
            style: TextStyle(
              color: couleur,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Le rond avec la vache (icône nav_animals) devant chaque animal.
class AvatarVache extends StatelessWidget {
  const AvatarVache({super.key, required this.statut, this.taille = 52});

  final Statut statut;
  final double taille;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final alerte = statut == Statut.alerte;
    return Container(
      width: taille,
      height: taille,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: alerte ? p.alerteClair : p.primaireClair,
      ),
      child: Center(
        child: Ico(
          'nav_animals',
          taille: taille * 0.56,
          couleur: alerte ? p.alerte : p.primaire,
        ),
      ),
    );
  }
}
