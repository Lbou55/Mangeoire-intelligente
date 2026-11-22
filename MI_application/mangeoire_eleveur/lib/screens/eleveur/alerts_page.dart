import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api.dart';
import '../../widgets/carte.dart';
import '../../widgets/common.dart';
import '../../widgets/ico.dart';

(Color, Color) severityColors(Palette p, Severity s) => switch (s) {
      Severity.critical => (p.danger, p.dangerClair),
      Severity.warning => (p.alerte, p.alerteClair),
      Severity.info => (p.primaire, p.primaireClair),
    };

String actionLabel(BuildContext context, String action) => context.t('action_$action');

/// Text of an alert: AI alerts are translated here, admin messages shown as typed.
String alertText(BuildContext context, AlertItem a) {
  if (a.type == 'appetite' && a.appetite != null) {
    return context.t('alert_appetite_${a.appetite!.name}', {'cow': a.cowId ?? ''});
  }
  return a.message;
}

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key, this.onChanged});
  final VoidCallback? onChanged;

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  final _key = GlobalKey<AsyncBodyState<List<AlertItem>>>();

  Future<void> _open(AlertItem a) async {
    if (!a.read) {
      try {
        await FarmApi.instance.markAlertRead(a.id);
        _key.currentState?.reload();
        widget.onChanged?.call();
      } catch (_) {}
    }
    if (a.cowId != null) await openCowById(a.cowId!);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AsyncBody<List<AlertItem>>(
        key: _key,
        load: () => FarmApi.instance.alerts(),
        builder: (context, list) {
          if (list.isEmpty) return EmptyView(icon: 'nav_alerts', text: context.t('no_alerts'));
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final a = list[i];
              final (fg, bg) = severityColors(p, a.severity);
              return CarteDouce(
                onTap: () => _open(a),
                padding: EdgeInsets.zero,
                child: IntrinsicHeight(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Container(
                      width: 6,
                      decoration: BoxDecoration(
                        color: fg,
                        borderRadius: const BorderRadiusDirectional.horizontal(
                            start: Radius.circular(22)),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Pill(context.t('severity_${a.severity.name}'),
                                color: fg, background: bg, icon: 'status_alert'),
                            const SizedBox(width: 8),
                            if (a.type == 'appetite')
                              Pill(context.t('source_ai'),
                                  color: p.texte2, background: p.bordure, icon: 'cube_3d'),
                            const Spacer(),
                            if (!a.read)
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: p.primaire),
                              ),
                          ]),
                          const SizedBox(height: 10),
                          Text(alertText(context, a),
                              style: const TextStyle(fontSize: 15.5, height: 1.35)),
                          const SizedBox(height: 10),
                          Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                            if (a.cowId != null)
                              Pill(a.cowId!,
                                  color: p.primaire, background: p.primaireClair, icon: 'nav_animals'),
                            if (a.action != null)
                              Pill(actionLabel(context, a.action!),
                                  color: p.alerte, background: p.alerteClair),
                            Text(formatDateTime(a.createdAt),
                                style: TextStyle(color: p.texte2, fontSize: 12.5)),
                          ]),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ).stagger(i);
            },
          );
        },
      ),
    );
  }
}
