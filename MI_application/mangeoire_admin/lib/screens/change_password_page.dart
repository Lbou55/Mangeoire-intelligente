import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../services/api.dart';
import '../widgets/carte.dart';
import '../widgets/common.dart';
import '../widgets/ico.dart';
import 'login_page.dart';

/// Change password. [forced] = first login with the temporary password
/// (cannot be skipped, only logout).
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key, this.forced = false});
  final bool forced;

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _hidden = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_current.text.isEmpty || _new.text.isEmpty || _confirm.text.isEmpty) {
      setState(() => _error = context.t('fill_all'));
      return;
    }
    if (_new.text.length < 8) {
      setState(() => _error = context.t('err_weak_password'));
      return;
    }
    if (_new.text != _confirm.text) {
      setState(() => _error = context.t('err_password_mismatch'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await AuthApi.instance.changePassword(_current.text, _new.text);
      if (!mounted) return;
      showMsg(context, context.t('password_changed'));
      if (widget.forced) {
        resetTo(homeFor(user));
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errorText(context, e);
      });
    }
  }

  Widget _field(Palette p, TextEditingController c, String label, {bool last = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: c,
        obscureText: _hidden,
        textInputAction: last ? TextInputAction.done : TextInputAction.next,
        onSubmitted: last ? (_) => _submit() : null,
        decoration: decorationChamp(
          p,
          indice: label,
          debut: Padding(
            padding: const EdgeInsets.all(14),
            child: Ico('password_lock', taille: 22, couleur: p.texte2),
          ),
          fin: IconButton(
            onPressed: () => setState(() => _hidden = !_hidden),
            icon: Ico(_hidden ? 'eye_show' : 'eye_hide', taille: 22, couleur: p.texte2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return PopScope(
      canPop: !widget.forced,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.forced,
          title: Text(context.t('change_password'),
              style: const TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            if (widget.forced)
              TextButton(
                onPressed: () async {
                  await AuthApi.instance.logout();
                  resetTo(const LoginPage());
                },
                child: Text(context.t('logout')),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (widget.forced)
              CarteDouce(
                child: Row(children: [
                  Ico('status_alert', taille: 28, couleur: p.alerte),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(context.t('must_change_password'),
                        style: TextStyle(color: p.texte2, height: 1.35)),
                  ),
                ]),
              ),
            const SizedBox(height: 18),
            _field(p, _current, context.t(widget.forced ? 'temp_password' : 'current_password')),
            _field(p, _new, context.t('new_password')),
            _field(p, _confirm, context.t('confirm_password'), last: true),
            Text(context.t('password_hint'), style: TextStyle(color: p.texte2, fontSize: 13)),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: p.dangerClair,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_error!,
                    style: TextStyle(color: p.danger, fontWeight: FontWeight.w600)),
              ),
            ],
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: _busy ? null : _submit,
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
      ),
    );
  }
}
