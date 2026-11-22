import 'package:flutter/services.dart';

/// Single entry point to the Kotlin code (channel "nfc/tag").
class CanauxNatifs {
  CanauxNatifs._();

  static const MethodChannel _nfc = MethodChannel('nfc/tag');

  static Future<bool> nfcDisponible() async =>
      await _nfc.invokeMethod<bool>('disponible') ?? false;

  /// Waits for a tag. Returns its UID as 8 hex chars (e.g. 3C43FA39),
  /// or null if cancelled. Throws [PlatformException] (NFC_ABSENT,
  /// NFC_DESACTIVE, DELAI_DEPASSE...).
  static Future<String?> lireUidNfc({int delaiSec = 30}) async {
    final data = await _nfc.invokeMapMethod<String, dynamic>('lire', {'delai': delaiSec});
    final uid = data?['uid'];
    if (uid is! String || uid.isEmpty) return null;
    return uid.replaceAll(':', '').toUpperCase();
  }

  static Future<void> annulerNfc() => _nfc.invokeMethod<void>('annuler');
  static Future<void> ouvrirParametresNfc() => _nfc.invokeMethod<void>('parametres');
}
