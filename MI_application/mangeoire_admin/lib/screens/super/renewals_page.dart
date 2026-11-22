import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/api.dart';
import '../../widgets/carte.dart';
import '../../widgets/common.dart';

/// Renewal requests sent by admins from their profile page.
class RenewalsPage extends StatefulWidget {
  const RenewalsPage({super.key});

  @override
  State<RenewalsPage> createState() => _RenewalsPageState();
}

class _RenewalsPageState extends State<RenewalsPage> {
  final _key = GlobalKey<AsyncBodyState<List<RenewalRequest>>>();
  String? _busyId;

  Future<void> _act(RenewalRequest r, bool approve) async {
    setState(() => _busyId = r.id);
    try {
      if (approve) {
        await SuperAdminApi.instance.approve(r.id);
      } else {
        await SuperAdminApi.instance.reject(r.id);
      }
      if (mounted) showMsg(context, context.t(approve ? 'renewal_approved' : 'renewal_rejected'));
      await _key.currentState?.reload();
    } catch (e) {
      if (mounted) showMsg(context, errorText(context, e));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return AsyncBody<List<RenewalRequest>>(
      key: _key,
      load: () => SuperAdminApi.instance.renewals(),
      builder: (context, items) {
        if (items.isEmpty) return EmptyView(icon: 'calendar', text: context.t('no_renewals'));
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final r = items[i];
            final pending = r.status == 'pending';
            final approved = r.status == 'approved';
            return CarteDouce(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  AvatarIco(icon: 'calendar', size: 46, warning: pending),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.adminName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      Text(r.adminEmail, style: TextStyle(color: p.texte2, fontSize: 13)),
                      Text(formatDateTime(r.createdAt),
                          style: TextStyle(color: p.texte2, fontSize: 12.5)),
                    ]),
                  ),
                  pending
                      ? Pill(context.t('status_pending'), color: p.alerte, background: p.alerteClair)
                      : approved
                          ? Pill(context.t('renewal_status_approved'),
                              color: p.succes, background: p.succesClair)
                          : Pill(context.t('renewal_status_rejected'),
                              color: p.danger, background: p.dangerClair),
                ]),
                if (pending) ...[
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busyId == r.id ? null : () => _act(r, false),
                        child: Text(context.t('reject')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                        onPressed: _busyId == r.id ? null : () => _act(r, true),
                        child: Text(context.t('approve')),
                      ),
                    ),
                  ]),
                ],
              ]),
            ).stagger(i);
          },
        );
      },
    );
  }
}
