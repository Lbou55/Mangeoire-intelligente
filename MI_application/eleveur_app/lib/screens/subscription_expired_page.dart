import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../services/api.dart';
import '../widgets/common.dart';
import '../widgets/ico.dart';

/// Shown to an eleveur when the farm's subscription is over.
class SubscriptionExpiredPage extends StatefulWidget {
  const SubscriptionExpiredPage({super.key});

  @override
  State<SubscriptionExpiredPage> createState() => _SubscriptionExpiredPageState();
}

class _SubscriptionExpiredPageState extends State<SubscriptionExpiredPage> {
  bool _busy = false;

  Future<void> _check() async {
    setState(() => _busy = true);
    try {
      await FarmApi.instance.cows();
      if (mounted) Navigator.pop(context); // renewed: back to the app
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        showMsg(context, context.t('eleveur_sub_title'));
      }
    }
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
              AvatarIco(icon: 'calendar', size: 96, warning: true),
              const SizedBox(height: 22),
              Text(context.t('eleveur_sub_title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text(context.t('eleveur_sub_body'),
                  textAlign: TextAlign.center, style: TextStyle(color: p.texte2, height: 1.4)),
              const SizedBox(height: 26),
              ElevatedButton.icon(
                onPressed: _busy ? null : _check,
                icon: Ico('refresh', taille: 20, couleur: p.surPrimaire),
                label: Text(context.t('retry')),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
