import 'package:flutter/material.dart';

/// Toutes les couleurs de l'application, en version claire et sombre.
class Palette {
  const Palette({
    required this.fond,
    required this.carte,
    required this.texte,
    required this.texte2,
    required this.primaire,
    required this.primaireClair,
    required this.surPrimaire,
    required this.alerte,
    required this.alerteClair,
    required this.danger,
    required this.dangerClair,
    required this.bordure,
    required this.ombre,
    required this.bandeau1,
    required this.bandeau2,
  });

  final Color fond;
  final Color carte;
  final Color texte;
  final Color texte2;
  final Color primaire;
  final Color primaireClair;
  final Color surPrimaire;
  final Color alerte;
  final Color alerteClair;
  final Color danger;
  final Color dangerClair;
  final Color bordure;
  final Color ombre;
  final Color bandeau1;
  final Color bandeau2;

  static const Palette clair = Palette(
    fond: Color(0xFFF3F7FC),
    carte: Color(0xFFFFFFFF),
    texte: Color(0xFF0F2342),
    texte2: Color(0xFF5E6E8A),
    primaire: Color(0xFF1F63D1),
    primaireClair: Color(0xFFE6EEFB),
    surPrimaire: Color(0xFFFFFFFF),
    alerte: Color(0xFFE8731A),
    alerteClair: Color(0xFFFDEBDD),
    danger: Color(0xFFD92D3A),
    dangerClair: Color(0xFFFBE4E6),
    bordure: Color(0xFFE3EAF5),
    ombre: Color(0x1F1B4FA6),
    bandeau1: Color(0xFF2F78E0),
    bandeau2: Color(0xFF1B4FA6),
  );

  static const Palette sombre = Palette(
    fond: Color(0xFF0B1424),
    carte: Color(0xFF13213A),
    texte: Color(0xFFEAF1FB),
    texte2: Color(0xFF9DB0CE),
    primaire: Color(0xFF5B9BFF),
    primaireClair: Color(0xFF1B3358),
    surPrimaire: Color(0xFF0B1424),
    alerte: Color(0xFFFF9A4D),
    alerteClair: Color(0xFF3A2616),
    danger: Color(0xFFFF6B75),
    dangerClair: Color(0xFF3F1B20),
    bordure: Color(0xFF22345A),
    ombre: Color(0x66000000),
    bandeau1: Color(0xFF2A5BB5),
    bandeau2: Color(0xFF163A78),
  );

  /// Donne la palette qui correspond au thème actuellement affiché.
  static Palette of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? sombre : clair;
  }
}

ThemeData construireTheme(Palette p, Brightness luminosite) {
  final base = ThemeData(brightness: luminosite, useMaterial3: true);
  final schema = ColorScheme.fromSeed(
    seedColor: p.primaire,
    brightness: luminosite,
  ).copyWith(
    primary: p.primaire,
    onPrimary: p.surPrimaire,
    surface: p.fond,
    onSurface: p.texte,
    error: p.alerte,
  );

  return base.copyWith(
    colorScheme: schema,
    scaffoldBackgroundColor: p.fond,
    textTheme: base.textTheme.apply(bodyColor: p.texte, displayColor: p.texte),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.carte,
      surfaceTintColor: Colors.transparent,
      indicatorColor: p.primaireClair,
      height: 70,
      iconTheme: WidgetStateProperty.resolveWith((etats) {
        final choisi = etats.contains(WidgetState.selected);
        return IconThemeData(color: choisi ? p.primaire : p.texte2);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((etats) {
        final choisi = etats.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: choisi ? FontWeight.w700 : FontWeight.w500,
          color: choisi ? p.primaire : p.texte2,
        );
      }),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: p.primaire,
        foregroundColor: p.surPrimaire,
        minimumSize: const Size.fromHeight(52),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: p.primaire),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.texte,
      contentTextStyle: TextStyle(color: p.fond),
    ),
  );
}

final ThemeData themeClair = construireTheme(Palette.clair, Brightness.light);
final ThemeData themeSombre = construireTheme(Palette.sombre, Brightness.dark);
