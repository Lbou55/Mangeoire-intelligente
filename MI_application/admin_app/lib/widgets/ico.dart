import 'package:flutter/material.dart';

/// One of our PNG icons (assets/icons/<name>.png), tinted.
/// To change an icon later, just replace the PNG file.
class Ico extends StatelessWidget {
  const Ico(this.nom, {super.key, this.taille = 24, this.couleur});

  final String nom;
  final double taille;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    return ImageIcon(AssetImage('assets/icons/$nom.png'), size: taille, color: couleur);
  }
}
