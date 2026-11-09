import 'package:flutter/material.dart';

import '../theme.dart';
import 'carte.dart';

/// Un champ de la petite fenêtre de saisie.
class ChampDialogue {
  const ChampDialogue(
    this.indice, {
    this.secret = false,
    this.clavier,
    this.valeur = '',
  });

  final String indice;
  final bool secret;
  final TextInputType? clavier;
  final String valeur;
}

/// Ouvre une fenêtre avec des champs de texte.
Future<List<String>?> demanderTextes(
  BuildContext context, {
  required String titre,
  required List<ChampDialogue> champs,
  String bouton = 'Enregistrer',
}) {
  final controleurs = [
    for (final c in champs)
      TextEditingController(text: c.valeur),
  ];

  return showDialog<List<String>>(
    context: context,
    builder: (contexteDialogue) {
      final p = Palette.of(contexteDialogue);

      return AlertDialog(
        backgroundColor: p.carte,
        surfaceTintColor: Colors.transparent,
        title: Text(
          titre,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 19,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < champs.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: TextField(
                    controller: controleurs[i],
                    obscureText: champs[i].secret,
                    keyboardType: champs[i].clavier,
                    decoration: decorationChamp(
                      p,
                      indice: champs[i].indice,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(contexteDialogue).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(contexteDialogue).pop([
                for (final c in controleurs) c.text.trim(),
              ]);
            },
            child: Text(
              bouton,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );
    },
  );
}

/// Petit message en bas de l'écran.
void message(BuildContext context, String texte) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(texte)),
    );
}