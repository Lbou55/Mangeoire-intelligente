import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/carte.dart';
import '../widgets/ico.dart';

class MangeoirePage extends StatelessWidget {
  const MangeoirePage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Votre image de la maquette : assets/images/mangeoire_maquette.png
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.asset(
                'assets/images/mangeoire_maquette.png',
                fit: BoxFit.cover,
                errorBuilder: (context, erreur, trace) {
                  return Container(
                    color: p.primaireClair,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Ico('feeder_online', taille: 56, couleur: p.primaire),
                        const SizedBox(height: 12),
                        Text(
                          'Ajoutez votre image ici :\nassets/images/mangeoire_maquette.png',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.texte2, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          CarteDouce(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Mangeoire n°1',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: p.primaireClair,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Ico('online', taille: 15, couleur: p.primaire),
                          const SizedBox(width: 6),
                          Text(
                            'En ligne',
                            style: TextStyle(
                              color: p.primaire,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text('Réservoir', style: TextStyle(color: p.texte2, fontSize: 13)),
                    ),
                    const Text('72 %', style: TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 8),
                // Barre de niveau : deux Expanded dont la largeur suit le pourcentage.
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 10,
                    child: Row(
                      children: [
                        Expanded(flex: 72, child: ColoredBox(color: p.primaire)),
                        Expanded(flex: 28, child: ColoredBox(color: p.primaireClair)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const _Ligne(libelle: 'Dernière distribution', valeur: '07:42'),
                const _Ligne(libelle: "Rations distribuées aujourd'hui", valeur: '14'),
                const _Ligne(libelle: 'Réapprovisionnement estimé', valeur: 'dans 6 jours'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bientôt disponible')),
              );
            },
            icon: const Ico('cube_3d', taille: 22),
            label: const Text('Voir le modèle 3D'),
          ),
        ],
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.libelle, required this.valeur});

  final String libelle;
  final String valeur;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(libelle, style: TextStyle(color: p.texte2, fontSize: 14)),
          ),
          Text(valeur, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }
}
