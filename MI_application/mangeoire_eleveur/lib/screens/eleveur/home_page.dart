import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../native/canaux.dart';
import '../../services/api.dart';
import '../../services/api_client.dart';
import '../../services/session.dart';
import '../../widgets/appetite.dart';
import '../../widgets/carte.dart';
import '../../widgets/common.dart';
import '../../widgets/ico.dart';
import 'cow_detail_page.dart';
import 'feeders_page.dart';

class _HomeData {
  const _HomeData({
    this.cows = const [],
    this.appetite = const {},
    this.unread = 0,
    this.offline = false,
    this.saved = const [],
    this.feeders = const [],
  });
  final List<Cow> cows;
  final Map<String, Appetite?> appetite;
  final int unread;
  final bool offline; // no network: [saved] comes from the phone (DataStore)
  final List<LastMeasure> saved;
  final List<Feeder> feeders;
}

Future<_HomeData> _loadHome() async {
  final api = FarmApi.instance;
  try {
    final results = await Future.wait<Object>([
      api.cows(),
      api.appetiteByCow(),
      api.alerts(status: 'unread', limit: 100),
      api.feeders(),
    ]);
    return _HomeData(
      cows: results[0] as List<Cow>,
      appetite: results[1] as Map<String, Appetite?>,
      unread: (results[2] as List<AlertItem>).length,
      feeders: results[3] as List<Feeder>,
    );
  } on ApiException catch (e) {
    if (e.statusCode == null) {
      List<LastMeasure> saved = const [];
      try {
        saved = await CanauxNatifs.dernieresMesures();
      } catch (_) {}
      return _HomeData(offline: true, saved: saved);
    }
    rethrow;
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onOpenAlerts, required this.onOpenCows});
  final VoidCallback onOpenAlerts;
  final VoidCallback onOpenCows;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return AsyncBody<_HomeData>(
      load: _loadHome,
      builder: (context, d) {
        final user = Session.instance.currentUser.value;
        final count = <Appetite?, int>{};
        for (final c in d.cows) {
          count[d.appetite[c.cowId]] = (count[d.appetite[c.cowId]] ?? 0) + 1;
        }
        final watch = d.cows.where((c) => d.appetite[c.cowId] == Appetite.decreasing).toList();

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [p.bandeau1, p.bandeau2],
                ),
                boxShadow: [BoxShadow(color: p.ombre, blurRadius: 26, offset: const Offset(0, 12))],
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.t('hello', {'name': user?.name ?? ''}),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(context.t('home_subtitle'),
                        style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  ]),
                ),
                const Ico('cube_3d', taille: 54, couleur: Colors.white),
              ]),
            ).stagger(0),
            const SizedBox(height: 14),
            if (d.offline) ..._offline(context, p, d.saved) else ..._online(context, p, d, count, watch),
          ],
        );
      },
    );
  }

  List<Widget> _online(BuildContext context, Palette p, _HomeData d, Map<Appetite?, int> count,
      List<Cow> watch) {
    return [
      Row(children: [
        Expanded(
          child: _Stat('nav_animals', '${d.cows.length}', context.t('stat_cows'), onTap: onOpenCows)
              .stagger(1),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Stat('nav_alerts', '${d.unread}', context.t('stat_unread'),
                  warning: d.unread > 0, onTap: onOpenAlerts)
              .stagger(2),
        ),
      ]),
      SectionTitle(context.t('appetite_overview')),
      CarteDouce(
        child: Row(children: [
          for (final a in [Appetite.decreasing, Appetite.stable, Appetite.increasing, null])
            Expanded(
              child: Column(children: [
                Text('${count[a] ?? 0}',
                    style: TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w800, color: appetiteColors(p, a).$1)),
                const SizedBox(height: 4),
                Text(appetiteLabel(context, a),
                    textAlign: TextAlign.center, style: TextStyle(color: p.texte2, fontSize: 12)),
              ]),
            ),
        ]),
      ).stagger(3),
      SectionTitle(context.t('feeders')),
      CarteDouce(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FeedersPage()),
        ),
        child: d.feeders.isEmpty
            ? Row(children: [
                Ico('nav_feeder', taille: 30, couleur: p.primaire),
                const SizedBox(width: 12),
                Expanded(child: Text(context.t('no_feeders'), style: TextStyle(color: p.texte2))),
              ])
            : Row(children: [
                Ico('nav_feeder', taille: 30, couleur: d.feeders.first.status == 'critical'
                    ? p.danger
                    : d.feeders.first.status == 'low'
                        ? p.alerte
                        : p.succes),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.feeders.first.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  Text('${d.feeders.first.levelPct.toStringAsFixed(1)}%',
                      style: TextStyle(color: p.texte2)),
                ])),
                const Icon(Icons.chevron_right),
              ]),
      ).stagger(3),
      SectionTitle(context.t('to_watch')),
      if (watch.isEmpty)
        CarteDouce(
          child: Row(children: [
            Ico('status_resolved', taille: 28, couleur: p.succes),
            const SizedBox(width: 12),
            Expanded(child: Text(context.t('nothing_to_watch'), style: TextStyle(color: p.texte2))),
          ]),
        ).stagger(4)
      else
        for (var i = 0; i < watch.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CarteDouce(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CowDetailPage(cow: watch[i])),
              ),
              child: Row(children: [
                const AvatarIco(icon: 'nav_animals', size: 46, warning: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(watch[i].cowId,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
                const AppetitePill(Appetite.decreasing),
              ]),
            ).stagger(4 + i),
          ),
    ];
  }

  List<Widget> _offline(BuildContext context, Palette p, List<LastMeasure> saved) {
    return [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: p.alerteClair, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Ico('status_alert', taille: 22, couleur: p.alerte),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              saved.isEmpty
                  ? context.t('offline_none')
                  : context.t('offline_banner', {'date': saved.first.date}),
              style: TextStyle(color: p.alerte, fontWeight: FontWeight.w600),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      for (var i = 0; i < saved.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: CarteDouce(
            child: Row(children: [
              AvatarIco(
                  icon: 'nav_animals', size: 46, warning: saved[i].appetite == Appetite.decreasing),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(saved[i].cowId,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  Text(
                    '${context.t('eaten_today')} : ${(saved[i].consumedG / 1000).toStringAsFixed(2)} kg'
                    '${saved[i].lastVisit != null ? ' · ${context.t('last_visit')} ${saved[i].lastVisit}' : ''}',
                    style: TextStyle(color: p.texte2, fontSize: 13),
                  ),
                ]),
              ),
              AppetitePill(saved[i].appetite),
            ]),
          ).stagger(i),
        ),
    ];
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.value, this.label, {this.warning = false, this.onTap});
  final String icon;
  final String value;
  final String label;
  final bool warning;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final color = warning ? p.alerte : p.primaire;
    return CarteDouce(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Ico(icon, taille: 24, couleur: color),
            const Spacer(),
            Text(value, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: color)),
          ]),
          const SizedBox(height: 8),
          Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.texte2, fontSize: 13.5)),
        ],
      ),
    );
  }
}
