import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/l10n.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../native/canaux.dart';
import '../services/api.dart';
import '../services/live_service.dart';
import '../services/securite.dart';
import '../services/session.dart';
import '../widgets/bouton_theme.dart';
import '../widgets/carte.dart';
import '../widgets/common.dart';
import '../widgets/ico.dart';
import 'register_page.dart';

/// Profile of the eleveur: account, language, fingerprint lock,
/// background alerts (thresholds, notifications) and logout.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _lock = true;
  bool _bioAvailable = false;
  bool _notifOk = false;
  double _threshold = 50;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final lock = await Securite.activeeParUtilisateur();
    final bio = await CanauxNatifs.empreinteDisponible();
    var notif = false;
    var seuil = 50;
    try {
      notif = await CanauxNatifs.notificationsAutorisees();
      seuil = await CanauxNatifs.lireSeuil();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _lock = lock;
      _bioAvailable = bio;
      _notifOk = notif;
      _threshold = seuil.toDouble();
    });
  }

  Future<void> _toggleLock(bool value) async {
    if (value && !_bioAvailable) {
      showMsg(context, context.t('bio_unavailable'));
      return;
    }
    setState(() => _lock = value);
    await Securite.definir(value);
  }

  Future<void> _askNotifications() async {
    bool ok = false;
    try {
      ok = await CanauxNatifs.demanderPermissionNotifications();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _notifOk = ok);
    showMsg(context, context.t(ok ? 'notif_granted' : 'notif_denied'));
  }

  Future<void> _saveThreshold(double v) async {
    try {
      await CanauxNatifs.definirSeuil(v.round());
    } catch (_) {}
  }

  Future<void> _testNow() async {
    setState(() => _testing = true);
    try {
      await CanauxNatifs.verifierMaintenant();
      if (mounted) showMsg(context, context.t('bg_test_started'));
    } catch (e) {
      if (mounted) showMsg(context, context.t('err_generic'));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _logout() async {
    final ok = await confirmDialog(
      context,
      title: context.t('logout'),
      message: context.t('logout_confirm'),
      confirmLabel: context.t('logout'),
      danger: true,
    );
    if (!ok) return;
    LiveService.instance.stop();
    try {
      await CanauxNatifs.annulerPlanification();
    } catch (_) {}
    await AuthApi.instance.logout();
    resetTo(const RegisterPage());
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ValueListenableBuilder<AppUser?>(
      valueListenable: Session.instance.currentUser,
      builder: (context, user, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            CarteDouce(
              child: Row(children: [
                const AvatarIco(icon: 'nav_profile', size: 68),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user?.name ?? '',
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Pill(context.t('role_eleveur'),
                        color: p.primaire, background: p.primaireClair),
                  ]),
                ),
              ]),
            ).stagger(0),
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
                const SizedBox(height: 10),
                Divider(color: p.bordure),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _lock && _bioAvailable,
                  onChanged: _toggleLock,
                  title: Text(context.t('bio_enable'),
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    _bioAvailable ? context.t('bio_enable_hint') : context.t('bio_unavailable'),
                    style: TextStyle(color: p.texte2, fontSize: 13),
                  ),
                  secondary: Icon(Icons.fingerprint, color: p.primaire, size: 28),
                ),
              ]),
            ).stagger(1),
            SectionTitle(context.t('bg_title')),
            CarteDouce(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.t('bg_hint'), style: TextStyle(color: p.texte2, height: 1.35)),
                const SizedBox(height: 14),
                Text(context.t('threshold_title'),
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                Slider(
                  value: _threshold,
                  min: 10,
                  max: 90,
                  divisions: 16,
                  label: '${_threshold.round()} %',
                  onChanged: (v) => setState(() => _threshold = v),
                  onChangeEnd: _saveThreshold,
                ),
                Text(context.t('threshold_value', {'pct': '${_threshold.round()}'}),
                    style: TextStyle(color: p.texte2, fontSize: 13)),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _notifOk ? null : _askNotifications,
                      child: Text(context.t(_notifOk ? 'notif_granted' : 'notif_permission'),
                          textAlign: TextAlign.center),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _testing ? null : _testNow,
                      child: Text(context.t('bg_test'), textAlign: TextAlign.center),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                Text(context.t('widget_hint'),
                    style: TextStyle(color: p.texte2, fontSize: 12.5, height: 1.35)),
              ]),
            ).stagger(2),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: p.danger,
                side: BorderSide(color: p.danger.withValues(alpha: 0.5)),
              ),
              onPressed: _logout,
              icon: Ico('sign_out', taille: 22, couleur: p.danger),
              label: Text(context.t('logout')),
            ).stagger(3),
          ],
        );
      },
    );
  }
}
