import 'package:flutter/material.dart';

import '../models/vache.dart';
import '../services/api.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets/carte.dart';
import '../widgets/dialogue.dart';

/// Ajouter une vache à la main (le propriétaire ET les agriculteurs peuvent le faire).
/// Si on lui donne une [vache], la page sert à la modifier.
class AjouterVachePage extends StatefulWidget {
  const AjouterVachePage({super.key, this.vache});

  final Vache? vache;

  @override
  State<AjouterVachePage> createState() => _AjouterVachePageState();
}

class _AjouterVachePageState extends State<AjouterVachePage> {
  late final TextEditingController _tag;
  late final TextEditingController _nom;
  late final TextEditingController _age;
  late String _type;
  late bool _archivee;
  bool _enCours = false;
  String? _erreur;

  bool get _modification => widget.vache != null;

  @override
  void initState() {
    super.initState();
    final v = widget.vache;
    _tag = TextEditingController(text: v?.tag ?? '');
    _nom = TextEditingController(text: v?.nom ?? '');
    _age = TextEditingController(text: v?.ageMois == null ? '' : v!.ageMois!.round().toString());
    _type = v?.type ?? 'laitiere';
    _archivee = v?.archivee ?? false;
  }

  @override
  void dispose() {
    _tag.dispose();
    _nom.dispose();
    _age.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    final tag = _tag.text.trim();
    if (!_modification && !RegExp(r'^[A-Za-z0-9]{4,16}$').hasMatch(tag)) {
      setState(() => _erreur = 'Le tag RFID doit contenir 4 à 16 lettres ou chiffres.');
      return;
    }
    final age = _age.text.trim().isEmpty ? null : double.tryParse(_age.text.trim().replaceAll(',', '.'));
    if (_age.text.trim().isNotEmpty && age == null) {
      setState(() => _erreur = "L'âge doit être un nombre (en mois).");
      return;
    }
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      final api = Session.instance.api;
      if (_modification) {
        await api.put('/cows/${widget.vache!.tag}', {
          'name': _nom.text.trim(),
          'type': _type,
          if (age != null) 'age_months': age,
          'archived': _archivee,
        });
      } else {
        await api.post('/cows', {
          'tag': tag,
          'name': _nom.text.trim(),
          'type': _type,
          if (age != null) 'age_months': age,
        });
      }
      if (!mounted) return;
      message(context, _modification ? 'Modifications enregistrées' : 'Vache ajoutée');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: Text(
          _modification ? 'Modifier la vache' : 'Ajouter une vache',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _tag,
                enabled: !_modification,
                textCapitalization: TextCapitalization.characters,
                decoration: decorationChamp(p, indice: 'Tag RFID (ex. 3C43FA39)'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _nom,
                textCapitalization: TextCapitalization.words,
                decoration: decorationChamp(p, indice: 'Nom (facultatif)'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _age,
                keyboardType: TextInputType.number,
                decoration: decorationChamp(p, indice: 'Âge en mois (facultatif)'),
              ),
              const SizedBox(height: 18),
              Text('Type', style: TextStyle(color: p.texte2, fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'laitiere', label: Text('Laitière')),
                  ButtonSegment(value: 'viande', label: Text('Viande')),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              if (_modification) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Archiver cette vache'),
                  subtitle: Text('Elle disparaît de la liste (rien n\'est supprimé).',
                      style: TextStyle(color: p.texte2, fontSize: 12.5)),
                  value: _archivee,
                  onChanged: (v) => setState(() => _archivee = v),
                ),
              ],
              if (_erreur != null) ...[
                const SizedBox(height: 12),
                Text(_erreur!, textAlign: TextAlign.center,
                    style: TextStyle(color: p.danger, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _enCours ? null : _enregistrer,
                child: _enCours
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : Text(_modification ? 'Enregistrer' : 'Ajouter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
