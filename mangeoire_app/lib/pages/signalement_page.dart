import 'package:flutter/material.dart';

import '../models/vache.dart';
import '../services/api.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets/carte.dart';
import '../widgets/dialogue.dart';
import '../widgets/statut.dart';

/// L'agriculteur choisit ce qui s'est passé (liste de motifs) et envoie le rapport au propriétaire.
class SignalementPage extends StatefulWidget {
  const SignalementPage({super.key, required this.vache});

  final Vache vache;

  @override
  State<SignalementPage> createState() => _SignalementPageState();
}

class _SignalementPageState extends State<SignalementPage> {
  final Set<String> _choisis = {};
  final _note = TextEditingController();
  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    if (_choisis.isEmpty) {
      setState(() => _erreur = 'Choisissez au moins un motif.');
      return;
    }
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      await Session.instance.api.post('/cows/${widget.vache.tag}/reports', {
        'reasons': _choisis.toList(),
        'note': _note.text.trim(),
      });
      if (!mounted) return;
      message(context, 'Signalement envoyé au propriétaire');
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final v = widget.vache;
    final danger = v.niveau == Niveau.danger;
    final (couleur, claire) = couleursNiveau(p, v.niveau);
    final motifs = danger ? motifsDanger : motifsAlerte;

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: Text(danger ? 'Signaler un danger' : 'Envoyer un rapport',
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AvatarNiveau(niveau: v.niveau, taille: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v.titre, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                        Text(v.tag, style: TextStyle(color: p.texte2, fontSize: 13)),
                      ],
                    ),
                  ),
                  PastilleNiveau(v.niveau),
                ],
              ),
              if (danger) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: claire, borderRadius: BorderRadius.circular(14)),
                  child: Text(
                    'Situation de danger : le propriétaire sera prévenu tout de suite et pourra décider d\'appeler le vétérinaire.',
                    style: TextStyle(color: couleur, fontWeight: FontWeight.w600, fontSize: 13.5),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const Text('Que s\'est-il passé ?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Vous pouvez choisir plusieurs motifs.', style: TextStyle(color: p.texte2, fontSize: 13)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in motifs.entries)
                    FilterChip(
                      label: Text(e.value),
                      selected: _choisis.contains(e.key),
                      selectedColor: claire,
                      checkmarkColor: couleur,
                      side: BorderSide(color: _choisis.contains(e.key) ? couleur : p.bordure),
                      onSelected: (on) => setState(() => on ? _choisis.add(e.key) : _choisis.remove(e.key)),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _note,
                maxLines: 3,
                maxLength: 500,
                decoration: decorationChamp(p, indice: 'Ajouter un détail (facultatif)'),
              ),
              const SizedBox(height: 6),
              // Le message vocal n'est pas encore utilisable : le bouton est là mais désactivé.
              Opacity(
                opacity: 0.55,
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.mic_none_rounded),
                  label: const Text('Message vocal · bientôt disponible'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              if (_erreur != null) ...[
                const SizedBox(height: 12),
                Text(_erreur!, textAlign: TextAlign.center,
                    style: TextStyle(color: p.danger, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: couleur, foregroundColor: p.surPrimaire),
                onPressed: _enCours ? null : _envoyer,
                child: _enCours
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Text('Envoyer au propriétaire'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
