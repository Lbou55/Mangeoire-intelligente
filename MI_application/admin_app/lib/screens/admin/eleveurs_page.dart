import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api.dart';
import '../../widgets/carte.dart';
import '../../widgets/common.dart';
import '../../widgets/ico.dart';

/// Eleveurs (farmers) of this farm + invitations (QR / code, valid 24 h).
class EleveursPage extends StatefulWidget {
  const EleveursPage({super.key});

  @override
  State<EleveursPage> createState() => _EleveursPageState();
}

class _EleveursPageState extends State<EleveursPage> {
  final _eleveursKey = GlobalKey<AsyncBodyState<List<Eleveur>>>();
  final _invitesKey = GlobalKey<AsyncBodyState<List<Invite>>>();
  bool _creating = false;

  Future<void> _newInvite() async {
    setState(() => _creating = true);
    try {
      final invite = await FarmApi.instance.createInvite();
      if (!mounted) return;
      _invitesKey.currentState?.reload();
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _InviteSheet(invite: invite),
      );
      _invitesKey.currentState?.reload();
    } catch (e) {
      if (mounted) showMsg(context, errorText(context, e));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _deleteEleveur(Eleveur e) async {
    final ok = await confirmDialog(
      context,
      title: context.t('remove_eleveur'),
      message: context.t('remove_eleveur_msg', {'name': e.name}),
      confirmLabel: context.t('delete'),
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      await FarmApi.instance.deleteEleveur(e.id);
      _eleveursKey.currentState?.reload();
    } catch (err) {
      if (mounted) showMsg(context, errorText(context, err));
    }
  }

  Future<void> _deleteInvite(Invite i) async {
    try {
      await FarmApi.instance.deleteInvite(i.id);
      _invitesKey.currentState?.reload();
    } catch (err) {
      if (mounted) showMsg(context, errorText(context, err));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Container(
            decoration: BoxDecoration(color: p.primaireClair, borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.all(4),
            child: TabBar(
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(color: p.primaire, borderRadius: BorderRadius.circular(12)),
              labelColor: p.surPrimaire,
              unselectedLabelColor: p.texte2,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700),
              tabs: [
                Tab(text: context.t('tab_eleveurs'), height: 42),
                Tab(text: context.t('invitations'), height: 42),
              ],
            ),
          ),
        ),
        Expanded(
          child: TabBarView(children: [
            AsyncBody<List<Eleveur>>(
              key: _eleveursKey,
              load: FarmApi.instance.eleveurs,
              builder: (context, list) {
                if (list.isEmpty) {
                  return EmptyView(icon: 'nav_users', text: context.t('no_eleveurs'));
                }
                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => CarteDouce(
                    child: Row(children: [
                      const AvatarIco(icon: 'nav_profile', size: 48),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(list[i].name,
                              style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
                          Text(
                            context.t('joined_on', {'date': formatDate(context, list[i].createdAt)}),
                            style: TextStyle(color: p.texte2, fontSize: 13),
                          ),
                        ]),
                      ),
                      IconButton(
                        tooltip: context.t('delete'),
                        onPressed: () => _deleteEleveur(list[i]),
                        icon: Ico('delete', couleur: p.danger),
                      ),
                    ]),
                  ).stagger(i),
                );
              },
            ),
            Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: ElevatedButton.icon(
                  onPressed: _creating ? null : _newInvite,
                  icon: Ico('qr_code', taille: 22, couleur: p.surPrimaire),
                  label: Text(context.t('new_invitation')),
                ),
              ),
              Expanded(
                child: AsyncBody<List<Invite>>(
                  key: _invitesKey,
                  load: FarmApi.instance.invites,
                  builder: (context, list) {
                    if (list.isEmpty) {
                      return EmptyView(icon: 'qr_code', text: context.t('no_invitations'));
                    }
                    return ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final inv = list[i];
                        final (fg, bg) = switch (inv.status) {
                          'active' => (p.primaire, p.primaireClair),
                          'used' => (p.succes, p.succesClair),
                          _ => (p.texte2, p.bordure),
                        };
                        return CarteDouce(
                          child: Row(children: [
                            AvatarIco(icon: 'qr_code', size: 46, warning: inv.status == 'expired'),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(formatDateTime(inv.createdAt),
                                      style: const TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Wrap(spacing: 8, runSpacing: 4, children: [
                                    Pill(context.t('invite_${inv.status}'), color: fg, background: bg),
                                    if (inv.usedByName != null)
                                      Text(inv.usedByName!, style: TextStyle(color: p.texte2)),
                                  ]),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => _deleteInvite(inv),
                              icon: Ico('delete', couleur: p.danger),
                            ),
                          ]),
                        ).stagger(i);
                      },
                    );
                  },
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _InviteSheet extends StatelessWidget {
  const _InviteSheet({required this.invite});
  final NewInvite invite;

  String get _spaced {
    final c = invite.code;
    return c.length == 8 ? '${c.substring(0, 4)} ${c.substring(4)}' : c;
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(color: p.bordure, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(height: 18),
          Text(context.t('invitation_ready'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(context.t('invitation_hint'),
              textAlign: TextAlign.center, style: TextStyle(color: p.texte2, height: 1.35)),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: QrImageView(data: invite.qrPayload, size: 210, backgroundColor: Colors.white),
          ),
          const SizedBox(height: 16),
          SelectableText(_spaced,
              style: TextStyle(
                  fontSize: 30, letterSpacing: 4, fontWeight: FontWeight.w800, color: p.primaire)),
          const SizedBox(height: 6),
          Text(context.t('expires_at', {'date': formatDateTime(invite.expiresAt)}),
              style: TextStyle(color: p.texte2, fontSize: 13.5)),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: invite.code));
                  showMsg(context, context.t('copied'));
                },
                icon: Ico('copy', taille: 20, couleur: p.primaire),
                label: Text(context.t('copy_code')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.t('done')),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
