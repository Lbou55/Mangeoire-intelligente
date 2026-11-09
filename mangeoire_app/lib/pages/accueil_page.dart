
import 'package:flutter/material.dart';

import '../models/animal.dart';
import '../outils.dart';
import '../services/session.dart';
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

    final nom = Session.instance.nom.trim();
    final nomAffiche = nom.isEmpty ? 'Utilisateur' : nom;

    final totalKg =
        animauxDemo.fold<double>(0, (somme, a) => somme + a.nourritureKg);

    final alertes = alertesDemo.where((a) => !a.resolue).toList();

    return SingleChildScrollView(
      child: Column(
        children: [
          // Bandeau de bienvenue.
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
                    BoxShadow(
                      color: p.ombre,
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bonjour, $nomAffiche',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ferme El Baraka · ${dateFr(DateTime.now())}',
                      style: const TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: 14,
                      ),
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
                // État de la mangeoire.
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
                          child: Ico(
                            'feeder_online',
                            taille: 28,
                            couleur: p.primaire,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Mangeoire en ligne',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Dernière mise à jour : il y a 2 min',
                              style: TextStyle(
                                color: p.texte2,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Ico('online', taille: 22, couleur: p.primaire),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Statistiques de l'exploitation.
                const Text(
                  'Votre exploitation',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.pets_outlined,
                        value: '${animauxDemo.length}',
                        label: 'Animaux suivis',
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: _StatCard(
                        icon: Icons.restaurant_outlined,
                        value: '18',
                        label: 'Distributions',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Analyse IA simulée.
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Analyse intelligente',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: p.primaireClair,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'SIMULATION IA',
                        style: TextStyle(
                          color: p.primaire,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                CarteDouce(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: p.primaire,
                            size: 25,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Prédiction de consommation',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        '8,2 kg',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      Text(
                        'Consommation prédite pour une vache',
                        style: TextStyle(
                          color: p.texte2,
                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(height: 20),

                      _LigneAnalyse(
                        label: 'Consommation observée',
                        valeur: '5,1 kg',
                        couleur: p.texte,
                      ),

                      const SizedBox(height: 10),

                      _LigneAnalyse(
                        label: 'Écart détecté',
                        valeur: '-3,1 kg',
                        couleur: p.alerte,
                      ),

                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: p.alerteClair,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: p.alerte,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Une consommation inférieure à la prédiction a été détectée. Une surveillance est recommandée.',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Recommandation IA.
                CarteDouce(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: p.primaire,
                        size: 27,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recommandation de l’IA',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Surveiller la consommation de cet animal lors des prochaines distributions et comparer son évolution sur plusieurs jours.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Alertes.
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Alertes en cours',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
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

                const SizedBox(height: 20),

                Text(
                  'Les prédictions et recommandations affichées sont fictives et servent uniquement à la démonstration.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: p.texte2,
                    fontSize: 11,
                  ),
                ),

                const SizedBox(height: 24),
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
              child: Center(
                child: Ico(icone, taille: 20, couleur: couleur),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: valeur,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
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
                  style: TextStyle(
                    color: p.texte2,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);

    return CarteDouce(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: p.primaire, size: 25),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: p.texte2,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _LigneAnalyse extends StatelessWidget {
  const _LigneAnalyse({
    required this.label,
    required this.valeur,
    required this.couleur,
  });

  final String label;
  final String valeur;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: p.texte2,
              fontSize: 13,
            ),
          ),
        ),
        Text(
          valeur,
          style: TextStyle(
            color: couleur,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
