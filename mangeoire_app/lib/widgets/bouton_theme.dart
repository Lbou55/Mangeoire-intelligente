import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import 'ico.dart';

/// Bouton soleil / lune. Au clic, le thème change avec un cercle qui grandit
/// depuis le bouton (comme dans Telegram).
/// Il doit être placé dans une page entourée de ThemeSwitchingArea.
class BoutonTheme extends StatelessWidget {
  const BoutonTheme({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemeSwitcher.withTheme(
      builder: (context, switcher, theme) {
        final sombre = theme.brightness == Brightness.dark;
        return IconButton(
          tooltip: sombre ? 'Mode clair' : 'Mode sombre',
          icon: Ico(sombre ? 'sun' : 'moon'),
          onPressed: () {
            switcher.changeTheme(
              theme: sombre ? themeClair : themeSombre,
              isReversed: false,
            );
          },
        );
      },
    );
  }
}
