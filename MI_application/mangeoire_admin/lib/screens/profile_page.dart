import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../services/session.dart';
import '../widgets/bouton_theme.dart';
import '../widgets/carte.dart';
import '../widgets/common.dart';
import '../widgets/ico.dart';
import 'change_password_page.dart';
import 'login_page.dart';

/// Profile for admin and superadmin: account, subscription (admin), language, logout.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _logout(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: context.t('logout'),
      message: context.t('logout_confirm'),
      confirmLabel: context.t('logout'),
      danger: true,
    );
    if (!ok) return;
    await AuthApi.instance.logout();
    resetTo(const LoginPage());
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ValueListenableBuilder<AppUser?>(
      valueListenable: Session.instance.currentUser,
      builder: (context, user, _) {
        if (user == null) return const LoadingView();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            CarteDouce(
              child: Row(children: [
                const AvatarIco(icon: 'nav_profile', size: 68),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user.name,
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                    if (user.email != null)
                      Text(user.email!, style: TextStyle(color: p.texte2, fontSize: 14)),
                    if (user.phone != null)
                      Text(user.phone!, style: TextStyle(color: p.texte2, fontSize: 13.5)),
                    const SizedBox(height: 8),
                    Pill(context.t(user.isSuperAdmin ? 'role_superadmin' : 'role_admin'),
                        color: p.primaire, background: p.primaireClair),
                  ]),
                ),
              ]),
            ).stagger(0),
            if (!user.isSuperAdmin) ...[
              SectionTitle(context.t('subscription')),
              const _SubscriptionCard().stagger(1),
            ],
            SectionTitle(context.t('settings')),
            CarteDouce(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Ico('language', taille: 22, couleur: p.primaire),
                  const SizedBox(width: 10),
                  Text(context.t('language'),
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 12),
                const LangSwitch(),
                const SizedBox(height: 14),
                Divider(color: p.bordure),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(children: [
                      Ico('password_lock', taille: 22, couleur: p.primaire),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(context.t('change_password'),
                            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                      ),
                      Icon(Icons.chevron_right, color: p.texte2),
                    ]),
                  ),
                ),
              ]),
            ).stagger(2),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: p.danger,
                side: BorderSide(color: p.danger.withValues(alpha: 0.5)),
              ),
              onPressed: () => _logout(context),
              icon: Ico('sign_out', taille: 22, couleur: p.danger),
              label: Text(context.t('logout')),
            ).stagger(3),
          ],
        );
      },
    );
  }
}

class _SubscriptionCard extends StatefulWidget {
  const _SubscriptionCard();

  @override
  State<_SubscriptionCard> createState() => _SubscriptionCardState();
}

class _SubscriptionCardState extends State<_SubscriptionCard> {
  SubscriptionInfo? _info;
  Object? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await SubscriptionApi.instance.mine();
      if (mounted) setState(() => _info = info);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _request() async {
    setState(() => _busy = true);
    try {
      await SubscriptionApi.instance.requestRenewal();
      if (mounted) showMsg(context, context.t('renewal_sent'));
      await _load();
    } catch (e) {
      if (mounted) showMsg(context, errorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final info = _info;
    if (info == null) {
      return CarteDouce(
        child: _error != null
            ? Row(children: [
                Expanded(child: Text(errorText(context, _error!))),
                TextButton(onPressed: _load, child: Text(context.t('retry'))),
              ])
            : const Center(
                child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())),
      );
    }

    final active = info.active;
    final progress = (info.daysLeft / 30).clamp(0.0, 1.0);
    return CarteDouce(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Ico('calendar', taille: 26, couleur: active ? p.primaire : p.alerte),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.t(active ? 'sub_active' : 'sub_expired'),
              style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
            ),
          ),
          Pill(
            context.t(active ? 'status_accepted' : 'sub_expired_short'),
            color: active ? p.succes : p.alerte,
            background: active ? p.succesClair : p.alerteClair,
          ),
        ]),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${info.daysLeft}',
              style: TextStyle(
                  fontSize: 40, fontWeight: FontWeight.w800, color: active ? p.primaire : p.alerte)),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(context.t('days_left'), style: TextStyle(color: p.texte2)),
          ),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            color: active ? p.primaire : p.alerte,
            backgroundColor: p.primaireClair,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          context.t('expires_on', {'date': formatDate(context, info.expiresAt)}),
          style: TextStyle(color: p.texte2, fontSize: 13.5),
        ),
        const SizedBox(height: 14),
        if (info.pendingRequest)
          Pill(context.t('renewal_pending'),
              color: p.alerte, background: p.alerteClair, icon: 'status_alert')
        else
          ElevatedButton(
            onPressed: _busy ? null : _request,
            child: _busy
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.6, color: p.surPrimaire),
                  )
                : Text(context.t('request_renewal')),
          ),
      ]),
    );
  }
}
