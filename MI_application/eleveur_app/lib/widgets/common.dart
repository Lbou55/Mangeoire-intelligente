import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../services/api.dart' show dateOnly;
import '../services/api_client.dart';
import 'carte.dart';
import 'ico.dart';

export '../services/api.dart' show dateOnly;

/// Human text for any error, in the current language.
String errorText(BuildContext context, Object e) {
  if (e is ApiException) {
    if (e.statusCode == null) {
      return context.t(e.code == 'timeout' ? 'err_timeout' : 'err_network');
    }
    final key = 'err_${e.code}';
    final translated = context.t(key);
    if (translated != key) return translated;
    return context.t('err_generic');
  }
  return context.t('err_generic');
}

void showMsg(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = false,
}) async {
  final p = Palette.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.t('cancel'))),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: danger ? p.danger : p.primaire),
          child: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  );
  return ok == true;
}

// ----------------------------------------------------------------- pills

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, required this.color, required this.background, this.icon});
  final String text;
  final Color color;
  final Color background;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Ico(icon!, taille: 15, couleur: color), const SizedBox(width: 6)],
        Text(text, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ----------------------------------------------------------------- states

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.text});
  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(40),
      children: [
        const SizedBox(height: 60),
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(shape: BoxShape.circle, color: p.primaireClair),
            child: Center(child: Ico(icon, taille: 44, couleur: p.primaire)),
          ),
        ),
        const SizedBox(height: 18),
        Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(color: p.texte2, fontSize: 15.5, height: 1.4)),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        Center(child: Ico('status_alert', taille: 56, couleur: p.alerte)),
        const SizedBox(height: 16),
        Text(errorText(context, error),
            textAlign: TextAlign.center, style: TextStyle(color: p.texte2, fontSize: 15.5)),
        const SizedBox(height: 20),
        Center(
          child: SizedBox(
            width: 200,
            child: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Ico('refresh', taille: 20),
              label: Text(context.t('retry')),
            ),
          ),
        ),
      ],
    );
  }
}

/// Banner shown while a request is slow (free server waking up).
class WakeBanner extends StatelessWidget {
  const WakeBanner({super.key, required this.listenable});
  final ValueNotifier<bool> listenable;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: listenable,
      builder: (context, waking, _) {
        if (!waking) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          color: p.alerteClair,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: p.alerte),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(context.t('server_waking'),
                  style: TextStyle(color: p.alerte, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ]),
        );
      },
    );
  }
}

/// Loads data, shows loading / error / content, pull-to-refresh included.
/// Keep a GlobalKey<AsyncBodyState<T>> to call `reload()` from outside.
class AsyncBody<T> extends StatefulWidget {
  const AsyncBody({super.key, required this.load, required this.builder});
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data) builder;

  @override
  State<AsyncBody<T>> createState() => AsyncBodyState<T>();
}

class AsyncBodyState<T> extends State<AsyncBody<T>> {
  T? _data;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    if (_data == null) setState(() => _loading = true);
    try {
      final data = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) return const LoadingView();
    if (_error != null && _data == null) return ErrorView(error: _error!, onRetry: reload);
    return RefreshIndicator(
      onRefresh: reload,
      child: widget.builder(context, _data as T),
    );
  }
}

String formatDate(BuildContext context, DateTime? d) {
  if (d == null) return '—';
  return dateOnly(d);
}

String formatDateTime(DateTime? d) {
  if (d == null) return '—';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dateOnly(d)}  ${two(d.hour)}:${two(d.minute)}';
}

/// Section title with the blue bar.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Row(children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(color: p.primaire, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

/// Round icon avatar (cow, admin, eleveur ...).
class AvatarIco extends StatelessWidget {
  const AvatarIco({super.key, required this.icon, this.size = 52, this.warning = false});
  final String icon;
  final double size;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: warning ? p.alerteClair : p.primaireClair,
      ),
      child: Center(
        child: Ico(icon, taille: size * 0.54, couleur: warning ? p.alerte : p.primaire),
      ),
    );
  }
}
