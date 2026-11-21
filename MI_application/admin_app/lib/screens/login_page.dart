import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/l10n.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../services/api.dart';
import '../widgets/bouton_theme.dart';
import '../widgets/carte.dart';
import '../widgets/common.dart';
import '../widgets/ico.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.sessionEnded = false});
  final bool sessionEnded;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidden = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = context.t('fill_all'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await AuthApi.instance.login(email, password);
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
            child: Column(
              children: [
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
                    child: Column(
                      children: [
                        Hero(
                          tag: 'logo',
                          child: Image.asset('assets/branding/mangeoire_logo_blue.png', width: 130),
                        ),
                        const SizedBox(height: 8),
                        Text(context.t('login_title'),
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Text(context.t('login_subtitle'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: p.texte2, fontSize: 15)),
                        const SizedBox(height: 26),
                        if (widget.sessionEnded)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Pill(context.t('session_ended'),
                                color: p.alerte, background: p.alerteClair, icon: 'status_alert'),
                          ),
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          decoration: decorationChamp(
                            p,
                            indice: context.t('email'),
                            debut: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Ico('email', taille: 22, couleur: p.texte2),
                            ),
                          ),
                        ).stagger(0),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _password,
                          obscureText: _hidden,
                          autofillHints: const [AutofillHints.password],
                          onSubmitted: (_) => _submit(),
                          decoration: decorationChamp(
                            p,
                            indice: context.t('password'),
                            debut: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Ico('password_lock', taille: 22, couleur: p.texte2),
                            ),
                            fin: IconButton(
                              onPressed: () => setState(() => _hidden = !_hidden),
                              icon: Ico(_hidden ? 'eye_show' : 'eye_hide',
                                  taille: 22, couleur: p.texte2),
                            ),
                          ),
                        ).stagger(1),
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
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.6, color: p.surPrimaire),
                                )
                              : Text(context.t('login')),
                        ).stagger(2),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
