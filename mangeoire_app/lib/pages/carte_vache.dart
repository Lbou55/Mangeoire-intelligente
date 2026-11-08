import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/vache.dart';
import '../outils.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets/carte.dart';
import '../widgets/ico.dart';
import '../widgets/statut.dart';
import 'ajouter_vache_page.dart';
import 'detail_signalement_page.dart';
import 'signalement_page.dart';

/// Ouvre la fiche d'une vache : une carte qui s'agrandit depuis la liste (animation Hero).
Future<void> ouvrirVache(BuildContext context, Vache vache) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierLabel: 'Fermer',
      barrierColor: const Color(0x8C0A1730),
      transitionDuration: const Duration(milliseconds: 450),
      reverseTransitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, animation, secondaryAnimation) {
        return CarteVache(vache: vache, animation: animation);
      },
    ),
  );
}

class CarteVache extends StatelessWidget {
  const CarteVache({super.key, required this.vache, required this.animation});

  final Vache vache;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final hauteurMax = MediaQuery.of(context).size.height * 0.84;

    final contenu = FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: const Interval(0.5, 1.0, curve: Curves.easeOut)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: hauteurMax),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _Contenu(vache: vache),
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
                    tag: 'surface-${vache.tag}',
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

class _Contenu extends StatefulWidget {
  const _Contenu({required this.vache});

  final Vache vache;

  @override
  State<_Contenu> createState() => _ContenuState();
}

class _ContenuState extends State<_Contenu> {
  List<Mesure> _historique = [];
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _chargerHistorique();
  }

  Future<void> _chargerHistorique() async {
    try {
      final r = await Session.instance.api.get('/cows/${widget.vache.tag}/history', query: {'days': '7'}) as List;
      if (!mounted) return;
      setState(() => _historique = [for (final j in r) Mesure(Map<String, dynamic>.from(j as Map))]);
    } catch (_) {
      // pas de graphique si le serveur ne répond pas : le reste de la fiche reste utile
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _modifier() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (context) => AjouterVachePage(vache: widget.vache)),
    );
    if (ok == true && mounted) Navigator.of(context).pop(); // la liste se recharge toute seule
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final v = widget.vache;
    final m = v.mesure;
    final (couleur, claire) = couleursNiveau(p, v.niveau);
    final aSignaler = v.niveau != Niveau.normal;
    final texteNiveau = switch (v.niveau) {
      Niveau.danger => 'Situation de danger : intervention nécessaire',
      Niveau.alerte => 'Appétit à surveiller',
      Niveau.normal => 'Comportement alimentaire normal',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Hero(tag: 'avatar-${v.tag}', child: AvatarNiveau(niveau: v.niveau, taille: 64)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v.titre, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Ico('rfid_tag', taille: 16, couleur: p.texte2),
                      const SizedBox(width: 6),
                      Text(v.tag, style: TextStyle(color: p.texte2, fontSize: 13)),
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
            _Info(titre: 'Type', valeur: v.typeFr),
            _Info(titre: 'Âge', valeur: v.ageFr),
            _Info(titre: 'Mesure du', valeur: m == null ? '—' : m.date.substring(5).split('-').reversed.join('/')),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: claire, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              PastilleNiveau(v.niveau),
              const SizedBox(width: 10),
              Expanded(
                child: Text(texteNiveau, style: TextStyle(color: couleur, fontWeight: FontWeight.w700, fontSize: 13.5)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text("Mesures de la mangeoire", style: TextStyle(color: p.texte2, fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 8),
        if (m == null)
          Text("Aucune mesure reçue pour l'instant.", style: TextStyle(color: p.texte2, fontSize: 13.5))
        else ...[
          Row(
            children: [
              _Chiffre(
                icone: 'food_delivered',
                valeur: '${fmtKg(m.nourritureKg)} kg',
                note: 'offert ${fmtKg(m.offerteKg)} kg',
                niveau: v.niveau,
              ),
              const SizedBox(width: 10),
              _Chiffre(icone: 'visits', valeur: '${m.visites}', note: 'visites', niveau: Niveau.normal),
              const SizedBox(width: 10),
              _Chiffre(icone: 'eating_time', valeur: '${m.minutes.round()} min', note: 'à manger', niveau: Niveau.normal),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Puce('Repas moyen ${m.repasMin.toStringAsFixed(1).replaceAll('.', ',')} min'),
              _Puce('${m.sansNourriture} visite(s) sans nourriture'),
              if (m.premiereVisite != null) _Puce('1re visite ${fmtHeure(m.premiereVisite!)}'),
              if (m.derniereVisite != null) _Puce('Dernière ${fmtHeure(m.derniereVisite!)}'),
            ],
          ),
        ],
        const SizedBox(height: 20),
        Text('Nourriture sur 7 jours (kg)', style: TextStyle(color: p.texte2, fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 10),
        if (_chargement)
          const SizedBox(height: 132, child: Center(child: CircularProgressIndicator()))
        else if (_historique.isEmpty)
          Text('Pas assez de données.', style: TextStyle(color: p.texte2, fontSize: 13.5))
        else
          _Graphique(mesures: _historique, niveau: v.niveau),
        const SizedBox(height: 20),
        if (aSignaler) ...[
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: couleur,
              foregroundColor: p.surPrimaire,
            ),
            icon: const Icon(Icons.edit_note_rounded),
            label: Text(v.niveau == Niveau.danger ? 'Signaler le danger' : 'Envoyer un rapport'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (context) => SignalementPage(vache: v)),
              );
            },
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            side: BorderSide(color: p.bordure),
            foregroundColor: p.texte,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: const Icon(Icons.forum_outlined),
          label: const Text('Signalements de cette vache'),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (context) => ListeSignalementsPage(vache: v)),
            );
          },
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: _modifier,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Modifier cette vache'),
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

class _Puce extends StatelessWidget {
  const _Puce(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.bordure),
      ),
      child: Text(texte, style: TextStyle(color: p.texte2, fontSize: 12)),
    );
  }
}

class _Chiffre extends StatelessWidget {
  const _Chiffre({required this.icone, required this.valeur, required this.note, required this.niveau});

  final String icone;
  final String valeur;
  final String note;
  final Niveau niveau;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final (couleur, claire) = couleursNiveau(p, niveau);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: claire, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Ico(icone, taille: 20, couleur: couleur),
            const SizedBox(height: 8),
            Text(valeur,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: couleur)),
            Text(note,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: p.texte2, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

/// Graphique très simple : une barre (Container) par jour.
class _Graphique extends StatelessWidget {
  const _Graphique({required this.mesures, required this.niveau});

  final List<Mesure> mesures;
  final Niveau niveau;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final (couleur, _) = couleursNiveau(p, niveau);
    final maxi = mesures.map((m) => m.nourritureKg).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 132,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < mesures.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(fmtKg(mesures[i].nourritureKg), style: TextStyle(color: p.texte2, fontSize: 10.5)),
                  const SizedBox(height: 4),
                  Container(
                    width: 18,
                    height: maxi <= 0 ? 4 : 84 * mesures[i].nourritureKg / maxi,
                    decoration: BoxDecoration(
                      color: i == mesures.length - 1 ? couleur : p.primaire.withAlpha(90),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    jourCourt(DateTime.tryParse(mesures[i].date) ?? DateTime.now()),
                    style: TextStyle(color: p.texte2, fontSize: 11),
                  ),
                ],
              )
                  .animate()
                  .fadeIn(delay: (150 + 60 * i).ms, duration: 350.ms)
                  .slideY(begin: 0.25, end: 0, delay: (150 + 60 * i).ms, duration: 350.ms),
            ),
        ],
      ),
    );
  }
}
