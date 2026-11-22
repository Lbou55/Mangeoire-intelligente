import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api.dart';
import '../../widgets/appetite.dart';
import '../../widgets/carte.dart';
import '../../widgets/common.dart';
import '../../widgets/ico.dart';
import 'alerts_page.dart';
import 'cow_form_page.dart';

typedef _DetailData = ({List<DailySummary> daily, List<Dispatch> dispatch, double? predicted});

Future<_DetailData> _loadDetail(String cowId) async {
  final api = FarmApi.instance;
  final results = await Future.wait<Object?>([
    api.daily(cowId, limit: 14).catchError((_) => <DailySummary>[]),
    api.dispatch(cowId, limit: 7).catchError((_) => <Dispatch>[]),
    api.predictedIntakeKg(cowId).catchError((_) => null),
  ]);
  return (
    daily: results[0] as List<DailySummary>,
    dispatch: results[1] as List<Dispatch>,
    predicted: results[2] as double?,
  );
}

String ageText(BuildContext context, int months) {
  final y = months ~/ 12;
  final m = months % 12;
  if (y == 0) return context.t('age_months', {'m': '$m'});
  if (m == 0) return context.t('age_years', {'y': '$y'});
  return context.t('age_years_months', {'y': '$y', 'm': '$m'});
}

class CowDetailPage extends StatelessWidget {
  const CowDetailPage({super.key, required this.cow});
  final Cow cow;

  Future<void> _delete(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: context.t('delete_cow'),
      message: context.t('delete_cow_msg', {'id': cow.cowId}),
      confirmLabel: context.t('delete'),
      danger: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await FarmApi.instance.deleteCow(cow.cowId);
      if (context.mounted) Navigator.pop(context, true);
    } catch (e) {
      if (context.mounted) showMsg(context, errorText(context, e));
    }
  }

  Future<void> _edit(BuildContext context) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CowFormPage(cow: cow)),
    );
    if (changed == true && context.mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(cow.cowId, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: context.t('edit'),
            onPressed: () => _edit(context),
            icon: Ico('edit', couleur: p.primaire),
          ),
          IconButton(
            tooltip: context.t('delete'),
            onPressed: () => _delete(context),
            icon: Ico('delete', couleur: p.danger),
          ),
        ],
      ),
      body: AsyncBody<_DetailData>(
        load: () => _loadDetail(cow.cowId),
        builder: (context, d) {
          final latest = d.daily.isEmpty ? null : d.daily.first;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              _ProfileCard(cow: cow).stagger(0),
              SectionTitle(context.t('appetite')),
              _AppetiteCard(latest: latest).stagger(1),
              if (latest != null) ...[
                SectionTitle(context.t('latest_day', {'date': latest.date})),
                _Numbers(latest: latest).stagger(2),
              ],
              SectionTitle(context.t('consumption_14d')),
              CarteDouce(child: _BarChart(days: d.daily.reversed.toList())).stagger(3),
              if (d.predicted != null) ...[
                SectionTitle(context.t('predicted_intake')),
                CarteDouce(
                  child: Row(children: [
                    Ico('cube_3d', taille: 30, couleur: p.primaire),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.t('predicted_text',
                            {'kg': d.predicted!.toStringAsFixed(1)}),
                        style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ]),
                ).stagger(4),
              ],
              if (d.dispatch.isNotEmpty) ...[
                SectionTitle(context.t('feed_dispatch')),
                CarteDouce(
                  child: Column(children: [
                    for (final x in d.dispatch)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(children: [
                          Ico('food_delivered', taille: 22, couleur: p.primaire),
                          const SizedBox(width: 10),
                          Expanded(child: Text(x.date)),
                          Text('${(x.foodG / 1000).toStringAsFixed(2)} kg',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ]),
                      ),
                  ]),
                ).stagger(5),
              ],
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SendAlertPage(cowId: cow.cowId)),
                ),
                icon: Ico('send', taille: 20, couleur: p.primaire),
                label: Text(context.t('send_alert_cow')),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.cow});
  final Cow cow;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    Widget row(String icon, String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Ico(icon, taille: 20, couleur: p.texte2),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(color: p.texte2)),
            const Spacer(),
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ]),
        );
    return CarteDouce(
      child: Column(children: [
        Row(children: [
          Hero(tag: 'cow_${cow.cowId}', child: const AvatarIco(icon: 'nav_animals', size: 64)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cow.cowId, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Wrap(spacing: 8, children: [
                Pill(cowTypeLabel(context, cow.type),
                    color: p.primaire, background: p.primaireClair),
                Pill(cow.breed, color: p.texte2, background: p.bordure),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Divider(color: p.bordure),
        row('rfid_tag', context.t('rfid_tag'), cow.nfcUid.isEmpty ? '—' : cow.nfcUid),
        row('weight', context.t('weight'), '${cow.weightKg.toStringAsFixed(0)} kg'),
        row('calendar', context.t('age'), ageText(context, cow.ageMonths)),
        row('calendar', context.t('birth_date'), cow.birthDate == null ? '—' : dateOnly(cow.birthDate!)),
      ]),
    );
  }
}

class _AppetiteCard extends StatelessWidget {
  const _AppetiteCard({required this.latest});
  final DailySummary? latest;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final a = latest?.appetite;
    final pct = latest?.appetitePct;
    return CarteDouce(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(context.t('appetite_model'),
                style: TextStyle(color: p.texte2, fontSize: 13.5)),
          ),
          AppetitePill(a),
        ]),
        if (a == null) ...[
          const SizedBox(height: 10),
          Text(context.t('appetite_need_days'), style: TextStyle(color: p.texte2, height: 1.35)),
        ],
        if (pct != null && pct.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final e in pct.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                SizedBox(
                  width: 92,
                  child: Text(appetiteLabel(context, parseAppetite(e.key)),
                      style: const TextStyle(fontSize: 13)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (e.value / 100).clamp(0.0, 1.0),
                      minHeight: 8,
                      color: appetiteColors(p, parseAppetite(e.key)).$1,
                      backgroundColor: p.bordure,
                    ),
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: Text('${e.value.toStringAsFixed(0)} %',
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ]),
            ),
        ],
      ]),
    );
  }
}

class _Numbers extends StatelessWidget {
  const _Numbers({required this.latest});
  final DailySummary latest;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    Widget cell(String icon, String value, String label) => Expanded(
          child: Column(children: [
            Ico(icon, taille: 26, couleur: p.primaire),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center, style: TextStyle(color: p.texte2, fontSize: 12)),
          ]),
        );
    return CarteDouce(
      child: Column(children: [
        Row(children: [
          cell('food_delivered', '${(latest.consumedG / 1000).toStringAsFixed(2)} kg',
              context.t('consumed')),
          cell('feeder_online', '${(latest.offeredG / 1000).toStringAsFixed(2)} kg',
              context.t('offered')),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          cell('eating_time', '${latest.eatingMinutes.toStringAsFixed(0)} min',
              context.t('eating_time')),
          cell('visits', latest.visits.toStringAsFixed(0), context.t('visits')),
        ]),
      ]),
    );
  }
}

/// Daily consumption bars (kg), oldest to newest.
class _BarChart extends StatelessWidget {
  const _BarChart({required this.days});
  final List<DailySummary> days;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    if (days.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Text(context.t('no_data'), style: TextStyle(color: p.texte2)),
      );
    }
    final maxV = days.map((d) => d.consumedG).fold<double>(1, (a, b) => b > a ? b : a);
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < days.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: days[i].consumedG / maxV),
                    duration: Duration(milliseconds: 500 + i * 40),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => Container(
                      height: 100 * v + 2,
                      decoration: BoxDecoration(
                        color: i == days.length - 1 ? p.primaire : p.primaire.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    days[i].date.length >= 10 ? days[i].date.substring(8, 10) : '',
                    style: TextStyle(color: p.texte2, fontSize: 10.5),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}
