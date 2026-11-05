import 'package:flutter/material.dart';

import '../models/animal.dart';
import '../theme.dart';
import '../widgets/carte.dart';
import '../widgets/ico.dart';
import 'connexion_page.dart';

class ProfilPage extends StatelessWidget {
  const ProfilPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final nbAlertes = alertesDemo.where((a) => !a.resolue).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: [
          CarteDouce(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: p.primaireClair),
                  child: Center(
                    child: Ico('nav_profile', taille: 48, couleur: p.primaire),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Karim Ben Salem',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: p.primaireClair,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Agriculteur',
                    style: TextStyle(
                      color: p.primaire,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Ferme El Baraka',
                  style: TextStyle(color: p.texte2, fontSize: 14),
                ),
                Text(
                  'karim.bensalem@exemple.com',
                  style: TextStyle(color: p.texte2, fontSize: 14),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _Compteur(valeur: '${animauxDemo.length}', libelle: 'Animaux'),
                    _Compteur(valeur: '1', libelle: 'Mangeoire'),
                    _Compteur(valeur: '$nbAlertes', libelle: 'Alertes'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _LigneMenu(
            icone: 'settings',
            libelle: 'Paramètres',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bientôt disponible')),
              );
            },
          ),
          const SizedBox(height: 12),
          _LigneMenu(
            icone: 'sign_out',
            libelle: 'Se déconnecter',
            alerte: true,
            onTap: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute<void>(builder: (context) => const ConnexionPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Compteur extends StatelessWidget {
  const _Compteur({required this.valeur, required this.libelle});

  final String valeur;
  final String libelle;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(valeur, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          Text(libelle, style: TextStyle(color: p.texte2, fontSize: 12.5)),
        ],
      ),
    );
  }
}

class _LigneMenu extends StatelessWidget {
  const _LigneMenu({
    required this.icone,
    required this.libelle,
    required this.onTap,
    this.alerte = false,
  });

  final String icone;
  final String libelle;
  final VoidCallback onTap;
  final bool alerte;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final couleur = alerte ? p.alerte : p.primaire;
    return CarteDouce(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Ico(icone, taille: 24, couleur: couleur),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              libelle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: alerte ? p.alerte : p.texte,
              ),
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: p.texte2),
        ],
      ),
    );
  }
}
