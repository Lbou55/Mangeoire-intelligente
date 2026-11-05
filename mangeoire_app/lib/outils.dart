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
