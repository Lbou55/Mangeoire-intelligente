import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/animal.dart';
import '../outils.dart';
import '../theme.dart';
import '../widgets/carte.dart';
import '../widgets/ico.dart';
import '../widgets/statut.dart';

/// Ouvre la fiche d'un animal : ce n'est pas une page pleine, c'est une carte
/// qui s'agrandit depuis la liste (animation Hero).
void ouvrirAnimal(BuildContext context, Animal animal) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierLabel: 'Fermer',
      barrierColor: const Color(0x8C0A1730),
      transitionDuration: const Duration(milliseconds: 450),
      reverseTransitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, animation, secondaryAnimation) {
        return CarteAnimal(animal: animal, animation: animation);
      },
    ),
  );
}

class CarteAnimal extends StatelessWidget {
  const CarteAnimal({super.key, required this.animal, required this.animation});

  final Animal animal;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final hauteurMax = MediaQuery.of(context).size.height * 0.82;

    // Le contenu apparaît dans la deuxième moitié de l'animation,
    // pendant que le fond de la carte finit de s'agrandir.
    final contenu = FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: hauteurMax),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _Contenu(animal: animal),
        ),
      ),
    );

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Hero(
                    tag: 'surface-${animal.id}',
                    child: Container(decoration: decorationCarte(p)),
                  ),
                ),
                contenu,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Contenu extends StatelessWidget {
  const _Contenu({required this.animal});

  final Animal animal;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final a = animal;
    final couleurStatut = a.enAlerte ? p.alerte : p.primaire;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // En-tête : avatar, nom, tag RFID, bouton fermer
        Row(
          children: [
            Hero(
              tag: 'avatar-${a.id}',
              child: AvatarVache(statut: a.statut, taille: 64),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.id,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Ico('rfid_tag', taille: 16, couleur: p.texte2),
                      const SizedBox(width: 6),
                      Text(a.rfid, style: TextStyle(color: p.texte2, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.close_rounded, color: p.texte2),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _Info(titre: 'Type', valeur: a.type),
            _Info(titre: 'Âge', valeur: '${a.ageMois} mois'),
            _Info(titre: 'Poids', valeur: '${a.poidsKg} kg'),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            PastilleStatut(a.statut),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                a.enAlerte ? 'Appétit à surveiller' : 'Comportement alimentaire normal',
                style: TextStyle(color: couleurStatut, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          "Aujourd'hui",
          style: TextStyle(color: p.texte2, fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _Chiffre(
              icone: 'food_delivered',
              valeur: '${fmtKg(a.nourritureKg)} kg',
              note: 'normale ${fmtKg(a.nourritureNormaleKg)} kg',
              alerte: a.enAlerte,
            ),
            const SizedBox(width: 10),
            _Chiffre(icone: 'visits', valeur: '${a.visites}', note: 'visites', alerte: false),
            const SizedBox(width: 10),
            _Chiffre(icone: 'eating_time', valeur: '${a.minutes} min', note: 'à manger', alerte: false),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Nourriture sur 7 jours (kg)',
          style: TextStyle(color: p.texte2, fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 10),
        _Graphique(animal: a),
        const SizedBox(height: 18),
        if (a.enAlerte)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.alerteClair,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              a.messageAlerte,
              style: TextStyle(color: p.alerte, fontWeight: FontWeight.w600, fontSize: 13.5),
            ),
          )
        else
          Text(
            "Rien à signaler aujourd'hui.",
            style: TextStyle(color: p.texte2, fontSize: 13.5),
          ),
      ],
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.titre, required this.valeur});

  final String titre;
  final String valeur;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titre, style: TextStyle(color: p.texte2, fontSize: 12)),
          const SizedBox(height: 2),
          Text(valeur, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _Chiffre extends StatelessWidget {
  const _Chiffre({
    required this.icone,
    required this.valeur,
    required this.note,
    required this.alerte,
  });

  final String icone;
  final String valeur;
  final String note;
  final bool alerte;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final couleur = alerte ? p.alerte : p.primaire;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: alerte ? p.alerteClair : p.primaireClair,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Ico(icone, taille: 20, couleur: couleur),
            const SizedBox(height: 8),
            Text(
              valeur,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: couleur),
            ),
            Text(
              note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.texte2, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

/// Graphique très simple : 7 barres dessinées avec des Container.
class _Graphique extends StatelessWidget {
  const _Graphique({required this.animal});

  final Animal animal;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final valeurs = animal.historiqueKg;
    final maxi = valeurs.reduce((x, y) => x > y ? x : y);
    final aujourdhui = DateTime.now();

    return SizedBox(
      height: 132,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < valeurs.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    fmtKg(valeurs[i]),
                    style: TextStyle(color: p.texte2, fontSize: 10.5),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 18,
                    height: 84 * valeurs[i] / maxi,
                    decoration: BoxDecoration(
                      color: i == valeurs.length - 1
                          ? (animal.enAlerte ? p.alerte : p.primaire)
                          : p.primaire.withAlpha(90),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    jourCourt(aujourdhui.subtract(Duration(days: valeurs.length - 1 - i))),
                    style: TextStyle(color: p.texte2, fontSize: 11),
                  ),
                ],
              )
                  .animate()
                  .fadeIn(delay: (350 + 60 * i).ms, duration: 350.ms)
                  .slideY(begin: 0.25, end: 0, delay: (350 + 60 * i).ms, duration: 350.ms),
            ),
        ],
      ),
    );
  }
}
