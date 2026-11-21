import 'package:flutter/material.dart';

import '../models/models.dart';
import '../screens/admin/admin_shell.dart';
import '../screens/change_password_page.dart';
import '../screens/super/super_shell.dart';
import 'l10n.dart';
import 'theme.dart';
import '../widgets/ico.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Lets any screen ask the admin shell to jump to a tab (4 = profile).
final ValueNotifier<int?> shellTabRequest = ValueNotifier<int?>(null);

/// First screen for a logged-in user.
Widget homeFor(AppUser user) {
  if (user.mustChangePassword) return const ChangePasswordPage(forced: true);
  return user.isSuperAdmin ? const SuperShell() : const AdminShell();
}

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

bool _subscriptionDialogOpen = false;

/// Pop-up shown when an admin taps a feature while the subscription is over.
Future<void> showSubscriptionDialog(BuildContext context) async {
  if (_subscriptionDialogOpen) return;
  _subscriptionDialogOpen = true;
  final p = Palette.of(context);
  final goProfile = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(shape: BoxShape.circle, color: p.alerteClair),
        child: Center(child: Ico('calendar', taille: 32, couleur: p.alerte)),
      ),
      title: Text(ctx.t('sub_expired_title'),
          textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
      content: Text(ctx.t('sub_expired_body'), textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.t('later'))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(150, 46)),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ctx.t('go_profile')),
        ),
      ],
    ),
  );
  _subscriptionDialogOpen = false;
  if (goProfile == true) shellTabRequest.value = 4;
}
