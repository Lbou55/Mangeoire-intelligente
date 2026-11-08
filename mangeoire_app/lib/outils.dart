/// Petites fonctions utilitaires (dates et nombres en français).

String dateFr(DateTime d) {
  const jours = [
    'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'
  ];
  const mois = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
  ];
  return '${jours[d.weekday - 1]} ${d.day} ${mois[d.month - 1]}';
}

/// 8.1 -> "8,1"
String fmtKg(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

/// -38.6 -> "−39 %"
String fmtPct(double v) {
  final n = v.round();
  if (n > 0) return '+$n %';
  return '${n.toString().replaceAll('-', '−')} %';
}

/// Première lettre du jour : L M M J V S D
String jourCourt(DateTime d) {
  const lettres = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
  return lettres[d.weekday - 1];
}

/// 6.3 -> "6h18"
String fmtHeure(double h) {
  final heures = h.floor();
  final minutes = ((h - heures) * 60).round();
  return '${heures}h${minutes.toString().padLeft(2, '0')}';
}

/// "Aujourd'hui 14:32", "Hier 09:05" ou "6 nov. 14:32"
String quandFr(DateTime d) {
  const mois = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  final maintenant = DateTime.now();
  final auj = DateTime(maintenant.year, maintenant.month, maintenant.day);
  final jour = DateTime(d.year, d.month, d.day);
  final ecart = auj.difference(jour).inDays;
  if (ecart == 0) return "Aujourd'hui $hh:$mm";
  if (ecart == 1) return 'Hier $hh:$mm';
  return '${d.day} ${mois[d.month - 1]} $hh:$mm';
}
