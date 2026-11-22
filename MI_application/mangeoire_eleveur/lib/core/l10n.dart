import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'strings.dart';

/// French (default) and Arabic (right-to-left). Switchable at any time.
class AppL10n {
  AppL10n(this.locale);
  final Locale locale;

  static const supported = [Locale('fr'), Locale('ar')];

  bool get isAr => locale.languageCode == 'ar';

  static AppL10n of(BuildContext context) =>
      Localizations.of<AppL10n>(context, AppL10n) ?? AppL10n(const Locale('fr'));

  String t(String key, [Map<String, String>? args]) {
    final table = isAr ? stringsAr : stringsFr;
    var text = table[key] ?? stringsFr[key] ?? key;
    if (args != null) {
      args.forEach((k, v) => text = text.replaceAll('{$k}', v));
    }
    return text;
  }
}

class AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const AppL10nDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppL10n.supported.any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppL10n> load(Locale locale) => SynchronousFuture<AppL10n>(AppL10n(locale));

  @override
  bool shouldReload(AppL10nDelegate old) => false;
}

extension L10nContext on BuildContext {
  String t(String key, [Map<String, String>? args]) => AppL10n.of(this).t(key, args);
  bool get isAr => AppL10n.of(this).isAr;
}

/// Holds the current language; persisted on the phone.
class LangController {
  LangController._();
  static final LangController instance = LangController._();

  final ValueNotifier<Locale> locale = ValueNotifier<Locale>(const Locale('fr'));

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString('lang');
      if (code == 'ar' || code == 'fr') locale.value = Locale(code!);
    } catch (_) {}
  }

  Future<void> set(String code) async {
    locale.value = Locale(code);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lang', code);
    } catch (_) {}
  }
}
