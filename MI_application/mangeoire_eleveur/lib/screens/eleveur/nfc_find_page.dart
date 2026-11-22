import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/l10n.dart';
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../native/canaux.dart';
import '../../services/api.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';
import '../../widgets/ico.dart';
import 'cow_detail_page.dart';

/// M1 - NFC: hold the phone against a cow's tag to open her file.
/// (Adding or changing a cow stays reserved to the admin.)
class NfcFindPage extends StatefulWidget {
  const NfcFindPage({super.key});

  @override
  State<NfcFindPage> createState() => _NfcFindPageState();
}

class _NfcFindPageState extends State<NfcFindPage> {
  bool _waiting = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  @override
  void dispose() {
    CanauxNatifs.annulerNfc().catchError((_) {});
    super.dispose();
  }

  Future<void> _scan() async {
    if (_waiting) return;
    setState(() {
      _waiting = true;
      _message = null;
    });
    try {
      final uid = await CanauxNatifs.lireUidNfc();
      if (uid == null || !mounted) return;
      final Cow cow = await FarmApi.instance.cowByNfc(uid);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => CowDetailPage(cow: cow)),
      );
      return;
    } on PlatformException catch (e) {
      if (!mounted) return;
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
          _message = context.t('err_nfc_absent');
        case 'DELAI_DEPASSE':
          _message = context.t('err_nfc_timeout');
        default:
          _message = context.t('err_nfc_generic');
      }
    } on MissingPluginException {
      if (mounted) _message = context.t('err_nfc_absent');
    } on ApiException catch (e) {
      if (!mounted) return;
      _message = e.statusCode == 404 ? context.t('nfc_cow_not_found') : errorText(context, e);
    }
    if (mounted) setState(() => _waiting = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('find_by_tag'), style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(shape: BoxShape.circle, color: p.primaireClair),
              child: Center(child: Ico('rfid_tag', taille: 76, couleur: p.primaire)),
            ).animate(target: _waiting ? 1 : 0).scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.08, 1.08),
                  duration: 700.ms,
                ),
            const SizedBox(height: 26),
            Text(context.t('scan_title'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(context.t('scan_hint'),
                textAlign: TextAlign.center, style: TextStyle(color: p.texte2, height: 1.4)),
            if (_message != null) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration:
                    BoxDecoration(color: p.dangerClair, borderRadius: BorderRadius.circular(12)),
                child: Text(_message!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: p.danger, fontWeight: FontWeight.w600)),
              ),
            ],
            const SizedBox(height: 26),
            ElevatedButton(
              onPressed: _waiting ? null : _scan,
              child: _waiting
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.6, color: p.surPrimaire))
                  : Text(context.t('retry')),
            ),
          ]),
        ),
      ),
    );
  }
}
