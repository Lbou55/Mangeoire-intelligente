import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api.dart';
import '../../widgets/carte.dart';
import '../../widgets/common.dart';
import '../../widgets/ico.dart';

String generatePassword([int length = 10]) {
  const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789';
  final r = Random.secure();
  return List.generate(length, (_) => chars[r.nextInt(chars.length)]).join();
}

Future<void> showAdminCreatedDialog(
  BuildContext context, {
  required String email,
  required String password,
  required bool emailSent,
  String? acceptUrl,
}) {
  final p = Palette.of(context);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.t(emailSent ? 'admin_email_sent_title' : 'admin_email_not_sent_title'),
          style: const TextStyle(fontWeight: FontWeight.w800)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ctx.t(emailSent ? 'admin_email_sent_body' : 'admin_email_not_sent_body',
                {'email': email})),
            if (!emailSent) ...[
              const SizedBox(height: 14),
              Text(ctx.t('temp_password'), style: TextStyle(color: p.texte2, fontSize: 13)),
              SelectableText(password, style: const TextStyle(fontWeight: FontWeight.w800)),
              if (acceptUrl != null) ...[
                const SizedBox(height: 10),
                Text(ctx.t('accept_link'), style: TextStyle(color: p.texte2, fontSize: 13)),
                SelectableText(acceptUrl, style: TextStyle(color: p.primaire, fontSize: 13)),
              ],
            ],
          ],
        ),
      ),
      actions: [
        if (!emailSent && acceptUrl != null)
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(
                  text: '$email\n$password\n$acceptUrl'));
              showMsg(ctx, ctx.t('copied'));
            },
            child: Text(ctx.t('copy')),
          ),
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.t('ok'))),
      ],
    ),
  );
}

class AdminsPage extends StatefulWidget {
  const AdminsPage({super.key});

  @override
  State<AdminsPage> createState() => _AdminsPageState();
}

class _AdminsPageState extends State<AdminsPage> {
  final _key = GlobalKey<AsyncBodyState<List<AdminAccount>>>();
  String _filter = 'all'; // all | active | pending

  Future<void> _add() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddAdminPage()),
    );
    if (created == true) _key.currentState?.reload();
  }

  Future<void> _resend(AdminAccount a) async {
    final controller = TextEditingController(text: generatePassword());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('resend_invitation'), style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(ctx.t('resend_hint')),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            decoration: decorationChamp(Palette.of(ctx), indice: ctx.t('temp_password')),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.t('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.t('send'))),
        ],
      ),
    );
    final password = controller.text.trim();
    controller.dispose();
    if (ok != true || !mounted) return;
    try {
      final r = await SuperAdminApi.instance.resend(a.id, password);
      if (!mounted) return;
      await showAdminCreatedDialog(context,
          email: a.email, password: password, emailSent: r.emailSent, acceptUrl: r.acceptUrl);
    } catch (e) {
      if (mounted) showMsg(context, errorText(context, e));
    }
  }

  Future<void> _cancel(AdminAccount a) async {
    final ok = await confirmDialog(
      context,
      title: context.t('cancel_invitation'),
      message: context.t('cancel_invitation_msg', {'name': a.name}),
      confirmLabel: context.t('delete'),
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      await SuperAdminApi.instance.deletePending(a.id);
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
        onPressed: _add,
        icon: Ico('add', taille: 22, couleur: p.surPrimaire),
        label: Text(context.t('add_admin'), style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: AsyncBody<List<AdminAccount>>(
        key: _key,
        load: () => SuperAdminApi.instance.admins(),
        builder: (context, admins) {
          final accepted = admins.where((a) => a.accepted).length;
          final pending = admins.where((a) => a.status == 'pending').length;
          final shown = admins.where((a) {
            if (_filter == 'active') return a.accepted;
            if (_filter == 'pending') return a.status == 'pending';
            return true;
          }).toList();

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            children: [
              _SummaryBanner(accepted: accepted, pending: pending).stagger(0),
              const SizedBox(height: 14),
              Wrap(spacing: 8, children: [
                for (final f in const ['all', 'active', 'pending'])
                  ChoiceChip(
                    label: Text(context.t('filter_$f')),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
              ]),
              const SizedBox(height: 12),
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Column(children: [
                    AvatarIco(icon: 'nav_users', size: 84),
                    const SizedBox(height: 14),
                    Text(context.t('no_admins'), style: TextStyle(color: p.texte2)),
                  ]),
                ),
              for (var i = 0; i < shown.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AdminCard(
                    admin: shown[i],
                    onResend: () => _resend(shown[i]),
                    onCancel: () => _cancel(shown[i]),
                  ).stagger(i + 1),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({required this.accepted, required this.pending});
  final int accepted;
  final int pending;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    Widget stat(String value, String label) => Expanded(
          child: Column(children: [
            Text(value,
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(colors: [p.bandeau1, p.bandeau2]),
        boxShadow: [BoxShadow(color: p.ombre, blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Row(children: [
        stat('$accepted', context.t('admins_accepted')),
        Container(width: 1, height: 44, color: Colors.white24),
        stat('$pending', context.t('admins_pending')),
      ]),
    );
  }
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({required this.admin, required this.onResend, required this.onCancel});
  final AdminAccount admin;
  final VoidCallback onResend;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final accepted = admin.accepted;
    return CarteDouce(
      child: Row(children: [
        AvatarIco(icon: 'nav_profile', warning: !accepted),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(admin.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(admin.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: p.texte2, fontSize: 13.5)),
            if (admin.phone != null)
              Text(admin.phone!, style: TextStyle(color: p.texte2, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: [
              accepted
                  ? Pill(context.t('status_accepted'),
                      color: p.succes, background: p.succesClair, icon: 'status_resolved')
                  : Pill(context.t('status_pending'),
                      color: p.alerte, background: p.alerteClair, icon: 'status_alert'),
              if (accepted && admin.subscriptionExpiresAt != null)
                Pill(context.t('until', {'date': formatDate(context, admin.subscriptionExpiresAt)}),
                    color: p.primaire, background: p.primaireClair, icon: 'calendar'),
            ]),
          ]),
        ),
        if (!accepted)
          PopupMenuButton<String>(
            onSelected: (v) => v == 'resend' ? onResend() : onCancel(),
            itemBuilder: (ctx) => [
              PopupMenuItem(value: 'resend', child: Text(ctx.t('resend_invitation'))),
              PopupMenuItem(value: 'cancel', child: Text(ctx.t('cancel_invitation'))),
            ],
          ),
      ]),
    );
  }
}

// ------------------------------------------------------------- add admin

class AddAdminPage extends StatefulWidget {
  const AddAdminPage({super.key});

  @override
  State<AddAdminPage> createState() => _AddAdminPageState();
}

class _AddAdminPageState extends State<AddAdminPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController(text: generatePassword());
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text.trim();
    if (name.length < 2 || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = context.t('err_invalid_admin_form'));
      return;
    }
    if (password.length < 8) {
      setState(() => _error = context.t('err_weak_password'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await SuperAdminApi.instance.createAdmin(
        name: name,
        email: email,
        password: password,
        phone: _phone.text.trim(),
      );
      if (!mounted) return;
      await showAdminCreatedDialog(context,
          email: email, password: password, emailSent: r.emailSent, acceptUrl: r.acceptUrl);
      if (mounted) Navigator.pop(context, true);
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
    Widget field(TextEditingController c, String hint, String icon,
            {TextInputType? type, Widget? trailing}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextField(
            controller: c,
            keyboardType: type,
            decoration: decorationChamp(
              p,
              indice: hint,
              debut: Padding(
                padding: const EdgeInsets.all(14),
                child: Ico(icon, taille: 22, couleur: p.texte2),
              ),
              fin: trailing,
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('add_admin'), style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(context.t('add_admin_hint'), style: TextStyle(color: p.texte2, height: 1.4)),
          const SizedBox(height: 18),
          field(_name, context.t('full_name'), 'nav_profile'),
          field(_email, context.t('email'), 'email', type: TextInputType.emailAddress),
          field(_phone, context.t('phone_optional'), 'phone', type: TextInputType.phone),
          field(
            _password,
            context.t('temp_password'),
            'password_lock',
            trailing: IconButton(
              tooltip: context.t('generate'),
              onPressed: () => setState(() => _password.text = generatePassword()),
              icon: Ico('refresh', taille: 22, couleur: p.primaire),
            ),
          ),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: p.dangerClair, borderRadius: BorderRadius.circular(12)),
              child: Text(_error!, style: TextStyle(color: p.danger, fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: p.surPrimaire),
                  )
                : Ico('send', taille: 20, couleur: p.surPrimaire),
            label: Text(context.t('create_and_send')),
          ),
        ],
      ),
    );
  }
}
