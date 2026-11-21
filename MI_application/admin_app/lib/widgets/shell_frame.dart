import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import 'package:flutter/material.dart';

import '../core/l10n.dart';
import 'bouton_theme.dart';
import 'ico.dart';

class ShellTab {
  const ShellTab(this.icon, this.labelKey, {this.badge = 0});
  final String icon;
  final String labelKey;
  final int badge;
}

/// App bar (logo, title, language, theme) + bottom navigation, shared by both shells.
class ShellFrame extends StatelessWidget {
  const ShellFrame({
    super.key,
    required this.tabs,
    required this.index,
    required this.onSelect,
    required this.body,
  });

  final List<ShellTab> tabs;
  final int index;
  final ValueChanged<int> onSelect;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return ThemeSwitchingArea(
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            scrolledUnderElevation: 0,
            titleSpacing: 16,
            title: Row(children: [
              Image.asset('assets/branding/mangeoire_app_icon_blue.png', height: 40),
              const SizedBox(width: 8),
              Text(context.t(tabs[index].labelKey),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ]),
            actions: const [LangIconButton(), BoutonTheme(), SizedBox(width: 8)],
          ),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: KeyedSubtree(key: ValueKey<int>(index), child: body),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: onSelect,
            destinations: [
              for (final t in tabs)
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: t.badge > 0,
                    label: Text('${t.badge > 99 ? '99+' : t.badge}'),
                    child: Ico(t.icon),
                  ),
                  label: context.t(t.labelKey),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
