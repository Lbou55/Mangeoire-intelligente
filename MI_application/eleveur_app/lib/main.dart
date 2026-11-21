import 'dart:async';

import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/l10n.dart';
import 'core/nav.dart';
import 'core/theme.dart';
import 'screens/register_page.dart';
import 'screens/startup_page.dart';
import 'services/live_service.dart';
import 'services/api_client.dart';
import 'services/session.dart';
import 'widgets/bouton_theme.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LangController.instance.load();
  final dark = await loadThemeChoice();
  runApp(MangeoireEleveurApp(startDark: dark));
}

class MangeoireEleveurApp extends StatefulWidget {
  const MangeoireEleveurApp({super.key, required this.startDark});
  final bool startDark;

  @override
  State<MangeoireEleveurApp> createState() => _MangeoireEleveurAppState();
}

class _MangeoireEleveurAppState extends State<MangeoireEleveurApp> {
  StreamSubscription<AuthEvent>? _sub;

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
    switch (e) {
      case AuthEvent.loggedOut:
        LiveService.instance.stop();
        await Session.instance.clear();
        resetTo(const RegisterPage(sessionEnded: true));
      case AuthEvent.passwordChangeRequired:
        break; // eleveurs have no password
      case AuthEvent.subscriptionExpired:
        showSubscriptionExpired();
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
              title: 'Mangeoire',
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
