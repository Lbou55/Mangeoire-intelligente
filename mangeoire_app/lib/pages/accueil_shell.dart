import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import 'package:flutter/material.dart';

import '../services/session.dart';
import '../widgets/bouton_theme.dart';
import '../widgets/ico.dart';
import 'accueil_page.dart';
import 'alertes_page.dart';
import 'animaux_page.dart';
import 'mangeoire_page.dart';
import 'notifications_page.dart';
import 'profil_page.dart';

/// La structure de l'application : barre du haut, 5 onglets en bas.
class AccueilShell extends StatefulWidget {
  const AccueilShell({super.key});

  @override
  State<AccueilShell> createState() => _AccueilShellState();
}

class _AccueilShellState extends State<AccueilShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Ouvre la connexion "temps réel" pour recevoir les notifications.
    Session.instance.demarrerNotifications();
  }

  static const List<String> _titres = [
    'Accueil',
    'Animaux',
    'Alertes',
    'Mangeoire',
    'Profil',
  ];

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      AccueilPage(onVoirAlertes: () => setState(() => _index = 2)),
      const AnimauxPage(),
      const AlertesPage(),
      const MangeoirePage(),
      const ProfilPage(),
    ];

    return ThemeSwitchingArea(
      child: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              scrolledUnderElevation: 0,
              titleSpacing: 16,
              title: Row(
                children: [
                  Image.asset(
                    'assets/branding/mangeoire_app_icon_blue.png',
                    height: 40,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _titres[_index],
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              actions: [
                // La cloche : le nombre de notifications non lues est un "badge".
                ValueListenableBuilder<int>(
                  valueListenable: Session.instance.nonLus,
                  builder: (context, nombre, _) {
                    return IconButton(
                      tooltip: 'Notifications',
                      icon: Badge(
                        isLabelVisible: nombre > 0,
                        label: Text(nombre > 99 ? '99+' : '$nombre'),
                        child: const Icon(Icons.notifications_none_rounded, size: 26),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (context) => const NotificationsPage()),
                        );
                      },
                    );
                  },
                ),
                const BoutonTheme(),
                const SizedBox(width: 8),
              ],
            ),
            body: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: KeyedSubtree(
                key: ValueKey<int>(_index),
                child: pages[_index],
              ),
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                NavigationDestination(
                  icon: const Ico('nav_home'),
                  label: _titres[0],
                ),
                NavigationDestination(
                  icon: const Ico('nav_animals'),
                  label: _titres[1],
                ),
                NavigationDestination(
                  icon: const Ico('nav_alerts'),
                  label: _titres[2],
                ),
                NavigationDestination(
                  icon: const Ico('nav_feeder'),
                  label: _titres[3],
                ),
                NavigationDestination(
                  icon: const Ico('nav_profile'),
                  label: _titres[4],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
