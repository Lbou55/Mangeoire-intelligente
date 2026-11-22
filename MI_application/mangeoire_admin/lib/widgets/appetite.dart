import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../models/models.dart';
import 'common.dart';

String appetiteLabel(BuildContext context, Appetite? a) => context.t(switch (a) {
      Appetite.decreasing => 'appetite_decreasing',
      Appetite.stable => 'appetite_stable',
      Appetite.increasing => 'appetite_increasing',
      null => 'appetite_unknown',
    });

(Color, Color) appetiteColors(Palette p, Appetite? a) => switch (a) {
      Appetite.decreasing => (p.alerte, p.alerteClair),
      Appetite.stable => (p.succes, p.succesClair),
      Appetite.increasing => (p.primaire, p.primaireClair),
      null => (p.texte2, p.bordure),
    };

String appetiteIcon(Appetite? a) => switch (a) {
      Appetite.decreasing => 'status_alert',
      Appetite.stable => 'status_normal',
      Appetite.increasing => 'status_resolved',
      null => 'status_normal',
    };

class AppetitePill extends StatelessWidget {
  const AppetitePill(this.appetite, {super.key});
  final Appetite? appetite;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final (fg, bg) = appetiteColors(p, appetite);
    return Pill(appetiteLabel(context, appetite),
        color: fg, background: bg, icon: appetite == null ? null : appetiteIcon(appetite));
  }
}
