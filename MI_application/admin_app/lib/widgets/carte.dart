import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/theme.dart';

/// Card style: white, rounded, soft blue-tinted shadow.
BoxDecoration decorationCarte(Palette p, {double rayon = 22}) {
  return BoxDecoration(
    color: p.carte,
    borderRadius: BorderRadius.circular(rayon),
    border: Border.all(color: p.bordure),
    boxShadow: [BoxShadow(color: p.ombre, blurRadius: 24, offset: const Offset(0, 10))],
  );
}

class CarteDouce extends StatelessWidget {
  const CarteDouce({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final carte = Container(
      width: double.infinity,
      padding: padding,
      decoration: decorationCarte(p),
      child: child,
    );
    if (onTap == null) return carte;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: carte);
  }
}

InputDecoration decorationChamp(
  Palette p, {
  required String indice,
  Widget? debut,
  Widget? fin,
  String? erreur,
}) {
  OutlineInputBorder bord(Color couleur, double epaisseur) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: couleur, width: epaisseur),
      );
  return InputDecoration(
    hintText: indice,
    errorText: erreur,
    hintStyle: TextStyle(color: p.texte2),
    filled: true,
    fillColor: p.carte,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    prefixIcon: debut,
    suffixIcon: fin,
    border: bord(p.bordure, 1),
    enabledBorder: bord(p.bordure, 1),
    focusedBorder: bord(p.primaire, 1.6),
    errorBorder: bord(p.danger, 1.2),
    focusedErrorBorder: bord(p.danger, 1.6),
  );
}

/// Staggered entrance used by every list: fade + slight slide, delayed by index.
extension StaggerX on Widget {
  Widget stagger(int index) => animate()
      .fadeIn(duration: 320.ms, delay: (45 * (index > 12 ? 12 : index)).ms)
      .slideY(begin: 0.06, end: 0, duration: 320.ms, curve: Curves.easeOut);
}
