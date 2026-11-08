import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/vache.dart';
import '../outils.dart';
import '../services/api.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets/carte.dart';
import '../widgets/dialogue.dart';
import '../widgets/statut.dart';

/// La liste des signalements (d'une vache). Le propriétaire voit tous ceux de la ferme,
/// l'agriculteur voit les siens.
class ListeSignalementsPage extends StatefulWidget {
  const ListeSignalementsPage({super.key, required this.vache});

  final Vache vache;

  @override
  State<ListeSignalementsPage> createState() => _ListeSignalementsPageState();
}

class _ListeSignalementsPageState extends State<ListeSignalementsPage> {
  List<Signalement>? _liste;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final r = await Session.instance.api.get('/reports', query: {'cow': widget.vache.tag}) as List;
      if (!mounted) return;
      setState(() {
        _liste = [for (final j in r) Signalement(Map<String, dynamic>.from(j as Map))];
        _erreur = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: Text('Signalements · ${widget.vache.titre}', style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _erreur != null
          ? Center(child: Text(_erreur!, style: TextStyle(color: p.texte2)))
          : _liste == null
              ? const Center(child: CircularProgressIndicator())
              : _liste!.isEmpty
                  ? Center(child: Text('Aucun signalement.', style: TextStyle(color: p.texte2)))
                  : RefreshIndicator(
                      onRefresh: _charger,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          for (final s in _liste!)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: CarteDouce(
                                onTap: () async {
                                  await Navigator.of(context).push(MaterialPageRoute<void>(
                                    builder: (context) => DetailSignalementPage(signalementId: s.id),
                                  ));
                                  _charger();
                                },
                                child: Row(
                                  children: [
                                    PastilleNiveau(s.niveau),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(s.auteur, style: const TextStyle(fontWeight: FontWeight.w700)),
                                          Text(quandFr(s.creeLe), style: TextStyle(color: p.texte2, fontSize: 12.5)),
                                        ],
                                      ),
                                    ),
                                    Text('${s.messages.length} msg', style: TextStyle(color: p.texte2, fontSize: 12.5)),
                                    Icon(Icons.chevron_right_rounded, color: p.texte2),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
    );
  }
}

/// Un signalement : ce qui a été envoyé, qui l'a lu, la discussion, et (si danger) le vétérinaire.
class DetailSignalementPage extends StatefulWidget {
  const DetailSignalementPage({super.key, required this.signalementId});

  final String signalementId;

  @override
  State<DetailSignalementPage> createState() => _DetailSignalementPageState();
}

class _DetailSignalementPageState extends State<DetailSignalementPage> {
  Signalement? _sig;
  String? _erreur;
  String _telVeto = '';
  final _texte = TextEditingController();
  bool _envoi = false;
  StreamSubscription<Notif>? _ecoute;

  ApiClient get _api => Session.instance.api;

  @override
  void initState() {
    super.initState();
    _charger();
    // Si une nouvelle notification concerne ce signalement, on recharge tout de suite.
    _ecoute = Session.instance.notifications.listen((n) {
      if (n.signalementId == widget.signalementId) _charger();
    });
  }

  @override
  void dispose() {
    _ecoute?.cancel();
    _texte.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    try {
      final r = await _api.get('/reports/${widget.signalementId}');
      if (Session.instance.estProprietaire) {
        final reglages = await _api.get('/settings') as Map;
        _telVeto = (reglages['vet_phone'] as String?) ?? '';
      }
      if (!mounted) return;
      setState(() {
        _sig = Signalement(Map<String, dynamic>.from(r as Map));
        _erreur = null;
      });
      // On vient d'ouvrir l'écran : c'est l'accusé de lecture.
      await _api.post('/reports/${widget.signalementId}/seen');
      Session.instance.rafraichirNonLus();
    } on ApiException catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    }
  }

  Future<void> _repondre() async {
    final t = _texte.text.trim();
    if (t.isEmpty) return;
    setState(() => _envoi = true);
    try {
      await _api.post('/reports/${widget.signalementId}/replies', {'text': t});
      _texte.clear();
      await _charger();
    } on ApiException catch (e) {
      if (mounted) message(context, e.message);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  Future<void> _decisionVeto(bool appeler) async {
    if (appeler && _telVeto.isEmpty) {
      message(context, "Ajoutez d'abord le numéro du vétérinaire dans Profil.");
      return;
    }
    try {
      await _api.post('/reports/${widget.signalementId}/vet', {'called': appeler});
      await _charger();
      if (appeler) {
        final ok = await launchUrl(Uri(scheme: 'tel', path: _telVeto));
        if (!ok && mounted) message(context, "Impossible d'ouvrir le téléphone sur cet appareil.");
      }
    } on ApiException catch (e) {
      if (mounted) message(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final s = _sig;
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: Text(s == null ? 'Signalement' : 'Signalement · ${s.vacheTitre}',
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _erreur != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_erreur!, style: TextStyle(color: p.texte2))))
          : s == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _charger,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          children: [
                            _Resume(sig: s),
                            const SizedBox(height: 12),
                            if (s.niveau == Niveau.danger) _BlocVeterinaire(sig: s, onDecision: _decisionVeto),
                            if (s.messages.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Text('Discussion', style: TextStyle(color: p.texte2, fontWeight: FontWeight.w700, fontSize: 13)),
                              const SizedBox(height: 8),
                              for (final m in s.messages) _Bulle(message: m),
                            ],
                            const SizedBox(height: 8),
                            _Accuses(sig: s),
                          ],
                        ),
                      ),
                    ),
                    _ZoneReponse(controleur: _texte, envoi: _envoi, onEnvoyer: _repondre),
                  ],
                ),
    );
  }
}

class _Resume extends StatelessWidget {
  const _Resume({required this.sig});

  final Signalement sig;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final (couleur, claire) = couleursNiveau(p, sig.niveau);
    final motifs = sig.niveau == Niveau.danger ? motifsDanger : motifsAlerte;
    return CarteDouce(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PastilleNiveau(sig.niveau),
              const Spacer(),
              Text(quandFr(sig.creeLe), style: TextStyle(color: p.texte2, fontSize: 12.5)),
            ],
          ),
          const SizedBox(height: 10),
          Text('${sig.vacheTitre} · ${sig.vacheTag}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          Text('Envoyé par ${sig.auteur}', style: TextStyle(color: p.texte2, fontSize: 13)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in sig.motifs)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: claire, borderRadius: BorderRadius.circular(16)),
                  child: Text(motifs[c] ?? c, style: TextStyle(color: couleur, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          if (sig.note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(sig.note, style: const TextStyle(fontSize: 14.5)),
          ],
        ],
      ),
    );
  }
}

/// Seulement pour un signalement "danger" : le propriétaire décide d'appeler le vétérinaire ou non.
class _BlocVeterinaire extends StatelessWidget {
  const _BlocVeterinaire({required this.sig, required this.onDecision});

  final Signalement sig;
  final void Function(bool appeler) onDecision;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final proprio = Session.instance.estProprietaire;
    final decide = sig.veterinaireAppele != null;

    String texte;
    if (decide) {
      texte = sig.veterinaireAppele!
          ? 'Vétérinaire appelé · ${quandFr(sig.veterinaireLe!)}'
          : "Vétérinaire non appelé pour l'instant · ${quandFr(sig.veterinaireLe!)}";
    } else {
      texte = proprio ? 'Que voulez-vous faire ?' : 'Le propriétaire n\'a pas encore décidé.';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.dangerClair,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.danger.withAlpha(110)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.medical_services_outlined, color: p.danger),
              const SizedBox(width: 8),
              Text('Vétérinaire', style: TextStyle(color: p.danger, fontWeight: FontWeight.w800, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 8),
          Text(texte, style: TextStyle(color: p.texte, fontWeight: FontWeight.w600)),
          if (proprio && !decide) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: p.danger, foregroundColor: Colors.white),
              onPressed: () => onDecision(true),
              icon: const Icon(Icons.call_rounded),
              label: const Text('Appeler le vétérinaire'),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: () => onDecision(false), child: const Text("Ne pas appeler pour l'instant")),
          ],
        ],
      ),
    );
  }
}

class _Bulle extends StatelessWidget {
  const _Bulle({required this.message});

  final MessageSig message;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final moi = message.parNom == Session.instance.nom;
    return Align(
      alignment: moi ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: moi ? p.primaire : p.carte,
          borderRadius: BorderRadius.circular(16),
          border: moi ? null : Border.all(color: p.bordure),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${message.parNom} · ${message.parRole == 'owner' ? 'Propriétaire' : 'Agriculteur'}',
              style: TextStyle(fontSize: 11.5, color: moi ? p.surPrimaire.withAlpha(200) : p.texte2),
            ),
            const SizedBox(height: 2),
            Text(message.texte, style: TextStyle(color: moi ? p.surPrimaire : p.texte, fontSize: 14.5)),
            const SizedBox(height: 2),
            Text(quandFr(message.quand), style: TextStyle(fontSize: 11, color: moi ? p.surPrimaire.withAlpha(180) : p.texte2)),
          ],
        ),
      ),
    );
  }
}

/// Les accusés de lecture : envoyé / lu, avec l'heure.
class _Accuses extends StatelessWidget {
  const _Accuses({required this.sig});

  final Signalement sig;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final lignes = <(bool, String)>[
      sig.luParProprio != null
          ? (true, 'Lu par le propriétaire · ${quandFr(sig.luParProprio!)}')
          : (false, 'Envoyé · pas encore lu par le propriétaire'),
    ];
    final reponseDuProprio = sig.messages.any((m) => m.parRole == 'owner') || sig.veterinaireAppele != null;
    if (reponseDuProprio) {
      lignes.add(sig.luParAgriculteur != null
          ? (true, 'Réponse lue par ${sig.auteur} · ${quandFr(sig.luParAgriculteur!)}')
          : (false, 'Réponse envoyée · pas encore lue par ${sig.auteur}'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (lu, t) in lignes)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(lu ? Icons.done_all_rounded : Icons.done_rounded, size: 17, color: lu ? p.primaire : p.texte2),
                const SizedBox(width: 6),
                Expanded(child: Text(t, style: TextStyle(color: p.texte2, fontSize: 12.5))),
              ],
            ),
          ),
      ],
    );
  }
}

class _ZoneReponse extends StatelessWidget {
  const _ZoneReponse({required this.controleur, required this.envoi, required this.onEnvoyer});

  final TextEditingController controleur;
  final bool envoi;
  final VoidCallback onEnvoyer;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(color: p.carte, border: Border(top: BorderSide(color: p.bordure))),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controleur,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onEnvoyer(),
                decoration: decorationChamp(p, indice: Session.instance.estProprietaire ? 'Répondre…' : 'Écrire un message…'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: envoi ? null : onEnvoyer,
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
