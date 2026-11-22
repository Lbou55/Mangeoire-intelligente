import 'package:flutter/material.dart';

import '../../core/nav.dart';
import '../../services/api.dart';
import '../../services/session.dart';
import '../../widgets/shell_frame.dart';
import '../profile_page.dart';
import 'alerts_page.dart';
import 'cows_page.dart';
import 'eleveurs_page.dart';
import 'home_page.dart';

/// Admin: home, cows, eleveurs, alerts, profile.
/// When the subscription is over, every tab except the profile is locked and a
/// pop-up sends the admin to the profile to renew.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> with WidgetsBindingObserver {
  late int _index;
  int _unread = 0;

  bool get _active => Session.instance.currentUser.value?.subscriptionActive ?? true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _index = _active ? 0 : 4;
    shellTabRequest.addListener(_onTabRequest);
    Session.instance.currentUser.addListener(_onUserChanged);
    _loadUnread();
    if (!_active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showSubscriptionDialog(context);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    shellTabRequest.removeListener(_onTabRequest);
    Session.instance.currentUser.removeListener(_onUserChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshUser();
      _loadUnread();
    }
  }

  Future<void> _refreshUser() async {
    try {
      await AuthApi.instance.me();
    } catch (_) {}
  }

  void _onUserChanged() {
    if (!mounted) return;
    if (!_active && _index != 4) setState(() => _index = 4);
    setState(() {});
  }

  void _onTabRequest() {
    final i = shellTabRequest.value;
    if (i == null || !mounted) return;
    shellTabRequest.value = null;
    setState(() => _index = i);
  }

  Future<void> _loadUnread() async {
    if (!_active) return;
    try {
      final unread = await FarmApi.instance.alerts(status: 'unread', limit: 100);
      if (mounted) setState(() => _unread = unread.length);
    } catch (_) {}
  }

  void _select(int i) {
    if (i != 4 && !_active) {
      showSubscriptionDialog(context);
      return;
    }
    setState(() => _index = i);
    if (i == 3) _loadUnread();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomePage(onOpenAlerts: () => _select(3), onOpenCows: () => _select(1)),
      const CowsPage(),
      const EleveursPage(),
      AlertsPage(onChanged: _loadUnread),
      const ProfilePage(),
    ];
    return ShellFrame(
      index: _index,
      onSelect: _select,
      tabs: [
        const ShellTab('nav_home', 'tab_home'),
        const ShellTab('nav_animals', 'tab_cows'),
        const ShellTab('nav_users', 'tab_eleveurs'),
        ShellTab('nav_alerts', 'tab_alerts', badge: _unread),
        const ShellTab('nav_profile', 'tab_profile'),
      ],
      body: pages[_index],
    );
  }
}
