import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/animal.dart';
import '../theme.dart';
import '../widgets/carte.dart';
import '../widgets/statut.dart';
import 'carte_animal.dart';

class AnimauxPage extends StatelessWidget {
  const AnimauxPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${animauxDemo.length} animaux enregistrés',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            'Identifiés par leur tag RFID',
            style: TextStyle(color: p.texte2, fontSize: 13),
          ),
          const SizedBox(height: 16),
          // Liste "en cascade" : chaque ligne apparaît 90 ms après la précédente.
          Column(
            children: [
              for (final a in animauxDemo)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TuileAnimal(a),
                ),
            ]
                .animate(interval: 90.ms)
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.15, end: 0, duration: 400.ms, curve: Curves.easeOut),
          ),
        ],
      ),
    );
  }
}

/// Une ligne de la liste. Au clic, la carte s'agrandit vers la fiche (widget Hero).
class TuileAnimal extends StatelessWidget {
  const TuileAnimal(this.animal, {super.key});

  final Animal animal;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return GestureDetector(
      onTap: () => ouvrirAnimal(context, animal),
      child: Stack(
        children: [
          // Le fond de la carte : c'est lui qui "voyage" vers la fiche.
          Positioned.fill(
            child: Hero(
              tag: 'surface-${animal.id}',
              child: Container(decoration: decorationCarte(p)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Hero(
                  tag: 'avatar-${animal.id}',
                  child: AvatarVache(statut: animal.statut),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        animal.id,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'RFID ${animal.rfid}',
                        style: TextStyle(color: p.texte2, fontSize: 12.5),
                      ),
                      Text(
                        '${animal.type} · ${animal.ageMois} mois',
                        style: TextStyle(color: p.texte2, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                PastilleStatut(animal.statut),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
