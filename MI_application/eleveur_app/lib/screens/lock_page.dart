import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/l10n.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../native/canaux.dart';
import '../widgets/common.dart';

/// Fingerprint check shown when the app opens (can be turned off in the profile).
class LockPage extends StatefulWidget {
  const LockPage({super.key, required this.next});
  final Widget next;

  @override
  State<LockPage> createState() => _LockPageState();
}

class _LockPageState extends State<LockPage> {
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await CanauxNatifs.authentifier(
        titre: context.t('bio_title'),
        sousTitre: context.t('bio_sub'),
        annuler: context.t('cancel'),
      );
      if (!mounted) return;
      if (ok) {
        resetTo(widget.next);
        return;
      }
    } on PlatformException {
      if (mounted) _error = context.t('err_bio');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Hero(
                tag: 'logo',
                child: Image.asset('assets/branding/mangeoire_logo_blue.png', width: 130),
              ),
              const SizedBox(height: 22),
              Text(context.t('lock_title'),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(context.t('lock_hint'),
                  textAlign: TextAlign.center, style: TextStyle(color: p.texte2)),
              const SizedBox(height: 28),
              InkResponse(
                onTap: _unlock,
                radius: 60,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: p.primaireClair),
                  child: Icon(Icons.fingerprint, size: 60, color: p.primaire),
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                    begin: const Offset(0.94, 0.94),
                    end: const Offset(1.04, 1.04),
                    duration: 900.ms,
                  ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: p.danger, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: _busy ? null : _unlock,
                child: Text(context.t('unlock')),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
