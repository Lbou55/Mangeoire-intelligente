import 'package:flutter/material.dart';

import '../models/animal.dart';
import '../outils.dart';
import '../theme.dart';
import '../widgets/carte.dart';
import '../widgets/ico.dart';
import 'alertes_page.dart';

class AccueilPage extends StatelessWidget {
  const AccueilPage({super.key, required this.onVoirAlertes});

  final VoidCallback onVoirAlertes;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);

    // Les chiffres de la page sont calculés à partir des animaux fictifs.
    final totalKg = animauxDemo.fold<double>(0, (somme, a) => somme + a.nourritureKg);
    final alertes = alertesDemo.where((a) => !a.resolue).toList();

    return SingleChildScrollView(
      child: Column(
        children: [
          // Bandeau bleu + deux cartes qui dépassent du bandeau.
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 150,
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [p.bandeau1, p.bandeau2],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(color: p.ombre, blurRadius: 24, offset: const Offset(0, 10)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bonjour, Karim',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ferme El Baraka · ${dateFr(DateTime.now())}',
                      style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 14),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 32,
                right: 32,
                top: 100,
                child: Row(
                  children: [
                    Expanded(
                      child: _CarteChiffre(
                        icone: 'food_delivered',
                        valeur: fmtKg(totalKg),
                        unite: ' kg',
                        libelle: 'Nourriture du jour',
                        alerte: false,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _CarteChiffre(
                        icone: 'status_alert',
                        valeur: '${alertes.length}',
                        unite: '',
                        libelle: 'Alertes du jour',
                        alerte: alertes.isNotEmpty,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 92),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CarteDouce(
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: p.primaireClair,
                        ),
                        child: Center(
                          child: Ico('feeder_online', taille: 28, couleur: p.primaire),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Mangeoire en ligne',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Dernière mise à jour : il y a 2 min',
                              style: TextStyle(color: p.texte2, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Ico('online', taille: 22, couleur: p.primaire),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Alertes en cours',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    TextButton(
                      onPressed: onVoirAlertes,
                      child: const Text('Tout voir'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                for (final a in alertes) ...[
                  AlerteTuile(a),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CarteChiffre extends StatelessWidget {
  const _CarteChiffre({
    required this.icone,
    required this.valeur,
    required this.unite,
    required this.libelle,
    required this.alerte,
  });

  final String icone;
  final String valeur;
  final String unite;
  final String libelle;
  final bool alerte;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final couleur = alerte ? p.alerte : p.primaire;
    return SizedBox(
      height: 126,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: decorationCarte(p, rayon: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: alerte ? p.alerteClair : p.primaireClair,
              ),
              child: Center(child: Ico(icone, taille: 20, couleur: couleur)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: valeur,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                      ),
                      TextSpan(
                        text: unite,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: p.texte2,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  libelle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.texte2, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
