import 'package:flutter/material.dart';

import '../models/animal.dart';
import '../theme.dart';
import '../widgets/carte.dart';
import '../widgets/ico.dart';

class AlertesPage extends StatelessWidget {
  const AlertesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final enCours = alertesDemo.where((a) => !a.resolue).toList();
    final resolues = alertesDemo.where((a) => a.resolue).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${enCours.length} alertes en cours',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          for (final a in enCours) ...[
            AlerteTuile(a),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 12),
          Text(
            'Résolues',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: p.texte2,
            ),
          ),
          const SizedBox(height: 12),
          for (final a in resolues) ...[
            AlerteTuile(a),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

/// Une ligne d'alerte (utilisée aussi sur la page d'accueil).
class AlerteTuile extends StatelessWidget {
  const AlerteTuile(this.alerte, {super.key});

  final AlerteItem alerte;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final resolue = alerte.resolue;
    final couleur = resolue ? p.primaire : p.alerte;
    return CarteDouce(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: resolue ? p.primaireClair : p.alerteClair,
            ),
            child: Center(
              child: Ico(
                resolue ? 'status_resolved' : 'status_alert',
                taille: 22,
                couleur: couleur,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alerte.titre,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  alerte.detail,
                  style: TextStyle(color: p.texte2, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  resolue ? '${alerte.quand} · Résolue' : alerte.quand,
                  style: TextStyle(
                    color: couleur,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
