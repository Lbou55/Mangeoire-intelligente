import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../native/canaux.dart';
import '../../services/api.dart';
import '../../widgets/carte.dart';
import '../../widgets/common.dart';
import '../../widgets/ico.dart';

String cowTypeLabel(BuildContext context, CowType t) => context.t('type_${t.name}');

/// Create or edit a cow. Only the admin can do this.
class CowFormPage extends StatefulWidget {
  const CowFormPage({super.key, this.cow});
  final Cow? cow;

  @override
  State<CowFormPage> createState() => _CowFormPageState();
}

class _CowFormPageState extends State<CowFormPage> {
  late final TextEditingController _cowId;
  late final TextEditingController _tag;
  late final TextEditingController _weight;
  DateTime? _birth;
  late CowType _type;
  String? _breed;
  bool _busy = false;
  String? _error;

  bool get _editing => widget.cow != null;

  /// Breeds of the chosen type (keeps an old breed outside our list selectable).
  List<String> get _breeds {
    final list = [...breedsByType[_type]!];
    if (_breed != null && !list.contains(_breed)) list.add(_breed!);
    return list;
  }

  @override
  void initState() {
    super.initState();
    final c = widget.cow;
    _cowId = TextEditingController(text: c?.cowId ?? '');
    _tag = TextEditingController(text: (c != null && c.nfcUid != c.cowId) ? c.nfcUid : '');
    _weight = TextEditingController(text: c == null ? '' : c.weightKg.toStringAsFixed(0));
    _birth = c?.birthDate;
    _type = c?.type ?? CowType.dairy;
    _breed = c?.breed;
    if (!_editing) _suggestId();
  }

  Future<void> _suggestId() async {
    try {
      final cows = await FarmApi.instance.cows();
      var max = 0;
      for (final c in cows) {
        final n = int.tryParse(c.cowId.replaceAll(RegExp(r'\D'), ''));
        if (n != null && n > max) max = n;
      }
      if (mounted && _cowId.text.isEmpty) {
        setState(() => _cowId.text = 'COW${(max + 1).toString().padLeft(3, '0')}');
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _cowId.dispose();
    _tag.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _pickBirth() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _birth ?? DateTime(now.year - 2, now.month, now.day),
      firstDate: DateTime(now.year - 30),
      lastDate: now,
    );
    if (d != null) setState(() => _birth = d);
  }

  Future<void> _scan() async {
    var cancelled = false;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ScanDialog(onCancel: () {
        cancelled = true;
        CanauxNatifs.annulerNfc().catchError((_) {});
        Navigator.pop(ctx);
      }),
    );
    try {
      final uid = await CanauxNatifs.lireUidNfc();
      if (cancelled || !mounted) return;
      Navigator.of(context).pop(); // close the scan dialog
      if (uid != null) setState(() => _tag.text = uid);
    } on PlatformException catch (e) {
      if (cancelled || !mounted) return;
      Navigator.of(context).pop();
      switch (e.code) {
        case 'NFC_DESACTIVE':
          final open = await confirmDialog(
            context,
            title: context.t('nfc_disabled_title'),
            message: context.t('nfc_disabled_body'),
            confirmLabel: context.t('open_settings'),
          );
          if (open) CanauxNatifs.ouvrirParametresNfc().catchError((_) {});
        case 'NFC_ABSENT':
          showMsg(context, context.t('err_nfc_absent'));
        case 'DELAI_DEPASSE':
          showMsg(context, context.t('err_nfc_timeout'));
        default:
          showMsg(context, context.t('err_nfc_generic'));
      }
    } on MissingPluginException {
      if (mounted) {
        Navigator.of(context).pop();
        showMsg(context, context.t('err_nfc_absent'));
      }
    }
  }

  Future<void> _save() async {
    final cowId = _cowId.text.trim().toUpperCase();
    final weight = double.tryParse(_weight.text.trim().replaceAll(',', '.'));
    if (cowId.length < 2 || _birth == null || weight == null || weight <= 0 || _breed == null) {
      setState(() => _error = context.t('err_invalid_cow_form'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = FarmApi.instance;
      if (_editing) {
        await api.updateCow(
          cowId: widget.cow!.cowId,
          nfcUid: _tag.text.trim().toUpperCase(),
          birthDate: _birth!,
          weightKg: weight,
          type: _type,
          breed: _breed!,
        );
      } else {
        await api.createCow(
          cowId: cowId,
          nfcUid: _tag.text.trim().toUpperCase(),
          birthDate: _birth!,
          weightKg: weight,
          type: _type,
          breed: _breed!,
        );
      }
      if (!mounted) return;
      showMsg(context, context.t(_editing ? 'cow_updated' : 'cow_created'));
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
    final breeds = _breeds;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t(_editing ? 'edit_cow' : 'add_cow'),
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(context.t('cow_id'), style: TextStyle(color: p.texte2, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _cowId,
            enabled: !_editing,
            textCapitalization: TextCapitalization.characters,
            decoration: decorationChamp(p, indice: 'COW001'),
          ),
          const SizedBox(height: 16),
          Text(context.t('rfid_tag'), style: TextStyle(color: p.texte2, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _tag,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z:]'))],
            decoration: decorationChamp(
              p,
              indice: context.t('rfid_tag_hint'),
              debut: Padding(
                padding: const EdgeInsets.all(14),
                child: Ico('rfid_tag', taille: 22, couleur: p.texte2),
              ),
              fin: TextButton(onPressed: _scan, child: Text(context.t('scan'))),
            ),
          ),
          const SizedBox(height: 16),
          Text(context.t('type'), style: TextStyle(color: p.texte2, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<CowType>(
              showSelectedIcon: false,
              segments: [
                for (final t in CowType.values)
                  ButtonSegment(value: t, label: Text(cowTypeLabel(context, t))),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                _breed = null;
              }),
            ),
          ),
          const SizedBox(height: 16),
          Text(context.t('breed'), style: TextStyle(color: p.texte2, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            key: ValueKey<CowType>(_type),
            initialValue: breeds.contains(_breed) ? _breed : null,
            items: [for (final b in breeds) DropdownMenuItem(value: b, child: Text(b))],
            onChanged: (v) => setState(() => _breed = v),
            decoration: decorationChamp(p, indice: context.t('choose_breed')),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.t('birth_date'),
                    style: TextStyle(color: p.texte2, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: _pickBirth,
                  icon: Ico('calendar', taille: 20, couleur: p.primaire),
                  label: Text(_birth == null ? context.t('choose') : dateOnly(_birth!)),
                ),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.t('weight_kg'),
                    style: TextStyle(color: p.texte2, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: _weight,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: decorationChamp(
                    p,
                    indice: '600',
                    debut: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Ico('weight', taille: 20, couleur: p.texte2),
                    ),
                  ),
                ),
              ]),
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
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.6, color: p.surPrimaire),
                  )
                : Text(context.t('save')),
          ),
        ],
      ),
    );
  }
}

class _ScanDialog extends StatelessWidget {
  const _ScanDialog({required this.onCancel});
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return AlertDialog(
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(shape: BoxShape.circle, color: p.primaireClair),
          child: Center(child: Ico('rfid_tag', taille: 48, couleur: p.primaire)),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(begin: const Offset(0.92, 0.92), end: const Offset(1.08, 1.08), duration: 900.ms),
        const SizedBox(height: 18),
        Text(context.t('scan_title'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(context.t('scan_hint'),
            textAlign: TextAlign.center, style: TextStyle(color: p.texte2, height: 1.35)),
      ]),
      actionsAlignment: MainAxisAlignment.center,
      actions: [TextButton(onPressed: onCancel, child: Text(context.t('cancel')))],
    );
  }
}
