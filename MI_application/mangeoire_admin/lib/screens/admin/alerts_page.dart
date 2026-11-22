import 'package:flutter/material.dart';

import '../../core/l10n.dart';
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

  Future<void> _send() async {
    final sent = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SendAlertPage()),
    );
    if (sent == true) {
      _key.currentState?.reload();
      widget.onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _send,
        icon: Ico('send', taille: 22, couleur: p.surPrimaire),
        label: Text(context.t('send_message'), style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: AsyncBody<List<AlertItem>>(
        key: _key,
        load: () => FarmApi.instance.alerts(),
        builder: (context, list) {
          if (list.isEmpty) return EmptyView(icon: 'nav_alerts', text: context.t('no_alerts'));
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final a = list[i];
              final (fg, bg) = severityColors(p, a.severity);
              return CarteDouce(
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

/// Custom message sent to the eleveurs of the farm (optionally about one cow).
class SendAlertPage extends StatefulWidget {
  const SendAlertPage({super.key, this.cowId});
  final String? cowId;

  @override
  State<SendAlertPage> createState() => _SendAlertPageState();
}

class _SendAlertPageState extends State<SendAlertPage> {
  final _message = TextEditingController();
  Severity _severity = Severity.info;
  String? _cowId;
  String? _action;
  List<Cow> _cows = [];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cowId = widget.cowId;
    FarmApi.instance.cows().then((c) {
      if (mounted) setState(() => _cows = c);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _message.text.trim();
    if (text.isEmpty) {
      setState(() => _error = context.t('err_empty_message'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FarmApi.instance.sendAlert(
        message: text,
        severity: _severity,
        cowId: _cowId,
        action: _action,
      );
      if (!mounted) return;
      showMsg(context, context.t('message_sent'));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errorText(context, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final cowIds = _cows.map((c) => c.cowId).toList();
    if (_cowId != null && !cowIds.contains(_cowId) && _cows.isNotEmpty) cowIds.add(_cowId!);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('send_message'), style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _message,
            maxLines: 5,
            maxLength: 500,
            decoration: decorationChamp(p, indice: context.t('message_hint')),
          ),
          const SizedBox(height: 10),
          Text(context.t('severity'), style: TextStyle(color: p.texte2, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final s in Severity.values)
              ChoiceChip(
                label: Text(context.t('severity_${s.name}')),
                selected: _severity == s,
                selectedColor: severityColors(p, s).$2,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _severity == s ? severityColors(p, s).$1 : p.texte2,
                ),
                onSelected: (_) => setState(() => _severity = s),
              ),
          ]),
          const SizedBox(height: 18),
          Text(context.t('about_cow'), style: TextStyle(color: p.texte2, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            key: ValueKey<int>(cowIds.length),
            initialValue: cowIds.contains(_cowId) ? _cowId : null,
            items: [
              DropdownMenuItem<String?>(value: null, child: Text(context.t('no_cow'))),
              for (final id in cowIds) DropdownMenuItem<String?>(value: id, child: Text(id)),
            ],
            onChanged: (v) => setState(() => _cowId = v),
            decoration: decorationChamp(p, indice: context.t('no_cow')),
          ),
          const SizedBox(height: 18),
          Text(context.t('suggested_action'),
              style: TextStyle(color: p.texte2, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            ChoiceChip(
              label: Text(context.t('action_none')),
              selected: _action == null,
              onSelected: (_) => setState(() => _action = null),
            ),
            for (final a in const ['sell', 'vet', 'butcher'])
              ChoiceChip(
                label: Text(actionLabel(context, a)),
                selected: _action == a,
                onSelected: (_) => setState(() => _action = a),
              ),
          ]),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: p.dangerClair, borderRadius: BorderRadius.circular(12)),
              child: Text(_error!, style: TextStyle(color: p.danger, fontWeight: FontWeight.w600)),
            ),
          ],
          const SizedBox(height: 22),
          ElevatedButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: p.surPrimaire),
                  )
                : Ico('send', taille: 20, couleur: p.surPrimaire),
            label: Text(context.t('send')),
          ),
        ],
      ),
    );
  }
}
