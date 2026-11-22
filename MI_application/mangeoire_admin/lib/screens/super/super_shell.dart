import 'package:flutter/material.dart';

import '../../widgets/shell_frame.dart';
import '../profile_page.dart';
import 'admins_page.dart';
import 'renewals_page.dart';

/// Superadmin: gives accounts to admins, sees who accepted, approves renewals.
class SuperShell extends StatefulWidget {
  const SuperShell({super.key});

  @override
  State<SuperShell> createState() => _SuperShellState();
}

class _SuperShellState extends State<SuperShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const AdminsPage(),
      const RenewalsPage(),
      const ProfilePage(),
    ];
    return ShellFrame(
      index: _index,
      onSelect: (i) => setState(() => _index = i),
      tabs: const [
        ShellTab('nav_users', 'tab_admins'),
        ShellTab('calendar', 'tab_renewals'),
        ShellTab('nav_profile', 'tab_profile'),
      ],
      body: pages[_index],
    );
  }
}
