import 'package:flutter/material.dart';

/// Affiche une de vos icônes (assets/icons/<nom>.png) et la colorie.
/// Pour changer une icône plus tard, remplacez simplement le fichier PNG.
class Ico extends StatelessWidget {
  const Ico(this.nom, {super.key, this.taille = 24, this.couleur});

  final String nom;
  final double taille;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    return ImageIcon(
      AssetImage('assets/icons/$nom.png'),
      size: taille,
      color: couleur,
    );
  }
}
