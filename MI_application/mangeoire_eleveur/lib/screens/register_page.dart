import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/l10n.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../native/canaux.dart';
import '../services/api.dart';
import '../widgets/bouton_theme.dart';
import '../widgets/carte.dart';
import '../widgets/common.dart';
import '../widgets/ico.dart';

/// First screen: the eleveur joins the farm with the invitation of his admin
/// (QR code or typed code) and his name. No password.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, this.sessionEnded = false});
  final bool sessionEnded;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() => _error = null);
    try {
      final text = await CanauxNatifs.scannerQr();
      if (text == null || !mounted) return;
      setState(() => _code.text = extractInviteCode(text));
    } on PlatformException {
      if (mounted) setState(() => _error = context.t('err_qr_failed'));
    } on MissingPluginException {
      if (mounted) setState(() => _error = context.t('err_qr_failed'));
    }
  }

  Future<void> _join() async {
    final code = extractInviteCode(_code.text);
    final name = _name.text.trim();
    if (code.isEmpty) {
      setState(() => _error = context.t('fill_all'));
      return;
    }
    if (name.length < 2) {
      setState(() => _error = context.t('err_name_required'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await AuthApi.instance.register(code, name);
      if (!mounted) return;
      resetTo(homeFor(user));
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
    return ThemeSwitchingArea(
      child: Builder(
        builder: (context) => Scaffold(
          body: SafeArea(
            child: Column(children: [
              const Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  LangIconButton(),
                  BoutonTheme(),
                  SizedBox(width: 8),
                ]),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(children: [
                    Hero(
                      tag: 'logo',
                      child: Image.asset('assets/branding/mangeoire_logo_blue.png', width: 130),
                    ),
                    const SizedBox(height: 8),
                    Text(context.t('reg_title'),
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(context.t('reg_subtitle'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: p.texte2, fontSize: 15)),
                    const SizedBox(height: 22),
                    if (widget.sessionEnded)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Pill(context.t('session_ended'),
                            color: p.alerte, background: p.alerteClair, icon: 'status_alert'),
                      ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _scan,
                      icon: Ico('qr_code', taille: 24, couleur: p.primaire),
                      label: Text(context.t('scan_qr')),
                    ).stagger(0),
                    const SizedBox(height: 14),
                    Text(context.t('or_code'), style: TextStyle(color: p.texte2)),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _code,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.next,
                      decoration: decorationChamp(
                        p,
                        indice: context.t('invite_code'),
                        debut: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Ico('rfid_tag', taille: 22, couleur: p.texte2),
                        ),
                      ),
                    ).stagger(1),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      onSubmitted: (_) => _join(),
                      decoration: decorationChamp(
                        p,
                        indice: context.t('your_name'),
                        debut: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Ico('nav_profile', taille: 22, couleur: p.texte2),
                        ),
                      ),
                    ).stagger(2),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: p.dangerClair,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(_error!,
                            style: TextStyle(color: p.danger, fontWeight: FontWeight.w600)),
                      ).animate().shakeX(hz: 4, amount: 6, duration: 400.ms),
                    ],
                    const SizedBox(height: 22),
                    ElevatedButton(
                      onPressed: _busy ? null : _join,
                      child: _busy
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.6, color: p.surPrimaire),
                            )
                          : Text(context.t('join')),
                    ).stagger(3),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
