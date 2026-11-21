import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/l10n.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../services/api.dart';
import '../services/api_client.dart';
import '../services/session.dart';
import '../widgets/common.dart';
import 'login_page.dart';

/// Splash: checks the saved session, then goes to login or the right home.
class StartupPage extends StatefulWidget {
  const StartupPage({super.key});

  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage> {
  Object? _error;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() => _error = null);
    final started = DateTime.now();
    final token = await Session.instance.readToken();

    Widget? target;
    if (token == null) {
      target = const LoginPage();
    } else {
      try {
        final user = await AuthApi.instance.me();
        target = homeFor(user);
      } on ApiException catch (e) {
        if (e.statusCode == null || e.statusCode! >= 500) {
          if (mounted) setState(() => _error = e);
          return;
        }
        await Session.instance.clear();
        target = const LoginPage(sessionEnded: true);
      }
    }
    // keep the logo visible a moment so the animation is seen
    final spent = DateTime.now().difference(started);
    if (spent < const Duration(milliseconds: 1100)) {
      await Future<void>.delayed(const Duration(milliseconds: 1100) - spent);
    }
    if (mounted) resetTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Hero(
              tag: 'logo',
              child: Image.asset('assets/branding/mangeoire_logo_blue.png', width: 170),
            )
                .animate()
                .fadeIn(duration: 500.ms)
                .scale(begin: const Offset(0.8, 0.8), duration: 600.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 18),
            Text(context.t('app_name'),
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: p.primaire))
                .animate()
                .fadeIn(delay: 250.ms, duration: 500.ms),
            const SizedBox(height: 28),
            if (_error == null)
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 3, color: p.primaire),
              ).animate().fadeIn(delay: 500.ms)
            else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Text(errorText(context, _error!),
                    textAlign: TextAlign.center, style: TextStyle(color: p.texte2)),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 190,
                child: ElevatedButton(onPressed: _boot, child: Text(context.t('retry'))),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
