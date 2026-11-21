import 'package:flutter/material.dart';

import '../models/models.dart';
import '../screens/eleveur/cow_detail_page.dart';
import '../screens/eleveur/eleveur_shell.dart';
import '../screens/subscription_expired_page.dart';
import '../services/api.dart';
import '../widgets/common.dart';
import 'l10n.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// First screen for a logged-in eleveur.
Widget homeFor(AppUser user) => const EleveurShell();

/// Replace the whole stack with [page].
void resetTo(Widget page) {
  navigatorKey.currentState?.pushAndRemoveUntil(
    PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      transitionDuration: const Duration(milliseconds: 300),
    ),
    (_) => false,
  );
}

/// Opens the file of a cow (from a notification, the widget or an NFC tag).
Future<void> openCowById(String cowId) async {
  final nav = navigatorKey.currentState;
  final ctx = navigatorKey.currentContext;
  if (nav == null || ctx == null) return;
  try {
    final cow = await FarmApi.instance.cow(cowId);
    navigatorKey.currentState
        ?.push(MaterialPageRoute<void>(builder: (_) => CowDetailPage(cow: cow)));
  } catch (e) {
    final c = navigatorKey.currentContext;
    if (c != null && c.mounted) showMsg(c, errorText(c, e));
  }
}

bool _subscriptionPageOpen = false;

/// The admin's subscription is over: the eleveur sees a full page (he can
/// only wait for his admin to renew it).
Future<void> showSubscriptionExpired() async {
  if (_subscriptionPageOpen) return;
  _subscriptionPageOpen = true;
  await navigatorKey.currentState?.push(
    MaterialPageRoute<void>(builder: (_) => const SubscriptionExpiredPage()),
  );
  _subscriptionPageOpen = false;
}
