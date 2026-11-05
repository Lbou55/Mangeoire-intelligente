import '../outils.dart';

enum Statut { normal, alerte }

/// Un animal enregistré dans la mangeoire (données fictives).
class Animal {
  const Animal({
    required this.id,
    required this.rfid,
    required this.type,
    required this.ageMois,
    required this.poidsKg,
    required this.statut,
    required this.nourritureKg,
    required this.nourritureNormaleKg,
    required this.visites,
    required this.minutes,
    required this.historiqueKg,
  });

  final String id; // C001 ... C007
  final String rfid; // identifiant du tag RFID
  final String type; // Laitière ou Viande
  final int ageMois;
  final int poidsKg;
  final Statut statut;
  final double nourritureKg; // mangé aujourd'hui
  final double nourritureNormaleKg; // sa normale
  final int visites;
  final int minutes; // temps passé à manger
  final List<double> historiqueKg; // 7 derniers jours, le dernier = aujourd'hui

  bool get enAlerte => statut == Statut.alerte;

  double get ecartPct =>
      (nourritureKg - nourritureNormaleKg) / nourritureNormaleKg * 100;

  String get messageAlerte =>
      'Appétit en baisse par rapport à sa normale (${fmtPct(ecartPct)}). '
      "Indicateur à suivre, ceci n'est pas un diagnostic.";
}

/// Les 7 tags du fichier rfid.txt, associés à C001 ... C007.
const List<Animal> animauxDemo = [
  Animal(
    id: 'C001', rfid: '3C43FA39', type: 'Laitière', ageMois: 52, poidsKg: 612,
    statut: Statut.normal, nourritureKg: 8.1, nourritureNormaleKg: 8.1,
    visites: 12, minutes: 94,
    historiqueKg: [7.8, 8.3, 7.9, 8.4, 8.0, 8.2, 8.1],
  ),
  Animal(
    id: 'C002', rfid: 'CC8B7922', type: 'Viande', ageMois: 38, poidsKg: 540,
    statut: Statut.normal, nourritureKg: 6.4, nourritureNormaleKg: 6.4,
    visites: 10, minutes: 86,
    historiqueKg: [6.2, 6.5, 6.3, 6.6, 6.4, 6.3, 6.4],
  ),
  Animal(
    id: 'C003', rfid: '92EBEA51', type: 'Laitière', ageMois: 71, poidsKg: 640,
    statut: Statut.alerte, nourritureKg: 4.9, nourritureNormaleKg: 8.0,
    visites: 7, minutes: 66,
    historiqueKg: [8.0, 7.9, 8.2, 7.7, 6.6, 5.7, 4.9],
  ),
  Animal(
    id: 'C004', rfid: '822D4251', type: 'Viande', ageMois: 24, poidsKg: 430,
    statut: Statut.normal, nourritureKg: 5.6, nourritureNormaleKg: 5.6,
    visites: 9, minutes: 80,
    historiqueKg: [5.4, 5.7, 5.5, 5.8, 5.6, 5.5, 5.6],
  ),
  Animal(
    id: 'C005', rfid: 'EC954B17', type: 'Laitière', ageMois: 45, poidsKg: 598,
    statut: Statut.normal, nourritureKg: 8.4, nourritureNormaleKg: 8.3,
    visites: 13, minutes: 97,
    historiqueKg: [8.2, 8.5, 8.1, 8.3, 8.6, 8.2, 8.4],
  ),
  Animal(
    id: 'C006', rfid: '92B47151', type: 'Viande', ageMois: 60, poidsKg: 585,
    statut: Statut.alerte, nourritureKg: 4.1, nourritureNormaleKg: 6.6,
    visites: 6, minutes: 58,
    historiqueKg: [6.5, 6.7, 6.4, 6.6, 5.9, 5.0, 4.1],
  ),
  Animal(
    id: 'C007', rfid: 'EDFF4D24', type: 'Laitière', ageMois: 33, poidsKg: 575,
    statut: Statut.normal, nourritureKg: 7.7, nourritureNormaleKg: 7.8,
    visites: 11, minutes: 91,
    historiqueKg: [7.6, 7.9, 7.5, 7.8, 7.7, 7.9, 7.7],
  ),
];

/// Une alerte affichée dans la page Alertes (données fictives).
class AlerteItem {
  const AlerteItem({
    required this.titre,
    required this.detail,
    required this.quand,
    required this.resolue,
  });

  final String titre;
  final String detail;
  final String quand;
  final bool resolue;
}

final List<AlerteItem> alertesDemo = [
  for (final a in animauxDemo.where((a) => a.enAlerte))
    AlerteItem(
      titre: '${a.id} · Appétit en baisse',
      detail: 'Nourriture ${fmtKg(a.nourritureKg)} kg au lieu de '
          '${fmtKg(a.nourritureNormaleKg)} kg (${fmtPct(a.ecartPct)})',
      quand: a.id == 'C003' ? "Aujourd'hui · 07:42" : "Aujourd'hui · 08:15",
      resolue: false,
    ),
  const AlerteItem(
    titre: 'C005 · Moins de visites que d\'habitude',
    detail: '8 visites au lieu de 12',
    quand: 'Hier · 18:20',
    resolue: true,
  ),
  const AlerteItem(
    titre: 'C001 · Premier repas plus tardif',
    detail: 'Première visite à 8 h au lieu de 5 h 30',
    quand: 'Samedi · 08:05',
    resolue: true,
  ),
];
