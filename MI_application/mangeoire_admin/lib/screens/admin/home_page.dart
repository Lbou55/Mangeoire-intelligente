import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api.dart';
import '../../services/session.dart';
import '../../widgets/appetite.dart';
import '../../widgets/carte.dart';
import '../../widgets/common.dart';
import '../../widgets/ico.dart';
import 'cow_detail_page.dart';

class _HomeData {
  const _HomeData(this.cows, this.appetite, this.eleveurs, this.unread, this.feeders);
  final List<Cow> cows;
  final Map<String, Appetite?> appetite;
  final int eleveurs;
  final int unread;
  final List<Feeder> feeders;
}

Future<List<Feeder>> _loadFeeders(FarmApi api) async {
  try {
    return await api.feeders();
  } catch (_) {
    return const [];
  }
}

Future<_HomeData> _loadHome() async {
  final api = FarmApi.instance;
  final feedersFuture = _loadFeeders(api);
  final results = await Future.wait<Object>([
    api.cows(),
    api.appetiteByCow(),
    api.eleveurs(),
    api.alerts(status: 'unread', limit: 100),
  ]);
  return _HomeData(
    results[0] as List<Cow>,
    results[1] as Map<String, Appetite?>,
    (results[2] as List<Eleveur>).length,
    (results[3] as List<AlertItem>).length,
    await feedersFuture,
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onOpenAlerts, required this.onOpenCows,
    required this.onOpenFeeders});
  final VoidCallback onOpenAlerts;
  final VoidCallback onOpenCows;
  final VoidCallback onOpenFeeders;

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
            // greeting
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
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.45,
              children: [
                _Stat('nav_animals', '${d.cows.length}', context.t('stat_cows'), onTap: onOpenCows)
                    .stagger(1),
                _Stat('nav_users', '${d.eleveurs}', context.t('stat_eleveurs')).stagger(2),
                _Stat('nav_alerts', '${d.unread}', context.t('stat_unread'),
                        warning: d.unread > 0, onTap: onOpenAlerts)
                    .stagger(3),
                _Stat('calendar', '${user?.daysLeft ?? 0}', context.t('stat_days_left'),
                        warning: (user?.daysLeft ?? 0) <= 5)
                    .stagger(4),
              ],
            ),
            SectionTitle(context.t('appetite_overview')),
            CarteDouce(
              child: Row(children: [
                for (final a in [Appetite.decreasing, Appetite.stable, Appetite.increasing, null])
                  Expanded(
                    child: Column(children: [
                      Text('${count[a] ?? 0}',
                          style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: appetiteColors(p, a).$1)),
                      const SizedBox(height: 4),
                      Text(appetiteLabel(context, a),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.texte2, fontSize: 12)),
                    ]),
                  ),
              ]),
            ).stagger(5),
            if (d.feeders.isNotEmpty) ...[
              SectionTitle(context.t('feeders')),
              CarteDouce(
                onTap: onOpenFeeders,
                child: Row(children: [
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
              ).stagger(5),
            ],
            SectionTitle(context.t('to_watch')),
            if (watch.isEmpty)
              CarteDouce(
                child: Row(children: [
                  Ico('status_resolved', taille: 28, couleur: p.succes),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(context.t('nothing_to_watch'), style: TextStyle(color: p.texte2)),
                  ),
                ]),
              ).stagger(6)
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
                  ).stagger(6 + i),
                ),
          ],
        );
      },
    );
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Ico(icon, taille: 24, couleur: color),
            const Spacer(),
            Text(value, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: color)),
          ]),
          Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.texte2, fontSize: 13.5)),
        ],
      ),
    );
  }
}
