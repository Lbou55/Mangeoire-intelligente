import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api.dart';
import '../../services/live_service.dart';
import '../../widgets/carte.dart';
import '../../widgets/common.dart';
import '../../widgets/feeder_visual.dart';

class FeedersPage extends StatefulWidget {
  const FeedersPage({super.key});

  @override
  State<FeedersPage> createState() => _FeedersPageState();
}

class _FeedersPageState extends State<FeedersPage> {
  final _key = GlobalKey<AsyncBodyState<List<Feeder>>>();
  StreamSubscription<Map<String, dynamic>>? _live;

  @override
  void initState() {
    super.initState();
    _live = LiveService.instance.events.listen((event) {
      if (event['type'] == 'feeder') _key.currentState?.reload();
    });
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  Future<List<Feeder>> _load() => FarmApi.instance.feeders();

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AsyncBody<List<Feeder>>(
        key: _key,
        load: _load,
        builder: (context, feeders) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CarteDouce(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Text(context.t('only_admin_edits_feeders'),
                      style: TextStyle(color: p.texte2)),
                ),
              ),
              if (feeders.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: EmptyView(icon: 'nav_feeder', text: context.t('no_feeders')),
                )
              else
                for (var i = 0; i < feeders.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: CarteDouce(
                      child: Row(children: [
                        FeederVisual(feeder: feeders[i]),
                        const SizedBox(width: 12),
                        Expanded(child: _FeederDetails(feeder: feeders[i], p: p)),
                      ]),
                    ).stagger(i),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _FeederDetails extends StatelessWidget {
  const _FeederDetails({required this.feeder, required this.p});
  final Feeder feeder;
  final Palette p;

  @override
  Widget build(BuildContext context) {
    final statusKey = feeder.status == 'ok'
        ? 'feeder_ok'
        : feeder.status == 'low'
            ? 'feeder_low'
            : 'feeder_critical';
    final statusColor = feeder.status == 'ok'
        ? p.succes
        : feeder.status == 'low'
            ? p.alerte
            : p.danger;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(feeder.name, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Text('${(feeder.currentG / 1000).toStringAsFixed(2)} kg / ${(feeder.capacityG / 1000).toStringAsFixed(1)} kg',
          style: TextStyle(color: p.texte2, fontSize: 13)),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: [
        Pill(
          feeder.online ? context.t('feeder_online') : context.t('feeder_offline'),
          color: feeder.online ? p.succes : p.texte2,
          background: feeder.online ? p.succesClair : p.primaireClair,
          icon: feeder.online ? 'feeder_online' : null,
        ),
        Pill(context.t(statusKey), color: statusColor,
            background: feeder.status == 'ok' ? p.succesClair : p.alerteClair),
      ]),
      const SizedBox(height: 8),
      Text(
        '${context.t('last_refill')}: ${feeder.lastRefillAt == null ? context.t('never_refilled') : formatDateTime(feeder.lastRefillAt)}',
        maxLines: 2,
        style: TextStyle(color: p.texte2, fontSize: 12),
      ),
    ]);
  }
}
