import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/models.dart';

/// Single entry point to the Kotlin code. No Flutter plugin is used for the
/// native modules; everything goes through these MethodChannels:
///
/// | Channel          | Module | Kotlin file          |
/// |------------------|--------|----------------------|
/// | nfc/tag          | M1     | NfcLecteur.kt        |
/// | qr/scanner       | -      | QrScanner.kt         |
/// | biometrie/auth   | -      | BiometrieLecteur.kt  |
/// | sync/planifier   | M2, M3 | CanalSync.kt         |
class CanauxNatifs {
  CanauxNatifs._();

  static const MethodChannel _nfc = MethodChannel('nfc/tag');
  static const MethodChannel _qr = MethodChannel('qr/scanner');
  static const MethodChannel _bio = MethodChannel('biometrie/auth');
  static const MethodChannel _sync = MethodChannel('sync/planifier');

  // ------------------------------------------------------------ M1: NFC
  static Future<bool> nfcDisponible() async =>
      await _nfc.invokeMethod<bool>('disponible') ?? false;

  /// Waits for a tag. Returns its UID as hex (e.g. 3C43FA39) or null if
  /// cancelled. Throws [PlatformException] (NFC_ABSENT, NFC_DESACTIVE,
  /// DELAI_DEPASSE...).
  static Future<String?> lireUidNfc({int delaiSec = 30}) async {
    final data = await _nfc.invokeMapMethod<String, dynamic>('lire', {'delai': delaiSec});
    final uid = data?['uid'];
    if (uid is! String || uid.isEmpty) return null;
    return uid.replaceAll(':', '').toUpperCase();
  }

  static Future<void> annulerNfc() => _nfc.invokeMethod<void>('annuler');
  static Future<void> ouvrirParametresNfc() => _nfc.invokeMethod<void>('parametres');

  // ------------------------------------------------------------- QR code
  /// Text of the scanned QR, or null if the person closed the scanner.
  static Future<String?> scannerQr() => _qr.invokeMethod<String>('scanner');

  // --------------------------------------------------------- fingerprint
  static Future<bool> empreinteDisponible() async {
    try {
      return await _bio.invokeMethod<bool>('disponible') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// true = recognised, false = cancelled. Throws [PlatformException] on error.
  static Future<bool> authentifier({
    required String titre,
    required String sousTitre,
    required String annuler,
  }) async =>
      await _bio.invokeMethod<bool>(
          'authentifier', {'titre': titre, 'sous_titre': sousTitre, 'annuler': annuler}) ??
      false;

  // ------------------------------------- M2: background alert (WorkManager)
  /// true if notifications are allowed (asks the system on Android 13+).
  static Future<bool> demanderPermissionNotifications() async =>
      await _sync.invokeMethod<bool>('demanderPermission') ?? false;

  static Future<bool> notificationsAutorisees() async =>
      await _sync.invokeMethod<bool>('permissionAccordee') ?? false;

  /// Plans the hourly check (even if the app is closed). The Kotlin worker
  /// calls the server itself with this address + token.
  static Future<void> planifier({
    required String baseUrl,
    required String token,
    required int seuilPct,
    required String langue,
  }) =>
      _sync.invokeMethod<void>('planifier', {
        'base_url': baseUrl,
        'token': token,
        'seuil_pct': seuilPct,
        'langue': langue,
      });

  static Future<void> annulerPlanification() => _sync.invokeMethod<void>('annuler');

  /// One immediate check. [silencieux] = refresh data + widget, no notification.
  static Future<void> verifierMaintenant({bool silencieux = false}) =>
      _sync.invokeMethod<void>('verifierMaintenant', {'silencieux': silencieux});

  // ------------------------------------------ bonus: thresholds + offline
  static Future<int> lireSeuil() async => await _sync.invokeMethod<int>('lireSeuil') ?? 50;
  static Future<void> definirSeuil(int pct) =>
      _sync.invokeMethod<void>('definirSeuil', {'seuil_pct': pct});

  static Future<void> definirLangue(String code) =>
      _sync.invokeMethod<void>('definirLangue', {'langue': code});

  static Future<List<LastMeasure>> dernieresMesures() async {
    final raw = await _sync.invokeMethod<String>('dernieresMesures');
    if (raw == null || raw.isEmpty) return const [];
    try {
      final data = jsonDecode(raw);
      if (data is! List) return const [];
      return [
        for (final e in data)
          if (e is Map) LastMeasure.fromJson(Map<String, dynamic>.from(e))
      ];
    } catch (_) {
      return const [];
    }
  }

  // ------------------------------------------- opening from a notification
  /// Cow id of the notification tapped while the app was closed (cold start).
  static Future<String?> actionInitiale() => _sync.invokeMethod<String>('actionInitiale');

  /// Notification tapped while the app is already open (warm start).
  static void ecouterActions(void Function(String cowId) onCow) {
    _sync.setMethodCallHandler((call) async {
      if (call.method == 'surAction' && call.arguments is String) {
        onCow(call.arguments as String);
      }
      return null;
    });
  }
}
