import 'dart:async';

import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/l10n.dart';
import 'core/nav.dart';
import 'core/theme.dart';
import 'screens/login_page.dart';
import 'screens/change_password_page.dart';
import 'screens/startup_page.dart';
import 'services/api.dart';
import 'services/api_client.dart';
import 'services/session.dart';
import 'widgets/bouton_theme.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LangController.instance.load();
  final dark = await loadThemeChoice();
  runApp(MangeoireAdminApp(startDark: dark));
}

class MangeoireAdminApp extends StatefulWidget {
  const MangeoireAdminApp({super.key, required this.startDark});
  final bool startDark;

  @override
  State<MangeoireAdminApp> createState() => _MangeoireAdminAppState();
}

class _MangeoireAdminAppState extends State<MangeoireAdminApp> {
  StreamSubscription<AuthEvent>? _sub;
  bool _passwordScreenOpen = false;

  @override
  void initState() {
    super.initState();
    _sub = Session.instance.events.listen(_onAuthEvent);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _onAuthEvent(AuthEvent e) async {
    final ctx = navigatorKey.currentContext;
    switch (e) {
      case AuthEvent.loggedOut:
        await Session.instance.clear();
        resetTo(const LoginPage(sessionEnded: true));
      case AuthEvent.passwordChangeRequired:
        if (_passwordScreenOpen || ctx == null) return;
        _passwordScreenOpen = true;
        resetTo(const ChangePasswordPage(forced: true));
        _passwordScreenOpen = false;
      case AuthEvent.subscriptionExpired:
        try {
          await AuthApi.instance.me(); // refresh the expiry shown in the app
        } catch (_) {}
        final c = navigatorKey.currentContext;
        if (c != null && c.mounted) showSubscriptionDialog(c);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ThemeProvider(
      initTheme: widget.startDark ? themeSombre : themeClair,
      builder: (context, theme) {
        return ValueListenableBuilder<Locale>(
          valueListenable: LangController.instance.locale,
          builder: (context, locale, _) {
            return MaterialApp(
              title: 'Mangeoire Admin',
              debugShowCheckedModeBanner: false,
              navigatorKey: navigatorKey,
              theme: theme,
              themeAnimationDuration: Duration.zero,
              locale: locale,
              supportedLocales: AppL10n.supported,
              localizationsDelegates: const [
                AppL10nDelegate(),
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) => Stack(children: [
                child ?? const SizedBox.shrink(),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Material(
                    color: Colors.transparent,
                    child: SafeArea(
                      bottom: false,
                      child: WakeBanner(listenable: ApiClient.instance.serverIsWakingUp),
                    ),
                  ),
                ),
              ]),
              home: const StartupPage(),
            );
          },
        );
      },
    );
  }
}
