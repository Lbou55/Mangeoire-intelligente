import 'package:shared_preferences/shared_preferences.dart';

import '../native/canaux.dart';

/// Fingerprint lock preference (on by default when the phone has a fingerprint).
class Securite {
  Securite._();
  static const _cle = 'lock_fingerprint';

  static Future<bool> activeeParUtilisateur() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_cle) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> definir(bool actif) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_cle, actif);
    } catch (_) {}
  }

  /// True if the app must ask for the fingerprint when it opens.
  static Future<bool> verrouillageActif() async {
    if (!await activeeParUtilisateur()) return false;
    return CanauxNatifs.empreinteDisponible();
  }
}
