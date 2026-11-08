import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/vache.dart';
import '../services/api.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets/carte.dart';
import '../widgets/statut.dart';
import 'ajouter_vache_page.dart';
import 'carte_vache.dart';

/// La page "Animaux" : trois menus (Danger, Alerte, Normal). On touche un menu
/// pour ouvrir la liste des vaches de cette classe.
class AnimauxPage extends StatefulWidget {
  const AnimauxPage({super.key});

  @override
  State<AnimauxPage> createState() => _AnimauxPageState();
}

class _AnimauxPageState extends State<AnimauxPage> {
  List<Vache> _vaches = [];
  bool _chargement = true;
  String? _erreur;
  String _recherche = '';
  Timer? _minuteur;

  // Danger et Alerte sont ouverts par défaut (ce sont les importants).
  final Map<Niveau, bool> _ouvert = {
    Niveau.danger: true,
    Niveau.alerte: true,
    Niveau.normal: false,
  };

  @override
  void initState() {
    super.initState();
    _charger();
    // Les statuts viennent du Raspberry Pi : on rafraîchit toutes les 30 secondes.
    _minuteur = Timer.periodic(const Duration(seconds: 30), (_) => _charger(silencieux: true));
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }

  Future<void> _charger({bool silencieux = false}) async {
    if (!silencieux) setState(() => _chargement = true);
    try {
      final r = await Session.instance.api.get('/cows') as List;
      if (!mounted) return;
      setState(() {
        _vaches = [for (final j in r) Vache(Map<String, dynamic>.from(j as Map))];
        _erreur = null;
      });
    } on ApiException catch (e) {
      if (mounted && !silencieux) setState(() => _erreur = e.message);
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  List<Vache> _de(Niveau n) {
    final q = _recherche.trim().toLowerCase();
    return [
      for (final v in _vaches)
        if (v.niveau == n && (q.isEmpty || v.tag.toLowerCase().contains(q) || v.nom.toLowerCase().contains(q))) v,
    ];
  }

  Future<void> _ajouter() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (context) => const AjouterVachePage()),
    );
    if (ok == true) _charger(silencieux: true);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);

    return RefreshIndicator(
      onRefresh: () => _charger(silencieux: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _recherche = v),
                  decoration: decorationChamp(
                    p,
                    indice: 'Rechercher une vache…',
                    debut: Icon(Icons.search_rounded, color: p.texte2),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: p.primaire,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _ajouter,
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: Icon(Icons.add_rounded, color: p.surPrimaire, size: 28),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_chargement && _vaches.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_erreur != null && _vaches.isEmpty)
            _MessageVide(texte: _erreur!, bouton: 'Réessayer', onTap: _charger)
          else if (_vaches.isEmpty)
            _MessageVide(
              texte: "Aucune vache pour l'instant. Touchez + pour ajouter la première.",
              bouton: 'Ajouter une vache',
              onTap: _ajouter,
            )
          else
            for (final n in const [Niveau.danger, Niveau.alerte, Niveau.normal])
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _MenuClasse(
                  niveau: n,
                  vaches: _de(n),
                  // Pendant une recherche, on ouvre les menus qui ont des résultats.
                  ouvert: _recherche.trim().isNotEmpty ? _de(n).isNotEmpty : _ouvert[n]!,
                  onBascule: () => setState(() => _ouvert[n] = !_ouvert[n]!),
                  onFermee: () => _charger(silencieux: true),
                ),
              ),
        ],
      ),
    );
  }
}

class _MessageVide extends StatelessWidget {
  const _MessageVide({required this.texte, required this.bouton, required this.onTap});

  final String texte;
  final String bouton;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Text(texte, textAlign: TextAlign.center, style: TextStyle(color: p.texte2, fontSize: 15)),
          const SizedBox(height: 14),
          TextButton(onPressed: onTap, child: Text(bouton)),
        ],
      ),
    );
  }
}

/// Un des trois menus. Ligne d'en-tête (icône, nom, compteur) + liste qui s'ouvre.
class _MenuClasse extends StatelessWidget {
  const _MenuClasse({
    required this.niveau,
    required this.vaches,
    required this.ouvert,
    required this.onBascule,
    required this.onFermee,
  });

  final Niveau niveau;
  final List<Vache> vaches;
  final bool ouvert;
  final VoidCallback onBascule;
  final VoidCallback onFermee;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final (couleur, claire) = couleursNiveau(p, niveau);

    return Container(
      decoration: BoxDecoration(
        color: ouvert ? claire.withAlpha(110) : p.carte,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ouvert ? couleur.withAlpha(120) : p.bordure),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onBascule,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  AvatarNiveau(niveau: niveau, taille: 46),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      libelleNiveau(niveau),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: couleur),
                    ),
                  ),
                  Container(
                    constraints: const BoxConstraints(minWidth: 32),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: couleur, shape: BoxShape.rectangle, borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      '${vaches.length}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.surPrimaire, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: ouvert ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.chevron_right_rounded, color: p.texte2),
                  ),
                ],
              ),
            ),
          ),
          // La liste s'ouvre et se ferme avec une petite animation de hauteur.
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: ouvert
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: vaches.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'Aucune vache ici.',
                              style: TextStyle(color: p.texte2),
                            ),
                          )
                        // Liste "en cascade" : chaque ligne apparaît 90 ms après la précédente.
                        : Column(
                            children: [
                              for (final v in vaches)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: TuileVache(v, onFermee: onFermee),
                                ),
                            ]
                                .animate(interval: 90.ms)
                                .fadeIn(duration: 350.ms)
                                .slideY(begin: 0.15, end: 0, duration: 350.ms, curve: Curves.easeOut),
                          ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Une ligne de la liste. Au clic, la carte s'agrandit vers la fiche (widget Hero).
class TuileVache extends StatelessWidget {
  const TuileVache(this.vache, {super.key, required this.onFermee});

  final Vache vache;
  final VoidCallback onFermee;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final v = vache;
    final nourriture = v.mesure == null ? 'pas encore de mesure' : '${_kg(v.mesure!.nourritureKg)} kg aujourd\'hui';
    return GestureDetector(
      onTap: () async {
        await ouvrirVache(context, v);
        onFermee();
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: Hero(
              tag: 'surface-${v.tag}',
              child: Container(decoration: decorationCarte(p, rayon: 18)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Hero(tag: 'avatar-${v.tag}', child: AvatarNiveau(niveau: v.niveau, taille: 46)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.titre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      Text('${v.tag} · ${v.typeFr} · ${v.ageFr}',
                          style: TextStyle(color: p.texte2, fontSize: 12)),
                      Text(nourriture, style: TextStyle(color: p.texte2, fontSize: 12)),
                    ],
                  ),
                ),
                PastilleNiveau(v.niveau),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _kg(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
