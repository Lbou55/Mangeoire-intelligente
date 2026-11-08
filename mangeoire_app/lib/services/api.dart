import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

/// Une erreur renvoyée par le serveur (ou par le réseau) avec un message en français.
class ApiException implements Exception {
  ApiException(this.code, this.message);

  final int code; // 0 = pas de réponse du serveur
  final String message;

  @override
  String toString() => message;
}

/// Parle au serveur FastAPI : ajoute le jeton de connexion et décode le JSON.
class ApiClient {
  String? token;

  /// Appelée quand le serveur répond 401 alors qu'on était connecté (session expirée).
  void Function()? onNonAutorise;

  Uri _url(String chemin, [Map<String, String>? query]) =>
      Uri.parse('$apiBase/api$chemin').replace(queryParameters: query);

  Map<String, String> get _entetes => {
        'Content-Type': 'application/json; charset=utf-8',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> _envoyer(Future<http.Response> Function() requete) async {
    http.Response r;
    try {
      r = await requete().timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw ApiException(0, 'Le serveur ne répond pas.');
    } catch (_) {
      throw ApiException(0, 'Impossible de joindre le serveur. Vérifiez la connexion.');
    }
    final texte = utf8.decode(r.bodyBytes);
    final corps = texte.isEmpty ? null : jsonDecode(texte);
    if (r.statusCode >= 400) {
      if (r.statusCode == 401 && token != null) onNonAutorise?.call();
      var message = 'Erreur ${r.statusCode}';
      if (corps is Map && corps['detail'] is String) {
        message = corps['detail'] as String;
      } else if (corps is Map && corps['detail'] is List) {
        message = 'Vérifiez les champs saisis.';
      }
      throw ApiException(r.statusCode, message);
    }
    return corps;
  }

  Future<dynamic> get(String chemin, {Map<String, String>? query}) =>
      _envoyer(() => http.get(_url(chemin, query), headers: _entetes));

  Future<dynamic> post(String chemin, [Object? corps]) => _envoyer(() =>
      http.post(_url(chemin), headers: _entetes, body: jsonEncode(corps ?? {})));

  Future<dynamic> put(String chemin, [Object? corps]) => _envoyer(() =>
      http.put(_url(chemin), headers: _entetes, body: jsonEncode(corps ?? {})));

  Future<dynamic> delete(String chemin) =>
      _envoyer(() => http.delete(_url(chemin), headers: _entetes));
}
