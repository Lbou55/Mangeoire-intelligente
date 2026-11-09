
import 'package:flutter/material.dart';

import '../services/api.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets/carte.dart';
import '../widgets/dialogue.dart';

/// Pour le propriétaire : gérer les agriculteurs et leurs informations.
class AgriculteursPage extends StatefulWidget {
  const AgriculteursPage({super.key});

  @override
  State<AgriculteursPage> createState() => _AgriculteursPageState();
}

class _AgriculteursPageState extends State<AgriculteursPage> {
  List<Map<String, dynamic>>? _liste;
  String? _erreur;

  ApiClient get _api => Session.instance.api;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final r = await _api.get('/users') as List;
      if (!mounted) return;

      setState(() {
        _liste = [
          for (final u in r) Map<String, dynamic>.from(u as Map),
        ];
        _erreur = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    }
  }

  Future<void> _ajouter() async {
    final v = await demanderTextes(
      context,
      titre: 'Nouvel agriculteur',
      bouton: 'Créer',
      champs: const [
        ChampDialogue('Nom complet'),
        ChampDialogue(
          'Adresse e-mail',
          clavier: TextInputType.emailAddress,
        ),
        ChampDialogue(
          'Mot de passe (8 caractères min.)',
          secret: true,
        ),
        ChampDialogue('Adresse'),
      ],
    );

    if (v == null) return;

    try {
      await _api.post('/users', {
        'name': v[0],
        'email': v[1],
        'password': v[2],
        'address': v[3],
      });

      if (mounted) message(context, 'Compte créé');
      _charger();
    } on ApiException catch (e) {
      if (mounted) message(context, e.message);
    }
  }

  Future<void> _adresse(Map<String, dynamic> u) async {
    final v = await demanderTextes(
      context,
      titre: 'Adresse de ${u['name']}',
      bouton: 'Enregistrer',
      champs: [
        ChampDialogue(
          'Adresse',
          valeur: (u['address'] ?? '').toString(),
        ),
      ],
    );

    if (v == null) return;

    try {
      await _api.put('/users/${u['id']}', {
        'address': v[0],
      });

      if (mounted) message(context, 'Adresse modifiée');
      _charger();
    } on ApiException catch (e) {
      if (mounted) message(context, e.message);
    }
  }

  Future<void> _motDePasse(Map<String, dynamic> u) async {
    final v = await demanderTextes(
      context,
      titre: 'Mot de passe de ${u['name']}',
      champs: const [
        ChampDialogue(
          'Nouveau mot de passe (8 caractères min.)',
          secret: true,
        ),
      ],
    );

    if (v == null) return;

    try {
      await _api.put('/users/${u['id']}/password', {
        'new_password': v[0],
      });

      if (mounted) message(context, 'Mot de passe modifié');
    } on ApiException catch (e) {
      if (mounted) message(context, e.message);
    }
  }

  Future<void> _retirer(Map<String, dynamic> u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Retirer ${u['name']} ?'),
        content: const Text(
          'Son compte sera désactivé. Ses signalements restent visibles.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _api.delete('/users/${u['id']}');
      _charger();
    } on ApiException catch (e) {
      if (mounted) message(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: const Text(
          'Agriculteurs',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _ajouter,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: 'Ajouter',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _erreur != null
          ? Center(
              child: Text(
                _erreur!,
                style: TextStyle(color: p.texte2),
              ),
            )
          : _liste == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    for (final u in _liste!)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: CarteDouce(
                          padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      u['name'] as String,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      u['email'] as String,
                                      style: TextStyle(
                                        color: p.texte2,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if ((u['address'] ?? '')
                                        .toString()
                                        .trim()
                                        .isNotEmpty)
                                      Text(
                                        u['address'].toString(),
                                        style: TextStyle(
                                          color: p.texte2,
                                          fontSize: 13,
                                        ),
                                      ),
                                    Text(
                                      u['role'] == 'owner'
                                          ? 'Propriétaire'
                                          : 'Agriculteur',
                                      style: TextStyle(
                                        color: p.primaire,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (u['role'] != 'owner')
                                PopupMenuButton<String>(
                                  onSelected: (choix) {
                                    switch (choix) {
                                      case 'adresse':
                                        _adresse(u);
                                        break;
                                      case 'mdp':
                                        _motDePasse(u);
                                        break;
                                      case 'retirer':
                                        _retirer(u);
                                        break;
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: 'adresse',
                                      child: Text('Modifier l’adresse'),
                                    ),
                                    PopupMenuItem(
                                      value: 'mdp',
                                      child: Text('Changer le mot de passe'),
                                    ),
                                    PopupMenuItem(
                                      value: 'retirer',
                                      child: Text('Retirer'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}
