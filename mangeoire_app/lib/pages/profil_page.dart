import 'package:flutter/material.dart';

import '../models/vache.dart';
import '../services/api.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets/carte.dart';
import '../widgets/dialogue.dart';
import '../widgets/ico.dart';
import 'agriculteurs_page.dart';
import 'connexion_page.dart';

/// Profil : son nom, son rôle, changer son mot de passe, se déconnecter.
/// Le propriétaire gère aussi les agriculteurs et le numéro du vétérinaire.
class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  int? _nbVaches;
  int? _nbAlertes;

  Session get _s => Session.instance;

  @override
  void initState() {
    super.initState();
    _compter();
  }

  Future<void> _compter() async {
    try {
      final r = await _s.api.get('/cows') as List;
      final vaches = [for (final j in r) Vache(Map<String, dynamic>.from(j as Map))];
      if (!mounted) return;
      setState(() {
        _nbVaches = vaches.length;
        _nbAlertes = vaches.where((v) => v.niveau != Niveau.normal).length;
      });
    } catch (_) {}
  }

  Future<void> _changerMotDePasse() async {
    final v = await demanderTextes(
      context,
      titre: 'Changer mon mot de passe',
      champs: const [
        ChampDialogue('Ancien mot de passe', secret: true),
        ChampDialogue('Nouveau mot de passe (8 caractères min.)', secret: true),
      ],
    );
    if (v == null) return;
    try {
      await _s.api.put('/auth/me/password', {'old_password': v[0], 'new_password': v[1]});
      if (mounted) message(context, 'Mot de passe modifié');
    } on ApiException catch (e) {
      if (mounted) message(context, e.message);
    }
  }

  Future<void> _numeroVeto() async {
    String actuel = '';
    try {
      final r = await _s.api.get('/settings') as Map;
      actuel = (r['vet_phone'] as String?) ?? '';
    } catch (_) {}
    if (!mounted) return;
    final v = await demanderTextes(
      context,
      titre: 'Numéro du vétérinaire',
      champs: [ChampDialogue('Ex. +216 12 345 678', clavier: TextInputType.phone, valeur: actuel)],
    );
    if (v == null) return;
    try {
      await _s.api.put('/settings/vet', {'vet_phone': v[0]});
      if (mounted) message(context, 'Numéro enregistré');
    } on ApiException catch (e) {
      if (mounted) message(context, e.message);
    }
  }

  Future<void> _deconnexion() async {
    await _s.deconnexion();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (context) => const ConnexionPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);

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
                  child: Center(child: Ico('nav_profile', taille: 48, couleur: p.primaire)),
                ),
                const SizedBox(height: 14),
                Text(_s.nom, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: p.primaireClair, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    _s.roleFr,
                    style: TextStyle(color: p.primaire, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 10),
                Text(_s.email, style: TextStyle(color: p.texte2, fontSize: 14)),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _Compteur(valeur: _nbVaches?.toString() ?? '–', libelle: 'Animaux'),
                    _Compteur(valeur: _nbAlertes?.toString() ?? '–', libelle: 'À surveiller'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _LigneMenu(icone: 'password_lock', libelle: 'Changer mon mot de passe', onTap: _changerMotDePasse),
          if (_s.estProprietaire) ...[
            const SizedBox(height: 12),
            _LigneMenu(
              icone: 'nav_profile',
              libelle: 'Agriculteurs',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (context) => const AgriculteursPage()),
              ),
            ),
            const SizedBox(height: 12),
            _LigneMenu(icone: 'settings', libelle: 'Numéro du vétérinaire', onTap: _numeroVeto),
          ],
          const SizedBox(height: 12),
          _LigneMenu(icone: 'sign_out', libelle: 'Se déconnecter', alerte: true, onTap: _deconnexion),
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
  const _LigneMenu({required this.icone, required this.libelle, required this.onTap, this.alerte = false});

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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: alerte ? p.alerte : p.texte),
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: p.texte2),
        ],
      ),
    );
  }
}
