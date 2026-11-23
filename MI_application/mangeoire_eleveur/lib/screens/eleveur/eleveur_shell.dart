import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/l10n.dart';
import '../../core/nav.dart';
import '../../native/canaux.dart';
import '../../services/api.dart';
import '../../services/live_service.dart';
import '../../services/session.dart';
import '../../widgets/common.dart';
import '../../widgets/shell_frame.dart';
import '../profile_page.dart';
import 'alerts_page.dart';
import 'cows_page.dart';
import 'home_page.dart';

/// Home of the eleveur: Accueil / Vaches / Alertes / Profil.
/// Also starts the real-time connection, the background check (WorkManager)
/// and listens to the notification taps.
class EleveurShell extends StatefulWidget {
  const EleveurShell({super.key});

  @override
  State<EleveurShell> createState() => _EleveurShellState();
}

class _EleveurShellState extends State<EleveurShell> {
  int _index = 0;
  int _unread = 0;
  int _reloadToken = 0; // changes when new data arrives -> pages reload
  StreamSubscription<Map<String, dynamic>>? _live;

  @override
  void initState() {
    super.initState();
    _refreshUnread();
    LiveService.instance.start();
    _live = LiveService.instance.events.listen(_onLive);
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupNative());
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  Future<void> _setupNative() async {
    // 1) a notification tapped: warm start (app open) and cold start (app closed)
    CanauxNatifs.ecouterActions(openCowById);
    try {
      final cow = await CanauxNatifs.actionInitiale();
      if (cow != null && cow.isNotEmpty) await openCowById(cow);
    } catch (_) {}

    // 2) notifications allowed ? (asked once, the system remembers the answer)
    try {
      await CanauxNatifs.demanderPermissionNotifications();
    } catch (_) {}

    // 3) hourly check in the background (Kotlin WorkManager)
    try {
      final token = await Session.instance.readToken();
      if (token != null) {
        await CanauxNatifs.planifier(
          baseUrl: AppConfig.apiBaseUrl,
          token: token,
          seuilPct: await CanauxNatifs.lireSeuil(),
          langue: LangController.instance.locale.value.languageCode,
        );
        // fills the home-screen widget + offline cache without any notification
        await CanauxNatifs.verifierMaintenant(silencieux: true);
      }
    } catch (_) {}
  }

  Future<void> _refreshUnread() async {
    try {
      final n = await FarmApi.instance.unreadCount();
      if (mounted) setState(() => _unread = n);
    } catch (_) {}
  }

  void _onLive(Map<String, dynamic> event) {
    if (!mounted) return;
    if (event['type'] == 'alert') {
      _refreshUnread();
      setState(() => _reloadToken++);
      showMsg(context, context.t('live_alert'));
    } else if (event['type'] == 'update') {
      setState(() => _reloadToken++);
    } else if (event['type'] == 'feeder') {
      setState(() => _reloadToken++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomePage(
        key: ValueKey('home$_reloadToken'),
        onOpenAlerts: () => setState(() => _index = 2),
        onOpenCows: () => setState(() => _index = 1),
      ),
      CowsPage(key: ValueKey('cows$_reloadToken')),
      AlertsPage(key: ValueKey('alerts$_reloadToken'), onChanged: _refreshUnread),
      const ProfilePage(),
    ];
    return ShellFrame(
      tabs: [
        const ShellTab('nav_home', 'tab_home'),
        const ShellTab('nav_animals', 'tab_cows'),
        ShellTab('nav_alerts', 'tab_alerts', badge: _unread),
        const ShellTab('nav_profile', 'tab_profile'),
      ],
      index: _index,
      onSelect: (i) => setState(() => _index = i),
      body: pages[_index],
    );
  }
}
