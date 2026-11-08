import 'dart:async';

import 'package:flutter/material.dart';

import '../models/vache.dart';
import '../outils.dart';
import '../services/api.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets/carte.dart';
import 'detail_signalement_page.dart';

/// La cloche : la liste des notifications. Les non lues sont en gras avec un point.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Notif>? _liste;
  String? _erreur;
  StreamSubscription<Notif>? _ecoute;

  @override
  void initState() {
    super.initState();
    _charger();
    _ecoute = Session.instance.notifications.listen((_) => _charger());
  }

  @override
  void dispose() {
    _ecoute?.cancel();
    super.dispose();
  }

  Future<void> _charger() async {
    try {
      final r = await Session.instance.api.get('/notifications') as List;
      if (!mounted) return;
      setState(() {
        _liste = [for (final j in r) Notif(Map<String, dynamic>.from(j as Map))];
        _erreur = null;
      });
      Session.instance.rafraichirNonLus();
    } on ApiException catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    }
  }

  Future<void> _toutLire() async {
    try {
      await Session.instance.api.post('/notifications/read-all');
      await _charger();
    } on ApiException catch (_) {}
  }

  Future<void> _ouvrir(Notif n) async {
    try {
      await Session.instance.api.post('/notifications/${n.id}/read');
    } on ApiException catch (_) {}
    if (!mounted) return;
    if (n.signalementId != null) {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (context) => DetailSignalementPage(signalementId: n.signalementId!),
      ));
    }
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          TextButton(onPressed: _toutLire, child: const Text('Tout lire')),
          const SizedBox(width: 6),
        ],
      ),
      body: _erreur != null && _liste == null
          ? Center(child: Text(_erreur!, style: TextStyle(color: p.texte2)))
          : _liste == null
              ? const Center(child: CircularProgressIndicator())
              : _liste!.isEmpty
                  ? Center(child: Text('Aucune notification.', style: TextStyle(color: p.texte2)))
                  : RefreshIndicator(
                      onRefresh: _charger,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          for (final n in _liste!)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _Ligne(notif: n, onTap: () => _ouvrir(n)),
                            ),
                        ],
                      ),
                    ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.notif, required this.onTap});

  final Notif notif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final danger = notif.type == 'report_danger';
    final alerte = notif.type == 'report_alerte';
    final couleur = danger ? p.danger : (alerte ? p.alerte : p.primaire);
    final claire = danger ? p.dangerClair : (alerte ? p.alerteClair : p.primaireClair);
    final icone = switch (notif.type) {
      'report_danger' => Icons.error_rounded,
      'report_alerte' => Icons.warning_amber_rounded,
      'vet_called' || 'vet_declined' => Icons.medical_services_outlined,
      _ => Icons.chat_bubble_outline_rounded,
    };
    return CarteDouce(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(shape: BoxShape.circle, color: claire),
            child: Icon(icone, color: couleur, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notif.titre,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: notif.lue ? FontWeight.w600 : FontWeight.w800,
                    color: danger ? p.danger : p.texte,
                  ),
                ),
                const SizedBox(height: 2),
                Text(notif.corps, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.texte2, fontSize: 13.5)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(quandFr(notif.creeLe), style: TextStyle(color: p.texte2, fontSize: 12)),
                    if (notif.veterinaireRequis) ...[
                      const SizedBox(width: 8),
                      Text('Décision vétérinaire',
                          style: TextStyle(color: p.danger, fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (!notif.lue)
            Container(
              margin: const EdgeInsets.only(top: 6, left: 8),
              width: 10,
              height: 10,
              decoration: BoxDecoration(shape: BoxShape.circle, color: couleur),
            ),
        ],
      ),
    );
  }
}
