/// Les données qui viennent du serveur (vaches, signalements, notifications).

enum Niveau { normal, alerte, danger }

Niveau niveauDe(String? s) {
  switch (s) {
    case 'danger':
      return Niveau.danger;
    case 'alerte':
      return Niveau.alerte;
    default:
      return Niveau.normal;
  }
}

/// Les motifs proposés à l'agriculteur (le code part au serveur, le texte reste ici).
const Map<String, String> motifsAlerte = {
  'mange_moins': "Mange moins que d'habitude",
  'boite': 'Boite / marche difficilement',
  'fatiguee': 'Semble fatiguée',
  'loin_mangeoire': 'Ne vient pas à la mangeoire',
  'toux': 'Toux ou respiration difficile',
  'autre': 'Autre',
};
const Map<String, String> motifsDanger = {
  ...motifsAlerte,
  'ne_leve_pas': 'Ne se lève pas',
  'blessure': 'Blessure visible',
  'fievre': 'Signes de fièvre',
  'ballonnement': 'Ballonnement',
};

DateTime? _date(dynamic v) => v == null ? null : DateTime.parse(v as String).toLocal();
double? _nombre(dynamic v) => v == null ? null : (v as num).toDouble();

/// Les mesures du jour envoyées par l'ESP32.
class Mesure {
  Mesure(Map<String, dynamic> j)
      : date = j['date'] as String,
        nourritureG = _nombre(j['food_consumed_g']) ?? 0,
        offerteG = _nombre(j['feed_offered_g']) ?? 0,
        visites = (j['visits'] as num?)?.toInt() ?? 0,
        minutes = _nombre(j['eating_minutes']) ?? 0,
        repasMin = _nombre(j['avg_meal_duration_min']) ?? 0,
        sansNourriture = (j['no_food_visits'] as num?)?.toInt() ?? 0,
        premiereVisite = _nombre(j['first_visit_hour']),
        derniereVisite = _nombre(j['last_visit_hour']);

  final String date;
  final double nourritureG;
  final double offerteG;
  final int visites;
  final double minutes;
  final double repasMin;
  final int sansNourriture;
  final double? premiereVisite;
  final double? derniereVisite;

  double get nourritureKg => nourritureG / 1000;
  double get offerteKg => offerteG / 1000;
}

class Vache {
  Vache(Map<String, dynamic> j)
      : tag = j['tag'] as String,
        nom = (j['name'] as String?) ?? '',
        type = (j['type'] as String?) ?? 'laitiere',
        ageMois = _nombre(j['age_months']),
        niveau = niveauDe(j['status'] as String?),
        archivee = (j['archived'] as bool?) ?? false,
        mesure = j['latest'] == null ? null : Mesure(j['latest'] as Map<String, dynamic>);

  final String tag;
  final String nom;
  final String type; // 'laitiere' ou 'viande'
  final double? ageMois;
  final Niveau niveau;
  final bool archivee;
  final Mesure? mesure;

  String get titre => nom.isEmpty ? tag : nom;
  String get typeFr => type == 'viande' ? 'Viande' : 'Laitière';
  String get ageFr => ageMois == null ? '—' : '${ageMois!.round()} mois';
}

class MessageSig {
  MessageSig(Map<String, dynamic> j)
      : parNom = j['by_name'] as String,
        parRole = j['by_role'] as String,
        texte = j['text'] as String,
        quand = _date(j['at'])!;

  final String parNom;
  final String parRole;
  final String texte;
  final DateTime quand;
}

class Signalement {
  Signalement(Map<String, dynamic> j)
      : id = j['id'] as String,
        vacheTag = j['cow_id'] as String,
        vacheNom = (j['cow_name'] as String?) ?? '',
        niveau = niveauDe(j['level'] as String?),
        motifs = List<String>.from(j['reasons'] as List),
        note = (j['note'] as String?) ?? '',
        auteur = j['author_name'] as String,
        creeLe = _date(j['created_at'])!,
        messages = [for (final m in (j['replies'] as List)) MessageSig(m as Map<String, dynamic>)],
        veterinaireAppele = j['vet'] == null ? null : (j['vet']['called'] as bool),
        veterinaireLe = j['vet'] == null ? null : _date(j['vet']['at']),
        luParProprio = _date((j['seen'] as Map?)?['owner_seen_at']),
        luParAgriculteur = _date((j['seen'] as Map?)?['farmer_seen_at']);

  final String id;
  final String vacheTag;
  final String vacheNom;
  final Niveau niveau;
  final List<String> motifs;
  final String note;
  final String auteur;
  final DateTime creeLe;
  final List<MessageSig> messages;
  final bool? veterinaireAppele; // null = pas encore décidé
  final DateTime? veterinaireLe;
  final DateTime? luParProprio; // accusé de lecture
  final DateTime? luParAgriculteur;

  String get vacheTitre => vacheNom.isEmpty ? vacheTag : vacheNom;
}

class Notif {
  Notif(Map<String, dynamic> j)
      : id = j['id'] as String,
        type = j['type'] as String,
        titre = j['title'] as String,
        corps = j['body'] as String,
        vacheTag = j['cow_id'] as String?,
        signalementId = j['report_id'] as String?,
        veterinaireRequis = (j['needs_vet'] as bool?) ?? false,
        creeLe = _date(j['created_at'])!,
        luLe = _date(j['read_at']);

  final String id;
  final String type;
  final String titre;
  final String corps;
  final String? vacheTag;
  final String? signalementId;
  final bool veterinaireRequis;
  final DateTime creeLe;
  final DateTime? luLe;

  bool get lue => luLe != null;
}
