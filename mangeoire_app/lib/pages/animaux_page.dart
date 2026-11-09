
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
  Niveau _categorie = Niveau.danger;
  Timer? _minuteur;

  @override
  void initState() {
    super.initState();
    _charger();

    _minuteur = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _charger(silencieux: true),
    );
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }

  Future<void> _charger({bool silencieux = false}) async {
    if (!silencieux && mounted) {
      setState(() => _chargement = true);
    }

    try {
      final r = await Session.instance.api.get('/cows') as List;

      if (!mounted) return;

      setState(() {
        _vaches = [
          for (final j in r)
            Vache(Map<String, dynamic>.from(j as Map)),
        ];
        _erreur = null;
      });
    } on ApiException catch (e) {
      if (mounted && !silencieux) {
        setState(() => _erreur = e.message);
      }
    } finally {
      if (mounted) {
        setState(() => _chargement = false);
      }
    }
  }

  List<Vache> _de(Niveau niveau) {
    final q = _recherche.trim().toLowerCase();

    return [
      for (final v in _vaches)
        if (!v.archivee &&
            v.niveau == niveau &&
            (q.isEmpty || v.displayId.toLowerCase().contains(q)))
          v,
    ];
  }

  Future<void> _ajouter() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => const AjouterVachePage(),
      ),
    );

    if (ok == true) {
      _charger(silencieux: true);
    }
  }

  void _choisirCategorie(Niveau niveau) {
    setState(() => _categorie = niveau);
    Navigator.of(context).pop();
  }

  String _titreCategorie(Niveau niveau) {
    switch (niveau) {
      case Niveau.danger:
        return 'Danger';
      case Niveau.alerte:
        return 'Alerte';
      case Niveau.normal:
        return 'Normal';
    }
  }


  Widget _elementMenu(Niveau niveau, Palette p) {
    final (couleur, _) = couleursNiveau(p, niveau);
    final selectionne = _categorie == niveau;

    return ListTile(
      leading: AvatarNiveau(niveau: niveau, taille: 40),
      title: Text(
        _titreCategorie(niveau),
        style: TextStyle(
          fontWeight: selectionne ? FontWeight.w800 : FontWeight.w600,
          color: selectionne ? couleur : null,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: couleur,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_de(niveau).length}',
              style: TextStyle(
                color: p.surPrimaire,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (selectionne) ...[
            const SizedBox(width: 8),
            Icon(Icons.check_rounded, color: couleur),
          ],
        ],
      ),
      selected: selectionne,
      onTap: () => _choisirCategorie(niveau),
    );
  }

  Widget _construireDrawer(Palette p) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.menu_rounded,
                    size: 32,
                    color: p.primaire,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Catégories des animaux',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Choisissez une catégorie',
                    style: TextStyle(color: p.texte2),
                  ),
                ],
              ),
            ),
            const Divider(),
            _elementMenu(Niveau.danger, p),
            _elementMenu(Niveau.alerte, p),
            _elementMenu(Niveau.normal, p),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${_vaches.where((v) => !v.archivee).length} animaux au total',
                style: TextStyle(
                  color: p.texte2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final vachesCategorie = _de(_categorie);
    final (couleur, _) = couleursNiveau(p, _categorie);

    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: _construireDrawer(p),
      body: Builder(
        builder: (pageContext) {
          return RefreshIndicator(
            onRefresh: () => _charger(silencieux: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Row(
                  children: [
                    Material(
                      color: p.carte,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          Scaffold.of(pageContext).openDrawer();
                        },
                        child: SizedBox(
                          width: 52,
                          height: 52,
                          child: Icon(
                            Icons.menu_rounded,
                            color: p.primaire,
                            size: 27,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _titreCategorie(_categorie),
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: couleur,
                            ),
                          ),
                          Text(
                            '${vachesCategorie.length} animal(aux)',
                            style: TextStyle(
                              color: p.texte2,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (v) {
                          setState(() => _recherche = v);
                        },
                        decoration: decorationChamp(
                          p,
                          indice: 'Rechercher par identifiant (C1...)',
                          debut: Icon(
                            Icons.search_rounded,
                            color: p.texte2,
                          ),
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
                          child: Icon(
                            Icons.add_rounded,
                            color: p.surPrimaire,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (_chargement && _vaches.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_erreur != null && _vaches.isEmpty)
                  _MessageVide(
                    texte: _erreur!,
                    bouton: 'Réessayer',
                    onTap: () => _charger(),
                  )
                else if (vachesCategorie.isEmpty)
                  _MessageVide(
                    texte: _recherche.isNotEmpty
                        ? 'Aucun animal trouvé dans cette catégorie.'
                        : 'Aucun animal dans cette catégorie.',
                    bouton: 'Actualiser',
                    onTap: () => _charger(),
                  )
                else
                  Column(
                    children: [
                      for (final v in vachesCategorie)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TuileVache(
                            v,
                            onFermee: () => _charger(silencieux: true),
                          ),
                        ),
                    ]
                        .animate(interval: 80.ms)
                        .fadeIn(duration: 300.ms)
                        .slideY(
                          begin: 0.12,
                          end: 0,
                          duration: 300.ms,
                          curve: Curves.easeOut,
                        ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MessageVide extends StatelessWidget {
  const _MessageVide({
    required this.texte,
    required this.bouton,
    required this.onTap,
  });

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
          Text(
            texte,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: p.texte2,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: onTap,
            child: Text(bouton),
          ),
        ],
      ),
    );
  }
}

/// Une ligne de la liste. Le RFID reste utilisé uniquement en interne.
class TuileVache extends StatelessWidget {
  const TuileVache(
    this.vache, {
    super.key,
    required this.onFermee,
  });

  final Vache vache;
  final VoidCallback onFermee;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final v = vache;

    final nourriture = v.mesure == null
        ? 'pas encore de mesure'
        : '${_kg(v.mesure!.nourritureKg)} kg aujourd’hui';

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
              child: Container(
                decoration: decorationCarte(p, rayon: 18),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Hero(
                  tag: 'avatar-${v.tag}',
                  child: AvatarNiveau(
                    niveau: v.niveau,
                    taille: 46,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v.titre,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${v.typeFr} · ${v.ageFr}',
                        style: TextStyle(
                          color: p.texte2,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        nourriture,
                        style: TextStyle(
                          color: p.texte2,
                          fontSize: 12,
                        ),
                      ),
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

String _kg(double v) =>
    v.toStringAsFixed(1).replaceAll('.', ',');
