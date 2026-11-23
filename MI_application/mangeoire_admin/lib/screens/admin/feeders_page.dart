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
import '../../widgets/ico.dart';

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

  Future<void> _create() async {
    final name = TextEditingController();
    final capacity = TextEditingController();
    final p = Palette.of(context);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(ctx.t('add_feeder'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextField(controller: name, decoration: decorationChamp(p, indice: ctx.t('feeder'))),
          const SizedBox(height: 10),
          TextField(
            controller: capacity,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: decorationChamp(p, indice: '${ctx.t('capacity')} (kg)'),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.t('save')),
          ),
        ]),
      ),
    );
    if (ok == true) {
      try {
        final kg = double.tryParse(capacity.text.replaceAll(',', '.'));
        if (name.text.trim().isEmpty || kg == null || kg <= 0) throw Exception();
        await FarmApi.instance.createFeeder(name: name.text.trim(), capacityKg: kg);
        if (mounted) showMsg(context, context.t('feeder_created'));
        _key.currentState?.reload();
      } catch (e) {
        if (mounted) showMsg(context, e is Exception ? errorText(context, e) : context.t('fill_all'));
      }
    }
  }

  Future<void> _open(Feeder feeder) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Ico('add', taille: 24),
              title: Text(ctx.t('refill_full')),
              onTap: () async {
                Navigator.pop(ctx);
                await _refill(feeder, null);
              },
            ),
            ListTile(
              leading: const Ico('nav_feeder', taille: 24),
              title: Text(ctx.t('refill_amount')),
              onTap: () async {
                Navigator.pop(ctx);
                await _refill(feeder, true);
              },
            ),
            ListTile(
              leading: const Ico('edit', taille: 24),
              title: Text(ctx.t('edit_feeder')),
              onTap: () async {
                Navigator.pop(ctx);
                await _edit(feeder);
              },
            ),
            ListTile(
              leading: const Ico('delete', taille: 24),
              title: Text(ctx.t('delete_feeder'), style: TextStyle(color: Palette.of(context).danger)),
              onTap: () async {
                Navigator.pop(ctx);
                await _delete(feeder);
              },
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _refill(Feeder feeder, bool? askAmount) async {
    double? kg;
    if (askAmount == true) {
      final controller = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.t('refill_amount')),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'kg'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.t('cancel'))),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.t('save'))),
          ],
        ),
      );
      if (ok != true) return;
      kg = double.tryParse(controller.text.replaceAll(',', '.'));
      if (kg == null || kg <= 0) return;
    }
    try {
      await FarmApi.instance.refillFeeder(feeder.id, quantityKg: kg);
      if (mounted) showMsg(context, context.t('feeder_refilled'));
      _key.currentState?.reload();
    } catch (e) {
      if (mounted) showMsg(context, errorText(context, e));
    }
  }

  Future<void> _edit(Feeder feeder) async {
    final name = TextEditingController(text: feeder.name);
    final capacity = TextEditingController(text: (feeder.capacityG / 1000).toStringAsFixed(1));
    final p = Palette.of(context);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(ctx.t('edit_feeder'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextField(controller: name, decoration: decorationChamp(p, indice: ctx.t('feeder'))),
          const SizedBox(height: 10),
          TextField(
            controller: capacity,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: decorationChamp(p, indice: '${ctx.t('capacity')} (kg)'),
          ),
          const SizedBox(height: 14),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.t('save'))),
        ]),
      ),
    );
    if (ok == true) {
      try {
        final kg = double.tryParse(capacity.text.replaceAll(',', '.'));
        await FarmApi.instance.updateFeeder(
          id: feeder.id,
          name: name.text.trim(),
          capacityKg: kg ?? 0,
        );
        if (mounted) showMsg(context, context.t('feeder_updated'));
        _key.currentState?.reload();
      } catch (e) {
        if (mounted) showMsg(context, errorText(context, e));
      }
    }
  }

  Future<void> _delete(Feeder feeder) async {
    final ok = await confirmDialog(
      context,
      title: context.t('delete_feeder'),
      message: context.t('delete_feeder_confirm', {'name': feeder.name}),
      confirmLabel: context.t('delete'),
      danger: true,
    );
    if (!ok) return;
    try {
      await FarmApi.instance.deleteFeeder(feeder.id);
      if (mounted) showMsg(context, context.t('feeder_deleted'));
      _key.currentState?.reload();
    } catch (e) {
      if (mounted) showMsg(context, errorText(context, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: Ico('add', taille: 22, couleur: p.surPrimaire),
        label: Text(context.t('add_feeder')),
      ),
      body: AsyncBody<List<Feeder>>(
        key: _key,
        load: _load,
        builder: (context, feeders) {
          if (feeders.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 80),
                EmptyView(icon: 'nav_feeder', text: context.t('no_feeders')),
              ],
            );
          }
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            children: [
              for (var i = 0; i < feeders.length; i)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: CarteDouce(
                    onTap: () => _open(feeders[i]),
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
