import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import 'ico.dart';

Future<void> saveThemeChoice(bool dark) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark', dark);
  } catch (_) {}
}

Future<bool> loadThemeChoice() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('dark') ?? false;
  } catch (_) {
    return false;
  }
}

/// Sun / moon button. The new theme grows as a circle from the button.
/// It must sit inside a [ThemeSwitchingArea].
class BoutonTheme extends StatelessWidget {
  const BoutonTheme({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemeSwitcher.withTheme(
      builder: (context, switcher, theme) {
        final sombre = theme.brightness == Brightness.dark;
        return IconButton(
          tooltip: sombre ? context.t('theme_light') : context.t('theme_dark'),
          icon: Ico(sombre ? 'sun' : 'moon'),
          onPressed: () {
            saveThemeChoice(!sombre);
            switcher.changeTheme(theme: sombre ? themeClair : themeSombre, isReversed: false);
          },
        );
      },
    );
  }
}

/// FR | عربي switch, usable from any screen.
class LangSwitch extends StatelessWidget {
  const LangSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ValueListenableBuilder<Locale>(
      valueListenable: LangController.instance.locale,
      builder: (context, locale, _) {
        Widget chip(String code, String label) {
          final selected = locale.languageCode == code;
          return Expanded(
            child: GestureDetector(
              onTap: () => LangController.instance.set(code),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: selected ? p.primaire : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? p.surPrimaire : p.texte2,
                  ),
                ),
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: p.primaireClair,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [chip('fr', 'Français'), chip('ar', 'العربية')]),
        );
      },
    );
  }
}

/// Compact language toggle for app bars.
class LangIconButton extends StatelessWidget {
  const LangIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isAr = context.isAr;
    return IconButton(
      tooltip: context.t('language'),
      icon: const Ico('language'),
      onPressed: () => LangController.instance.set(isAr ? 'fr' : 'ar'),
    );
  }
}
